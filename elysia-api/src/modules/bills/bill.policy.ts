export class BillPolicy {
  static canEditBill(userId: string, billOwnerId: string, hasAnyPayment = false) {
    if (userId !== billOwnerId) {
      throw new Error("Unauthorized: Only the bill owner can edit this bill.");
    }
    if (hasAnyPayment) {
      throw new Error("PAID_DEBT_LOCKED: Cannot edit a bill after payments/installments have been made.");
    }
  }

  static canEditBillItem(
    userId: string,
    billOwnerId: string,
    itemStatus: string,
    isLocked: boolean,
    amountPaid: number | string = 0
  ) {
    if (userId !== billOwnerId) {
      throw new Error("Unauthorized: Only the bill owner can edit participant amounts.");
    }
    if (isLocked || Number(amountPaid) > 0) {
      throw new Error("PAID_DEBT_LOCKED: Cannot edit a debt item after payments/installments have been made.");
    }
    if (itemStatus !== "unpaid") {
      throw new Error("Business rule violation: Cannot directly edit a paid or written-off item.");
    }
  }

  static canDeleteBill(
    userId: string,
    billOwnerId: string,
    hasLockedItems: boolean,
    hasAnyPayment = false
  ) {
    if (userId !== billOwnerId) {
      throw new Error("Unauthorized: Only the bill owner can delete this bill.");
    }
    if (hasLockedItems || hasAnyPayment) {
      throw new Error("PAID_DEBT_LOCKED: Cannot delete or cancel a bill after payments/installments have been made.");
    }
  }

  static canWriteOffDebt(userId: string, billOwnerId: string) {
    if (userId !== billOwnerId) {
      throw new Error("Unauthorized: Only the bill owner can write off debt.");
    }
  }
}
