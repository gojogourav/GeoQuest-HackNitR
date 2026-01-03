import ImageKit from "imagekit";
import { GoogleGenAI } from "@google/genai";
import { PrismaClient } from "@prisma/client";
import { Pool } from "pg";
import { PrismaPg } from "@prisma/adapter-pg";
import admin from "firebase-admin";
import { env } from "./env";

export const imagekit = new ImageKit({
  publicKey: process.env.IMAGEKIT_PUBLIC_KEY!,
  privateKey: process.env.IMAGEKIT_PRIVATE_KEY!,
  urlEndpoint: process.env.IMAGEKIT_URL_ENDPOINT!,
});
export const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY! });

// Initialize Firebase Admin
// Checks if already initialized to avoid hot-reload errors
if (!admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(), // Uses GOOGLE_APPLICATION_CREDENTIALS or default env
    });
    console.log("Firebase Admin Initialized");
  } catch (error) {
    console.error("Firebase Admin Initialization Failed:", error);
  }
}

const connectionString = env.DATABASE_URL;
const pool = new Pool({ connectionString });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

export default prisma;
export { admin };
