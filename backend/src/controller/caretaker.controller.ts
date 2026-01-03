import { Request, Response } from "express";
import { asyncHandler } from "../utils/handler";
import prisma from "../config/Configs";

export const adoptPlant = asyncHandler(async (req: Request, res: Response) => {
  const userId = (req as any).user?.uid;
  const { plantId, careSchedule } = req.body;

  if (!userId || !plantId || !careSchedule || !Array.isArray(careSchedule)) {
    return res
      .status(400)
      .json({ error: "Missing plantId or valid careSchedule" });
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      
      const existing = await tx.plantCaretaker.findUnique({
        where: { userId_plantId: { userId, plantId } }
      });

      if (existing) {
        throw new Error("You are already taking care of this plant!");
      }

      // B. Create Caretaker Link
      const caretaker = await tx.plantCaretaker.create({
        data: {
          userId,
          plantId,
          role: "GUARDIAN",
          joinedAt: new Date(),
          currentStreak: 0,
          pointsEarned: 0
        }
      });

      const tasksData = careSchedule.map((task: any) => ({
        plantId,
        taskName: task.taskName || "General Care",
        action: task.action || "CHECK_IN",
        frequencyDays: task.frequencyDays || 1,
        xpReward: task.xpReward || 10,
        instruction: task.instruction || "",
        // Set first due date to TODAY so they can start immediately
        nextDueAt: new Date() 
      }));

      await tx.careTask.createMany({
        data: tasksData
      });

      return caretaker;
    });

    return res.status(200).json({ 
      message: "Success! You are now the Guardian.", 
      caretaker_profile: result 
    });

  } catch (error: any) {
    if (error.message.includes("already taking care")) {
        return res.status(409).json({ error: error.message });
    }
    console.error("Adoption Error:", error);
    return res.status(500).json({ error: "Failed to adopt plant" });
  }

});
