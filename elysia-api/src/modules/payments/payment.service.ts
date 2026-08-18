import { db } from "../../db";
import {
  payments,
  billItems,
  bills,
  financialTransactions,
  editLogs,
  users,
} from "../../db/schema";
import { eq, sql } from "drizzle-orm";
import { PaymentRepository } from "./payment.repository";
import { PaymentStateMachine } from "./payment-state-machine";
import {
  SlipVerificationService,
  defaultSlipVerificationService,
} from "./slip-verification.service";
import { BillStatusService } from "../bills/bill-status.service";
import {
  NotificationService,
  defaultNotificationService,
} from "../bills/bill-notification.service";
import {
  NotificationOutboxService,
  defaultNotificationOutboxService,
} from "../notifications/notification-outbox.service";

export interface CreatePaymentDTO {
  participantId: string; // bill_items.id
  amount: number;
  method?: "full" | "installment";
  channel?: "promptpay_qr" | "bank_transfer" | "cash";
  slip?: Blob | Buffer;
  qrData?: string;
  idempotencyKey?: string;
}

export interface ConfirmPaymentDTO {
  idempotencyKey?: string;
}

export interface RejectPaymentDTO {
  reason: string;
  idempotencyKey?: string;
}

export class PaymentService {
  private repo: PaymentRepository;
  private slipService: SlipVerificationService;
  private notificationService: NotificationService;
  private outboxService: NotificationOutboxService;
  private processedIdempotencyKeys = new Map<string, any>();

  constructor(
    repo?: PaymentRepository,
    slipService?: SlipVerificationService,
    notificationService?: NotificationService,
    outboxService?: NotificationOutboxService
  ) {
    this.repo = repo || new PaymentRepository();
    this.slipService = slipService || defaultSlipVerificationService;
    this.notificationService = notificationService || defaultNotificationService;
    this.outboxService = outboxService || defaultNotificationOutboxService;
  }

  /**
   * 4.4 & 4.13 Create Payment Flow (Debtor submits payment + slip):
   * 1. Authenticate & validate payer is the debtor
   * 2. Calculate outstanding balance & prevent overpayment
   * 3. Compute slip hash and call SlipOK
   * 4. Validate SlipOK amount, recipient & duplicate references
   * 5. Set status = PENDING_OWNER_CONFIRMATION (NOT confirmed!)
   * 6. Notify bill owner to review & confirm
   */
  async createPayment(payerId: string, billId: string, dto: CreatePaymentDTO) {
    if (dto.idempotencyKey && this.processedIdempotencyKeys.has(dto.idempotencyKey)) {
      return this.processedIdempotencyKeys.get(dto.idempotencyKey);
    }

    if (!dto.amount || dto.amount <= 0) {
      throw new Error("INVALID_AMOUNT: Payment amount must be greater than 0.");
    }

    const bill = await db.query.bills.findFirst({
      where: eq(bills.id, billId),
      with: {
        items: { with: { debtor: true } },
        owner: true,
      },
    });

    if (!bill) {
      throw new Error("BILL_NOT_FOUND: Bill not found.");
    }

    const item = bill.items.find((i) => i.id === dto.participantId);
    if (!item) {
      throw new Error("PARTICIPANT_NOT_FOUND: Participant not found in this bill.");
    }

    // Authorization: Only the debtor can submit payments for their own debt
    if (item.debtorId !== payerId) {
      throw new Error("UNAUTHORIZED: You can only submit payments for your own debt.");
    }

    // 4.11 & 4.12 Outstanding Balance and Overpayment Prevention
    const currentCents = Math.round(Number(item.currentAmount) * 100);
    const paidCents = Math.round(Number(item.amountPaid) * 100);
    const writtenOffCents = Math.round(Number(item.amountWrittenOff) * 100);
    const outstandingCents = Math.max(0, currentCents - paidCents - writtenOffCents);
    const paymentCents = Math.round(dto.amount * 100);

    if (paymentCents > outstandingCents) {
      throw new Error(
        `PAYMENT_EXCEEDS_OUTSTANDING: Payment amount (${dto.amount} THB) exceeds outstanding debt (${(
          outstandingCents / 100
        ).toFixed(2)} THB).`
      );
    }

    // Compute slip hash if file provided
    let slipHash: string | undefined = undefined;
    let slipBuffer: Buffer | undefined = undefined;
    if (dto.slip) {
      if (dto.slip instanceof Buffer) {
        slipBuffer = dto.slip;
      } else {
        const ab = await dto.slip.arrayBuffer();
        slipBuffer = Buffer.from(ab);
      }
      slipHash = this.slipService.computeFileHash(slipBuffer);
    }

    // Check duplicate slip hash across system
    if (slipHash) {
      const duplicateByHash = await this.repo.findDuplicateSlip(slipHash);
      if (duplicateByHash) {
        throw new Error("DUPLICATE_SLIP: This slip image has already been submitted for a payment.");
      }
    }

    // 4.19 - 4.21 Verify with SlipOK
    const slipResult = await this.slipService.verify({
      slipFile: slipBuffer,
      qrData: dto.qrData,
      expectedAmount: dto.amount,
      expectedReceiverPromptPay: bill.owner.promptPayId || undefined,
      expectedReceiverAccount: bill.owner.bankAccountNumber || undefined,
    });

    // 4.22 Check duplicate SlipOK transaction reference
    if (slipResult.transactionReference) {
      const duplicateByRef = await this.repo.findDuplicateSlip(
        undefined,
        slipResult.transactionReference
      );
      if (duplicateByRef) {
        throw new Error(
          "DUPLICATE_SLIP: This bank transfer transaction reference has already been consumed."
        );
      }
    }

    // 4.21 Validate verified amount matches payment amount
    if (slipResult.verified && slipResult.amount !== undefined) {
      const slipAmountCents = Math.round(slipResult.amount * 100);
      if (slipAmountCents !== paymentCents) {
        throw new Error(
          `SLIP_AMOUNT_MISMATCH: Slip amount (${slipResult.amount} THB) does not match submitted amount (${dto.amount} THB).`
        );
      }
    }

    // 4.26 Validate receiver promptpay / account if available
    if (slipResult.verified && slipResult.receiver) {
      const expectedPP = bill.owner.promptPayId;
      const expectedAcc = bill.owner.bankAccountNumber;
      const actualPP = slipResult.receiver.promptPayId;
      const actualAcc = slipResult.receiver.account;

      if (expectedPP && actualPP && expectedPP !== actualPP) {
        throw new Error("SLIP_RECIPIENT_MISMATCH: Slip was transferred to an unexpected recipient PromptPay ID.");
      }
    }

    const installmentNo = await this.repo.getNextInstallmentNumber(item.id);
    const initialStatus = slipResult.verified
      ? "pending_owner_confirmation"
      : "verification_failed";

    const newPayment = await this.repo.createPayment(
      {
        billItemId: item.id,
        payerId,
        amount: dto.amount.toFixed(2),
        method: dto.method || "full",
        channel: dto.channel || "promptpay_qr",
        installmentNumber: installmentNo,
        slipHash: slipResult.slipHash || slipHash,
        slipOkReferenceId: slipResult.transactionReference,
        slipOkVerifiedAt: slipResult.verified ? new Date() : undefined,
        slipOkRawResponse: slipResult.rawResponse,
        status: initialStatus,
      },
      {
        provider: "slipok",
        status: slipResult.verified ? "success" : "failed",
        providerReference: slipResult.transactionReference,
        verifiedAmount: slipResult.amount !== undefined ? slipResult.amount.toFixed(2) : undefined,
        senderInfo: slipResult.sender,
        receiverInfo: slipResult.receiver,
        failureCode: slipResult.failureCode,
        failureMessage: slipResult.failureMessage,
        rawResponse: slipResult.rawResponse,
      }
    );

    // 5.2 & 5.26 Enqueue PAYMENT_PENDING_CONFIRMATION to Bill Owner
    if (initialStatus === "pending_owner_confirmation") {
      await this.outboxService.enqueue({
        eventType: "PAYMENT_PENDING_CONFIRMATION",
        recipientUserId: bill.ownerId,
        deduplicationKey: `PAYMENT_PENDING_CONFIRMATION:${newPayment.id}:${bill.ownerId}`,
        payload: {
          billId: bill.id,
          billTitle: bill.title || "Bill",
          paymentId: newPayment.id,
          participantId: item.id,
          payerId,
          payerName: item.debtor.displayName || item.debtor.fullName || "Friend",
          amount: dto.amount.toFixed(2),
          currency: bill.currency || "THB",
          slipVerified: true,
        },
      });

      // Backward compatibility with mock line notification
      try {
        await this.notificationService.notify({
          userId: bill.ownerId,
          billId: bill.id,
          billTitle: bill.title || "Bill",
          actorName: item.debtor.displayName || item.debtor.fullName || "Friend",
          type: "update",
          oldAmount: (outstandingCents / 100).toFixed(2),
          newAmount: ((outstandingCents - paymentCents) / 100).toFixed(2),
          reason: `Slip verified (${dto.amount} THB). Please review and confirm receipt.`,
          timestamp: new Date(),
        });
      } catch (err) {}
    }

    const result = {
      id: newPayment.id,
      billId: bill.id,
      participantId: item.id,
      payerId,
      amount: parseFloat(newPayment.amount),
      status: newPayment.status,
      installmentNumber: newPayment.installmentNumber,
      slipOkVerified: slipResult.verified,
      message: slipResult.verified
        ? "Payment submitted and verified by SlipOK. Waiting for bill owner confirmation."
        : "Slip verification failed. Payment cannot proceed to confirmation.",
    };

    if (dto.idempotencyKey) {
      this.processedIdempotencyKeys.set(dto.idempotencyKey, result);
    }

    return result;
  }

  /**
   * 4.16 Bill Owner Confirmation Flow:
   * 1. Authenticate & Authorize owner
   * 2. Acquire lock on payment & bill item
   * 3. Validate state is PENDING_OWNER_CONFIRMATION
   * 4. Execute atomic DB transaction:
   *    - Set payment status = CONFIRMED
   *    - Insert immutable financial_transactions row
   *    - Update billItems.amountPaid
   *    - Recalculate bill & participant statuses using BillStatusService
   *    - Create audit log in edit_logs
   * 5. Dispatch LINE notification to debtor AFTER commit
   */
  async confirmPayment(userId: string, paymentId: string, dto: ConfirmPaymentDTO = {}) {
    if (dto.idempotencyKey && this.processedIdempotencyKeys.has(dto.idempotencyKey)) {
      return this.processedIdempotencyKeys.get(dto.idempotencyKey);
    }

    let notificationToSend: {
      debtorId: string;
      billId: string;
      billTitle: string;
      actorName: string;
      paidAmount: string;
      remainingDebt: string;
      installmentNo: number;
    } | null = null;

    const confirmedResult = await db.transaction(async (tx) => {
      // 4.44 Concurrency Lock: Lock payment row FOR UPDATE
      const paymentRows = await tx
        .select()
        .from(payments)
        .where(eq(payments.id, paymentId))
        .for("update");

      if (!paymentRows || paymentRows.length === 0) {
        throw new Error("PAYMENT_NOT_FOUND: Payment record not found.");
      }

      const payment = paymentRows[0];

      // Verify payment state
      if (payment.status === "confirmed") {
        throw new Error("PAYMENT_ALREADY_CONFIRMED: This payment has already been confirmed.");
      }

      PaymentStateMachine.assertTransition(payment.status as any, "confirmed");

      // Load bill item & bill with FOR UPDATE lock
      const itemRows = await tx
        .select()
        .from(billItems)
        .where(eq(billItems.id, payment.billItemId))
        .for("update");

      if (!itemRows || itemRows.length === 0) {
        throw new Error("PARTICIPANT_NOT_FOUND: Associated bill item not found.");
      }

      const item = itemRows[0];
      const bill = await tx.query.bills.findFirst({
        where: eq(bills.id, item.billId),
        with: { items: true, owner: true },
      });

      if (!bill) {
        throw new Error("BILL_NOT_FOUND: Bill not found.");
      }

      // Authorization: Only bill owner or developer can confirm payments
      if (bill.ownerId !== userId) {
        throw new Error("UNAUTHORIZED: Only the bill owner can confirm payments.");
      }

      const currentCents = Math.round(Number(item.currentAmount) * 100);
      const paidCents = Math.round(Number(item.amountPaid) * 100);
      const writtenOffCents = Math.round(Number(item.amountWrittenOff) * 100);
      const paymentCents = Math.round(Number(payment.amount) * 100);

      const newPaidCents = paidCents + paymentCents;
      const newPaidAmount = (newPaidCents / 100).toFixed(2);
      const remainingCents = Math.max(0, currentCents - newPaidCents - writtenOffCents);
      const newRemainingDebt = (remainingCents / 100).toFixed(2);

      // 4.12 Concurrency safety check: check if total paid exceeds current amount
      if (newPaidCents + writtenOffCents > currentCents) {
        throw new Error("PAYMENT_EXCEEDS_OUTSTANDING: Concurrent transactions exceeded the remaining debt balance.");
      }

      const isFullySettled = remainingCents === 0;

      // 1. Update Payment Status to CONFIRMED
      const [updatedPayment] = await tx
        .update(payments)
        .set({
          status: "confirmed",
          confirmedByOwnerAt: new Date(),
          confirmedByOwnerId: userId,
          updatedAt: new Date(),
        })
        .where(eq(payments.id, payment.id))
        .returning();

      // 2. Insert Immutable Financial Transaction
      await tx.insert(financialTransactions).values({
        billId: bill.id,
        billItemId: item.id,
        type: "payment",
        amount: payment.amount,
        currency: bill.currency,
        referenceId: payment.id,
        createdById: userId,
        metadata: {
          installmentNumber: payment.installmentNumber,
          slipOkReferenceId: payment.slipOkReferenceId,
          idempotencyKey: dto.idempotencyKey,
        },
      });

      // 3. Update Bill Item
      await tx
        .update(billItems)
        .set({
          amountPaid: newPaidAmount,
          status: isFullySettled ? "paid" : "partially_paid",
          isLocked: isFullySettled ? true : item.isLocked,
          updatedAt: new Date(),
        })
        .where(eq(billItems.id, item.id));

      // 4. Derive and Recalculate Overall Bill Status via BillStatusService
      const allBillItems = await tx.query.billItems.findMany({
        where: eq(billItems.billId, bill.id),
      });

      const participantStates = allBillItems.map((bi) => {
        if (bi.id === item.id) {
          return {
            originalDebt: Number(bi.originalAmount),
            currentAmount: Number(bi.currentAmount),
            amountPaid: newPaidCents / 100,
            amountWrittenOff: Number(bi.amountWrittenOff),
          };
        }
        return {
          originalDebt: Number(bi.originalAmount),
          currentAmount: Number(bi.currentAmount),
          amountPaid: Number(bi.amountPaid),
          amountWrittenOff: Number(bi.amountWrittenOff),
        };
      });

      const calculatedBillStatus = BillStatusService.calculateBillStatus({
        participants: participantStates,
      });

      await tx
        .update(bills)
        .set({
          status: calculatedBillStatus.status,
          updatedAt: new Date(),
        })
        .where(eq(bills.id, bill.id));

      // 5. Create Audit Log
      await tx.insert(editLogs).values({
        action: "bill_item_edited",
        billId: bill.id,
        billItemId: item.id,
        performedById: userId,
        affectedUserId: item.debtorId,
        previousValue: { amountPaid: item.amountPaid, status: item.status },
        newValue: { amountPaid: newPaidAmount, status: isFullySettled ? "paid" : "partially_paid" },
        note: `Payment confirmed: ${payment.amount} THB (Installment #${payment.installmentNumber || 1})`,
      });

      // 5.27 Enqueue PAYMENT_CONFIRMED atomically in Outbox
      await this.outboxService.enqueueInTx(tx, {
        eventType: "PAYMENT_CONFIRMED",
        recipientUserId: item.debtorId,
        deduplicationKey: `PAYMENT_CONFIRMED:${payment.id}:${item.debtorId}`,
        payload: {
          billId: bill.id,
          billTitle: bill.title || "Bill",
          paymentId: payment.id,
          participantId: item.id,
          payerId: item.debtorId,
          confirmerId: userId,
          confirmerName: bill.owner?.displayName || bill.owner?.fullName || "Bill Owner",
          amount: payment.amount,
          currency: bill.currency || "THB",
          installmentNumber: payment.installmentNumber || null,
          remainingDebt: newRemainingDebt,
          isFullyPaid: isFullySettled,
        },
      });

      notificationToSend = {
        debtorId: item.debtorId,
        billId: bill.id,
        billTitle: bill.title || "Bill",
        actorName: bill.owner?.displayName || bill.owner?.fullName || "Bill Owner",
        paidAmount: payment.amount,
        remainingDebt: newRemainingDebt,
        installmentNo: payment.installmentNumber || 1,
      };

      return {
        payment: updatedPayment,
        billStatus: calculatedBillStatus.status,
        remainingDebt: newRemainingDebt,
      };
    });

    // 4.36 Send LINE notification to payer AFTER commit
    if (notificationToSend) {
      const n = notificationToSend;
      try {
        await this.notificationService.notify({
          userId: n.debtorId,
          billId: n.billId,
          billTitle: n.billTitle,
          actorName: n.actorName,
          type: "update",
          oldAmount: (Number(n.remainingDebt) + Number(n.paidAmount)).toFixed(2),
          newAmount: n.remainingDebt,
          reason: `Payment confirmed for ${n.paidAmount} THB (Installment #${n.installmentNo}). Remaining: ${n.remainingDebt} THB`,
          timestamp: new Date(),
        });
      } catch (err) {
        console.error("Failed to send LINE notification to payer:", err);
      }
    }

    const responseData = {
      success: true,
      data: confirmedResult,
    };

    if (dto.idempotencyKey) {
      this.processedIdempotencyKeys.set(dto.idempotencyKey, responseData);
    }

    return responseData;
  }

  /**
   * 4.17 Reject Payment Flow:
   * 1. Authenticate & Authorize bill owner
   * 2. Set payment status = REJECTED
   * 3. Debt balance remains completely unchanged
   * 4. Notify payer of rejection reason
   */
  async rejectPayment(userId: string, paymentId: string, dto: RejectPaymentDTO) {
    if (dto.idempotencyKey && this.processedIdempotencyKeys.has(dto.idempotencyKey)) {
      return this.processedIdempotencyKeys.get(dto.idempotencyKey);
    }

    let notificationToSend: {
      debtorId: string;
      billId: string;
      billTitle: string;
      actorName: string;
      amount: string;
      reason: string;
    } | null = null;

    const rejectedPayment = await db.transaction(async (tx) => {
      const payment = await tx.query.payments.findFirst({
        where: eq(payments.id, paymentId),
        with: {
          billItem: {
            with: {
              bill: { with: { owner: true } },
            },
          },
        },
      });

      if (!payment) {
        throw new Error("PAYMENT_NOT_FOUND: Payment record not found.");
      }

      if (payment.billItem.bill.ownerId !== userId) {
        throw new Error("UNAUTHORIZED: Only the bill owner can reject payments.");
      }

      PaymentStateMachine.assertTransition(payment.status as any, "rejected");

      const [updated] = await tx
        .update(payments)
        .set({
          status: "rejected",
          rejectedAt: new Date(),
          rejectedById: userId,
          rejectedReason: dto.reason,
          updatedAt: new Date(),
        })
        .where(eq(payments.id, payment.id))
        .returning();

      // 5.28 Enqueue PAYMENT_REJECTED atomically in Outbox
      await this.outboxService.enqueueInTx(tx, {
        eventType: "PAYMENT_REJECTED",
        recipientUserId: payment.payerId,
        deduplicationKey: `PAYMENT_REJECTED:${payment.id}:${payment.payerId}`,
        payload: {
          billId: payment.billItem.billId,
          billTitle: payment.billItem.bill.title || "Bill",
          paymentId: payment.id,
          participantId: payment.billItemId,
          payerId: payment.payerId,
          rejecterId: userId,
          rejecterName: payment.billItem.bill.owner?.displayName || "Bill Owner",
          amount: payment.amount,
          currency: payment.billItem.bill.currency || "THB",
          reason: dto.reason,
        },
      });

      notificationToSend = {
        debtorId: payment.payerId,
        billId: payment.billItem.billId,
        billTitle: payment.billItem.bill.title || "Bill",
        actorName: payment.billItem.bill.owner?.displayName || "Bill Owner",
        amount: payment.amount,
        reason: dto.reason,
      };

      return updated;
    });

    if (notificationToSend) {
      const n = notificationToSend;
      try {
        await this.notificationService.notify({
          userId: n.debtorId,
          billId: n.billId,
          billTitle: n.billTitle,
          actorName: n.actorName,
          type: "update",
          oldAmount: n.amount,
          newAmount: n.amount,
          reason: `Payment of ${n.amount} THB was rejected: ${n.reason}`,
          timestamp: new Date(),
        });
      } catch (err) {
        console.error("Failed to send LINE notification for payment rejection:", err);
      }
    }

    const responseData = {
      success: true,
      data: rejectedPayment,
    };

    if (dto.idempotencyKey) {
      this.processedIdempotencyKeys.set(dto.idempotencyKey, responseData);
    }

    return responseData;
  }

  async getPaymentDetails(userId: string, paymentId: string) {
    const payment = await this.repo.getPaymentById(paymentId);
    if (!payment) {
      throw new Error("PAYMENT_NOT_FOUND: Payment not found.");
    }

    // Authorization: only payer or bill owner can inspect payment details
    const isPayer = payment.payerId === userId;
    const isOwner = payment.billItem.bill.ownerId === userId;

    if (!isPayer && !isOwner) {
      throw new Error("UNAUTHORIZED: You do not have permission to view this payment.");
    }

    return payment;
  }

  async getBillPaymentsHistory(userId: string, billId: string) {
    const bill = await db.query.bills.findFirst({
      where: eq(bills.id, billId),
      with: { items: true },
    });

    if (!bill) {
      throw new Error("BILL_NOT_FOUND: Bill not found.");
    }

    // Authorization: owner or participants in the bill can view payments history
    const isOwner = bill.ownerId === userId;
    const isParticipant = bill.items.some((i) => i.debtorId === userId);

    if (!isOwner && !isParticipant) {
      throw new Error("UNAUTHORIZED: You do not have permission to view payments for this bill.");
    }

    return await this.repo.getPaymentsByBillId(billId);
  }
}
