import { Request, Response } from "express";
import { asyncHandler } from "../utils/handler";
import prisma from "../config/Configs";

export const getMyGarden = asyncHandler(async (req: Request, res: Response) => {
  const userId = (req as any).user?.uid;

  const garden = await prisma.plantCaretaker.findMany({
    where: { userId },
    include: {
      plant: {
        include: {
          object: true, // To get the Plant Name (commonName)
          tasks: {      // To get the "To-Do List"
            where: {
                nextDueAt: { lte: new Date() } 
            }
          }
        }
      }
    }
  });

  
  const formattedGarden = garden.map(item => ({
    plant_id: item.plantId,
    name: item.plant.object.commonName,
    health: item.plant.healthScore,
    streak: item.currentStreak,
    tasks_due: item.plant.tasks // The frontend can loop this list to show buttons
  }));

  res.json({ garden: formattedGarden });
});

export const getLeaderboard = asyncHandler(async (req: Request, res: Response) => {
  // Simple Top 10 by XP
  const leaders = await prisma.user.findMany({
    take: 10,
    orderBy: { xp: 'desc' },
    select: {
      username: true,
      photoUrl: true,
      xp: true,
      level: true,
      totalDiscoveries: true
    }
  });

  res.json({ leaderboard: leaders });
});