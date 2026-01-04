import { Router } from "express";
import multer from "multer";
import { verifyDailyCare } from "../controller/dailycare.controller";
import { verifyToken } from "../middleware/auth.middleware";

const dailyCareRouter: Router = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 }, // Limit to 15MB
});

dailyCareRouter.post(
  "/verify",
  verifyToken,
  upload.single("photo"),
  verifyDailyCare
);

export default dailyCareRouter;
