export const env = {
  DATABASE_URL: process.env.DATABASE_URL as string,
  LINE_CLIENT_ID: process.env.LINE_CLIENT_ID as string,
  LINE_CLIENT_SECRET: process.env.LINE_CLIENT_SECRET as string,
  LINE_CALLBACK_URL: process.env.LINE_CALLBACK_URL as string,
  JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET as string,
  JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET as string,
  PADDLE_OCR_URL: process.env.PADDLE_OCR_URL || "http://localhost:8866/predict/ocr_system",
  SLIPOK_API_KEY: process.env.SLIPOK_API_KEY || "",
  SLIPOK_BRANCH_ID: process.env.SLIPOK_BRANCH_ID || "",
  LINE_CHANNEL_ACCESS_TOKEN: process.env.LINE_CHANNEL_ACCESS_TOKEN || "",
  PORT: process.env.PORT ? parseInt(process.env.PORT, 10) : 3000,
};

// Validate required environment variables
const requiredEnvVars: (keyof typeof env)[] = [
  "DATABASE_URL",
  "LINE_CLIENT_ID",
  "LINE_CLIENT_SECRET",
  "LINE_CALLBACK_URL",
  "JWT_ACCESS_SECRET",
  "JWT_REFRESH_SECRET",
];

for (const key of requiredEnvVars) {
  if (!env[key]) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
}
