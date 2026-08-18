import { describe, it, expect } from "bun:test";
import { BillDiffService } from "../../../src/modules/bills/bill-diff.service";

describe("Unit: Bill Diff Service", () => {
  it("should generate diff when bill title or total changes", () => {
    const diff = BillDiffService.diff(
      { title: "Dinner", totalAmount: "1000.00" },
      { title: "Dinner + Drinks", totalAmount: "1200.00" },
      [],
      []
    );

    expect(diff.bill?.title).toEqual({ old: "Dinner", new: "Dinner + Drinks" });
    expect(diff.bill?.totalAmount).toEqual({ old: "1000.00", new: "1200.00" });
  });

  it("should generate diff when participant amounts change", () => {
    const diff = BillDiffService.diff(
      { title: "Dinner", totalAmount: "1000.00" },
      { title: "Dinner", totalAmount: "1000.00" },
      [
        { debtorId: "user-1", currentAmount: "500.00" },
        { debtorId: "user-2", currentAmount: "500.00" }
      ],
      [
        { debtorId: "user-1", currentAmount: "700.00" },
        { debtorId: "user-2", currentAmount: "300.00" }
      ]
    );

    expect(diff.bill).toBeUndefined();
    expect(diff.participants?.length).toBe(2);
    expect(diff.participants?.[0]).toEqual({
      debtorId: "user-1",
      oldAmount: "500.00",
      newAmount: "700.00"
    });
  });

  it("should return empty diff when nothing changed", () => {
    const diff = BillDiffService.diff(
      { title: "Dinner", totalAmount: "1000.00" },
      { title: "Dinner", totalAmount: "1000.00" },
      [{ debtorId: "user-1", currentAmount: "500.00" }],
      [{ debtorId: "user-1", currentAmount: "500.00" }]
    );

    expect(diff.bill).toBeUndefined();
    expect(diff.participants).toBeUndefined();
  });
});
