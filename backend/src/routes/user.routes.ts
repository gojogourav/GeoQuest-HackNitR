import express, { Router } from "express";
import { getLeaderboard, getMyProfile, getMyGarden } from "../controller/user.controller";
import { verifyToken } from "../middleware/auth.middleware";

const UserRouter: Router = express.Router();

UserRouter.route("/profile").get(verifyToken, getMyProfile);
UserRouter.route("/leaderboard").get(verifyToken, getLeaderboard);
UserRouter.route("/garden").get(verifyToken, getMyGarden);

export default UserRouter;
