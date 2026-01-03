import { Request, Response } from "express";
import { asyncHandler } from "../utils/handler";
import prisma from "../config/Configs";
import { AuthenticatedRequest } from "../middleware/auth.middleware";

export const loginController = asyncHandler(
  async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;

    // authReq.user is guaranteed by verifyToken middleware
    if (!authReq.user || !authReq.user.uid) {
      return res
        .status(401)
        .json({ message: "Unauthorized: User not identified" });
    }

    const { uid, email } = authReq.user;

    let user = await prisma.user.findUnique({
      where: { id: uid },
    });

    // Sync User: If not found, create a basic profile (Auto-Sign Up behavior)
    // This supports "Sign in with Google" flow where registration is implicit
    if (!user) {
      const emailPrefix = email ? email.split("@")[0] : "explorer";
      const randomSuffix = Math.floor(1000 + Math.random() * 9000);
      const generatedUsername = `${emailPrefix}_${randomSuffix}`;

      user = await prisma.user.create({
        data: {
          id: uid,
          email: email || "",
          username: generatedUsername,
          name: emailPrefix!,
        },
      });
    }

    res.status(200).json({
      success: true,
      message: "User synced successfully",
      data: user,
    });
  }
);

export const registerController = asyncHandler(
  async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;

    if (!authReq.user || !authReq.user.uid) {
      return res
        .status(401)
        .json({ message: "Unauthorized: No valid token found" });
    }

    const { uid, email } = authReq.user;
    const { username } = req.body;

    if (!username || username.length < 3) {
      return res.status(400).json({
        message: "Username is required and must be at least 3 characters",
      });
    }

    const existingUser = await prisma.user.findUnique({
      where: { id: uid },
    });

    if (existingUser) {
      return res.status(409).json({
        message: "User already registered. Please log in instead.",
      });
    }

    const isUsernameTaken = await prisma.user.findUnique({
      where: { username: username },
    });

    if (isUsernameTaken) {
      return res.status(409).json({
        message: "Username is already taken. Please choose another.",
      });
    }

    const newUser = await prisma.user.create({
      data: {
        id: uid,
        email: email || "",
        username: username,
        name: email?.split("@")[0] || "Explorer",
        joinedAt: new Date(),
      },
    });

    res.status(201).json({
      success: true,
      message: "User registered successfully",
      data: newUser,
    });
  }
);