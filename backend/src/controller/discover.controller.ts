import { Request, Response } from "express";
import { asyncHandler } from "../utils/handler";
import { ai, imagekit } from "../config/Configs"; 
import prisma from "../config/Configs"; 

export const AnalyzeAndUpload = asyncHandler(
  async (req: Request, res: Response) => {
    const file = req.file;
    const userId = (req as any).user?.uid;
    
    const latitude = parseFloat(req.body.latitude);
    const longitude = parseFloat(req.body.longitude);

    const district = req.body.district || "Unknown District"; 
    const state = req.body.state || "Unknown State";
    const country = req.body.country || "India";

    if (!file) return res.status(400).json({ error: "No image provided" });
    if (!userId) return res.status(401).json({ error: "Unauthorized" });
    
    // Fix MIME
    let mimeType = file.mimetype;
    if (mimeType === "application/octet-stream") mimeType = "image/jpeg";

    // --- 2. PREPARE LOCATION CONTEXT ---
    
    // A. Create a readable string for Gemini (e.g. "Rourkela, Odisha, India")
    // This tells the AI EXACTLY where the plant is.
    const locationContext = `${district}, ${state}, ${country}`;
    
    // B. Generate a consistent Database ID (e.g. "IN_OD_ROURKELA")
    // We sanitize strings to ensure "Rourkela" and "rourkela " are treated as the same ID.
    const cleanId = (str: string) => str.toUpperCase().replace(/[^A-Z0-9]/g, "").substring(0, 3);
    const cleanDistrict = district.toUpperCase().replace(/[^A-Z0-9]/g, "");
    
    // ID Format: IN_OD_ROURKELA
    const districtId = `${cleanId(country)}_${cleanId(state)}_${cleanDistrict}`;

    console.log(`🚀 Analyzing for: ${locationContext} (ID: ${districtId})`);


    const uploadPromise = imagekit.upload({
      file: file.buffer,
      fileName: `geo_${Date.now()}_${userId}.jpg`,
      folder: "/geoquest/discoveries",
    });

    const analysisPromise = (async () => {
      const modelId = "gemini-flash-lite-latest"; 
      
      const complexPrompt = `
        Analyze this image strictly.
        
        CONTEXT:
        - Found in: ${locationContext}
        - Coordinates: ${latitude}, ${longitude}
        
        TASKS:
        1. Identify the plant. If NOT a plant, return null.
        2. imageSourceConfidence MUST sum to 1.0.
        3. Estimate rarity specifically for the region "${locationContext}".
           (Example: A Coconut tree is 'Common' in Odisha, but 'Rare' in Delhi).
        
        Return JSON exactly:
        {
          "isPlant": true,
          "commonName": "string",
          "scientificName": "string",
          "description": "Short interesting fact",
          "confidence": 0.95,
          "imageSourceConfidence": { "realPlant": 0.0, "screenOrPhoto": 0.0 },
          "rarity": {
            "score": 0, 
            "level": "Common", 
            "locality": "${locationContext}",
            "note": "Short reason" 
          },
          "healthStatus": "HEALTHY", 
          "growingTips": {
            "wateringPerDay": "string",
            "sunlight": "string",
            "easyCareTips": "string"
          }
        }
        *Note: Rarity Score 0 (Very Common) to 10 (Endangered).*
        *HealthStatus: HEALTHY, WILTED, DORMANT, DISEASED.*
      `;

      const response = await ai.models.generateContent({
        model: modelId,
        contents: [{
            role: "user",
            parts: [
              { inlineData: { mimeType, data: file.buffer.toString("base64") } },
              { text: complexPrompt }
            ]
        }],
        config: { responseMimeType: "application/json" },
      });

      const jsonText = response.text || response.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
      return JSON.parse(jsonText);
    })();

    const [uploadResult, aiResult] = await Promise.all([uploadPromise, analysisPromise]);

    if (!aiResult.isPlant || aiResult.confidence < 0.6) {
      return res.status(400).json({ error: "Not a plant", details: aiResult });
    }
    if (aiResult.imageSourceConfidence?.screenOrPhoto > 0.6) {
        return res.status(400).json({ error: "Anti-Cheat: Screen detected", details: aiResult });
    }

    
    await prisma.district.upsert({
        where: { id: districtId },
        create: { 
            id: districtId,
            country: country,
            state: state,
            district: district
        },
        update: {}
    });

    const dbResult = await prisma.$transaction(async (tx) => {
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

        const aiScore = aiResult.rarity?.score || 0; 
        const generalMultiplier = Math.max(1, aiScore); 

        const rarityRecord = await tx.districtObjectRarity.findUnique({
            where: { districtId_objectId: { districtId: districtId, objectId: object.id } }
        });
        
        const currentCount = rarityRecord ? rarityRecord.discoveryCount : 0;
        let localMultiplier = 1.0;
        let localStatus = "COMMON";
        
        if (currentCount === 0) {
            localMultiplier = 5.0; 
            localStatus = "NEW";
        } else if (currentCount < 10) {
            localMultiplier = 2.0;
            localStatus = "RARE";
        }

        const finalMultiplier = generalMultiplier * localMultiplier;
        const xpEarned = Math.floor(50 * finalMultiplier);

        const discovery = await tx.discovery.create({
            data: {
                userId,
                objectId: object.id,
                districtId: districtId,
                latitude,
                longitude,
                imageUrl: uploadResult.url,
                aiConfidence: aiResult.confidence,
                rarityScore: finalMultiplier,
                verified: true
            }
        });

        const plant = await tx.plant.create({
            data: {
                discoveryId: discovery.id,
                objectId: object.id,
                latitude,
                longitude,
                healthScore: aiResult.healthStatus === "HEALTHY" ? 100 : 50,
                status: aiResult.healthStatus || "HEALTHY",
            }
        });

        await tx.districtObjectRarity.upsert({
            where: { districtId_objectId: { districtId: districtId, objectId: object.id } },
            create: { districtId: districtId, objectId: object.id, discoveryCount: 1 },
            update: { discoveryCount: { increment: 1 } }
        });

        const currentUser = await tx.user.findUnique({ where: { id: userId } });
        const newTotalXp = (currentUser?.xp || 0) + xpEarned;
        const newLevel = Math.floor(1 + (newTotalXp / 1000));

        const updatedUser = await tx.user.update({
            where: { id: userId },
            data: { xp: newTotalXp, totalDiscoveries: { increment: 1 }, level: newLevel }
        });

        return { discovery, plant, xpEarned, updatedUser, localStatus, generalLevel: aiResult.rarity?.level };
    });

    return res.status(200).json({
      message: "Discovery Successful!",
      image_url: uploadResult.url,
      plant_data: aiResult,
      game_data: {
          xp_earned: dbResult.xpEarned,
          new_total_xp: dbResult.updatedUser.xp,
          level: dbResult.updatedUser.level,
          rarity_badge: {
             local: dbResult.localStatus,
             global: dbResult.generalLevel
          },
          plant_id: dbResult.plant.id
      }
    });
  }
);