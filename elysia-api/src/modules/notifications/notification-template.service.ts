import {
  BillCreatedPayload,
  BillUpdatedPayload,
  BillWrittenOffPayload,
  PaymentPendingConfirmationPayload,
  PaymentConfirmedPayload,
  PaymentRejectedPayload,
  DebtWeeklyReminderPayload,
  NotificationPayload,
  NotificationEventType,
} from "./notification.types";

export interface FormattedNotificationMessage {
  title: string;
  body: string;
  fallbackText: string;
}

export class NotificationTemplateService {
  /**
   * 5.10 New Bill Created Notification Template
   * Never exposes unrelated participants' private debt amounts.
   */
  static billCreated(payload: BillCreatedPayload, locale = "th"): FormattedNotificationMessage {
    if (locale === "th") {
      const body = [
        `🧾 บิลใหม่: ${payload.billTitle}`,
        ``,
        `ยอดของคุณ:`,
        `${payload.participantDebtAmount} ${payload.currency}`,
        ``,
        `ยอดรวมทั้งบิล:`,
        `${payload.totalAmount} ${payload.currency}`,
        ``,
        `สร้างโดย:`,
        `${payload.creatorName}`,
        ``,
        `โปรดตรวจสอบรายละเอียดและชำระเงินเมื่อสะดวกครับ`,
      ].join("\n");

      return {
        title: `🧾 มีบิลใหม่: ${payload.billTitle}`,
        body,
        fallbackText: `มีบิลใหม่ ${payload.billTitle} ยอดของคุณ ${payload.participantDebtAmount} ${payload.currency}`,
      };
    }

    // Default English fallback
    return {
      title: `🧾 New Bill: ${payload.billTitle}`,
      body: `New bill: ${payload.billTitle}\nYour amount: ${payload.participantDebtAmount} ${payload.currency}\nTotal: ${payload.totalAmount} ${payload.currency}\nCreated by: ${payload.creatorName}`,
      fallbackText: `New bill ${payload.billTitle}: ${payload.participantDebtAmount} ${payload.currency}`,
    };
  }

  /**
   * 5.12 & 5.13 Bill Edited Notification Template with Diff
   */
  static billUpdated(payload: BillUpdatedPayload, locale = "th"): FormattedNotificationMessage {
    if (locale === "th") {
      const lines = [
        `📋 อัปเดตรายละเอียดบิล: ${payload.billTitle}`,
        ``,
        `ยอดของคุณ:`,
        `${payload.oldAmount} ${payload.newAmount ? `→ ${payload.newAmount} THB` : ""}`,
      ];

      if (payload.titleChanged) {
        lines.push(`ชื่อบิล: ${payload.titleChanged.old || "-"} → ${payload.titleChanged.new}`);
      }

      if (payload.totalAmountChanged) {
        lines.push(`ยอดรวมบิล: ${payload.totalAmountChanged.old} → ${payload.totalAmountChanged.new} THB`);
      }

      lines.push(``, `แก้ไขโดย:`, `${payload.editorName}`);

      if (payload.reason) {
        lines.push(``, `เหตุผล: ${payload.reason}`);
      }

      return {
        title: `📋 บิลมีการแก้ไข: ${payload.billTitle}`,
        body: lines.join("\n"),
        fallbackText: `บิล ${payload.billTitle} มีการแก้ไขยอดของคุณเป็น ${payload.newAmount} THB`,
      };
    }

    return {
      title: `📋 Bill Updated: ${payload.billTitle}`,
      body: `Bill updated: ${payload.billTitle}\nYour amount: ${payload.oldAmount} -> ${payload.newAmount} THB\nChanged by: ${payload.editorName}`,
      fallbackText: `Bill updated: ${payload.billTitle} (${payload.newAmount} THB)`,
    };
  }

  /**
   * 5.14 Bill Write-Off Notification Template
   * Explicitly uses the term "ยกหนี้/ยกยอดให้ (written off)", NEVER "paid".
   */
  static billWrittenOff(payload: BillWrittenOffPayload, locale = "th"): FormattedNotificationMessage {
    if (locale === "th") {
      const isFull = Number(payload.newAmount) === 0;
      const lines = [
        `📋 มีการยกยอดหนี้ให้: ${payload.billTitle}`,
        ``,
        `ยอดหนี้ของคุณ:`,
        `${payload.oldAmount} → ${payload.newAmount} THB`,
        ``,
        `จำนวนที่ยกหนี้ให้:`,
        `${payload.writtenOffAmount} THB`,
        ``,
        `ดำเนินการโดย:`,
        `${payload.actorName}`,
      ];

      if (isFull) {
        lines.push(``, `🎉 หนี้ในรายการนี้ได้รับการยกยอดทั้งหมดแล้ว`);
      }

      if (payload.reason) {
        lines.push(``, `เหตุผล: ${payload.reason}`);
      }

      return {
        title: `📋 มีการยกยอดหนี้: ${payload.billTitle}`,
        body: lines.join("\n"),
        fallbackText: `มีการยกยอดหนี้ให้คุณจำนวน ${payload.writtenOffAmount} THB ในบิล ${payload.billTitle}`,
      };
    }

    return {
      title: `📋 Debt Written Off: ${payload.billTitle}`,
      body: `Debt written off: ${payload.billTitle}\nYour debt: ${payload.oldAmount} -> ${payload.newAmount} THB\nWritten off: ${payload.writtenOffAmount} THB\nChanged by: ${payload.actorName}`,
      fallbackText: `Debt written off for ${payload.billTitle}: ${payload.writtenOffAmount} THB`,
    };
  }

  /**
   * 5.2 & 5.26 Slip Verification Passed -> Bill Owner Confirmation Request
   * CRITICAL RULE: Explicitly says "Slip verification passed. Please confirm receipt."
   * NEVER claims payment is finalized yet.
   */
  static paymentPendingConfirmation(
    payload: PaymentPendingConfirmationPayload,
    locale = "th"
  ): FormattedNotificationMessage {
    if (locale === "th") {
      const body = [
        `💳 ได้รับแจ้งการโอนเงิน (รอคุณตรวจสอบ)`,
        ``,
        `บิล:`,
        `${payload.billTitle}`,
        ``,
        `จาก:`,
        `${payload.payerName}`,
        ``,
        `ยอดโอน:`,
        `${payload.amount} ${payload.currency}`,
        ``,
        `ผลตรวจสอบสลิป:`,
        `✅ ตรวจสอบสลิปผ่านแล้ว`,
        ``,
        `สถานะ:`,
        `รอคุณกดยืนยันการรับเงิน`,
        ``,
        `โปรดตรวจสอบยอดเงินในบัญชีของคุณและกดยืนยันในแอปเพื่อตัดยอดหนี้`,
      ].join("\n");

      return {
        title: `💳 มีรายการโอนเงินรอการยืนยัน: ${payload.billTitle}`,
        body,
        fallbackText: `มีการโอนเงิน ${payload.amount} ${payload.currency} จาก ${payload.payerName} รอคุณตรวจสอบและยืนยัน`,
      };
    }

    return {
      title: `💳 Payment Received for Review: ${payload.billTitle}`,
      body: `Payment received for review\nBill: ${payload.billTitle}\nFrom: ${payload.payerName}\nAmount: ${payload.amount} ${payload.currency}\nSlip verification: Passed\nStatus: Waiting for your confirmation\n\nPlease review and confirm the payment.`,
      fallbackText: `Payment received from ${payload.payerName} for ${payload.billTitle}`,
    };
  }

  /**
   * 5.27 Payment Confirmed -> Payer Notification
   */
  static paymentConfirmed(payload: PaymentConfirmedPayload, locale = "th"): FormattedNotificationMessage {
    if (locale === "th") {
      const isComplete = payload.isFullyPaid || Number(payload.remainingDebt) <= 0;
      const lines = [
        `✅ เจ้าของบิลยืนยันการรับเงินแล้ว`,
        ``,
        `บิล: ${payload.billTitle}`,
        ``,
        `ยอดชำระ:`,
        `${payload.amount} ${payload.currency}`,
      ];

      if (payload.installmentNumber) {
        lines.push(`งวดที่: ${payload.installmentNumber}`);
      }

      lines.push(
        ``,
        `ยอดหนี้คงเหลือ:`,
        `${payload.remainingDebt} ${payload.currency}`,
        ``,
        `ยืนยันโดย:`,
        `${payload.confirmerName}`
      );

      if (isComplete) {
        lines.push(``, `🎉 ชำระเงินครบถ้วนเรียบร้อยแล้ว ขอบคุณครับ!`);
      }

      return {
        title: `✅ ชำระเงินสำเร็จ: ${payload.billTitle}`,
        body: lines.join("\n"),
        fallbackText: `การชำระเงิน ${payload.amount} ${payload.currency} สำหรับ ${payload.billTitle} ได้รับการยืนยันแล้ว`,
      };
    }

    return {
      title: `✅ Payment Confirmed: ${payload.billTitle}`,
      body: `Payment confirmed\nBill: ${payload.billTitle}\nPayment: ${payload.amount} ${payload.currency}\nRemaining: ${payload.remainingDebt} ${payload.currency}\nConfirmed by: ${payload.confirmerName}`,
      fallbackText: `Payment confirmed for ${payload.billTitle}`,
    };
  }

  /**
   * 5.28 Payment Rejected -> Payer Notification
   */
  static paymentRejected(payload: PaymentRejectedPayload, locale = "th"): FormattedNotificationMessage {
    if (locale === "th") {
      const body = [
        `❌ รายการโอนเงินไม่ผ่านการอนุมัติ`,
        ``,
        `บิล: ${payload.billTitle}`,
        ``,
        `ยอดเงิน: ${payload.amount} ${payload.currency}`,
        ``,
        `รายการชำระเงินของคุณถูกปฏิเสธ`,
        ``,
        `เหตุผล:`,
        `${payload.reason}`,
        ``,
        `โปรดตรวจสอบและทำรายการแนบสลิปใหม่อีกครั้งครับ`,
      ].join("\n");

      return {
        title: `❌ การชำระเงินถูกปฏิเสธ: ${payload.billTitle}`,
        body,
        fallbackText: `การชำระเงิน ${payload.amount} ${payload.currency} ถูกปฏิเสธ: ${payload.reason}`,
      };
    }

    return {
      title: `❌ Payment Needs Attention: ${payload.billTitle}`,
      body: `Payment rejected\nBill: ${payload.billTitle}\nAmount: ${payload.amount} ${payload.currency}\nReason: ${payload.reason}\n\nPlease submit a new payment.`,
      fallbackText: `Payment rejected for ${payload.billTitle}`,
    };
  }

  /**
   * 5.21 & 5.22 Weekly Unpaid Debt Reminder Template
   */
  static weeklyDebtReminder(payload: DebtWeeklyReminderPayload, locale = "th"): FormattedNotificationMessage {
    if (locale === "th") {
      const lines = [
        `⏰ แจ้งเตือนยอดค้างชำระประจำสัปดาห์`,
        ``,
        `บิล: ${payload.billTitle}`,
        ``,
        `ยอดหนี้คงเหลือ:`,
        `${payload.remainingDebt} ${payload.currency}`,
      ];

      if (Number(payload.amountPaid) > 0 || Number(payload.amountWrittenOff) > 0) {
        lines.push(
          ``,
          `ความคืบหน้า:`,
          `- ยอดตั้งต้น: ${payload.originalDebt} ${payload.currency}`,
          `- จ่ายแล้ว: ${payload.amountPaid} ${payload.currency}`,
          `- ยกหนี้ให้: ${payload.amountWrittenOff} ${payload.currency}`
        );
      }

      lines.push(``, `โปรดตรวจสอบและชำระเงินเมื่อสะดวก ขอบคุณครับ 🙏`);

      return {
        title: `⏰ แจ้งเตือนยอดค้างชำระ: ${payload.billTitle}`,
        body: lines.join("\n"),
        fallbackText: `แจ้งเตือนยอดค้างชำระ ${payload.billTitle} คงเหลือ ${payload.remainingDebt} ${payload.currency}`,
      };
    }

    return {
      title: `⏰ Weekly Payment Reminder: ${payload.billTitle}`,
      body: `Weekly payment reminder\nBill: ${payload.billTitle}\nRemaining debt: ${payload.remainingDebt} ${payload.currency}\nPaid: ${payload.amountPaid} ${payload.currency}\nWritten off: ${payload.amountWrittenOff} ${payload.currency}`,
      fallbackText: `Weekly payment reminder: ${payload.remainingDebt} ${payload.currency} for ${payload.billTitle}`,
    };
  }

  /**
   * Central dispatch generator based on event type
   */
  static formatMessage(
    eventType: NotificationEventType,
    payload: NotificationPayload,
    locale = "th"
  ): FormattedNotificationMessage {
    switch (eventType) {
      case "BILL_CREATED":
        return this.billCreated(payload as BillCreatedPayload, locale);
      case "BILL_UPDATED":
        return this.billUpdated(payload as BillUpdatedPayload, locale);
      case "BILL_WRITTEN_OFF":
        return this.billWrittenOff(payload as BillWrittenOffPayload, locale);
      case "PAYMENT_PENDING_CONFIRMATION":
        return this.paymentPendingConfirmation(payload as PaymentPendingConfirmationPayload, locale);
      case "PAYMENT_CONFIRMED":
        return this.paymentConfirmed(payload as PaymentConfirmedPayload, locale);
      case "PAYMENT_REJECTED":
        return this.paymentRejected(payload as PaymentRejectedPayload, locale);
      case "DEBT_WEEKLY_REMINDER":
        return this.weeklyDebtReminder(payload as DebtWeeklyReminderPayload, locale);
      default:
        throw new Error(`Unsupported notification event type: ${eventType}`);
    }
  }
}
