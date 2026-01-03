import { Request, Response, NextFunction } from "express";
import { admin } from "../config/Configs";

export interface AuthenticatedRequest extends Request {
  user?: {
    uid: string;
    email?: string | undefined;
  };
}

export const verifyToken = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const token = req.headers.authorization?.split(" ")[1];

  if (!token) {
    // For now, checking if we are in a dev environment without strict auth
    // But logically, if verifyToken is called, we expect a token.
    return res.status(401).json({ message: "Unauthorized: No token provided" });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    (req as AuthenticatedRequest).user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
    };
    next();
  } catch (error) {
    console.error("Token verification failed:", error);
    return res.status(401).json({ message: "Unauthorized: Invalid token" });
  }
};
