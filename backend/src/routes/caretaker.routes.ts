import { Router } from "express";
import { verifyToken } from "../middleware/auth.middleware";
import { adoptPlant, getCareTasks } from "../controller/caretaker.controller";

const router:Router = Router();
// Body: { "plantId": "uuid...", "careSchedule": [...] }
router.post("/adopt", verifyToken, adoptPlant);

// Get tasks for a specific plant
router.get("/tasks/:plantId", verifyToken, getCareTasks);

export default router;