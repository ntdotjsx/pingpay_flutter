import { describe, it, expect } from "bun:test";
import { BillStatusService } from "../../../src/modules/bills/bill-status.service";

describe("Unit: BillStatusService & Participant Status", () => {
  describe("Participant Status Calculation", () => {
    it("should return unpaid when nothing paid or written off", () => {
      const res = BillStatusService.calculateParticipantStatus({
        originalDebt: 1000,
        currentAmount: 1000,
        amountPaid: 0,
        amountWrittenOff: 0,
      });
      expect(res.status).toBe("unpaid");
      expect(res.remainingDebt).toBe(1000);
      expect(res.isFullySettled).toBe(false);
    });

    it("should return partially_paid when partial amount paid", () => {
      const res = BillStatusService.calculateParticipantStatus({
        originalDebt: 1000,
        currentAmount: 1000,
        amountPaid: 300,
        amountWrittenOff: 0,
      });
      expect(res.status).toBe("partially_paid");
      expect(res.remainingDebt).toBe(700);
      expect(res.isFullySettled).toBe(false);
    });

    it("should return paid when fully paid", () => {
      const res = BillStatusService.calculateParticipantStatus({
        originalDebt: 1000,
        currentAmount: 1000,
        amountPaid: 1000,
        amountWrittenOff: 0,
      });
      expect(res.status).toBe("paid");
      expect(res.remainingDebt).toBe(0);
      expect(res.isFullySettled).toBe(true);
    });

    it("should return written_off when entire amount written off without payment", () => {
      const res = BillStatusService.calculateParticipantStatus({
        originalDebt: 1000,
        currentAmount: 1000,
        amountPaid: 0,
        amountWrittenOff: 1000,
      });
      expect(res.status).toBe("written_off");
      expect(res.remainingDebt).toBe(0);
      expect(res.isFullySettled).toBe(true);
    });

    it("should return partially_paid when settled with combination of payment and write-off", () => {
      const res = BillStatusService.calculateParticipantStatus({
        originalDebt: 1000,
        currentAmount: 1000,
        amountPaid: 600,
        amountWrittenOff: 400,
      });
      expect(res.status).toBe("partially_paid");
      expect(res.remainingDebt).toBe(0);
      expect(res.isFullySettled).toBe(true);
    });
  });

  describe("Bill Overall Status Calculation Matrix", () => {
    it("should return unpaid for all unpaid participants", () => {
      const res = BillStatusService.calculateBillStatus({
        participants: [
          { originalDebt: 500, currentAmount: 500, amountPaid: 0, amountWrittenOff: 0 },
          { originalDebt: 500, currentAmount: 500, amountPaid: 0, amountWrittenOff: 0 },
        ],
      });
      expect(res.status).toBe("unpaid");
      expect(res.totalRemaining).toBe(1000);
      expect(res.totalPaid).toBe(0);
    });

    it("should return partially_paid when one participant paid and others unpaid", () => {
      const res = BillStatusService.calculateBillStatus({
        participants: [
          { originalDebt: 500, currentAmount: 500, amountPaid: 500, amountWrittenOff: 0 },
          { originalDebt: 500, currentAmount: 500, amountPaid: 0, amountWrittenOff: 0 },
        ],
      });
      expect(res.status).toBe("partially_paid");
      expect(res.totalPaid).toBe(500);
      expect(res.totalRemaining).toBe(500);
    });

    it("should return fully_paid when all participants have fully paid", () => {
      const res = BillStatusService.calculateBillStatus({
        participants: [
          { originalDebt: 500, currentAmount: 500, amountPaid: 500, amountWrittenOff: 0 },
          { originalDebt: 500, currentAmount: 500, amountPaid: 500, amountWrittenOff: 0 },
        ],
      });
      expect(res.status).toBe("fully_paid");
      expect(res.totalRemaining).toBe(0);
      expect(res.totalPaid).toBe(1000);
    });

    it("should return partially_written_off when some written off and no payments made yet", () => {
      const res = BillStatusService.calculateBillStatus({
        participants: [
          { originalDebt: 500, currentAmount: 500, amountPaid: 0, amountWrittenOff: 200 },
          { originalDebt: 500, currentAmount: 500, amountPaid: 0, amountWrittenOff: 0 },
        ],
      });
      expect(res.status).toBe("partially_written_off");
      expect(res.totalWrittenOff).toBe(200);
      expect(res.totalRemaining).toBe(800);
    });

    it("should return fully_written_off when entire bill was written off with 0 payments", () => {
      const res = BillStatusService.calculateBillStatus({
        participants: [
          { originalDebt: 500, currentAmount: 500, amountPaid: 0, amountWrittenOff: 500 },
          { originalDebt: 500, currentAmount: 500, amountPaid: 0, amountWrittenOff: 500 },
        ],
      });
      expect(res.status).toBe("fully_written_off");
      expect(res.totalRemaining).toBe(0);
      expect(res.totalWrittenOff).toBe(1000);
    });
  });
});
