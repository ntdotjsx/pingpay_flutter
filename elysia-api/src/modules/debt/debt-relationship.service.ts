import { db } from "../../db";
import { bills, billItems } from "../../db/schema";
import { eq, or, and, notInArray } from "drizzle-orm";

export class DebtRelationshipService {
  /**
   * Calculates outstanding debt between two users based on existing bill item records.
   * Outstanding debt exists if there are unpaid items in either direction.
   */
  static async getOutstandingDebtBetween(userAId: string, userBId: string) {
    // We query billItems where the bill owner is userA/userB and debtor is the other user,
    // and status is not fully paid/written off.
    
    // In Drizzle, doing complex joins across bills and billItems
    const relevantBillItems = await db
      .select({
        billOwnerId: bills.ownerId,
        debtorId: billItems.debtorId,
        currentAmount: billItems.currentAmount,
        amountPaid: billItems.amountPaid,
        amountWrittenOff: billItems.amountWrittenOff,
      })
      .from(billItems)
      .innerJoin(bills, eq(billItems.billId, bills.id))
      .where(
        and(
          notInArray(billItems.status, ["paid", "written_off"]),
          or(
            and(eq(bills.ownerId, userAId), eq(billItems.debtorId, userBId)),
            and(eq(bills.ownerId, userBId), eq(billItems.debtorId, userAId))
          )
        )
      );

    let userAOwesUserB = 0;
    let userBOwesUserA = 0;

    for (const item of relevantBillItems) {
      const remaining =
        parseFloat(item.currentAmount as string) -
        parseFloat(item.amountPaid as string) -
        parseFloat(item.amountWrittenOff as string);

      if (remaining > 0) {
        if (item.billOwnerId === userBId && item.debtorId === userAId) {
          userAOwesUserB += remaining;
        } else if (item.billOwnerId === userAId && item.debtorId === userBId) {
          userBOwesUserA += remaining;
        }
      }
    }

    return {
      hasOutstandingDebt: userAOwesUserB > 0 || userBOwesUserA > 0,
      userAOwesUserB: userAOwesUserB.toFixed(2),
      userBOwesUserA: userBOwesUserA.toFixed(2),
    };
  }
}
