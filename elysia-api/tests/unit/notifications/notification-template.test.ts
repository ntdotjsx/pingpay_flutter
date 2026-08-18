import { describe, test, expect } from "bun:test";
import { NotificationTemplateService } from "../../../src/modules/notifications/notification-template.service";

describe("Unit: NotificationTemplateService (Thai & English, Privacy & Accuracy)", () => {
  test("5.10 BILL_CREATED: message contains debtor amount, total, creator, and is clear", () => {
    const msg = NotificationTemplateService.billCreated({
      billId: "bill-1",
      billTitle: "Shabu Shabu Dinner",
      creatorId: "user-owner",
      creatorName: "Nut Thanapon",
      participantId: "item-1",
      participantDebtAmount: "350.00",
      totalAmount: "1050.00",
      currency: "THB",
    });

    expect(msg.title).toContain("Shabu Shabu Dinner");
    expect(msg.body).toContain("350.00 THB");
    expect(msg.body).toContain("1050.00 THB");
    expect(msg.body).toContain("Nut Thanapon");
  });

  test("5.12 BILL_UPDATED: contains diff and affected debtor amounts only", () => {
    const msg = NotificationTemplateService.billUpdated({
      billId: "bill-1",
      billTitle: "Shabu Shabu Dinner",
      editorId: "user-owner",
      editorName: "Nut Thanapon",
      participantId: "item-1",
      oldAmount: "350.00",
      newAmount: "450.00",
      titleChanged: { old: "Shabu", new: "Shabu Shabu Dinner" },
      totalAmountChanged: { old: "1050.00", new: "1200.00" },
      reason: "Added drinks",
    });

    expect(msg.body).toContain("350.00 → 450.00 THB");
    expect(msg.body).toContain("1050.00 → 1200.00 THB");
    expect(msg.body).toContain("Added drinks");
    expect(msg.body).toContain("Nut Thanapon");
  });

  test("5.14 BILL_WRITTEN_OFF: uses the term 'written off/ยกหนี้', NEVER says 'paid/จ่ายแล้ว'", () => {
    const msg = NotificationTemplateService.billWrittenOff({
      billId: "bill-1",
      billTitle: "Dinner at ABC",
      actorId: "user-owner",
      actorName: "Nut Thanapon",
      participantId: "item-1",
      oldAmount: "700.00",
      newAmount: "400.00",
      writtenOffAmount: "300.00",
      reason: "Birthday discount",
    });

    expect(msg.body).toContain("ยกยอดหนี้");
    expect(msg.body).toContain("300.00 THB");
    expect(msg.body).toContain("700.00 → 400.00 THB");
    // Ensure it NEVER claims payment occurred
    expect(msg.body).not.toContain("ชำระเงินแล้ว");
  });

  test("5.2 & 5.26 PAYMENT_PENDING_CONFIRMATION: tells bill owner to confirm, does NOT say payment is finished", () => {
    const msg = NotificationTemplateService.paymentPendingConfirmation({
      billId: "bill-1",
      billTitle: "Dinner ABC",
      paymentId: "pay-1",
      participantId: "item-1",
      payerId: "user-debtor",
      payerName: "Somchai",
      amount: "500.00",
      currency: "THB",
      slipVerified: true,
    });

    expect(msg.body).toContain("ได้รับแจ้งการโอนเงิน (รอคุณตรวจสอบ)");
    expect(msg.body).toContain("✅ ตรวจสอบสลิปผ่านแล้ว");
    expect(msg.body).toContain("รอคุณกดยืนยันการรับเงิน");
    expect(msg.body).toContain("Somchai");
    expect(msg.body).not.toContain("ชำระเงินสำเร็จ");
  });

  test("5.27 PAYMENT_CONFIRMED: informs payer of confirmation, installment, and remaining debt", () => {
    const msg = NotificationTemplateService.paymentConfirmed({
      billId: "bill-1",
      billTitle: "Dinner ABC",
      paymentId: "pay-1",
      participantId: "item-1",
      payerId: "user-debtor",
      confirmerId: "user-owner",
      confirmerName: "Nut Thanapon",
      amount: "500.00",
      currency: "THB",
      installmentNumber: 2,
      remainingDebt: "200.00",
      isFullyPaid: false,
    });

    expect(msg.body).toContain("เจ้าของบิลยืนยันการรับเงินแล้ว");
    expect(msg.body).toContain("500.00 THB");
    expect(msg.body).toContain("งวดที่: 2");
    expect(msg.body).toContain("200.00 THB");
    expect(msg.body).toContain("Nut Thanapon");
  });

  test("5.28 PAYMENT_REJECTED: informs payer that payment was rejected with reason", () => {
    const msg = NotificationTemplateService.paymentRejected({
      billId: "bill-1",
      billTitle: "Dinner ABC",
      paymentId: "pay-1",
      participantId: "item-1",
      payerId: "user-debtor",
      rejecterId: "user-owner",
      rejecterName: "Nut Thanapon",
      amount: "500.00",
      currency: "THB",
      reason: "Slip amount does not match the actual bank transaction",
    });

    expect(msg.body).toContain("❌ รายการโอนเงินไม่ผ่านการอนุมัติ");
    expect(msg.body).toContain("Slip amount does not match the actual bank transaction");
    expect(msg.body).toContain("500.00 THB");
  });

  test("5.21 DEBT_WEEKLY_REMINDER: shows accurate remaining balance and breakdown", () => {
    const msg = NotificationTemplateService.weeklyDebtReminder({
      billId: "bill-1",
      billTitle: "Dinner ABC",
      billItemId: "item-1",
      debtorId: "user-debtor",
      originalDebt: "1000.00",
      remainingDebt: "500.00",
      amountPaid: "300.00",
      amountWrittenOff: "200.00",
      currency: "THB",
      weekKey: "2026-W34",
    });

    expect(msg.body).toContain("แจ้งเตือนยอดค้างชำระประจำสัปดาห์");
    expect(msg.body).toContain("ยอดหนี้คงเหลือ:\n500.00 THB");
    expect(msg.body).toContain("จ่ายแล้ว: 300.00 THB");
    expect(msg.body).toContain("ยกหนี้ให้: 200.00 THB");
  });
});
