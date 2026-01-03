import express, { Router } from "express";
import { loginController, registerController } from "../controller/auth.controller";
import { verifyToken } from "../middleware/auth.middleware";

const AuthRouter: Router = express.Router();

// Both login and register require the user to be authenticated with Firebase first
// to extract the UID and email from the token.
AuthRouter.route("/login").post(verifyToken, loginController);
AuthRouter.route("/register").post(verifyToken, registerController);

export default AuthRouter;
