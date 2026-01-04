import { Request, Response } from "express";
import { asyncHandler } from "../utils/handler";
import { ai, imagekit } from "../config/Configs";
import prisma from "../config/Configs";
import { getWeatherContext } from "../utils/weather.helper";

export const verifyDailyCare = asyncHandler(
  async (req: Request, res: Response) => {
    const file = req.file;
    const userId = (req as any).user?.uid;
    // taskId is optional (e.g., if they just want to post a status update)
    const { plantId, taskId } = req.body;

    console.log(`[DEBUG] Verify Request: PlantId=${plantId}, TaskId=${taskId}, User=${userId}`);
    if (file) {
      console.log(`[DEBUG] File received: ${file.originalname}, Size: ${file.size}, Mime: ${file.mimetype}`);
    } else {
      console.error("[DEBUG] No file received!");
    }

    if (!file || !plantId || !userId) {
      return res.status(400).json({ error: "Photo and Plant ID required" });
    }

    const plant = await prisma.plant.findUnique({
        where: { id: plantId },
        select: { latitude: true, longitude: true, healthScore: true }
    });

    if (!plant) {
        console.error(`[DEBUG] Plant not found: ${plantId}`);
        return res.status(404).json({ error: "Plant not found" });
    }

    const [historyLogs, weatherContext] = await Promise.all([
        prisma.careLog.findMany({
            where: { plantId: plantId },
            orderBy: { createdAt: 'desc' },
            take: 3,
            select: { action: true, createdAt: true }
        }),
        getWeatherContext(plant.latitude, plant.longitude)
    ]);

    const historyText = historyLogs.length > 0 
      ? historyLogs.map(log => `- ${log.action} on ${new Date(log.createdAt).toLocaleDateString()}`).join("\n")
      : "No previous care history.";
    
    console.log(`[DEBUG] Uploading to ImageKit...`);

    let upload;
    try {
        upload = await imagekit.upload({
          file: file.buffer,
          fileName: `care_${plantId}_${Date.now()}.jpg`,
          folder: "/geoquest/care_logs",
        });
        console.log(`[DEBUG] ImageKit Upload Success: ${upload.url}`);
    } catch (uploadErr) {
        console.error("ImageKit Upload Failed:", uploadErr);
        return res.status(500).json({ error: "Image Upload Failed" });
    }
    

    //  https://api.openweathermap.org/data/2.5/weather?lat=44.34&lon=10.99&appid={API key} 

    const checkupPrompt = `
    Analyze this plant photo strictly as a Botanist.
    
    CONTEXT:
    The user has provided this recent care history for this plant:
    ${historyText}

    - Current Local Weather: ${weatherContext}
    
    TASKS:
    1. FIRST, check if the image is valid (visible plant, not black/blurry/random object).
    2. If Invalid, set validImage: false and provide reason.
    3. If Valid:
       - Estimate Health Score looking at leaves (0-100).
       - Give a status update.
       - Give a care tip.
    
    Return JSON exactly: 
    { 
      "validImage": true,
      "rejectionReason": null,
      "healthScore": 90, 
      "status": "Looking hydrated and happy!",
      "tip": "Since you watered yesterday, let the soil dry out for 2 more days."
    }
  `;

    const modelId = "gemini-flash-lite-latest";

    const response = await ai.models.generateContent({
      model: modelId,
      contents: [
        {
          role: "user",
          parts: [
            {
              inlineData: {
                mimeType: (file.mimetype === "application/octet-stream" ? "image/jpeg" : file.mimetype) || "image/jpeg",
                data: file.buffer.toString("base64"),
              },
            },
            { text: checkupPrompt },
          ],
        },
      ],
      config: { responseMimeType: "application/json" },
    });

    let healthData;
    const jsonText =
      response.text ||
      response.candidates?.[0]?.content?.parts?.[0]?.text ||
      "{}";
    
    // Clean markdown code blocks if present
    const cleanedJson = jsonText.replace(/```json|```/g, "").trim();

    try {
      healthData = JSON.parse(cleanedJson);
    } catch (e) {
      console.error("AI JSON Parse Error:", e, "Raw Text:", jsonText);
      // FAIL if we can't parse. Do not assume success for anti-cheat.
      return res.status(422).json({ error: "AI Analysis Failed. Please try a clearer photo." });
    }

    if (healthData.validImage === false) {
       console.log(`[DEBUG] Image Rejected: ${healthData.rejectionReason}`);
       return res.status(400).json({ error: healthData.rejectionReason || "Image not clear or not a plant." });
    }

    await prisma.$transaction(async (tx) => {
      await tx.plant.update({
        where: { id: plantId },
        data: { healthScore: healthData.healthScore },
      });

      if (taskId) {
        const task = await tx.careTask.findUnique({ where: { id: taskId } });
        if (task) {
          // Calculate next due date
          const nextDate = new Date();
          nextDate.setDate(nextDate.getDate() + task.frequencyDays);

          await tx.careTask.update({
            where: { id: taskId },
            data: {
              lastCompletedAt: new Date(),
              nextDueAt: nextDate,
            },
          });
        }
      }

      await tx.careLog.create({
        data: {
          userId,
          plantId,
          action: taskId ? "TASK_COMPLETE" : "DAILY_CHECKIN",
          photoUrl: upload.url,
          locationVerified: true,
        },
      });

      const xpReward = taskId ? 50 : 20;
      await tx.user.update({
        where: { id: userId },
        data: { xp: { increment: xpReward } },
      });

      // --- Streak Logic ---
      const caretaker = await tx.plantCaretaker.findUnique({
        where: { userId_plantId: { userId, plantId } }
      });

      if (caretaker) {
          const now = new Date();
          const lastLog = caretaker.lastLogDate;
          
          let newStreak = caretaker.currentStreak;

          if (lastLog) {
            // Check if last log was "yesterday"
            const yesterday = new Date(now);
            yesterday.setDate(yesterday.getDate() - 1);

            const isYesterday = 
                lastLog.getDate() === yesterday.getDate() &&
                lastLog.getMonth() === yesterday.getMonth() &&
                lastLog.getFullYear() === yesterday.getFullYear();
            
            const isToday = 
                lastLog.getDate() === now.getDate() &&
                lastLog.getMonth() === now.getMonth() &&
                lastLog.getFullYear() === now.getFullYear();

            if (isYesterday) {
                newStreak += 1;
            } else if (!isToday) {
                // If not yesterday and not today, steak breaks
                newStreak = 1;
            }
            // If isToday, streak remains same (already incremented for today)
          } else {
             newStreak = 1;
          }
          
          const newLongest = Math.max(newStreak, caretaker.longestStreak);

          await tx.plantCaretaker.update({
              where: { userId_plantId: { userId, plantId } },
              data: {
                  currentStreak: newStreak,
                  longestStreak: newLongest,
                  lastLogDate: now,
                  pointsEarned: { increment: 10 } // Bonus points for care
              }
          });
      }

    }, {
      maxWait: 5000,
      timeout: 20000 
    });

    res.json({
      message: "Care Verified!",
      health_update: healthData.status,
      xp_gained: taskId ? 50 : 20,
    });
  }
);
