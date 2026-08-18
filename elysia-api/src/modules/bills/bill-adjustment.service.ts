import { db } from "../../db";
import { bills, billItems, financialTransactions, editLogs } from "../../db/schema";
import { eq } from "drizzle-orm";
import { BillPolicy } from "./bill.policy";
import { defaultNotificationService, NotificationService } from "./bill-notification.service";

export interface AdjustmentRequestDTO {
  participantId: string; // bill_items.id
  newAmount: number;
  reason?: string;
  idempotencyKey?: string;
}

export class BillAdjustmentService {
  private processedIdempotencyKeys = new Set<string>();

  constructor(private notificationService: NotificationService = defaultNotificationService) {}

  async adjustPaidDebt(userId: string, billId: string, dto: AdjustmentRequestDTO) {
    if (dto.idempotencyKey && this.processedIdempotencyKeys.has(dto.idempotencyKey)) {
      return { success: true, message: "Duplicate adjustment request processed idempotently" };
    }

    if (dto.newAmount < 0) {
      throw new Error("INVALID_AMOUNT: New amount cannot be negative.");
    }

    let notificationToSend: {
      debtorId: string;
      billTitle: string;
      actorName: string;
      oldAmount: string;
      newAmount: string;
      reason?: string;
    } | null = null;

    const result = await db.transaction(async (tx) => {
      const bill = await tx.query.bills.findFirst({
        where: eq(bills.id, billId),
        with: { items: true, owner: true }
      });

      if (!bill) throw new Error("BILL_NOT_FOUND: Bill not found.");

      BillPolicy.canEditBill(userId, bill.ownerId);

      const item = bill.items.find((i) => i.id === dto.participantId);
      if (!item) {
        throw new Error(`PARTICIPANT_NOT_FOUND: Participant ${dto.participantId} not found in this bill.`);
      }

      const currentAmtCents = Math.round(Number(item.currentAmount) * 100);
      const paidAmtCents = Math.round(Number(item.amountPaid) * 100);
      const newAmtCents = Math.round(dto.newAmount * 100);

      const formattedNewAmount = (newAmtCents / 100).toFixed(2);

      if (newAmtCents < paidAmtCents) {
        // Refund required
        const refundCents = paidAmtCents - newAmtCents;
        const refundAmt = (refundCents / 100).toFixed(2);

        await tx.insert(financialTransactions).values({
          billId: bill.id,
          billItemId: item.id,
          type: "refund",
          amount: refundAmt,
          currency: bill.currency,
          createdById: userId,
          metadata: {
            reason: dto.reason,
            originalPaid: item.amountPaid,
            adjustedAmount: formattedNewAmount,
            idempotencyKey: dto.idempotencyKey
          }
        });
      } else if (newAmtCents > paidAmtCents) {
        // Additional debt required
        const additionalCents = newAmtCents - paidAmtCents;
        const additionalAmt = (additionalCents / 100).toFixed(2);

        await tx.insert(financialTransactions).values({
          billId: bill.id,
          billItemId: item.id,
          type: "debt_adjusted",
          amount: additionalAmt,
          currency: bill.currency,
          createdById: userId,
          metadata: {
            reason: dto.reason,
            originalPaid: item.amountPaid,
            adjustedAmount: formattedNewAmount,
            idempotencyKey: dto.idempotencyKey
          }
        });
      }

      // Update billItem current amount
      const isLocked = newAmtCents <= paidAmtCents;
      const newStatus = newAmtCents <= paidAmtCents ? "paid" : "partially_paid";

      const [updatedItem] = await tx.update(billItems)
        .set({
          currentAmount: formattedNewAmount,
          status: newStatus,
          isLocked,
          updatedAt: new Date()
        })
        .where(eq(billItems.id, item.id))
        .returning();

      await tx.insert(editLogs).values({
        action: "bill_item_edited",
        billId: bill.id,
        billItemId: item.id,
        performedById: userId,
        affectedUserId: item.debtorId,
        previousValue: { currentAmount: item.currentAmount, amountPaid: item.amountPaid },
        newValue: { currentAmount: formattedNewAmount, amountPaid: item.amountPaid },
        note: dto.reason
      });

      notificationToSend = {
        debtorId: item.debtorId,
        billTitle: bill.title || "Bill",
        actorName: bill.owner?.displayName || bill.owner?.fullName || "Bill Owner",
        oldAmount: item.currentAmount,
        newAmount: formattedNewAmount,
        reason: dto.reason
      };

      return updatedItem;
    });

    if (dto.idempotencyKey) {
      this.processedIdempotencyKeys.add(dto.idempotencyKey);
    }

    // Dispatch LINE notification after commit
    if (notificationToSend) {
      const n = notificationToSend as {
        debtorId: string;
        billTitle: string;
        actorName: string;
        oldAmount: string;
        newAmount: string;
        reason?: string;
      };
      try {
        await this.notificationService.notify({
          userId: n.debtorId,
          billId,
          billTitle: n.billTitle,
          actorName: n.actorName,
          type: "adjustment",
          oldAmount: n.oldAmount,
          newAmount: n.newAmount,
          reason: n.reason,
          timestamp: new Date()
        });
      } catch (err) {
        console.error("Failed to send LINE notification for adjustment:", err);
      }
    }

    return { success: true, data: result };
  }
}
