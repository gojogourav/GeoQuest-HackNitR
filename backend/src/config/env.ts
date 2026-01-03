import "dotenv/config";

const getEnvParam = (key: string): string => {
  const value = process.env[key];
  if (!value) {
    throw new Error(`MISSING ENV VARIABLE: ${key}`);
  }
  return value;
};

export const env = {
  PORT: Number(process.env.PORT) || 5000,
  DATABASE_URL: getEnvParam("DATABASE_URL"),
  // JWT_SECRET is legacy/unused if we use Firebase, but I'll keep it safe if needed, checking lazily or optionally
  JWT_SECRET: process.env.JWT_SECRET || "default_secret_dev_only",
};
