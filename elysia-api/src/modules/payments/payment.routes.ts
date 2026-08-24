import { Elysia, t } from "elysia";
import { PaymentService } from "./payment.service";
import {
  CreatePaymentSchema,
  ConfirmPaymentSchema,
  RejectPaymentSchema,
} from "./payment.schema";

const paymentService = new PaymentService();

export const paymentRoutes = new Elysia()
  // 4.13 Submit payment with slip (debtor submits payment)
  .post("/:id/payments", async ({ params: { id }, body, user, set }) => {
    try {
      const result = await paymentService.createPayment(user.id, id, body);
      set.status = 201;
      return { success: true, data: result };
    } catch (e: any) {
      if (
        e.message.includes("PAYMENT_EXCEEDS_OUTSTANDING") ||
        e.message.includes("SLIP_AMOUNT_MISMATCH") ||
        e.message.includes("SLIP_RECIPIENT_MISMATCH") ||
        e.message.includes("DUPLICATE_SLIP") ||
        e.message.includes("INVALID_AMOUNT")
      ) {
        set.status = 422;
      } else if (e.message.includes("UNAUTHORIZED")) {
        set.status = 403;
      } else if (e.message.includes("BILL_NOT_FOUND") || e.message.includes("PARTICIPANT_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    body: CreatePaymentSchema,
    detail: {
      tags: ["Payments"],
      summary: "Submit payment with slip",
      description: "Uploads a bank transfer slip or QR data to initiate a payment. Verified by SlipOK, moving to PENDING_OWNER_CONFIRMATION.",
    }
  })

  // 4.15 Get payments history for a bill
  .get("/:id/payments", async ({ params: { id }, user, set }) => {
    try {
      const history = await paymentService.getBillPaymentsHistory(user.id, id);
      return { success: true, data: history };
    } catch (e: any) {
      if (e.message.includes("UNAUTHORIZED")) {
        set.status = 403;
      } else if (e.message.includes("BILL_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Payments"],
      summary: "Get payment history for a bill",
      description: "Retrieves complete chronological list of installment payments for the given bill.",
    }
  })

  // 4.14 Get specific payment details
  .get("/payments/:paymentId", async ({ params: { paymentId }, user, set }) => {
    try {
      const payment = await paymentService.getPaymentDetails(user.id, paymentId);
      return { success: true, data: payment };
    } catch (e: any) {
      if (e.message.includes("UNAUTHORIZED")) {
        set.status = 403;
      } else if (e.message.includes("PAYMENT_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ paymentId: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Payments"],
      summary: "Get payment details",
      description: "Retrieves payment metadata, SlipOK verification results, and owner confirmation status.",
    }
  })

  // 4.16 Bill Owner Confirmation
  .post("/payments/:paymentId/confirm", async ({ params: { paymentId }, body, user, set }) => {
    try {
      const result = await paymentService.confirmPayment(user.id, paymentId, body);
      return result;
    } catch (e: any) {
      if (e.message.includes("UNAUTHORIZED")) {
        set.status = 403;
      } else if (e.message.includes("PAYMENT_ALREADY_CONFIRMED") || e.message.includes("PAYMENT_STATE_CONFLICT")) {
        set.status = 409;
      } else if (e.message.includes("PAYMENT_EXCEEDS_OUTSTANDING")) {
        set.status = 422;
      } else if (e.message.includes("PAYMENT_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ paymentId: t.String({ format: "uuid" }) }),
    body: ConfirmPaymentSchema,
    detail: {
      tags: ["Payments"],
      summary: "Confirm payment (Bill Owner)",
      description: "Allows the bill owner to confirm receipt of funds, committing the immutable financial transaction and reducing the debtor's balance.",
    }
  })

  // 4.17 Reject Payment
  .post("/payments/:paymentId/reject", async ({ params: { paymentId }, body, user, set }) => {
    try {
      const result = await paymentService.rejectPayment(user.id, paymentId, body);
      return result;
    } catch (e: any) {
      if (e.message.includes("UNAUTHORIZED")) {
        set.status = 403;
      } else if (e.message.includes("PAYMENT_STATE_CONFLICT")) {
        set.status = 409;
      } else if (e.message.includes("PAYMENT_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ paymentId: t.String({ format: "uuid" }) }),
    body: RejectPaymentSchema,
    detail: {
      tags: ["Payments"],
      summary: "Reject payment (Bill Owner)",
      description: "Allows the bill owner to reject a payment slip (e.g. invalid amount, fake slip). Debt balance remains unchanged.",
    }
  })

  // 4.50 Get user debts list and outstanding summary
  .get("/debts", async ({ user, set }) => {
    try {
      const data = await paymentService.getUserDebtsAndSummary(user.id);
      return { success: true, data };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    detail: {
      tags: ["Payments", "Debts"],
      summary: "Get debts and payment summary for current user",
      description: "Retrieves list of debts owed by the authenticated user with creditor info, outstanding amount, and summary count/total.",
    }
  })

  // 4.51 Get user receivables list (Money owed TO current user as bill owner)
  .get("/receivables", async ({ user, set }) => {
    try {
      const data = await paymentService.getUserReceivablesAndSummary(user.id);
      return { success: true, data };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    detail: {
      tags: ["Payments", "Receivables"],
      summary: "Get receivables summary and friends who owe current user",
      description: "Retrieves list of debtors and bills owed to the authenticated user, including unique debtor count and outstanding totals.",
    }
  })

  // 4.52 Debtor swipes to acknowledge/accept debt
  .post("/debts/:billItemId/acknowledge", async ({ params: { billItemId }, user, set }) => {
    try {
      const data = await paymentService.acknowledgeDebt(user.id, billItemId);
      return { success: true, data };
    } catch (e: any) {
      if (e.message.includes("UNAUTHORIZED")) {
        set.status = 403;
      } else if (e.message.includes("PARTICIPANT_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ billItemId: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Payments", "Debts"],
      summary: "Debtor accepts and acknowledges debt",
      description: "Debtor performs a swipe action to confirm that they acknowledge the debt.",
    }
  });

