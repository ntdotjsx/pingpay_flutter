import { describe, it, expect } from "bun:test";
import { parseReceiptText } from "../../../src/modules/bills/ocr.service";

describe("Unit: PaddleOCR Receipt Text Parser", () => {
  it("should parse Thai receipt text lines extracted from PaddleOCR", () => {
    const rawText = `ต๋อง อาหารพื้นเมือง
ลาบหมูคั่ว 52.00
แกงฮังเล 62.00
ข้าวเหนียว 15.00
น้ำดื่ม 12.00
รวมจำนวนเงินทั้งหมด 141.00`;

    const parsed = parseReceiptText(rawText);

    expect(parsed.merchant).toBe("ต๋อง อาหารพื้นเมือง");
    expect(parsed.items.length).toBe(4);
    expect(parsed.items[0]).toEqual({ name: "ลาบหมูคั่ว", amount: 52 });
    expect(parsed.items[1]).toEqual({ name: "แกงฮังเล", amount: 62 });
    expect(parsed.totalAmount).toBe(141.00);
    expect(parsed.currency).toBe("THB");
  });

  it("should parse English receipt format with Net Total", () => {
    const rawText = `MAI THAI
Khaw phad in saparot 210.00
PANAENG KAI 210.00
Water 55.00
STEAMED RICE 45.00
Net Total 520.00`;

    const parsed = parseReceiptText(rawText);

    expect(parsed.merchant).toBe("MAI THAI");
    expect(parsed.items.length).toBe(4);
    expect(parsed.totalAmount).toBe(520.00);
  });
});
