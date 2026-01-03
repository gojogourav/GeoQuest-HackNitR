import { Request, Response } from "express";
import { asyncHandler } from "../utils/handler";
import { ai, imagekit } from "../config/Configs";
import prisma from "../config/Configs";

// 1. VERIFY CARE (The "Tamagotchi" Feed Mechanic)
export const verifyDailyCare = asyncHandler(async (req: Request, res: Response) => {
  const file = req.file;
  const userId = (req as any).user?.uid;
  // taskId is optional (e.g., if they just want to post a status update)
  const { plantId, taskId } = req.body; 

  if (!file || !plantId || !userId) {
    return res.status(400).json({ error: "Photo and Plant ID required" });
  }

  const upload = await imagekit.upload({
    file: file.buffer,
    fileName: `care_${plantId}_${Date.now()}.jpg`,
    folder: "/geoquest/care_logs"
  });

  const checkupPrompt = `
    Analyze this plant photo.
    1. Estimate Health Score (0-100).
    2. Give a 1-sentence status update (e.g. "Looking hydrated and happy!").
    3. Return JSON: { "healthScore": 90, "status": "Good" }
  `;


  //FIX THIS PART
//   const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
//   const aiRes = await model.generateContent([
//     checkupPrompt, 
//     { inlineData: { mimeType: file.mimetype || "image/jpeg", data: file.buffer.toString("base64") } }
//   ]);
  
  const healthData = JSON.parse(aiRes.response.text());

  // C. Update Database (XP, Health, Task Status)
  await prisma.$transaction(async (tx) => {
    
    // 1. Update Plant Health
    await tx.plant.update({
      where: { id: plantId },
      data: { healthScore: healthData.healthScore }
    });

    // 2. Mark Task as Done (If this was a specific task)
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
                    nextDueAt: nextDate 
                }
            });
        }
    }

    // 3. Log the Action
    await tx.careLog.create({
      data: {
        userId,
        plantId,
        action: taskId ? "TASK_COMPLETE" : "DAILY_CHECKIN",
        photoUrl: upload.url,
        locationVerified: true
      }
    });

    // 4. Give XP (50 for task, 20 for just checking in)
    const xpReward = taskId ? 50 : 20;
    await tx.user.update({
        where: { id: userId },
        data: { xp: { increment: xpReward } }
    });
  });

  res.json({ 
    message: "Care Verified!", 
    health_update: healthData.status,
    xp_gained: taskId ? 50 : 20
  });
});