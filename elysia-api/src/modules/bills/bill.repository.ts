import { db } from "../../db";
import { bills, billItems, financialTransactions, editLogs } from "../../db/schema";
import { eq, and } from "drizzle-orm";

export class BillRepository {
  async createBillWithItems(
    ownerId: string,
    data: {
      title?: string;
      totalAmount: string;
      currency: string;
      groupId?: string;
    },
    items: { debtorId: string; amount: string }[]
  ) {
    return await db.transaction(async (tx) => {
      const [bill] = await tx.insert(bills).values({
        ownerId,
        title: data.title,
        totalAmount: data.totalAmount,
        currency: data.currency,
        groupId: data.groupId,
        status: "unpaid",
      }).returning();

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
    return await db.query.bills.findFirst({
      where: eq(bills.id, id),
      with: {
        items: true,
      }
    });
  }

  async getBillItem(billId: string, debtorId: string) {
    return await db.query.billItems.findFirst({
      where: and(eq(billItems.billId, billId), eq(billItems.debtorId, debtorId)),
      with: { bill: true }
    });
  }

  async updateBill(id: string, userId: string, data: { title?: string; totalAmount?: string }) {
    return await db.transaction(async (tx) => {
      const bill = await tx.query.bills.findFirst({ where: eq(bills.id, id) });
      if (!bill) throw new Error("Bill not found");

      const [updatedBill] = await tx.update(bills)
        .set({
          title: data.title !== undefined ? data.title : bill.title,
          totalAmount: data.totalAmount !== undefined ? data.totalAmount : bill.totalAmount,
          updatedAt: new Date(),
        })
        .where(eq(bills.id, id))
        .returning();
      
      await tx.insert(editLogs).values({
        action: "bill_amount_edited",
        billId: id,
        performedById: userId,
        previousValue: { title: bill.title, totalAmount: bill.totalAmount },
        newValue: { title: updatedBill.title, totalAmount: updatedBill.totalAmount },
      });

      return updatedBill;
    });
  }

  async updateBillItemAmount(billItemId: string, billId: string, userId: string, newAmount: string) {
    return await db.transaction(async (tx) => {
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

      await tx.insert(editLogs).values({
        action: "bill_item_edited",
        billId,
        billItemId,
        performedById: userId,
        affectedUserId: item.debtorId,
        previousValue: { currentAmount: item.currentAmount },
        newValue: { currentAmount: updatedItem.currentAmount },
      });

      return updatedItem;
    });
  }
}
