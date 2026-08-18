import { describe, it, expect } from "bun:test";

export function assertFinancialInvariant(item: {
  originalAmount: number | string;
  amountPaid: number | string;
  amountWrittenOff: number | string;
  remainingDebt?: number | string;
  currentAmount?: number | string;
}) {
  const orig = Math.round(Number(item.originalAmount) * 100);
  const paid = Math.round(Number(item.amountPaid) * 100);
  const writtenOff = Math.round(Number(item.amountWrittenOff) * 100);
  const current = item.currentAmount ? Math.round(Number(item.currentAmount) * 100) : orig;
  const remaining = item.remainingDebt !== undefined ? Math.round(Number(item.remainingDebt) * 100) : current - paid - writtenOff;

  expect(current).toBe(paid + remaining + writtenOff);
}

export function assertBillTotalInvariant(total: number | string, participants: Array<{ amount: number | string }>) {
  const totalCents = Math.round(Number(total) * 100);
  const sumCents = participants.reduce((acc, p) => acc + Math.round(Number(p.amount) * 100), 0);
  expect(sumCents).toBe(totalCents);
}

describe("Unit: Financial Invariants", () => {
  it("should uphold debt invariant: current = paid + writtenOff + remaining", () => {
    assertFinancialInvariant({
      originalAmount: "1000.00",
      currentAmount: "1000.00",
      amountPaid: "400.00",
      amountWrittenOff: "200.00",
      remainingDebt: "400.00",
    });
  });

  it("should uphold bill total invariant: sum(participants) === billTotal", () => {
    assertBillTotalInvariant("1500.00", [
      { amount: "500.00" },
      { amount: "400.00" },
      { amount: "600.00" },
    ]);
  });
});
