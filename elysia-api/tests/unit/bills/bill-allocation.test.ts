import { describe, it, expect } from "bun:test";
import { BillAllocationService } from "../../../src/modules/bills/bill-allocation.service";

describe("Unit: Bill Allocation Service", () => {
  it("should split evenly with exact divisions (1000 / 2 = 500, 500)", () => {
    const result = BillAllocationService.allocateEvenly(1000, 2);
    expect(result).toEqual([500, 500]);
    expect(result.reduce((a, b) => a + b, 0)).toBe(1000);
  });

  it("should split deterministically with remainder (1000 / 3 = 333.34, 333.33, 333.33)", () => {
    const result = BillAllocationService.allocateEvenly(1000, 3);
    expect(result).toEqual([333.34, 333.33, 333.33]);
    const sum = Math.round(result.reduce((a, b) => a + b, 0) * 100) / 100;
    expect(sum).toBe(1000);
  });

  it("should handle remainder for 100 / 3", () => {
    const result = BillAllocationService.allocateEvenly(100, 3);
    expect(result).toEqual([33.34, 33.33, 33.33]);
    const sum = Math.round(result.reduce((a, b) => a + b, 0) * 100) / 100;
    expect(sum).toBe(100);
  });

  it("should handle 1 participant (total = 1000 -> 1000)", () => {
    const result = BillAllocationService.allocateEvenly(1000, 1);
    expect(result).toEqual([1000]);
  });

  it("should handle large number of participants (1000 / 6)", () => {
    const result = BillAllocationService.allocateEvenly(1000, 6);
    expect(result.length).toBe(6);
    const sum = Math.round(result.reduce((a, b) => a + b, 0) * 100) / 100;
    expect(sum).toBe(1000);
  });

  it("should validate exact allocations accurately", () => {
    expect(BillAllocationService.validateExactAllocation(1000, [300, 300, 400])).toBe(true);
    expect(BillAllocationService.validateExactAllocation(1000, [300, 300, 300])).toBe(false);
    expect(BillAllocationService.validateExactAllocation(100.50, [50.25, 50.25])).toBe(true);
    expect(BillAllocationService.validateExactAllocation(100.50, [50.25, 50.24])).toBe(false);
  });

  it("should exclude owner amount from participant debt when splitting evenly", () => {
    const result = BillAllocationService.allocateEvenly(518, 1, 259);
    expect(result).toEqual([259]);
  });

  it("should validate exact participant debt plus owner share against total", () => {
    expect(BillAllocationService.validateExactAllocation(518, [259], 259)).toBe(true);
    expect(BillAllocationService.validateExactAllocation(518, [518], 259)).toBe(false);
  });

  it("should handle User Case 1: Total = 498, 2 participants (Owner share = 249, 1 Debtor = 249)", () => {
    const result = BillAllocationService.allocateEvenly(498, 1, 249);
    expect(result).toEqual([249]);
    expect(BillAllocationService.validateExactAllocation(498, [249], 249)).toBe(true);
  });

  it("should handle User Case 2: Total = 498, 3 participants (Owner share = 166, 2 Debtors = 166 each)", () => {
    const result = BillAllocationService.allocateEvenly(498, 2, 166);
    expect(result).toEqual([166, 166]);
    expect(BillAllocationService.validateExactAllocation(498, [166, 166], 166)).toBe(true);
  });

  it("should return empty array if participants count <= 0", () => {
    expect(BillAllocationService.allocateEvenly(1000, 0)).toEqual([]);
  });
});
