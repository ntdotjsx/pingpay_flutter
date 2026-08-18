import { describe, it, expect, beforeEach } from "bun:test";
import { db } from "../../../src/db";
import {
  users,
  bills,
  billItems,
  payments,
  paymentVerifications,
  financialTransactions,
  editLogs,
  userCredentials,
  consentRecords,
} from "../../../src/db/schema";
import { eq } from "drizzle-orm";
import { PaymentService } from "../../../src/modules/payments/payment.service";
import { SlipOkVerificationService } from "../../../src/modules/payments/slip-verification.service";
import { FakeLineNotificationService } from "../../../src/modules/bills/bill-notification.service";
import { BillWriteoffService } from "../../../src/modules/bills/bill-writeoff.service";
import { BillAdjustmentService } from "../../../src/modules/bills/bill-adjustment.service";

describe.skip("Integration: Payments Financial System, Verification, Owner Confirmation & Edge Cases", () => {
  let slipService: SlipOkVerificationService;
  let notificationService: FakeLineNotificationService;
  let paymentService: PaymentService;
  let writeOffService: BillWriteoffService;
  let adjustmentService: BillAdjustmentService;

  const ownerId = "11111111-1111-1111-1111-111111111111";
  const debtor1Id = "22222222-2222-2222-2222-222222222222";
  const debtor2Id = "33333333-3333-3333-3333-333333333333";
  const outsiderId = "44444444-4444-4444-4444-444444444444";

  beforeEach(async () => {
    slipService = new SlipOkVerificationService();
    notificationService = new FakeLineNotificationService();
    paymentService = new PaymentService(undefined, slipService, notificationService);
    writeOffService = new BillWriteoffService(notificationService);
    adjustmentService = new BillAdjustmentService(notificationService);

    // Clean tables
    await db.delete(financialTransactions);
    await db.delete(paymentVerifications);
    await db.delete(payments);
    await db.delete(editLogs);
    await db.delete(billItems);
    await db.delete(bills);
    await db.delete(userCredentials);
    await db.delete(consentRecords);
    await db.delete(users);

    // Setup Test Users
    await db.insert(users).values([
      {
        id: ownerId,
        userCode: "USR-OWNER",
        displayName: "Bill Owner",
        fullName: "Owner Somchai",
        promptPayId: "0812345678",
        bankAccountNumber: "1234567890",
        profileCompletedAt: new Date(),
      },
      {
        id: debtor1Id,
        userCode: "USR-DEBTOR1",
        displayName: "Debtor One",
        fullName: "Debtor Somying",
        profileCompletedAt: new Date(),
      },
      {
        id: debtor2Id,
        userCode: "USR-DEBTOR2",
        displayName: "Debtor Two",
        fullName: "Debtor Somsak",
        profileCompletedAt: new Date(),
      },
      {
        id: outsiderId,
        userCode: "USR-OUTSIDER",
        displayName: "Random User",
        fullName: "Random Guy",
        profileCompletedAt: new Date(),
      },
    ]);
  });

  async function createTestBill(total = 1000, participantAmounts = [{ debtorId: debtor1Id, amount: 1000 }]) {
    const [bill] = await db
      .insert(bills)
      .values({
        ownerId,
        title: "Team Dinner",
        totalAmount: total.toFixed(2),
        currency: "THB",
        status: "unpaid",
      })
      .returning();

    const createdItems = await db
      .insert(billItems)
      .values(
        participantAmounts.map((p) => ({
          billId: bill.id,
          debtorId: p.debtorId,
          originalAmount: p.amount.toFixed(2),
          currentAmount: p.amount.toFixed(2),
          amountPaid: "0.00",
          amountWrittenOff: "0.00",
          status: "unpaid" as const,
        }))
      )
      .returning();

    return { bill, items: createdItems };
  }

  // 4.48 Test 1 — Full Payment Flow
  it("Test 1: Full Payment — SlipOK Pass + Owner Confirm -> CONFIRMED, Paid 1000, FULLY_PAID", async () => {
    const { bill, items } = await createTestBill(1000);
    const item = items[0];

    slipService.setMockResult({
      verified: true,
      amount: 1000,
      transactionReference: "TX-TEST-1",
    });

    const createRes = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 1000,
      slip: Buffer.from("test-slip-full"),
    });

    expect(createRes.status).toBe("pending_owner_confirmation");

    // Owner confirms
    const confirmRes = await paymentService.confirmPayment(ownerId, createRes.id);
    expect(confirmRes.success).toBe(true);

    const updatedBill = await db.query.bills.findFirst({ where: eq(bills.id, bill.id) });
    const updatedItem = await db.query.billItems.findFirst({ where: eq(billItems.id, item.id) });

    expect(updatedBill?.status).toBe("fully_paid");
    expect(updatedItem?.status).toBe("paid");
    expect(updatedItem?.amountPaid).toBe("1000.00");

    // Financial ledger check
    const ledgers = await db.query.financialTransactions.findMany({ where: eq(financialTransactions.billId, bill.id) });
    expect(ledgers.length).toBe(1);
    expect(ledgers[0].type).toBe("payment");
    expect(ledgers[0].amount).toBe("1000.00");
  });

  // 4.48 Test 2 — SlipOK Pass But Owner Does NOT Confirm
  it("Test 2: SlipOK Pass But Owner Does NOT Confirm — Remaining remains 1000, NOT fully paid", async () => {
    const { bill, items } = await createTestBill(1000);
    const item = items[0];

    slipService.setMockResult({
      verified: true,
      amount: 1000,
      transactionReference: "TX-TEST-2",
    });

    const createRes = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 1000,
      slip: Buffer.from("test-slip-unconfirmed"),
    });

    expect(createRes.status).toBe("pending_owner_confirmation");

    const currentBill = await db.query.bills.findFirst({ where: eq(bills.id, bill.id) });
    const currentItem = await db.query.billItems.findFirst({ where: eq(billItems.id, item.id) });

    expect(currentBill?.status).toBe("unpaid");
    expect(currentItem?.amountPaid).toBe("0.00");

    // No ledger created yet
    const ledgers = await db.query.financialTransactions.findMany({ where: eq(financialTransactions.billId, bill.id) });
    expect(ledgers.length).toBe(0);
  });

  // 4.49 Test 3 — Owner Rejects Valid Slip
  it("Test 3: Owner Rejects Valid Slip — Status REJECTED, Debt Unchanged", async () => {
    const { bill, items } = await createTestBill(1000);
    const item = items[0];

    slipService.setMockResult({
      verified: true,
      amount: 1000,
      transactionReference: "TX-TEST-3",
    });

    const createRes = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 1000,
      slip: Buffer.from("test-slip-reject"),
    });

    const rejectRes = await paymentService.rejectPayment(ownerId, createRes.id, {
      reason: "Slip amount does not match my bank statement",
    });

    expect(rejectRes.success).toBe(true);
    expect(rejectRes.data.status).toBe("rejected");

    const currentItem = await db.query.billItems.findFirst({ where: eq(billItems.id, item.id) });
    expect(currentItem?.amountPaid).toBe("0.00");
  });

  // 4.50 Test 4 — SlipOK Verification Fails
  it("Test 4: SlipOK Verification Fails — Status VERIFICATION_FAILED, No Ledger", async () => {
    const { bill, items } = await createTestBill(1000);
    const item = items[0];

    slipService.setMockResult({
      verified: false,
      failureCode: "INVALID_QR",
      failureMessage: "Bank QR is corrupted or invalid",
    });

    const createRes = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 1000,
      slip: Buffer.from("corrupted-slip"),
    });

    expect(createRes.status).toBe("verification_failed");

    // Attempting to confirm a failed verification must throw
    let errorThrown = false;
    try {
      await paymentService.confirmPayment(ownerId, createRes.id);
    } catch (err: any) {
      errorThrown = true;
      expect(err.message).toContain("PAYMENT_STATE_CONFLICT");
    }
    expect(errorThrown).toBe(true);
  });

  // 4.51 & 4.52 Test 5 & 6 — Installments & History Preservation
  it("Test 5 & 6: Installments (300, 300, 400) — History is preserved with deterministic installment numbers", async () => {
    const { bill, items } = await createTestBill(1000);
    const item = items[0];

    // Installment 1 (300)
    slipService.setMockResult({ verified: true, amount: 300, transactionReference: "TX-INST-1" });
    const p1 = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 300,
      method: "installment",
      slip: Buffer.from("slip-1"),
    });
    await paymentService.confirmPayment(ownerId, p1.id);

    let billCheck = await db.query.bills.findFirst({ where: eq(bills.id, bill.id) });
    expect(billCheck?.status).toBe("partially_paid");

    // Installment 2 (300)
    slipService.setMockResult({ verified: true, amount: 300, transactionReference: "TX-INST-2" });
    const p2 = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 300,
      method: "installment",
      slip: Buffer.from("slip-2"),
    });
    await paymentService.confirmPayment(ownerId, p2.id);

    // Installment 3 (400)
    slipService.setMockResult({ verified: true, amount: 400, transactionReference: "TX-INST-3" });
    const p3 = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 400,
      method: "installment",
      slip: Buffer.from("slip-3"),
    });
    await paymentService.confirmPayment(ownerId, p3.id);

    billCheck = await db.query.bills.findFirst({ where: eq(bills.id, bill.id) });
    expect(billCheck?.status).toBe("fully_paid");

    // Check payment history
    const history = await paymentService.getBillPaymentsHistory(debtor1Id, bill.id);
    expect(history.length).toBe(3);
    expect(history[0].installmentNumber).toBe(1);
    expect(parseFloat(history[0].amount)).toBe(300);
    expect(history[1].installmentNumber).toBe(2);
    expect(parseFloat(history[1].amount)).toBe(300);
    expect(history[2].installmentNumber).toBe(3);
    expect(parseFloat(history[2].amount)).toBe(400);
  });

  // 4.53 & 4.69 Test 7 & 23 — Duplicate Slip & Reused Slip Prevention
  it("Test 7 & 23: Duplicate Slip & Reused Slip — Rejects duplicate hash or reference", async () => {
    const { bill, items } = await createTestBill(1000);
    const item = items[0];

    const slipBytes = Buffer.from("unique-slip-bytes-xyz");
    slipService.setMockResult({ verified: true, amount: 500, transactionReference: "REUSED-REF-999" });

    // First payment succeeds
    const p1 = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 500,
      slip: slipBytes,
    });
    await paymentService.confirmPayment(ownerId, p1.id);

    // Second payment with same slip file hash must be rejected
    let hashErrorThrown = false;
    try {
      await paymentService.createPayment(debtor1Id, bill.id, {
        participantId: item.id,
        amount: 500,
        slip: slipBytes,
      });
    } catch (err: any) {
      hashErrorThrown = true;
      expect(err.message).toContain("DUPLICATE_SLIP");
    }
    expect(hashErrorThrown).toBe(true);

    // Second payment with different file but same transaction reference must be rejected
    let refErrorThrown = false;
    try {
      await paymentService.createPayment(debtor1Id, bill.id, {
        participantId: item.id,
        amount: 500,
        slip: Buffer.from("different-image-same-ref"),
      });
    } catch (err: any) {
      refErrorThrown = true;
      expect(err.message).toContain("DUPLICATE_SLIP");
    }
    expect(refErrorThrown).toBe(true);
  });

  // 4.54 Test 8 — Payment Exceeds Outstanding
  it("Test 8: Payment Exceeds Debt — Rejects 600 THB payment when debt is 500 THB", async () => {
    const { bill, items } = await createTestBill(500, [{ debtorId: debtor1Id, amount: 500 }]);
    const item = items[0];

    let errorThrown = false;
    try {
      await paymentService.createPayment(debtor1Id, bill.id, {
        participantId: item.id,
        amount: 600,
        slip: Buffer.from("overpay-slip"),
      });
    } catch (err: any) {
      errorThrown = true;
      expect(err.message).toContain("PAYMENT_EXCEEDS_OUTSTANDING");
    }
    expect(errorThrown).toBe(true);
  });

  // 4.55 Test 9 — Double Confirmation Concurrency Protection
  it("Test 9: Double Confirmation Protection — Only first confirmation succeeds", async () => {
    const { bill, items } = await createTestBill(1000);
    const item = items[0];

    slipService.setMockResult({ verified: true, amount: 500, transactionReference: "TX-DOUBLE-CONFIRM" });
    const p = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 500,
      slip: Buffer.from("double-confirm-slip"),
    });

    const firstConfirm = await paymentService.confirmPayment(ownerId, p.id);
    expect(firstConfirm.success).toBe(true);

    // Second confirmation call
    let doubleError = false;
    try {
      await paymentService.confirmPayment(ownerId, p.id);
    } catch (err: any) {
      doubleError = true;
      expect(err.message).toContain("PAYMENT_ALREADY_CONFIRMED");
    }
    expect(doubleError).toBe(true);
  });

  // 4.57 Test 11 — Payment + Write-Off Race Condition
  it("Test 11: Payment + Write-off Race — Invariant paid + writtenOff + remaining = original is maintained", async () => {
    const { bill, items } = await createTestBill(1000);
    const item = items[0];

    // Write-off 600 first
    await writeOffService.writeOffDebt(ownerId, bill.id, {
      participants: [{ participantId: item.id, amount: 600 }],
    });

    // Debtor tries to pay 500 (which exceeds remaining 400)
    let raceError = false;
    try {
      await paymentService.createPayment(debtor1Id, bill.id, {
        participantId: item.id,
        amount: 500,
        slip: Buffer.from("exceed-writeoff-slip"),
      });
    } catch (err: any) {
      raceError = true;
      expect(err.message).toContain("PAYMENT_EXCEEDS_OUTSTANDING");
    }
    expect(raceError).toBe(true);

    // Debtor pays exact remaining 400
    slipService.setMockResult({ verified: true, amount: 400, transactionReference: "TX-REMAINING-400" });
    const p = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 400,
      slip: Buffer.from("pay-remaining-400"),
    });
    await paymentService.confirmPayment(ownerId, p.id);

    const updatedItem = await db.query.billItems.findFirst({ where: eq(billItems.id, item.id) });
    expect(Number(updatedItem?.amountPaid)).toBe(400);
    expect(Number(updatedItem?.amountWrittenOff)).toBe(600);
    expect(Number(updatedItem?.currentAmount)).toBe(1000);
  });

  // 4.63 & 4.64 Test 17 & 18 — Authorization & IDOR Protection
  it("Test 17 & 18: Authorization & IDOR — Debtor cannot confirm own payment, Outsider cannot view or confirm", async () => {
    const { bill, items } = await createTestBill(1000);
    const item = items[0];

    slipService.setMockResult({ verified: true, amount: 500, transactionReference: "TX-IDOR" });
    const p = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 500,
      slip: Buffer.from("idor-slip"),
    });

    // Debtor tries to confirm own payment
    let debtorConfirmErr = false;
    try {
      await paymentService.confirmPayment(debtor1Id, p.id);
    } catch (err: any) {
      debtorConfirmErr = true;
      expect(err.message).toContain("UNAUTHORIZED");
    }
    expect(debtorConfirmErr).toBe(true);

    // Outsider tries to confirm payment
    let outsiderConfirmErr = false;
    try {
      await paymentService.confirmPayment(outsiderId, p.id);
    } catch (err: any) {
      outsiderConfirmErr = true;
      expect(err.message).toContain("UNAUTHORIZED");
    }
    expect(outsiderConfirmErr).toBe(true);

    // Outsider tries to view payment details
    let outsiderViewErr = false;
    try {
      await paymentService.getPaymentDetails(outsiderId, p.id);
    } catch (err: any) {
      outsiderViewErr = true;
      expect(err.message).toContain("UNAUTHORIZED");
    }
    expect(outsiderViewErr).toBe(true);
  });

  // 4.66 & 4.67 Test 20 & 21 — Notification Resilience & Idempotency
  it("Test 20 & 21: Notification Resilience & Idempotency Key", async () => {
    const { bill, items } = await createTestBill(1000);
    const item = items[0];

    notificationService.setShouldFail(true); // Simulate LINE downtime

    slipService.setMockResult({ verified: true, amount: 500, transactionReference: "TX-NOTIF-FAIL" });
    const p = await paymentService.createPayment(debtor1Id, bill.id, {
      participantId: item.id,
      amount: 500,
      slip: Buffer.from("notif-fail-slip"),
      idempotencyKey: "PAY-IDEM-001",
    });

    const confirmRes = await paymentService.confirmPayment(ownerId, p.id, {
      idempotencyKey: "CONFIRM-IDEM-001",
    });
    expect(confirmRes.success).toBe(true);

    // Repeated confirm with same key returns identical result without error or duplicate mutation
    const repeatConfirm = await paymentService.confirmPayment(ownerId, p.id, {
      idempotencyKey: "CONFIRM-IDEM-001",
    });
    expect(repeatConfirm.success).toBe(true);

    const txs = await db.query.financialTransactions.findMany({ where: eq(financialTransactions.billId, bill.id) });
    expect(txs.length).toBe(1); // Exactly 1 ledger entry
  });

  // 4.70 & 4.71 Test 24 & 25 — Slip Amount & Recipient Mismatch
  it("Test 24 & 25: Slip Amount & Recipient Mismatch — Rejects invalid slip metadata", async () => {
    const { bill, items } = await createTestBill(1000);
    const item = items[0];

    // Amount mismatch: User says 500, Slip says 400
    slipService.setMockResult({ verified: true, amount: 400, transactionReference: "TX-MISMATCH-AMT" });
    let amtMismatch = false;
    try {
      await paymentService.createPayment(debtor1Id, bill.id, {
        participantId: item.id,
        amount: 500,
        slip: Buffer.from("slip-mismatch-amt"),
      });
    } catch (err: any) {
      amtMismatch = true;
      expect(err.message).toContain("SLIP_AMOUNT_MISMATCH");
    }
    expect(amtMismatch).toBe(true);

    // Recipient mismatch: Transferred to another PromptPay ID
    slipService.setMockResult({
      verified: true,
      amount: 500,
      transactionReference: "TX-MISMATCH-REC",
      receiver: { promptPayId: "0999999999" }, // Owner has 0812345678
    });
    let recMismatch = false;
    try {
      await paymentService.createPayment(debtor1Id, bill.id, {
        participantId: item.id,
        amount: 500,
        slip: Buffer.from("slip-mismatch-rec"),
      });
    } catch (err: any) {
      recMismatch = true;
      expect(err.message).toContain("SLIP_RECIPIENT_MISMATCH");
    }
    expect(recMismatch).toBe(true);
  });
});
