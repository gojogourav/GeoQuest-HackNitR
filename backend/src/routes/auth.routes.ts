import express, { Request, Response, Router } from "express";
import { loginController, registerController } from "../controller/auth.controller";


const AuthRouter:Router = express.Router();

AuthRouter.route("/login").post(loginController);


AuthRouter.route("/login").post(registerController);


export default AuthRouter;
