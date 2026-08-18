import { describe, it, expect } from "bun:test";

function toSatang(thb: number): number {
  return Math.round(thb * 100);
}

function fromSatang(satang: number): number {
  return satang / 100;
}

describe("Unit: Financial & Money Calculations", () => {
  it("should convert THB to Satang accurately without floating-point errors", () => {
    expect(toSatang(100.50)).toBe(10050);
    expect(toSatang(0.1 + 0.2)).toBe(30); // JS 0.1 + 0.2 is 0.30000000000000004
    expect(toSatang(33.33)).toBe(3333);
    expect(toSatang(999999.99)).toBe(99999999);
  });

  it("should convert Satang back to THB correctly", () => {
    expect(fromSatang(10050)).toBe(100.50);
    expect(fromSatang(30)).toBe(0.30);
    expect(fromSatang(3333)).toBe(33.33);
  });

  it("should preserve exact sums when adding minor units", () => {
    const p1 = toSatang(33.33);
    const p2 = toSatang(33.33);
    const p3 = toSatang(33.34);
    const total = p1 + p2 + p3;
    expect(total).toBe(10000);
    expect(fromSatang(total)).toBe(100.00);
  });
});
