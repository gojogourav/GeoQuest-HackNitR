import express, { Express } from "express";
import cors from "cors";
import cookieParser from "cookie-parser";
import { env } from "./config/env";
import AuthRouter from "./routes/auth.routes";
import discoveryRouter from "./routes/discover.routes";
import dailyCareRouter from "./routes/dailyCare.routes";
import UserRouter from "./routes/user.routes";
import { errorHandler } from "./middleware/error.middleware";

const app: Express = express();

const PORT = env.PORT;

// Middleware
app.use(
  cors({
    origin: true, // TODO: restricting this to the frontend URL in production is better security
    credentials: true,
  })
);
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));
app.use(cookieParser());

// Logging Middleware
app.use((req, res, next) => {
  console.log(`Incoming Request: ${req.method} ${req.url}`);
  next();
});

// Health Check
app.get("/health", (_, res) => {
  res.json({ status: "ok", timestamp: new Date() });
});

// Routes
app.use("/api/auth", AuthRouter);
app.use("/api/discover", discoveryRouter);
app.use("/api/care", dailyCareRouter);
app.use("/api/user", UserRouter);

// Error Handling (Must be last)
app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`Server starting at - http://localhost:${PORT}`);
});

