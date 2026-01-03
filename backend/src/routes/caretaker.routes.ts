import { Router } from "express";
import { verifyToken } from "../middleware/auth.middleware";
import { adoptPlant } from "../controller/caretaker.controller";

const router:Router = Router();

// 1. ADOPT PLANT
// Endpoint: POST /api/caretaker/adopt
// Body: { "plantId": "uuid...", "careSchedule": [...] }
router.post("/adopt", verifyToken, adoptPlant);

export default router;