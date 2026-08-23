import { describe, it, expect } from "bun:test";
import { BillPolicy } from "../../../src/modules/bills/bill.policy";

describe("Unit: Bill Policy", () => {
  it("should allow bill owner to edit bill", () => {
    expect(() => BillPolicy.canEditBill("user-1", "user-1")).not.toThrow();
  });

  it("should forbid non-owners from editing bill", () => {
    expect(() => BillPolicy.canEditBill("user-2", "user-1")).toThrow("Unauthorized");
  });

  it("should reject editing locked bill items", () => {
    expect(() => BillPolicy.canEditBillItem("user-1", "user-1", "paid", true)).toThrow("locked");
  });

  it("should reject editing paid or written-off items directly", () => {
    expect(() => BillPolicy.canEditBillItem("user-1", "user-1", "paid", false)).toThrow("Cannot directly edit a paid or written-off item");
    expect(() => BillPolicy.canEditBillItem("user-1", "user-1", "written_off", false)).toThrow("Cannot directly edit a paid or written-off item");
  });

  it("should allow editing unpaid and unlocked items by bill owner", () => {
    expect(() => BillPolicy.canEditBillItem("user-1", "user-1", "unpaid", false)).not.toThrow();
  });

  it("should forbid debtors from writing off debt they owe to someone else", () => {
    expect(() => BillPolicy.canWriteOffDebt("debtor-user", "owner-user")).toThrow("Only the bill owner can write off debt");
  });

  it("should allow bill owner to write off debt", () => {
    expect(() => BillPolicy.canWriteOffDebt("owner-user", "owner-user")).not.toThrow();
  });
});
