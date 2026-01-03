import ImageKit from "imagekit";
import { GoogleGenAI } from "@google/genai";
import { PrismaClient } from "@prisma/client";

export const imagekit = new ImageKit({
  publicKey: process.env.IMAGEKIT_PUBLIC_KEY!,
  privateKey: process.env.IMAGEKIT_PRIVATE_KEY!,
  urlEndpoint: process.env.IMAGEKIT_URL_ENDPOINT!,
});
export const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY! });

const prisma = new PrismaClient();

export default prisma;



export const prompt = `
Analyze this image strictly.

Rules:
1. Identify the plant if present.
2. If it is NOT a plant, return null.
3. Return ONLY a valid raw JSON object (no markdown, no comments).
4. imageSourceConfidence values MUST sum to 1.0 exactly.
   - realPlant = 1 - screenOrPhoto
   - Example: if screenOrPhoto is 0.7, realPlant must be 0.3
5. Estimate plant rarity based on the user's most probable local region
   (state or district inferred from latitude/longitude context [think for indian users accordingly]).

Return JSON with this exact structure:

{
  "isPlant": true,
  "commonName": "string",
  "scientificName": "string",
  "description": "Short interesting fact (max 12 sentences)",
  "confidence": 0.0,
  "imageSourceConfidence": {
    "realPlant": 0.0,
    "screenOrPhoto": 0.0
  },
  "rarity": {
    "score":"give a score from 0 to 10 where 0 is very common in that region 2 is common 5 is rare 7 is very rare and 10 is endangered"
    "level": "Very Common | Common | Occasional | Rare | Very Rare",
    "locality": "Most probable user state or district [if don,t know then set region to india]",
    "note": "Short explanation of how common or rare this plant is in that region [probably in india]"
  },
  "growingTips": {
    "wateringPerDay": "string",
    "wateringIntervalHours": "string",
    "sunlight": "Low | Medium | Bright indirect | Direct",
    "soil": "string",
    "easyCareTips": "string"
  }
}
`;


