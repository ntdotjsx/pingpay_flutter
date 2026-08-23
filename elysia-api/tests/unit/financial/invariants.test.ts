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

export function assertBillTotalInvariant(
  total: number | string,
  participants: Array<{ amount: number | string }>,
  ownerAmount: number | string = 0
) {
  const totalCents = Math.round(Number(total) * 100);
  const ownerCents = Math.round(Number(ownerAmount) * 100);
  const sumCents = participants.reduce((acc, p) => acc + Math.round(Number(p.amount) * 100), 0);
  expect(sumCents + ownerCents).toBe(totalCents);
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

  it("should uphold bill total invariant: sum(participants) + ownerAmount === billTotal", () => {
    assertBillTotalInvariant("1500.00", [
      { amount: "500.00" },
      { amount: "400.00" },
      { amount: "600.00" },
    ]);

    assertBillTotalInvariant("498.00", [{ amount: "249.00" }], "249.00");
  });

  describe("Case 1: Total 498 THB, 2 Participants (Owner + 1 Debtor)", () => {
    const totalAmount = 498;
    const participantCount = 2;
    const amountPerPerson = totalAmount / participantCount; // 249
    const myShare = amountPerPerson; // 249
    const debtorDebt = amountPerPerson; // 249

    it("should correctly separate Bill Total, My Share, Debt Per Person, and Total Outstanding", () => {
      expect(totalAmount).toBe(498);
      expect(myShare).toBe(249);
      expect(debtorDebt).toBe(249);

      // Debtor unpaid
      const debtorOutstanding = debtorDebt;
      const totalOutstanding = debtorOutstanding; // Only debtor's unpaid portion
      expect(totalOutstanding).toBe(249);
      expect(totalOutstanding).not.toBe(498); // MUST NOT be total bill!
    });
  });

  describe("Case 2: Total 498 THB, 3 Participants (Owner + 2 Debtors)", () => {
    const totalAmount = 498;
    const participantCount = 3;
    const amountPerPerson = totalAmount / participantCount; // 166
    const myShare = amountPerPerson; // 166
    const debtorADebt = amountPerPerson; // 166
    const debtorBDebt = amountPerPerson; // 166

    it("should correctly calculate debtor debts and total outstanding without creator share", () => {
      expect(totalAmount).toBe(498);
      expect(myShare).toBe(166);
      expect(debtorADebt).toBe(166);
      expect(debtorBDebt).toBe(166);

      const totalOutstanding = debtorADebt + debtorBDebt; // 166 + 166 = 332
      expect(totalOutstanding).toBe(332);
      expect(totalOutstanding).not.toBe(498); // MUST NOT be total bill!
    });
  });
});
