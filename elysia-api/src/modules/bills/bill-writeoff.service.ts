import { db } from "../../db";
import { bills, billItems, financialTransactions, editLogs, users } from "../../db/schema";
import { eq, inArray, and } from "drizzle-orm";
import { BillPolicy } from "./bill.policy";
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

export class BillWriteoffService {
  private processedIdempotencyKeys = new Set<string>();

  constructor(private notificationService: NotificationService = defaultNotificationService) {}

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

    const result = await db.transaction(async (tx) => {
      const bill = await tx.query.bills.findFirst({
        where: eq(bills.id, billId),
        with: { items: true, owner: true }
      });

      if (!bill) throw new Error("BILL_NOT_FOUND: Bill not found.");

      BillPolicy.canEditBill(userId, bill.ownerId);

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

        await tx.insert(editLogs).values({
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
