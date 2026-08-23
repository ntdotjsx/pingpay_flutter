export class BillPolicy {
  static canEditBill(userId: string, billOwnerId: string) {
    if (userId !== billOwnerId) {
      throw new Error("Unauthorized: Only the bill owner can edit this bill.");
    }
  }

  static canEditBillItem(userId: string, billOwnerId: string, itemStatus: string, isLocked: boolean) {
    if (userId !== billOwnerId) {
      throw new Error("Unauthorized: Only the bill owner can edit participant amounts.");
    }
    if (isLocked) {
      throw new Error("Business rule violation: Cannot edit a locked bill item. Revert the payment or write-off first.");
    }
    if (itemStatus !== "unpaid") {
      throw new Error("Business rule violation: Cannot directly edit a paid or written-off item.");
    }
  }

  static canDeleteBill(userId: string, billOwnerId: string, hasLockedItems: boolean) {
    if (userId !== billOwnerId) {
      throw new Error("Unauthorized: Only the bill owner can delete this bill.");
    }
    if (hasLockedItems) {
      throw new Error("Business rule violation: Cannot delete a bill with locked items.");
    }
  }

  static canWriteOffDebt(userId: string, billOwnerId: string) {
    if (userId !== billOwnerId) {
      throw new Error("Unauthorized: Only the bill owner can write off debt.");
    }
  }
}
