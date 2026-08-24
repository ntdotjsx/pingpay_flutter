import { db } from "../../db";
import {
  payments,
  billItems,
  bills,
  financialTransactions,
  editLogs,
  users,
  suspiciousActivityLogs,
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
import { realtimeService } from "../../realtime/realtime.service";
import { logActivity } from "../activity/activity.service";

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
        await db.insert(suspiciousActivityLogs).values({
          userId: payerId,
          type: "duplicate_slip",
          description: `Duplicate slip hash submitted for bill ${billId} item ${dto.participantId}`,
          metadata: { slipHash, billId, participantId: dto.participantId, existingPaymentId: duplicateByHash.id },
        }).catch(() => {});
        throw new Error("DUPLICATE_SLIP: This slip image has already been submitted for a payment.");
      }
    }

    // 4.19 - 4.21 Verify with EasySlip
    const slipResult = await this.slipService.verify({
      slipFile: slipBuffer,
      qrData: dto.qrData,
      expectedAmount: dto.amount,
      expectedReceiverPromptPay: bill.owner.promptPayId || undefined,
      expectedReceiverAccount: bill.owner.bankAccountNumber || undefined,
    });

    // 4.22 Check duplicate EasySlip transaction reference
    if (slipResult.transactionReference) {
      const duplicateByRef = await this.repo.findDuplicateSlip(
        undefined,
        slipResult.transactionReference
      );
      if (duplicateByRef) {
        await db.insert(suspiciousActivityLogs).values({
          userId: payerId,
          type: "duplicate_slip",
          description: `Duplicate EasySlip bank reference ${slipResult.transactionReference} submitted`,
          metadata: { transactionReference: slipResult.transactionReference, billId, participantId: dto.participantId, existingPaymentId: duplicateByRef.id },
        }).catch(() => {});
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

    // 4.19 Strict Check: Must be verified by EasySlip
    if (!slipResult.verified) {
      throw new Error(`SLIP_VERIFICATION_FAILED: ${slipResult.failureMessage || "Slip verification failed."}`);
    }

    const installmentNo = await this.repo.getNextInstallmentNumber(item.id);

    // 1. Create Payment as CONFIRMED directly
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
        slipOkVerifiedAt: new Date(),
        slipOkRawResponse: slipResult.rawResponse,
        status: "confirmed",
        confirmedByOwnerAt: new Date(),
        confirmedByOwnerId: bill.ownerId,
      },
      {
        provider: "easyslip",
        status: "success",
        providerReference: slipResult.transactionReference,
        verifiedAmount: slipResult.amount !== undefined ? slipResult.amount.toFixed(2) : undefined,
        senderInfo: slipResult.sender,
        receiverInfo: slipResult.receiver,
        failureCode: slipResult.failureCode,
        failureMessage: slipResult.failureMessage,
        rawResponse: slipResult.rawResponse,
      }
    );

    // 2. Auto Settle Debts & Update Balance immediately
    const newPaidCents = paidCents + paymentCents;
    const newPaidAmount = (newPaidCents / 100).toFixed(2);
    const remainingCents = Math.max(0, currentCents - newPaidCents - writtenOffCents);
    const isFullySettled = remainingCents === 0;

    // 3. Insert Immutable Financial Transaction
    await db.insert(financialTransactions).values({
      billId: bill.id,
      billItemId: item.id,
      type: "payment",
      amount: dto.amount.toFixed(2),
      currency: bill.currency,
      referenceId: newPayment.id,
      createdById: payerId,
      metadata: {
        installmentNumber: installmentNo,
        slipOkReferenceId: slipResult.transactionReference,
        autoConfirmed: true,
        idempotencyKey: dto.idempotencyKey,
      },
    });

    // 4. Update Bill Item paid amount and status
    await db
      .update(billItems)
      .set({
        amountPaid: newPaidAmount,
        status: isFullySettled ? "paid" : "partially_paid",
        isLocked: isFullySettled ? true : item.isLocked,
        updatedAt: new Date(),
      })
      .where(eq(billItems.id, item.id));

    // 5. Derive & Recalculate Overall Bill Status
    const allBillItems = await db.query.billItems.findMany({
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

    await db
      .update(bills)
      .set({
        status: calculatedBillStatus.status,
        updatedAt: new Date(),
      })
      .where(eq(bills.id, bill.id));

    // 6. Award Points upon full debt settlement
    if (isFullySettled) {
      let earnedPoints = 10;
      if (dto.amount > 5000) earnedPoints = 300;
      else if (dto.amount > 2000) earnedPoints = 150;
      else if (dto.amount > 500) earnedPoints = 60;
      else if (dto.amount > 100) earnedPoints = 25;

      const debtorUser = await db.query.users.findFirst({
        where: eq(users.id, item.debtorId),
      });
      if (debtorUser) {
        await db
          .update(users)
          .set({
            rewardPoints: (debtorUser.rewardPoints ?? 0) + earnedPoints,
            updatedAt: new Date(),
          })
          .where(eq(users.id, item.debtorId));
      }
    }

    // 7. Enqueue Confirmed Notifications
    await this.outboxService.enqueue({
      eventType: "PAYMENT_CONFIRMED",
      recipientUserId: bill.ownerId,
      deduplicationKey: `PAYMENT_CONFIRMED_OWNER:${newPayment.id}:${bill.ownerId}`,
      payload: {
        billId: bill.id,
        billTitle: bill.title || "Bill",
        paymentId: newPayment.id,
        participantId: item.id,
        payerId,
        payerName: item.debtor.displayName || item.debtor.fullName || "Friend",
        amount: dto.amount.toFixed(2),
        currency: bill.currency || "THB",
        remainingDebt: (remainingCents / 100).toFixed(2),
        autoConfirmed: true,
      },
    });

    await this.outboxService.enqueue({
      eventType: "PAYMENT_CONFIRMED",
      recipientUserId: payerId,
      deduplicationKey: `PAYMENT_CONFIRMED_PAYER:${newPayment.id}:${payerId}`,
      payload: {
        billId: bill.id,
        billTitle: bill.title || "Bill",
        paymentId: newPayment.id,
        participantId: item.id,
        amount: dto.amount.toFixed(2),
        currency: bill.currency || "THB",
        remainingDebt: (remainingCents / 100).toFixed(2),
        autoConfirmed: true,
      },
    });

    const result = {
      id: newPayment.id,
      billId: bill.id,
      participantId: item.id,
      payerId,
      amount: parseFloat(newPayment.amount),
      status: "confirmed",
      installmentNumber: newPayment.installmentNumber,
      slipOkVerified: true,
      message: "Payment verified by EasySlip and confirmed automatically.",
    };

    if (dto.idempotencyKey) {
      this.processedIdempotencyKeys.set(dto.idempotencyKey, result);
    }

    logActivity(payerId, "slip_uploaded", {
      billId: bill.id,
      paymentId: newPayment.id,
      amount: dto.amount,
      channel: dto.channel || "promptpay_qr",
    });

    realtimeService.sendToUsers(
      [bill.ownerId, payerId],
      realtimeService.makeEvent(
        "bill.transaction.created",
        {
          billId: bill.id,
          paymentId: newPayment.id,
          participantId: item.id,
          payerId,
          ownerId: bill.ownerId,
          status: "confirmed",
        },
        { resourceId: bill.id }
      )
    );

    return result;
    if (initialStatus === "pending_owner_confirmation") {
      realtimeService.sendToUser(
        bill.ownerId,
        realtimeService.makeEvent(
          "notification.created",
          {
            billId: bill.id,
            paymentId: newPayment.id,
            type: "PAYMENT_PENDING_CONFIRMATION",
          },
          { resourceId: newPayment.id }
        )
      );
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

      // 5. Award Points upon full debt settlement (คืนเงินหรือเพื่อนจ่ายเงินครบ)
      if (isFullySettled) {
        const amountNum = Number(payment.amount);
        // Tier Level Multiplier based on transaction amount
        // Lv 1 (<= 100 THB) -> 10 pts
        // Lv 2 (101 - 500 THB) -> 25 pts
        // Lv 3 (501 - 2,000 THB) -> 60 pts
        // Lv 4 (2,001 - 5,000 THB) -> 150 pts
        // Lv 5 (> 5,000 THB) -> 300 pts
        let earnedPoints = 10;
        if (amountNum > 5000) {
          earnedPoints = 300;
        } else if (amountNum > 2000) {
          earnedPoints = 150;
        } else if (amountNum > 500) {
          earnedPoints = 60;
        } else if (amountNum > 100) {
          earnedPoints = 25;
        }

        // Award points to debtor (คนคืนเงินครบ)
        const debtorUser = await tx.query.users.findFirst({
          where: eq(users.id, item.debtorId),
        });
        if (debtorUser) {
          await tx
            .update(users)
            .set({
              rewardPoints: (debtorUser.rewardPoints ?? 0) + earnedPoints,
              updatedAt: new Date(),
            })
            .where(eq(users.id, item.debtorId));
        }

        // Award points to creditor / bill owner (คนได้รับเงินคืนครบ)
        const creditorUser = await tx.query.users.findFirst({
          where: eq(users.id, userId),
        });
        if (creditorUser) {
          await tx
            .update(users)
            .set({
              rewardPoints: (creditorUser.rewardPoints ?? 0) + earnedPoints,
              updatedAt: new Date(),
            })
            .where(eq(users.id, userId));
        }
      }

      // 6. Create Audit Log
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

    if (notificationToSend) {
      const n = notificationToSend;
      realtimeService.sendToUsers(
        [userId, n.debtorId],
        realtimeService.makeEvent(
          "bill.payment.updated",
          {
            billId: n.billId,
            paymentId,
            confirmedBy: userId,
            debtorId: n.debtorId,
            remainingDebt: n.remainingDebt,
          },
          { resourceId: n.billId }
        )
      );
      realtimeService.sendToUser(
        n.debtorId,
        realtimeService.makeEvent(
          "notification.created",
          {
            billId: n.billId,
            paymentId,
            type: "PAYMENT_CONFIRMED",
          },
          { resourceId: paymentId }
        )
      );
    }

    const responseData = {
      success: true,
      data: confirmedResult,
    };

    if (dto.idempotencyKey) {
      this.processedIdempotencyKeys.set(dto.idempotencyKey, responseData);
    }

    logActivity(userId, "payment_confirmed", {
      paymentId,
      confirmedResult,
    });

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

    if (notificationToSend) {
      const n = notificationToSend;
      realtimeService.sendToUsers(
        [userId, n.debtorId],
        realtimeService.makeEvent(
          "bill.payment.updated",
          {
            billId: n.billId,
            paymentId,
            rejectedBy: userId,
            debtorId: n.debtorId,
            reason: n.reason,
          },
          { resourceId: n.billId }
        )
      );
      realtimeService.sendToUser(
        n.debtorId,
        realtimeService.makeEvent(
          "notification.created",
          {
            billId: n.billId,
            paymentId,
            type: "PAYMENT_REJECTED",
          },
          { resourceId: paymentId }
        )
      );
    }

    const responseData = {
      success: true,
      data: rejectedPayment,
    };

    if (dto.idempotencyKey) {
      this.processedIdempotencyKeys.set(dto.idempotencyKey, responseData);
    }

    logActivity(userId, "payment_rejected", {
      paymentId,
      reason: dto.reason,
    });

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

  /**
   * 4.50 Get Outstanding Debts and Summary for the Current User:
   * Returns list of debts owed by the user, filtered or categorized by status,
   * along with total outstanding count and sum.
   */
  async getUserDebtsAndSummary(userId: string) {
    const rawItems = await this.repo.getOutstandingDebtsForUser(userId);

    let totalOutstandingSatang = 0;
    let outstandingCount = 0;

    const formattedDebts = rawItems.map((item) => {
      const origSatang = Math.round(parseFloat(item.originalAmount || "0") * 100);
      const currSatang = Math.round(parseFloat(item.currentAmount || "0") * 100);
      const paidSatang = Math.round(parseFloat(item.amountPaid || "0") * 100);
      const writtenOffSatang = Math.round(parseFloat(item.amountWrittenOff || "0") * 100);
      const outstandingSatang = Math.max(0, currSatang - paidSatang - writtenOffSatang);

      const isOutstanding =
        item.status !== "paid" &&
        item.status !== "written_off" &&
        outstandingSatang > 0 &&
        !item.bill.cancelledAt;

      if (isOutstanding) {
        totalOutstandingSatang += outstandingSatang;
        outstandingCount += 1;
      }

      return {
        id: item.id,
        billId: item.billId,
        debtorId: item.debtorId,
        billTitle: item.bill.title || "บิลค่าใช้จ่าย",
        currency: item.bill.currency || "THB",
        originalAmount: (origSatang / 100).toFixed(2),
        currentAmount: (currSatang / 100).toFixed(2),
        amountPaid: (paidSatang / 100).toFixed(2),
        amountWrittenOff: (writtenOffSatang / 100).toFixed(2),
        outstandingAmount: (outstandingSatang / 100).toFixed(2),
        status: item.status,
        isAcknowledged: item.isAcknowledged,
        acknowledgedAt: item.acknowledgedAt ? item.acknowledgedAt.toISOString() : null,
        isLocked: item.isLocked,
        isOutstanding,
        debtStartDate: item.createdAt.toISOString(),
        receiptImageUrl: item.bill.receiptImageUrl || null,
        creditor: {
          id: item.bill.owner.id,
          userCode: item.bill.owner.userCode,
          displayName: item.bill.owner.displayName || item.bill.owner.fullName || "เจ้าของบิล",
          avatarUrl: item.bill.owner.avatarUrl || null,
          promptPayId: item.bill.owner.promptPayId || null,
          promptPayIdType: item.bill.owner.promptPayIdType || null,
          bankAccountNumber: item.bill.owner.bankAccountNumber || null,
        },
        paymentsCount: item.payments.length,
        latestPaymentStatus: item.payments.length > 0 ? item.payments[0].status : null,
      };
    });

    return {
      summary: {
        outstandingCount,
        totalOutstandingAmount: (totalOutstandingSatang / 100).toFixed(2),
        currency: "THB",
      },
      debts: formattedDebts,
    };
  }

  /**
   * Get all receivables (debts other users owe to this user), grouped and summarized.
   * Calculates unique debtors count, total outstanding, and per-friend / per-bill breakdowns.
   */
  async getUserReceivablesAndSummary(userId: string) {
    const ownerBills = await this.repo.getReceivablesForOwner(userId);

    let totalOutstandingSatang = 0;
    let totalPaidSatang = 0;
    let totalWrittenOffSatang = 0;
    let totalOriginalSatang = 0;

    // Grouping by debtorId
    const debtorMap = new Map<string, {
      debtor: {
        id: string;
        userCode: string;
        displayName: string;
        avatarUrl: string | null;
        promptPayId: string | null;
        bankAccountNumber: string | null;
      };
      bills: Array<{
        id: string; // bill_items.id
        billId: string;
        billTitle: string;
        currency: string;
        originalAmount: string;
        currentAmount: string;
        amountPaid: string;
        amountWrittenOff: string;
        outstandingAmount: string;
        status: string;
        isLocked: boolean;
        isOutstanding: boolean;
        debtStartDate: string;
        paymentsCount: number;
        latestPaymentStatus: string | null;
      }>;
      totalOriginalAmount: number;
      totalCurrentAmount: number;
      totalAmountPaid: number;
      totalAmountWrittenOff: number;
      totalOutstandingAmount: number;
      oldestDebtStartDate: string;
      latestPaymentStatus: string | null;
    }>();

    for (const bill of ownerBills) {
      if (bill.cancelledAt) continue;

      for (const item of bill.items) {
        const origSat = Math.round(parseFloat(item.originalAmount || "0") * 100);
        const currSat = Math.round(parseFloat(item.currentAmount || "0") * 100);
        const paidSat = Math.round(parseFloat(item.amountPaid || "0") * 100);
        const writtenOffSat = Math.round(parseFloat(item.amountWrittenOff || "0") * 100);
        const outstandingSat = Math.max(0, currSat - paidSat - writtenOffSat);

        const isOutstanding =
          item.status !== "paid" &&
          item.status !== "written_off" &&
          outstandingSat > 0;

        if (isOutstanding) {
          totalOutstandingSatang += outstandingSat;
        }
        totalPaidSatang += paidSat;
        totalWrittenOffSatang += writtenOffSat;
        totalOriginalSatang += origSat;

        const billItemFormatted = {
          id: item.id,
          billId: bill.id,
          billTitle: bill.title || "บิลค่าใช้จ่าย",
          currency: bill.currency || "THB",
          originalAmount: (origSat / 100).toFixed(2),
          currentAmount: (currSat / 100).toFixed(2),
          amountPaid: (paidSat / 100).toFixed(2),
          amountWrittenOff: (writtenOffSat / 100).toFixed(2),
          outstandingAmount: (outstandingSat / 100).toFixed(2),
          status: item.status,
          isAcknowledged: item.isAcknowledged,
          acknowledgedAt: item.acknowledgedAt ? item.acknowledgedAt.toISOString() : null,
          isLocked: item.isLocked,
          isOutstanding,
          debtStartDate: item.createdAt.toISOString(),
          receiptImageUrl: bill.receiptImageUrl || null,
          paymentsCount: item.payments.length,
          latestPaymentStatus: item.payments.length > 0 ? item.payments[0].status : null,
        };

        const debtorUser = item.debtor;
        const dId = item.debtorId;

        if (!debtorMap.has(dId)) {
          debtorMap.set(dId, {
            debtor: {
              id: debtorUser.id,
              userCode: debtorUser.userCode,
              displayName: debtorUser.displayName || debtorUser.fullName || "เพื่อน",
              avatarUrl: debtorUser.avatarUrl || null,
              promptPayId: debtorUser.promptPayId || null,
              bankAccountNumber: debtorUser.bankAccountNumber || null,
            },
            bills: [],
            totalOriginalAmount: 0,
            totalCurrentAmount: 0,
            totalAmountPaid: 0,
            totalAmountWrittenOff: 0,
            totalOutstandingAmount: 0,
            oldestDebtStartDate: item.createdAt.toISOString(),
            latestPaymentStatus: null,
          });
        }

        const debtorGroup = debtorMap.get(dId)!;
        debtorGroup.bills.push(billItemFormatted);
        debtorGroup.totalOriginalAmount += origSat / 100;
        debtorGroup.totalCurrentAmount += currSat / 100;
        debtorGroup.totalAmountPaid += paidSat / 100;
        debtorGroup.totalAmountWrittenOff += writtenOffSat / 100;
        debtorGroup.totalOutstandingAmount += outstandingSat / 100;

        if (new Date(item.createdAt).getTime() < new Date(debtorGroup.oldestDebtStartDate).getTime()) {
          debtorGroup.oldestDebtStartDate = item.createdAt.toISOString();
        }

        if (item.payments.length > 0 && !debtorGroup.latestPaymentStatus) {
          debtorGroup.latestPaymentStatus = item.payments[0].status;
        }
      }
    }

    // Convert debtorMap to array and format amounts to fixed strings
    const debtorFriends = Array.from(debtorMap.values()).map((group) => {
      const outstandingBills = group.bills.filter((b) => b.isOutstanding);
      return {
        debtor: group.debtor,
        outstandingBillCount: outstandingBills.length,
        totalBillsCount: group.bills.length,
        totalOriginalAmount: group.totalOriginalAmount.toFixed(2),
        totalCurrentAmount: group.totalCurrentAmount.toFixed(2),
        totalAmountPaid: group.totalAmountPaid.toFixed(2),
        totalAmountWrittenOff: group.totalAmountWrittenOff.toFixed(2),
        totalOutstandingAmount: group.totalOutstandingAmount.toFixed(2),
        hasOutstandingDebt: group.totalOutstandingAmount > 0,
        oldestDebtStartDate: group.oldestDebtStartDate,
        latestPaymentStatus: group.latestPaymentStatus,
        bills: group.bills,
      };
    });

    // Count unique friends who currently owe money
    const uniqueDebtorsWithOutstanding = debtorFriends.filter((f) => f.hasOutstandingDebt).length;

    return {
      summary: {
        debtorCount: uniqueDebtorsWithOutstanding,
        totalOutstandingAmount: (totalOutstandingSatang / 100).toFixed(2),
        totalPaidAmount: (totalPaidSatang / 100).toFixed(2),
        totalWrittenOffAmount: (totalWrittenOffSatang / 100).toFixed(2),
        totalOriginalAmount: (totalOriginalSatang / 100).toFixed(2),
        currency: "THB",
      },
      friends: debtorFriends,
    };
  }

  /**
   * Debtor swipes to acknowledge/accept that they indeed owe this debt.
   */
  async acknowledgeDebt(debtorId: string, billItemId: string) {
    const item = await db.query.billItems.findFirst({
      where: eq(billItems.id, billItemId),
      with: { bill: { with: { owner: true } } },
    });

    if (!item) {
      throw new Error("PARTICIPANT_NOT_FOUND: Debt item not found.");
    }

    if (item.debtorId !== debtorId) {
      throw new Error("UNAUTHORIZED: Only the assigned debtor can acknowledge this debt.");
    }

    const [updated] = await db
      .update(billItems)
      .set({
        isAcknowledged: true,
        acknowledgedAt: new Date(),
        updatedAt: new Date(),
      })
      .where(eq(billItems.id, billItemId))
      .returning();

    // Enqueue Outbox notification to bill owner
    await this.outboxService.enqueue({
      eventType: "DEBT_ACKNOWLEDGED",
      recipientUserId: item.bill.ownerId,
      deduplicationKey: `DEBT_ACKNOWLEDGED:${billItemId}:${debtorId}`,
      payload: {
        billId: item.billId,
        billTitle: item.bill.title || "Bill",
        billItemId: item.id,
        debtorId,
        amount: item.currentAmount,
      },
    });

    realtimeService.sendToUsers(
      [debtorId, item.bill.ownerId],
      realtimeService.makeEvent(
        "bill.payment.updated",
        {
          billId: item.billId,
          billItemId: item.id,
          debtorId,
          acknowledged: true,
        },
        { resourceId: item.billId }
      )
    );

    realtimeService.sendToBill(
      item.billId,
      realtimeService.makeEvent(
        "bill.updated",
        {
          billId: item.billId,
          billItemId: item.id,
          debtorId,
          acknowledged: true,
        },
        { resourceId: item.billId }
      )
    );

    logActivity(debtorId, "debt_acknowledged", {
      billId: item.billId,
      billItemId: item.id,
      amount: item.currentAmount,
    });

    return updated;
  }
}
