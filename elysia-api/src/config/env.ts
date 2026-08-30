process.env.TZ = "Asia/Bangkok";

export const env = {
  TZ: "Asia/Bangkok",
  DATABASE_URL: process.env.DATABASE_URL as string,

  // ── LINE Mobile App Config ─────────────────────────────────────────
  LINE_MOBILE_CHANNEL_ID: (process.env.LINE_MOBILE_CHANNEL_ID || process.env.LINE_CLIENT_ID || process.env.LINE_CHANNEL_ID || "2011160144") as string,

  // ── LINE Web Console Config ────────────────────────────────────────
  LINE_WEB_CHANNEL_ID: (process.env.LINE_WEB_CHANNEL_ID || process.env.LINE_CLIENT_ID || process.env.LINE_CHANNEL_ID || "2011160144") as string,
  LINE_WEB_CHANNEL_SECRET: (process.env.LINE_WEB_CHANNEL_SECRET || process.env.LINE_CLIENT_SECRET || process.env.LINE_CHANNEL_SECRET || "") as string,
  LINE_WEB_CALLBACK_URL: (process.env.LINE_WEB_CALLBACK_URL || process.env.LINE_CALLBACK_URL || "http://localhost:3000/api/v1/auth/line/callback") as string,
  WEB_CONSOLE_URL: (process.env.WEB_CONSOLE_URL || "http://localhost:5173") as string,

  // ── Legacy Aliases (backward compatibility) ────────────────────────
  LINE_CLIENT_ID: (process.env.LINE_WEB_CHANNEL_ID || process.env.LINE_CLIENT_ID || process.env.LINE_CHANNEL_ID || "") as string,
  LINE_CHANNEL_ID: (process.env.LINE_WEB_CHANNEL_ID || process.env.LINE_CLIENT_ID || process.env.LINE_CHANNEL_ID || "") as string,
  LINE_CLIENT_SECRET: (process.env.LINE_WEB_CHANNEL_SECRET || process.env.LINE_CLIENT_SECRET || "") as string,
  LINE_CALLBACK_URL: (process.env.LINE_WEB_CALLBACK_URL || process.env.LINE_CALLBACK_URL || "http://localhost:3000/api/v1/auth/line/callback") as string,

  // ── JWT & Security ────────────────────────────────────────────────
  JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET || "pingpay-production-jwt-access-secret-key-fallback",
  JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || "pingpay-production-jwt-refresh-secret-key-fallback",

  // ── Email & OTP Services ──────────────────────────────────────────
  RESEND_API_KEY: process.env.RESEND_API_KEY || process.env.RESEND_API || "",
  EMAIL_FROM: process.env.EMAIL_FROM || "PingPay <onboarding@resend.dev>",
  SMTP_HOST: process.env.SMTP_HOST || "",
  SMTP_PORT: process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : 587,
  SMTP_USER: process.env.SMTP_USER || "",
  SMTP_PASS: process.env.SMTP_PASS || "",

  // ── Third-Party Services ──────────────────────────────────────────
  PADDLE_OCR_URL: process.env.PADDLE_OCR_URL || "http://localhost:8866/predict/ocr_system",
  AKSON_OCR_API_KEY: process.env.AKSON_OCR_API_KEY || "",
  AKSON_OCR_URL: process.env.AKSON_OCR_URL || "https://backend.aksonocr.com/api/v2/upload",
  EASYSLIP_API_KEY: process.env.EASYSLIP_API_KEY || process.env.SLIPOK_API_KEY || "",
  SLIPOK_API_KEY: process.env.SLIPOK_API_KEY || process.env.EASYSLIP_API_KEY || "",
  SLIPOK_BRANCH_ID: process.env.SLIPOK_BRANCH_ID || "",
  LINE_CHANNEL_ACCESS_TOKEN: process.env.LINE_CHANNEL_ACCESS_TOKEN || "",
  DISCORD_FEEDBACK_WEBHOOK_URL: process.env.DISCORD_FEEDBACK_WEBHOOK_URL || process.env.DISCORD_WEBHOOK_URL || "",
  PORT: process.env.PORT ? parseInt(process.env.PORT, 10) : 3000,
};

// Validate required environment variables
const requiredEnvVars: (keyof typeof env)[] = [
  "DATABASE_URL",
];

for (const key of requiredEnvVars) {
  if (!env[key]) {
    console.warn(`[WARNING] Missing required environment variable: ${key}`);
  }
}

