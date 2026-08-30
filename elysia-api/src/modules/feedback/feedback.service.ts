import { env } from "../../config/env";
import type { CreateFeedbackDto, FeedbackResponse, FeedbackUserContext } from "./feedback.types";

/**
 * Builds Discord Embed Color and Icon based on Feedback Type
 */
function getFeedbackTheme(type: string): { color: number; icon: string; label: string } {
  switch (type) {
    case "BUG_REPORT":
      return { color: 0xef4444, icon: "🐛", label: "แจ้งปัญหาการใช้งาน (Bug Report)" };
    case "FEATURE_REQUEST":
      return { color: 0x6366f1, icon: "💡", label: "ขอฟีเจอร์ใหม่ (Feature Request)" };
    case "FEEDBACK":
      return { color: 0xff5000, icon: "💬", label: "ข้อเสนอแนะทั่วไป (Feedback)" };
    case "OTHER":
    default:
      return { color: 0x64748b, icon: "❓", label: "เรื่องอื่น ๆ (Other)" };
  }
}

/**
 * Format star rating to string
 */
function formatRating(rating?: number): string {
  if (!rating || rating < 1) return "ไม่ได้ระบุ";
  const stars = "⭐".repeat(Math.min(5, Math.max(1, rating)));
  return `${stars} (${rating}/5)`;
}

/**
 * Format severity level with emoji
 */
function formatSeverity(severity?: string): string {
  switch (severity) {
    case "CRITICAL":
      return "🚨 วิกฤต (Critical - แอปใช้งานไม่ได้)";
    case "HIGH":
      return "⚠️ สูง (High - ฟังก์ชันสำคัญผิดพลาด)";
    case "MEDIUM":
      return "🟡 ปานกลาง (Medium - ใช้งานได้แต่ไม่สมบูรณ์)";
    case "LOW":
    default:
      return "🟢 ต่ำ (Low - ข้อผิดพลาดเล็กน้อย/UI)";
  }
}

/**
 * Sends user feedback directly to Discord Webhook without saving to database.
 */
export async function sendFeedbackToDiscord(
  dto: CreateFeedbackDto,
  user: FeedbackUserContext
): Promise<FeedbackResponse> {
  const webhookUrl = env.DISCORD_FEEDBACK_WEBHOOK_URL;
  const theme = getFeedbackTheme(dto.type);
  const nowIso = new Date().toISOString();

  const embedFields: Array<{ name: string; value: string; inline?: boolean }> = [
    {
      name: "👤 ผู้ส่ง (User)",
      value: `${user.displayName || user.fullName || "User"} (\`${user.userCode || "N/A"}\`)`,
      inline: true,
    },
    {
      name: "🏷️ หมวดหมู่ (Category)",
      value: `${theme.icon} ${theme.label}`,
      inline: true,
    },
  ];

  if (dto.type === "BUG_REPORT" && dto.severity) {
    embedFields.push({
      name: "⚡ ระดับความเร่งด่วน (Severity)",
      value: formatSeverity(dto.severity),
      inline: true,
    });
  }

  if (dto.type === "FEEDBACK" && dto.rating) {
    embedFields.push({
      name: "⭐ คะแนนความพึงพอใจ (Rating)",
      value: formatRating(dto.rating),
      inline: true,
    });
  }

  const contactEmail = (dto.contactEmail && dto.contactEmail.trim().length > 0)
    ? dto.contactEmail.trim()
    : user.email;

  if (contactEmail && contactEmail.trim().length > 0) {
    embedFields.push({
      name: "📧 อีเมลติดต่อกลับ (Contact Email)",
      value: `\`${contactEmail.trim()}\``,
      inline: true,
    });
  }

  embedFields.push({
    name: "📱 ระบบและอุปกรณ์ (Diagnostics)",
    value: `App: \`${dto.appVersion || "PingPay Mobile"}\`\nDevice: \`${dto.deviceInfo || "Mobile Device"}\``,
    inline: false,
  });

  embedFields.push({
    name: "📝 รายละเอียด (Description)",
    value: dto.description.length > 1024 ? `${dto.description.substring(0, 1020)}...` : dto.description,
    inline: false,
  });

  const discordPayload = {
    username: "PingPay Feedback Bot",
    avatar_url: "https://raw.githubusercontent.com/ntdotjsx/pingpay_flutter/main/assets/icons/app_icon.png",
    embeds: [
      {
        title: `${theme.icon} [${dto.type}] ${dto.subject}`,
        color: theme.color,
        fields: embedFields,
        footer: {
          text: "PingPay Support & Bug Tracker • Stateless Webhook (No DB)",
        },
        timestamp: nowIso,
      },
    ],
  };

  let deliveredToDiscord = false;

  if (webhookUrl && webhookUrl.trim().length > 0) {
    try {
      const response = await fetch(webhookUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(discordPayload),
      });

      if (response.ok || response.status === 204) {
        deliveredToDiscord = true;
        console.log(`[Discord Webhook] Feedback sent successfully: [${dto.type}] ${dto.subject}`);
      } else {
        const errText = await response.text();
        console.warn(`[Discord Webhook] Failed with status ${response.status}: ${errText}`);
      }
    } catch (err: any) {
      console.error(`[Discord Webhook] Network error dispatching webhook:`, err.message);
    }
  } else {
    console.log(`[Discord Webhook (Simulated / Local)] Feedback received without webhook URL:`, JSON.stringify(discordPayload, null, 2));
  }

  return {
    success: true,
    message: dto.type === "BUG_REPORT"
      ? "ส่งรายงานปัญหาไปยังทีมพัฒนาเรียบร้อยแล้ว ขอบคุณที่ช่วยแจ้งปัญหาครับ!"
      : "ส่งข้อเสนอแนะของคุณเรียบร้อยแล้ว ขอบคุณสำหรับความคิดเห็นครับ!",
    deliveredToDiscord,
  };
}
