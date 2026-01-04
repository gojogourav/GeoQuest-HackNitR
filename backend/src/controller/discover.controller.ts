import { Request, Response } from "express";
import { asyncHandler } from "../utils/handler";
import { ai, imagekit } from "../config/Configs";
import prisma from "../config/Configs";

export const AnalyzeAndUpload = asyncHandler(
  async (req: Request, res: Response) => {
    // 1. Handle Image Input (File or Base64)
    let fileBuffer: Buffer | undefined;
    let mimeType: string = "image/jpeg";

    if (req.file) {
      fileBuffer = req.file.buffer;
      mimeType = req.file.mimetype;
    } else if (req.body.image) {
      try {
        const base64Data = req.body.image.replace(/^data:image\/\w+;base64,/, "");
        fileBuffer = Buffer.from(base64Data, 'base64');
      } catch (e) {
        return res.status(400).json({ error: "Invalid Base64 Image" });
      }
    }

    if (!fileBuffer) {
      return res.status(400).json({ error: "No image provided. Send 'photo' file or 'image' base64 string." });
    }

    const userId = (req as any).user?.uid;
    const { latitude, longitude, district, state, country } = req.body;

    if (!userId) return res.status(401).json({ error: "Unauthorized" });

    const locationContext = `${district || "Unknown"}, ${state || "Unknown"}, ${country || "India"}`;
    // ID: IN_OD_ROURKELA
    const cleanId = (s: string) => s?.toUpperCase().replace(/[^A-Z0-9]/g, "").substring(0, 3) || "UNK";
    const cleanDist = district?.toUpperCase().replace(/[^A-Z0-9]/g, "") || "UNKNOWN";
    const districtId = `${cleanId(country)}_${cleanId(state)}_${cleanDist}`;

    console.log(` Generating Habit Schedule for: ${locationContext}`);

    const uploadPromise = imagekit.upload({
      file: fileBuffer,
      fileName: `geo_${Date.now()}_${userId}.jpg`,
      folder: "/geoquest/discoveries",
    });

    const analysisPromise = (async () => {
      const modelId = "gemini-flash-lite-latest";

      const questPrompt = `
        Analyze this image strictly as a Game Master & Botanist.
        
        CONTEXT:
        - Location: ${locationContext}
        - User Goal: Restore plant health & gain XP.
        
        TASKS:
        1. Identify the plant.
        2. Assess Health (0-100 score).
        3. Generate exactly 5 distinct "Habit Schedule" tasks (Quests) SPECIFIC to this identified species (e.g. Cactus vs Fern).
        4. IMAGE SOURCE CHECK: Determine if this image is a direct photo of a real plant OR a photo of a screen/digital display/photo.
        5. NAMING: Provide a "canonicalName" which is the most common, broad English name (e.g. use "Money Plant" for Epipremnum aureum, not "Devil's Ivy").

        CRITICAL RULES:
        - strictly analyze the image and determine if it is a direct photo of a real plant OR a photo of a screen/digital display/photo.
        - If the image looks like it was taken from a screen, monitor, or is a photo of another photo:
          -> SET "confidence" to < 0.4 (PENALIZE HEAVILY).
          -> Set "imageSourceConfidence.realPlant" to < 0.2.
          -> Set "imageSourceConfidence.screenOrPhoto" to > 0.8.
        - If it is a real, direct photo of a plant:
          -> "confidence" can be high.
        
        Return JSON exactly:
        {
          "isPlant": true,
          "commonName": "string",
          "canonicalName": "string",
          "scientificName": "string",
          "description": "string",
          "confidence": 0.95,
          "imageSourceConfidence": { "realPlant": 0.0, "screenOrPhoto": 0.0 },
          "rarity": { "score": 0, "level": "Common", "locality": "${locationContext}" },
          
          "health": {
             "status": "HEALTHY" | "WILTED" | "DISEASED",
             "score": 85, 
             "diagnosis": "Leaves are yellowing due to overwatering."
          },

          "careSchedule": [
            {
              "taskName": "Morning Sip",
              "action": "WATER",
              "frequencyDays": 2,
              "timeOfDay": "Morning",
              "difficulty": "EASY",
              "xpReward": 15,
              "instruction": "Water until soil is moist but not soggy."
            },
            {
              "taskName": "Nutrient Boost",
              "action": "FERTILIZE",
              "frequencyDays": 14,
              "difficulty": "MEDIUM",
              "xpReward": 50,
              "instruction": "Apply balanced liquid fertilizer."
            }
          ]
        }
      `;

      const response = await ai.models.generateContent({
        model: modelId,
        contents: [{
          role: "user",
          parts: [
            { inlineData: { mimeType: (mimeType === "application/octet-stream" ? "image/jpeg" : mimeType) || "image/jpeg", data: fileBuffer.toString("base64") } },
            { text: questPrompt }
          ]
        }],
        config: { responseMimeType: "application/json" },
      });

      const jsonText = response.text || response.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
      const cleaned = jsonText.replace(/```json|```/g, "").trim(); // Fix Markdown issues
      try {
        const parsed = JSON.parse(cleaned);
        console.log(`[DEBUG] AI Analysis Result: Plant=${parsed.isPlant}, Tasks=${parsed.careSchedule?.length || 0}`);
        return parsed;
      } catch (e) {
        console.error("AI Parse Error in Discover:", e, "Raw:", jsonText);
        throw new Error("Failed to parse AI response");
      }
    })();

    const [uploadResult, aiResult] = await Promise.all([uploadPromise, analysisPromise]);

    if (!aiResult.isPlant || aiResult.confidence < 0.6) {
      return res.status(400).json({ error: "Not a plant", details: aiResult });
    }


    await prisma.district.upsert({
      where: { id: districtId },
      create: { id: districtId, country, state, district },
      update: {}
    });

    // Validating User Existence (Self-Healing)
    let userExists = await prisma.user.findUnique({ where: { id: userId } });
    if (!userExists) {
      console.log(` User ${userId} not found. Creating fallback profile...`);
      const email = (req as any).user?.email;
      const emailPrefix = email ? email.split("@")[0] : "explorer";
      const randomSuffix = Math.floor(1000 + Math.random() * 9000);

      try {
        userExists = await prisma.user.create({
          data: {
            id: userId,
            email: email || `unknown_${userId}@geoquest.com`,
            username: `${emailPrefix}_${randomSuffix}`,
            name: emailPrefix,
            joinedAt: new Date(),
          }
        });
      } catch (err) {
        // Handle race condition where user might be created in parallel
        console.error("Error creating fallback user:", err);
        // Try fetching again to be safe
        userExists = await prisma.user.findUnique({ where: { id: userId } });
        if (!userExists) return res.status(500).json({ error: "User synchronization failed." });
      }
    }

    const dbResult = await prisma.$transaction(async (tx) => {
      // A. Find/Create Species
      let object = await tx.object.findFirst({
        where: { commonName: { equals: aiResult.commonName, mode: "insensitive" } }
      });

      if (!object) {
        object = await tx.object.create({
          data: {
            category: "Plant",
            commonName: aiResult.commonName,
            scientificName: aiResult.scientificName,
            description: aiResult.description,
            verified: true
          }
        });
      }

      // ANTI-SPAM CHECK: User + Species + Location (20m radius)
      const lat = parseFloat(latitude);
      const lng = parseFloat(longitude);
      const threshold = 0.0002; // Approx 20-30m

      const existingNearby = await tx.discovery.findFirst({
        where: {
          userId,
          objectId: object.id,
          latitude: { gte: lat - threshold, lte: lat + threshold },
          longitude: { gte: lng - threshold, lte: lng + threshold }
        }
      });

      if (existingNearby) {
        // Return a special flag to handle outside
        return { duplicate: true, existing: existingNearby };
      }

      // B. Rarity & XP Logic
      const aiScore = aiResult.rarity?.score || 0;
      const generalMultiplier = Math.max(1, aiScore);

      const rarityRecord = await tx.districtObjectRarity.findUnique({
        where: { districtId_objectId: { districtId, objectId: object.id } }
      });

      const currentCount = rarityRecord ? rarityRecord.discoveryCount : 0;
      let localMultiplier = currentCount === 0 ? 5.0 : (currentCount < 10 ? 2.0 : 1.0);

      const finalMultiplier = generalMultiplier * localMultiplier;
      const xpEarned = Math.floor(50 * finalMultiplier);

      // C. Save Discovery
      const discovery = await tx.discovery.create({
        data: {
          userId,
          objectId: object.id,
          districtId,
          latitude: parseFloat(latitude),
          longitude: parseFloat(longitude),
          imageUrl: uploadResult.url,
          aiConfidence: aiResult.imageSourceConfidence?.realPlant ?? aiResult.confidence, // Save REALNESS score
          rarityScore: finalMultiplier,
          verified: true
        }
      });

      // D. CREATE PLANT & SAVE HABITS 
      // We save the AI-generated schedule into the plant's description or a JSON field 
      // so the frontend can load it later.
      const plant = await tx.plant.create({
        data: {
          discoveryId: discovery.id,
          objectId: object.id,
          latitude: parseFloat(latitude),
          longitude: parseFloat(longitude),
          healthScore: aiResult.health?.score || 100,
          status: aiResult.health?.status || "HEALTHY",
        }
      });

      // Save care schedule immediately
      if (aiResult.careSchedule && Array.isArray(aiResult.careSchedule)) {
         const tasksData = aiResult.careSchedule.map((task: any) => ({
            plantId: plant.id,
            taskName: task.taskName || "General Care",
            action: task.action || "CHECK_IN",
            frequencyDays: task.frequencyDays || 1,
            xpReward: task.xpReward || 10,
            instruction: task.instruction || "",
            // Not setting nextDueAt yet, will set on adoption
         }));
         
         await tx.careTask.createMany({ data: tasksData });
      }

      await tx.districtObjectRarity.upsert({
        where: { districtId_objectId: { districtId, objectId: object.id } },
        create: { districtId, objectId: object.id, discoveryCount: 1 },
        update: { discoveryCount: { increment: 1 } }
      });

      const currentUser = await tx.user.findUnique({ where: { id: userId } });
      const newTotalXp = (currentUser?.xp || 0) + xpEarned;
      const newLevel = Math.floor(1 + (newTotalXp / 1000));

      const updatedUser = await tx.user.update({
        where: { id: userId },
        data: { xp: newTotalXp, totalDiscoveries: { increment: 1 }, level: newLevel }
      });

      return { discovery, plant, xpEarned, updatedUser, habits: aiResult.careSchedule };
    });

    if ((dbResult as any).duplicate) {
      return res.status(409).json({ 
        error: "You have already discovered this plant at this location! Explore further to find new ones." 
      });
    }

    const successData = dbResult as any;

    return res.status(200).json({
      message: "Discovery & Quest Generated!",
      image_url: uploadResult.url,
      plant_data: aiResult,
      game_data: {
        xp_earned: successData.xpEarned,
        new_total_xp: successData.updatedUser.xp,
        level: successData.updatedUser.level,
        plant_id: successData.plant.id,
        // SEND HABITS TO FRONTEND
        quests: successData.habits
      }
    });
  }
);



export const getAllDiscoveries = asyncHandler(
  async (req: Request, res: Response) => {
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 10;
    const skip = (page - 1) * limit;

    const discoveries = await prisma.discovery.findMany({
      skip: skip,
      take: limit,
      orderBy: { discoveredAt: 'desc' },
      include: {
        user: {
          select: { username: true, photoUrl: true, level: true }
        },
        object: {
          select: { commonName: true, scientificName: true, category: true }
        },
        district: {
          select: { district: true, state: true }
        }
      }
    });

    const totalCount = await prisma.discovery.count();

    res.status(200).json({
      success: true,
      data: discoveries,
      pagination: {
        current_page: page,
        total_pages: Math.ceil(totalCount / limit),
        total_items: totalCount
      }
    });
  }
);

export const getUserDiscoveries = asyncHandler(
  async (req: Request, res: Response) => {
    const userId = (req as any).user?.uid; // From token

    const discoveries = await prisma.discovery.findMany({
      where: { userId: userId },
      orderBy: { discoveredAt: 'desc' },
      include: {
        object: true,
        district: {
          select: { district: true }
        },
        plant: {
          select: { 
            id: true, 
            healthScore: true, 
            status: true,
            tasks: { // Return saved tasks for history adoption
              select: {
                taskName: true,
                action: true,
                frequencyDays: true,
                xpReward: true,
                instruction: true,
                // No need for id, just the data to display/adopt
              }
            }
          }
        }
      }
    });

    console.log(`[DEBUG] getUserDiscoveries: userId=${userId}, count=${discoveries.length}`);

    res.status(200).json({
      success: true,
      count: discoveries.length,
      data: discoveries
    });
  }
);