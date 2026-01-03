import { Router } from "express";
import multer from "multer";
import { AnalyzeAndUpload, getAllDiscoveries, getUserDiscoveries } from "../controller/discover.controller";
import { verifyToken } from "../middleware/auth.middleware";

const discoveryRouter: Router = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // Limit to 5MB
});

// Protect scan and user-specific discoveries
discoveryRouter.post(
  "/scan",
  verifyToken,
  upload.single("photo"),
  AnalyzeAndUpload
);

// Feed can be public
discoveryRouter.get("/feed", getAllDiscoveries);

// My discoveries must be authenticated
discoveryRouter.get("/my-discoveries", verifyToken, getUserDiscoveries);

export default discoveryRouter;
