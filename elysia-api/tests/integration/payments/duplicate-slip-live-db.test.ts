import { describe, it, expect, afterAll } from "bun:test";
import { db } from "../../../src/db";
import {
  users,
  bills,
  billItems,
  payments,
  paymentVerifications,
  financialTransactions,
  editLogs,
  suspiciousActivityLogs,
} from "../../../src/db/schema";
import { eq, and } from "drizzle-orm";
import { PaymentService } from "../../../src/modules/payments/payment.service";
import { EasySlipVerificationService } from "../../../src/modules/payments/slip-verification.service";

describe("Live DB: Duplicate Slip Detection & Suspicious Activity Logging", () => {
  const testOwnerId = "11111111-9999-4444-8888-111111111111";
  const testDebtorId = "22222222-9999-4444-8888-222222222222";
  const testBillId = "33333333-9999-4444-8888-333333333333";
  const testBillItemId = "44444444-9999-4444-8888-444444444444";

  const slipFileA = Buffer.from("PINGPAY_TEST_SLIP_IMAGE_CONTENT_SAMPLE_2026");

  afterAll(async () => {
    // Clean up test data from real DB
    await db.delete(suspiciousActivityLogs).where(eq(suspiciousActivityLogs.userId, testDebtorId));
    await db.delete(financialTransactions).where(eq(financialTransactions.billId, testBillId));
    await db.delete(paymentVerifications).where(
      eq(
        paymentVerifications.paymentId,
        db.select({ id: payments.id }).from(payments).where(eq(payments.billItemId, testBillItemId)) as any
      )
    ).catch(() => {});
    await db.delete(payments).where(eq(payments.billItemId, testBillItemId));
    await db.delete(billItems).where(eq(billItems.id, testBillItemId));
    await db.delete(bills).where(eq(bills.id, testBillId));
    await db.delete(users).where(eq(users.id, testOwnerId));
    await db.delete(users).where(eq(users.id, testDebtorId));
  });

  it("should record duplicate slip in real DB suspicious_activity_logs when same slip is submitted", async () => {
    // 1. Clean previous run artifacts
    await db.delete(suspiciousActivityLogs).where(eq(suspiciousActivityLogs.userId, testDebtorId));
    await db.delete(financialTransactions).where(eq(financialTransactions.billId, testBillId));
    await db.delete(payments).where(eq(payments.billItemId, testBillItemId));
    await db.delete(billItems).where(eq(billItems.id, testBillItemId));
    await db.delete(bills).where(eq(bills.id, testBillId));
    await db.delete(users).where(eq(users.id, testOwnerId));
    await db.delete(users).where(eq(users.id, testDebtorId));

    // 2. Setup real DB records
    await db.insert(users).values([
      {
        id: testOwnerId,
        userCode: "USR-TEST-OWNER",
        displayName: "Test Owner",
        fullName: "Owner Somchai",
        promptPayId: "0812345678",
        bankAccountNumber: "1234567890",
      },
      {
        id: testDebtorId,
        userCode: "USR-TEST-DEBTOR",
        displayName: "Test Debtor",
        fullName: "Debtor Somsak",
        promptPayId: "0898765432",
      },
    ]);

    await db.insert(bills).values({
      id: testBillId,
      ownerId: testOwnerId,
      title: "Dinner Live Test",
      totalAmount: "1000.00",
      status: "unpaid",
    });

    await db.insert(billItems).values({
      id: testBillItemId,
      billId: testBillId,
      debtorId: testDebtorId,
      originalAmount: "500.00",
      currentAmount: "500.00",
      amountPaid: "0.00",
      amountWrittenOff: "0.00",
      status: "unpaid",
    });

    // 3. Mock slip verification engine (Offline mock, does NOT call external EasySlip API)
    const mockSlipService = new EasySlipVerificationService();
    mockSlipService.setMockResult({
      verified: true,
      amount: 250,
      transactionReference: "EASYSLIP-MOCK-REF-1001",
      sender: { name: "Debtor Somsak", account: "089-xxx-5432" },
      receiver: { name: "Owner Somchai", promptPayId: "081-xxx-5678" },
    });

    const paymentService = new PaymentService(undefined, mockSlipService);

    // 4. First submission: Valid payment with Slip A
    const firstPayment = await paymentService.createPayment(testDebtorId, testBillId, {
      participantId: testBillItemId,
      amount: 250,
      slip: slipFileA,
      channel: "promptpay_qr",
      method: "installment",
    });

    expect(firstPayment.status).toBe("confirmed");
    expect(firstPayment.slipOkVerified).toBe(true);

    // Verify slip hash is stored in real DB payments table
    const storedPayment = await db.query.payments.findFirst({
      where: eq(payments.id, firstPayment.id),
    });
    expect(storedPayment).toBeDefined();
    expect(storedPayment?.slipHash).toBeDefined();
    const expectedHash = mockSlipService.computeFileHash(slipFileA);
    expect(storedPayment?.slipHash).toBe(expectedHash);

    // 5. Second submission: Submit the EXACT SAME slip again (Duplicate Attempt)
    let duplicateError: Error | null = null;
    try {
      await paymentService.createPayment(testDebtorId, testBillId, {
        participantId: testBillItemId,
        amount: 250,
        slip: slipFileA, // Same file buffer -> Same SHA-256 hash
        channel: "promptpay_qr",
        method: "installment",
      });
    } catch (err: any) {
      duplicateError = err;
    }

    // 6. Assert error thrown
    expect(duplicateError).not.toBeNull();
    expect(duplicateError?.message).toContain("DUPLICATE_SLIP");

    // 7. Verify real DB suspicious_activity_logs table has captured this event
    const threatLogs = await db.query.suspiciousActivityLogs.findMany({
      where: and(
        eq(suspiciousActivityLogs.userId, testDebtorId),
        eq(suspiciousActivityLogs.type, "duplicate_slip")
      ),
    });

    expect(threatLogs.length).toBeGreaterThan(0);
    const latestThreat = threatLogs[threatLogs.length - 1];
    expect(latestThreat.type).toBe("duplicate_slip");
    expect(latestThreat.description).toContain("Duplicate slip hash submitted");
    expect(latestThreat.metadata).toBeDefined();
    expect((latestThreat.metadata as any)?.slipHash).toBe(expectedHash);
  });
});
