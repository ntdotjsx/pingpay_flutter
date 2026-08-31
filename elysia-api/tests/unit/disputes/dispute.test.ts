import { describe, it, expect } from "bun:test";
import { NotificationTemplateService } from "../../../src/modules/notifications/notification-template.service";

describe("Dispute Management & Templates", () => {
  it("should format DISPUTE_RAISED notification message for creditor", () => {
    const message = NotificationTemplateService.formatMessage(
      "DISPUTE_RAISED",
      {
        disputeId: "disp-123",
        billId: "bill-456",
        billTitle: "ชาบูนางใน",
        billItemId: "item-789",
        debtorId: "user-debtor",
        debtorName: "สมชาย",
        creditorId: "user-creditor",
        disputedAmount: "250.00",
        reason: "คิดเงินเกิน ไม่ได้สั่งเนื้อวัว",
        evidenceUrl: "https://storage.pingpay.app/evidence/slip.png",
      },
      "th"
    );

    expect(message.title).toContain("มีการยื่นข้อพิพาท: ชาบูนางใน");
    expect(message.body).toContain("สมชาย");
    expect(message.body).toContain("250.00 THB");
    expect(message.body).toContain("คิดเงินเกิน ไม่ได้สั่งเนื้อวัว");
    expect(message.imageUrl).toBe("https://storage.pingpay.app/evidence/slip.png");
  });

  it("should format DISPUTE_RESOLVED notification message for users", () => {
    const message = NotificationTemplateService.formatMessage(
      "DISPUTE_RESOLVED",
      {
        disputeId: "disp-123",
        billId: "bill-456",
        billTitle: "ชาบูนางใน",
        billItemId: "item-789",
        debtorId: "user-debtor",
        creditorId: "user-creditor",
        status: "resolved_paid",
        resolutionNote: "ตรวจสอบสลิปผ่าน EasySlip แล้ว ยอดเงินเข้าบัญชีเรียบร้อย",
        resolvedAt: new Date().toISOString(),
      },
      "th"
    );

    expect(message.title).toContain("ข้อพิพาทได้รับการตัดสินแล้ว: ชาบูนางใน");
    expect(message.body).toContain("ปรับสถานะเป็นชำระเงินแล้ว (Paid)");
    expect(message.body).toContain("ตรวจสอบสลิปผ่าน EasySlip แล้ว");
  });
});
