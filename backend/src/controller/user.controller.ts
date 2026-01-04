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
          object: true, 
          tasks: {      
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
    tasks_due: item.plant.tasks 
  }));

  res.json({ garden: formattedGarden });
});

export const getMyProfile = asyncHandler(async (req: Request, res: Response) => {
  const userId = (req as any).user?.uid;

  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      _count: {
        select: { discoveries: true, caretakerProfiles: true }
      }
    }
  });

  if (!user) return res.status(404).json({ error: "User not found" });

  const rankCount = await prisma.user.count({
    where: { xp: { gt: user.xp } }
  });
  const myRank = rankCount + 1;

  res.json({
    user: {
      username: user.username,
      photoUrl: user.photoUrl,
      level: user.level,
      xp: user.xp,
      joinedAt: user.joinedAt,
      rank: myRank,
      stats: {
        total_discoveries: user._count.discoveries,
        plants_adopted: user._count.caretakerProfiles,
      }
    }
  });
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

export const getXPHistory = asyncHandler(async (req: Request, res: Response) => {
  const userId = (req as any).user?.uid;

  // 1. Fetch Discoveries (XP = 50 * rarityScore)
  const discoveries = await prisma.discovery.findMany({
    where: { userId },
    select: {
      id: true,
      discoveredAt: true,
      rarityScore: true,
      object: { select: { commonName: true } }
    },
    orderBy: { discoveredAt: 'desc' },
    take: 20
  });

  // 2. Fetch Care Logs (XP = 50 for TASK, 20 for CHECKIN)
  const careLogs = await prisma.careLog.findMany({
    where: { userId },
    select: {
      id: true,
      createdAt: true,
      action: true,
      plant: { select: { object: { select: { commonName: true } } } }
    },
    orderBy: { createdAt: 'desc' },
    take: 20
  });

  console.log(`[DEBUG] getXPHistory: userId=${userId}, discoveries=${discoveries.length}, logs=${careLogs.length}`);

  // 3. Normalize & Merge
  const discoveryItems = discoveries.map(d => ({
    type: "DISCOVERY",
    title: `Discovered a ${d.object.commonName}`,
    date: d.discoveredAt,
    xp: Math.floor(50 * d.rarityScore)
  }));

  const careItems = careLogs.map(c => {
    let xp = 20;
    let title = "Daily Check-in";
    
    if (c.action === "TASK_COMPLETE") {
      xp = 50;
      title = `Care Task for ${c.plant.object.commonName}`;
    } else if (c.action === "DAILY_CHECKIN") {
      title = `Check-in for ${c.plant.object.commonName}`;
    }

    return {
      type: "CARE",
      title: title,
      date: c.createdAt,
      xp: xp
    };
  });

  const history = [...discoveryItems, ...careItems].sort((a, b) => b.date.getTime() - a.date.getTime());

  res.json({ history });
});