import { describe, it, expect } from "bun:test";
import { sendFeedbackToDiscord } from "../src/modules/feedback/feedback.service";
import type { CreateFeedbackDto } from "../src/modules/feedback/feedback.types";

describe("Feedback Service (Discord Webhook Stateless Dispatcher)", () => {
  it("successfully formats and dispatches bug report without database storage", async () => {
    const dto: CreateFeedbackDto = {
      type: "BUG_REPORT",
      subject: "หน้าคำนวณบิลค้างเมื่อกดแบ่งสัดส่วน",
      description: "เมื่อกดแบ่งสัดส่วนในหน้าบิล ยอดเงินไม่แสดงทันที ต้องกดรีเฟรชก่อน",
      severity: "HIGH",
      appVersion: "1.0.0 (42)",
      deviceInfo: "iPhone 15 Pro, iOS 17.5",
      contactEmail: "test@pingpay.com",
    };

    const user = {
      userId: "usr_123456",
      userCode: "USR-60CE13",
      displayName: "นัท พัฒนาการ",
    };

    const result = await sendFeedbackToDiscord(dto, user);

    expect(result.success).toBe(true);
    expect(result.message).toContain("ส่งรายงานปัญหา");
  });

  it("successfully formats and dispatches general feedback with rating", async () => {
    const dto: CreateFeedbackDto = {
      type: "FEEDBACK",
      subject: "แอปใช้งานง่ายมาก ชอบฟังก์ชันสั่งด้วยเสียง",
      description: "พิมพ์สั่ง AI คำนวณบิลได้เร็วมาก อยากให้เพิ่มฟอนต์น่ารัก ๆ เพิ่มเติม",
      rating: 5,
      appVersion: "1.0.0",
      deviceInfo: "Samsung Galaxy S24",
    };

    const user = {
      userId: "usr_789012",
      userCode: "USR-0931C3",
      displayName: "ป่น",
    };

    const result = await sendFeedbackToDiscord(dto, user);

    expect(result.success).toBe(true);
    expect(result.message).toContain("ส่งข้อเสนอแนะ");
  });

  it("successfully formats feature request", async () => {
    const dto: CreateFeedbackDto = {
      type: "FEATURE_REQUEST",
      subject: "อยากให้มี Export บิลเป็น PDF/Excel",
      description: "ต้องการดาวน์โหลดสรุปค่าใช้จ่ายประจำเดือนเป็นไฟล์ PDF ไปแนบส่งบัญชี",
      appVersion: "1.0.0",
      deviceInfo: "Web Browser",
    };

    const user = {
      userId: "usr_999999",
      userCode: "USR-1CE875",
      displayName: "Pastis",
    };

    const result = await sendFeedbackToDiscord(dto, user);

    expect(result.success).toBe(true);
  });
});
