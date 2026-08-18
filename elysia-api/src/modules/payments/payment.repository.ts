import { db } from "../../db";
import {
  payments,
  paymentVerifications,
  financialTransactions,
  billItems,
  bills,
  editLogs,
  users,
} from "../../db/schema";
import { eq, and, desc, sql, or } from "drizzle-orm";
import { PaymentStatus } from "./payment-state-machine";

export interface CreatePaymentRecordInput {
  billItemId: string;
  payerId: string;
  amount: string;
  method: "full" | "installment";
  channel: "promptpay_qr" | "bank_transfer" | "cash";
  installmentNumber: number | null;
  slipImageUrl?: string;
  slipHash?: string;
  slipOkReferenceId?: string;
  slipOkVerifiedAt?: Date;
  slipOkRawResponse?: any;
  status: PaymentStatus;
}

export class PaymentRepository {
  /**
   * Find existing payment with the same slip hash or slip reference
   * to detect duplicate or reused slips across the system.
   */
  async findDuplicateSlip(slipHash?: string, slipReference?: string) {
    if (!slipHash && !slipReference) return null;

    const conditions = [];
    if (slipHash) conditions.push(eq(payments.slipHash, slipHash));
    if (slipReference) conditions.push(eq(payments.slipOkReferenceId, slipReference));

    // Only count payments that are not rejected or failed
    return await db.query.payments.findFirst({
      where: and(
        or(...conditions),
        or(
          eq(payments.status, "confirmed"),
          eq(payments.status, "pending_owner_confirmation"),
          eq(payments.status, "pending_verification")
        )
      ),
      with: { billItem: { with: { bill: true } } },
    });
  }

  /**
   * Compute next installment number deterministically for a participant.
   */
  async getNextInstallmentNumber(billItemId: string): Promise<number> {
    const existing = await db.query.payments.findMany({
      where: eq(payments.billItemId, billItemId),
      orderBy: [desc(payments.createdAt)],
    });
    const maxInstallment = existing.reduce((max, p) => {
      return p.installmentNumber && p.installmentNumber > max ? p.installmentNumber : max;
    }, 0);
    return maxInstallment + 1;
  }

  /**
   * Create payment record & initial verification attempt.
   */
  async createPayment(
    data: CreatePaymentRecordInput,
    verification?: {
      provider: string;
      status: string;
      providerReference?: string;
      verifiedAmount?: string;
      senderInfo?: any;
      receiverInfo?: any;
      failureCode?: string;
      failureMessage?: string;
      rawResponse?: any;
    }
  ) {
    return await db.transaction(async (tx) => {
      const [newPayment] = await tx
        .insert(payments)
        .values({
          billItemId: data.billItemId,
          payerId: data.payerId,
          amount: data.amount,
          method: data.method,
          channel: data.channel,
          installmentNumber: data.installmentNumber,
          slipImageUrl: data.slipImageUrl,
          slipHash: data.slipHash,
          slipOkReferenceId: data.slipOkReferenceId,
          slipOkVerifiedAt: data.slipOkVerifiedAt,
          slipOkRawResponse: data.slipOkRawResponse,
          status: data.status,
        })
        .returning();

      if (verification) {
        await tx.insert(paymentVerifications).values({
          paymentId: newPayment.id,
          provider: verification.provider,
          status: verification.status,
          providerReference: verification.providerReference,
          verifiedAmount: verification.verifiedAmount,
          senderInfo: verification.senderInfo,
          receiverInfo: verification.receiverInfo,
          failureCode: verification.failureCode,
          failureMessage: verification.failureMessage,
          rawResponse: verification.rawResponse,
        });
      }

      return newPayment;
    });
  }

  async getPaymentById(paymentId: string) {
    return await db.query.payments.findFirst({
      where: eq(payments.id, paymentId),
      with: {
        billItem: {
          with: {
            bill: { with: { owner: true } },
            debtor: true,
          },
        },
        payer: true,
        verifications: true,
      },
    });
  }

  async getPaymentsByBillId(billId: string) {
    const items = await db.query.billItems.findMany({
      where: eq(billItems.billId, billId),
      with: {
        payments: {
          orderBy: (p, { asc }) => [asc(p.createdAt)],
          with: { payer: true },
        },
        debtor: true,
      },
    });

    const allPayments = items.flatMap((item) =>
      item.payments.map((p) => ({
        ...p,
        participantId: item.id,
        debtor: item.debtor,
      }))
    );

    // Sort chronologically
    return allPayments.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
  }
}
