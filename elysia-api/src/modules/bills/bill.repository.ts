import { db } from "../../db";
import { bills, billItems, financialTransactions, editLogs, users } from "../../db/schema";
import { eq, and, ne } from "drizzle-orm";
import {
  NotificationOutboxService,
  defaultNotificationOutboxService,
} from "../notifications/notification-outbox.service";

export class BillRepository {
  private outboxService: NotificationOutboxService;

  constructor(
    private customDb: any = db,
    outboxService?: NotificationOutboxService
  ) {
    this.outboxService = outboxService || new NotificationOutboxService(customDb);
  }

  private get db() {
    return this.customDb;
  }
  async createBillWithItems(
    ownerId: string,
    data: {
      title?: string;
      description?: string;
      totalAmount: string;
      currency: string;
      groupId?: string;
      itemsBreakdown?: any;
      receiptImageUrl?: string;
    },
    items: { debtorId: string; amount: string }[]
  ) {
    return await this.db.transaction(async (tx: any) => {
      const [bill] = await tx.insert(bills).values({
        ownerId,
        title: data.title,
        currency: data.currency,
        totalAmount: data.totalAmount,
        groupId: data.groupId,
        itemsBreakdown: data.itemsBreakdown,
        receiptImageUrl: data.receiptImageUrl,
        status: "unpaid",
      }).returning();

      const ownerUser = await tx.query.users?.findFirst?.({
        where: eq(users.id, ownerId),
      });
      const creatorName = ownerUser?.displayName || ownerUser?.fullName || "Bill Owner";

      if (items.length > 0) {
        const billItemValues = items.map(item => ({
          billId: bill.id,
          debtorId: item.debtorId,
          originalAmount: item.amount,
          currentAmount: item.amount,
          status: "unpaid" as const,
        }));

        const createdItems = await tx.insert(billItems).values(billItemValues).returning();

        const finTxValues = createdItems.map(item => ({
          billId: bill.id,
          billItemId: item.id,
          type: "debt_created" as const,
          amount: item.currentAmount,
          currency: bill.currency,
          createdById: ownerId,
        }));
        await tx.insert(financialTransactions).values(finTxValues);

        // 5.10 & 5.11 Enqueue BILL_CREATED notification for each participant atomically
        for (const item of createdItems) {
          await this.outboxService.enqueueInTx(tx, {
            eventType: "BILL_CREATED",
            recipientUserId: item.debtorId,
            deduplicationKey: `BILL_CREATED:${bill.id}:${item.debtorId}`,
            payload: {
              billId: bill.id,
              billTitle: bill.title || "Bill",
              creatorId: ownerId,
              creatorName,
              participantId: item.id,
              participantDebtAmount: item.currentAmount,
              totalAmount: bill.totalAmount,
              currency: bill.currency,
            },
          });
        }
      }

      await tx.insert(editLogs).values({
        action: "bill_created",
        billId: bill.id,
        performedById: ownerId,
        newValue: { totalAmount: bill.totalAmount, items: items },
      });

      return bill;
    });
  }

  async getBillById(id: string) {
    return await this.db.query.bills.findFirst({
      where: eq(bills.id, id),
      with: {
        items: {
          with: { debtor: true, payments: true },
        },
        owner: true,
      },
    });
  }

  async getBillsForUser(userId: string) {
    const ownerBills = await this.db.query.bills.findMany({
      where: and(eq(bills.ownerId, userId), ne(bills.status, "cancelled")),
      with: {
        items: {
          with: { debtor: true, payments: true },
        },
        owner: true,
      },
      orderBy: (bills: any, { desc }: any) => [desc(bills.createdAt)],
    });

    return ownerBills;
  }

  async getBillItem(billId: string, debtorId: string) {
    return await this.db.query.billItems.findFirst({
      where: and(eq(billItems.billId, billId), eq(billItems.debtorId, debtorId)),
      with: { bill: true }
    });
  }

  async updateBill(
    id: string,
    userId: string,
    data: { title?: string; description?: string; totalAmount?: string; itemsBreakdown?: any }
  ) {
    return await this.db.transaction(async (tx: any) => {
      const bill = await tx.query.bills.findFirst({ where: eq(bills.id, id) });
      if (!bill) throw new Error("Bill not found");

      const [updatedBill] = await tx.update(bills)
        .set({
          title: data.title !== undefined ? data.title : bill.title,
          description: data.description !== undefined ? data.description : bill.description,
          totalAmount: data.totalAmount !== undefined ? data.totalAmount : bill.totalAmount,
          itemsBreakdown: data.itemsBreakdown !== undefined ? data.itemsBreakdown : bill.itemsBreakdown,
          updatedAt: new Date(),
        })
        .where(eq(bills.id, id))
        .returning();

      await tx.insert(editLogs).values({
        action: "bill_amount_edited",
        billId: id,
        performedById: userId,
        previousValue: { title: bill.title, totalAmount: bill.totalAmount, itemsBreakdown: bill.itemsBreakdown },
        newValue: { title: updatedBill.title, totalAmount: updatedBill.totalAmount, itemsBreakdown: updatedBill.itemsBreakdown },
      });

      return updatedBill;
    });
  }

  async updateBillItemAmount(billItemId: string, billId: string, userId: string, newAmount: string) {
    return await this.db.transaction(async (tx: any) => {
      const item = await tx.query.billItems.findFirst({ where: eq(billItems.id, billItemId), with: { bill: true } });
      if (!item) throw new Error("Bill item not found");

      const [updatedItem] = await tx.update(billItems)
        .set({
          currentAmount: newAmount,
          updatedAt: new Date(),
        })
        .where(eq(billItems.id, billItemId))
        .returning();

      await tx.insert(financialTransactions).values({
        billId,
        billItemId,
        type: "debt_adjusted",
        amount: newAmount, // Represents the new amount adjusted to
        currency: item.bill.currency,
        createdById: userId,
      });

      const [log] = await tx.insert(editLogs).values({
        action: "bill_item_edited",
        billId,
        billItemId,
        performedById: userId,
        affectedUserId: item.debtorId,
        previousValue: { currentAmount: item.currentAmount },
        newValue: { currentAmount: updatedItem.currentAmount },
      }).returning();

      // 5.12 & 5.13 Enqueue BILL_UPDATED notification atomically inside transaction
      if (item.currentAmount !== updatedItem.currentAmount) {
        const editorUser = await tx.query.users?.findFirst?.({
          where: eq(users.id, userId),
        });
        const editorName = editorUser?.displayName || editorUser?.fullName || "Bill Owner";

        await this.outboxService.enqueueInTx(tx, {
          eventType: "BILL_UPDATED",
          recipientUserId: item.debtorId,
          deduplicationKey: `BILL_UPDATED:${log.id}:${item.debtorId}`,
          payload: {
            billId,
            billTitle: item.bill?.title || "Bill",
            editorId: userId,
            editorName,
            participantId: item.id,
            oldAmount: item.currentAmount,
            newAmount: updatedItem.currentAmount,
          },
        });
      }

      return updatedItem;
    });
  }

  async cancelBill(billId: string, userId: string, reason?: string) {
    return await this.db.transaction(async (tx: any) => {
      const bill = await tx.query.bills.findFirst({
        where: eq(bills.id, billId),
        with: { items: true },
      });
      if (!bill) throw new Error("BILL_NOT_FOUND: Bill not found.");

      const [cancelledBill] = await tx
        .update(bills)
        .set({
          status: "cancelled",
          cancelledAt: new Date(),
          updatedAt: new Date(),
        })
        .where(eq(bills.id, billId))
        .returning();

      // Cancel / write off all unpaid items
      for (const item of bill.items) {
        if (item.status !== "paid") {
          await tx
            .update(billItems)
            .set({
              status: "written_off",
              updatedAt: new Date(),
            })
            .where(eq(billItems.id, item.id));
        }
      }

      await tx.insert(editLogs).values({
        action: "bill_cancelled",
        billId,
        performedById: userId,
        note: reason || "Bill cancelled by owner",
      });

      return cancelledBill;
    });
  }
}
