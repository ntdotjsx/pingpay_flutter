import { db } from "../../db";
import { bills, billItems, financialTransactions, editLogs, users } from "../../db/schema";
import { eq, inArray, and } from "drizzle-orm";
import { BillPolicy } from "./bill.policy";
import { BillStatusService } from "./bill-status.service";
import { defaultNotificationService, NotificationService } from "./bill-notification.service";

export interface WriteOffParticipantInput {
  participantId: string; // bill_items.id
  amount: number;
}

export interface WriteOffRequestDTO {
  reason?: string;
  idempotencyKey?: string;
  participants: WriteOffParticipantInput[];
}

import {
  NotificationOutboxService,
  defaultNotificationOutboxService,
} from "../notifications/notification-outbox.service";

export class BillWriteoffService {
  private processedIdempotencyKeys = new Set<string>();
  private outboxService: NotificationOutboxService;

  constructor(
    private notificationService: NotificationService = defaultNotificationService,
    private customDb: any = db,
    outboxService?: NotificationOutboxService
  ) {
    this.outboxService = outboxService || new NotificationOutboxService(customDb);
  }

  private get db() {
    return this.customDb;
  }

  async writeOffDebt(userId: string, billId: string, dto: WriteOffRequestDTO) {
    if (dto.idempotencyKey && this.processedIdempotencyKeys.has(dto.idempotencyKey)) {
      return { success: true, message: "Duplicate request processed idempotently" };
    }

    if (!dto.participants || dto.participants.length === 0) {
      throw new Error("INVALID_WRITE_OFF: At least one participant is required for write-off.");
    }

    const notificationsToSend: Array<{
      debtorId: string;
      billTitle: string;
      actorName: string;
      oldAmount: string;
      newAmount: string;
      reason?: string;
    }> = [];

    const result = await this.db.transaction(async (tx: any) => {
      const bill = await tx.query.bills.findFirst({
        where: eq(bills.id, billId),
        with: { items: true, owner: true }
      });

      if (!bill) throw new Error("BILL_NOT_FOUND: Bill not found.");

      // Verify that user is either bill owner or a participant in this bill
      const isOwner = bill.ownerId === userId;
      const isParticipant = bill.items.some((i) => i.debtorId === userId);
      if (!isOwner && !isParticipant) {
        throw new Error("Unauthorized: Only the bill owner or involved debtor can perform debt offset.");
      }

      for (const itemInput of dto.participants) {
        if (itemInput.amount <= 0) {
          throw new Error("INVALID_WRITE_OFF: Write-off amount must be greater than 0.");
        }

        const item = bill.items.find((i) => i.id === itemInput.participantId);
        if (!item) {
          throw new Error(`PARTICIPANT_NOT_FOUND: Participant ${itemInput.participantId} not found in this bill.`);
        }

        const currentAmt = Math.round(Number(item.currentAmount || 0) * 100);
        const paidAmt = Math.round(Number(item.amountPaid || 0) * 100);
        const writtenOffAmt = Math.round(Number(item.amountWrittenOff || 0) * 100);
        const remainingDebtCents = currentAmt - paidAmt - writtenOffAmt;

        const writeOffCents = Math.round(itemInput.amount * 100);

        if (writeOffCents > remainingDebtCents) {
          throw new Error(
            `INSUFFICIENT_REMAINING_DEBT: Write-off amount (${itemInput.amount}) exceeds remaining debt (${(remainingDebtCents / 100).toFixed(2)}).`
          );
        }

        const newWrittenOffCents = writtenOffAmt + writeOffCents;
        const newWrittenOffAmt = (newWrittenOffCents / 100).toFixed(2);
        const newRemainingDebt = ((remainingDebtCents - writeOffCents) / 100).toFixed(2);

        const isFullySettled = (paidAmt + newWrittenOffCents) >= currentAmt;

        await tx.update(billItems)
          .set({
            amountWrittenOff: newWrittenOffAmt,
            status: isFullySettled ? (paidAmt > 0 ? "partially_paid" : "written_off") : item.status,
            isLocked: isFullySettled ? true : item.isLocked,
            updatedAt: new Date()
          })
          .where(eq(billItems.id, item.id));

        await tx.insert(financialTransactions).values({
          billId: bill.id,
          billItemId: item.id,
          type: "write_off",
          amount: itemInput.amount.toFixed(2),
          currency: bill.currency,
          createdById: userId,
          metadata: { reason: dto.reason, idempotencyKey: dto.idempotencyKey }
        });

        const [editLog] = await tx.insert(editLogs).values({
          action: "debt_written_off",
          billId: bill.id,
          billItemId: item.id,
          performedById: userId,
          affectedUserId: item.debtorId,
          previousValue: {
            amountWrittenOff: item.amountWrittenOff,
            remainingDebt: (remainingDebtCents / 100).toFixed(2)
          },
          newValue: {
            amountWrittenOff: newWrittenOffAmt,
            remainingDebt: newRemainingDebt
          },
          note: dto.reason
        }).returning();

        // 5.14 Enqueue BILL_WRITTEN_OFF notification atomically inside transaction
        await this.outboxService.enqueueInTx(tx, {
          eventType: "BILL_WRITTEN_OFF",
          recipientUserId: item.debtorId,
          deduplicationKey: `BILL_WRITTEN_OFF:${editLog.id}:${item.debtorId}`,
          payload: {
            billId: bill.id,
            billTitle: bill.title || "Bill",
            actorId: userId,
            actorName: bill.owner?.displayName || bill.owner?.fullName || "Bill Owner",
            participantId: item.id,
            oldAmount: (remainingDebtCents / 100).toFixed(2),
            newAmount: newRemainingDebt,
            writtenOffAmount: itemInput.amount.toFixed(2),
            reason: dto.reason,
          },
        });

        notificationsToSend.push({
          debtorId: item.debtorId,
          billTitle: bill.title || "Bill",
          actorName: bill.owner?.displayName || bill.owner?.fullName || "Bill Owner",
          oldAmount: (remainingDebtCents / 100).toFixed(2),
          newAmount: newRemainingDebt,
          reason: dto.reason
        });
      }

      // Recalculate overall bill status via BillStatusService
      const allBillItems = await tx
        .select()
        .from(billItems)
        .where(eq(billItems.billId, bill.id));

      const participantStates = allBillItems.map((bi) => {
        const inputItem = dto.participants.find((p) => p.participantId === bi.id);
        const wOff = inputItem
          ? Number(bi.amountWrittenOff) + inputItem.amount
          : Number(bi.amountWrittenOff);
        return {
          originalDebt: Number(bi.originalAmount),
          currentAmount: Number(bi.currentAmount),
          amountPaid: Number(bi.amountPaid),
          amountWrittenOff: wOff,
        };
      });

      const calculatedStatus = BillStatusService.calculateBillStatus({
        participants: participantStates,
      });

      await tx.update(bills)
        .set({ status: calculatedStatus.status, updatedAt: new Date() })
        .where(eq(bills.id, bill.id));

      return bill;
    });

    if (dto.idempotencyKey) {
      this.processedIdempotencyKeys.add(dto.idempotencyKey);
    }

    // Send LINE notifications AFTER transaction commits successfully
    for (const n of notificationsToSend) {
      try {
        await this.notificationService.notify({
          userId: n.debtorId,
          billId,
          billTitle: n.billTitle,
          actorName: n.actorName,
          type: "write_off",
          oldAmount: n.oldAmount,
          newAmount: n.newAmount,
          reason: n.reason,
          timestamp: new Date()
        });
      } catch (err) {
        console.error("Failed to send LINE notification for write-off:", err);
      }
    }

    return { success: true, data: result };
  }
}
