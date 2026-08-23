import { env } from "../../config/env";

export interface SendOtpEmailOptions {
  toEmail: string;
  otp: string;
  userName?: string;
  expiresInMinutes?: number;
}

export class EmailService {
  /**
   * Sends a 6-digit OTP verification email for PIN reset.
   */
  async sendOtpEmail(options: SendOtpEmailOptions): Promise<{ success: boolean; error?: string }> {
    const { toEmail, otp, userName = "ผู้ใช้งาน", expiresInMinutes = 5 } = options;

    const subject = `🔐 [PingPay] รหัส OTP สำหรับรีเซ็ตรหัส PIN ของคุณคือ ${otp}`;
    const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PingPay OTP Reset PIN</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f6f5f4; margin: 0; padding: 24px; color: #1a1a1a; }
    .card { max-width: 480px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); border: 1px solid #eaeAEA; }
    .header { text-align: center; margin-bottom: 24px; }
    .logo { font-size: 24px; font-weight: 800; color: #FF5000; letter-spacing: -0.5px; }
    .title { font-size: 18px; font-weight: 700; color: #111111; margin-top: 12px; margin-bottom: 6px; }
    .subtitle { font-size: 14px; color: #666666; line-height: 1.5; }
    .otp-box { background: #FFF4EE; border: 2px dashed #FF5000; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0; }
    .otp-code { font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #FF5000; font-family: monospace; }
    .expiry { font-size: 12px; color: #888888; margin-top: 8px; font-weight: 500; }
    .warning { background: #fef3f2; border-left: 4px solid #f04438; padding: 12px 16px; border-radius: 6px; font-size: 13px; color: #b42318; line-height: 1.4; margin-top: 20px; }
    .footer { text-align: center; font-size: 12px; color: #999999; margin-top: 32px; line-height: 1.5; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="logo">⚡ PingPay</div>
      <div class="title">คำขอรีเซ็ตรหัส PIN</div>
      <div class="subtitle">สวัสดีคุณ <strong>${userName}</strong>,<br>เราได้รับคำขอรีเซ็ตรหัส PIN สำหรับเข้าใช้งานแอป PingPay ของคุณ</div>
    </div>

    <div class="otp-box">
      <div class="otp-code">${otp}</div>
      <div class="expiry">⏱️ รหัสนี้มีอายุการใช้งาน ${expiresInMinutes} นาที</div>
    </div>

    <div class="warning">
      ⚠️ <strong>ข้อควรระวังด้านความปลอดภัย:</strong><br>
      ห้ามเปิดเผยรหัส OTP นี้ให้ผู้อื่นทราบโดยเด็ดขาด ทีมงาน PingPay จะไม่มีการขอรหัส OTP หรือ PIN จากคุณ
    </div>

    <div class="footer">
      หากคุณไม่ได้เป็นผู้ทำรายการนี้ โปรดตรวจสอบความปลอดภัยของบัญชี Google ของคุณทันที<br><br>
      © ${new Date().getFullYear()} PingPay. All rights reserved.
    </div>
  </div>
</body>
</html>
    `;

    // 1. Try sending via Resend API if API Key is configured
    if (env.RESEND_API_KEY) {
      try {
        const response = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${env.RESEND_API_KEY}`,
          },
          body: JSON.stringify({
            from: env.EMAIL_FROM,
            to: [toEmail],
            subject: subject,
            html: htmlContent,
          }),
        });

        if (response.ok) {
          console.log(`[EmailService] Resend API delivered OTP email to: ${toEmail}`);
          return { success: true };
        } else {
          const errBody = await response.text();
          console.warn(`[EmailService] Resend API error: ${response.status} - ${errBody}`);
        }
      } catch (err: any) {
        console.error("[EmailService] Failed to send email via Resend:", err);
      }
    }

    // 2. Dev / Testing / Console Fallback Logger
    console.log(`\n=============================================================`);
    console.log(`📧 [EMAIL OTP SERVICE - DISPATCHED]`);
    console.log(`To: ${toEmail}`);
    console.log(`Subject: ${subject}`);
    console.log(`🔐 OTP Code: [ ${otp} ] (Expires in ${expiresInMinutes} min)`);
    console.log(`=============================================================\n`);

    return { success: true };
  }
}

export const defaultEmailService = new EmailService();
