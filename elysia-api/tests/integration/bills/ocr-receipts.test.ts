import { describe, it, expect, beforeEach } from "bun:test";
import { BillService } from "../../../src/modules/bills/bill.service";
import { MockOCRService, ReceiptData } from "../../../src/modules/bills/ocr.service";
import { FakeLineNotificationService } from "../../../src/modules/bills/bill-notification.service";
import { BillAllocationService } from "../../../src/modules/bills/bill-allocation.service";

/* -------------------------------------------------------------------------- */
/* REAL RECEIPT FIXTURES FROM USER UPLOADS                                    */
/* -------------------------------------------------------------------------- */

export const sampleReceipt1_TheLocal: ReceiptData = {
  merchant: "THE LOCAL BY OAMTHONG THAI CUISINE",
  date: "2019-03-29T20:02:00Z",
  items: [
    { name: "Appetizer set", amount: 250.00 },
    { name: "Pomelo Salad", amount: 250.00 },
    { name: "Bai cha kram local vegeta (x2)", amount: 500.00 },
    { name: "Grill Beef with homemade", amount: 850.00 },
    { name: "Chicken in Pandanus Leave", amount: 220.00 },
    { name: "Rice (x2)", amount: 80.00 },
    { name: "Mango Blended", amount: 120.00 },
    { name: "Cold Butt&Passion", amount: 85.00 },
    { name: "Soda", amount: 55.00 },
  ],
  subtotal: 2410.00,
  tax: 185.57, // VAT
  discount: 0,
  totalAmount: 2836.57, // Net (Includes 10% Service Charge 241.00 + VAT 185.57)
  currency: "THB"
};

export const sampleReceipt2_MaiThai: ReceiptData = {
  merchant: "MAI THAI (Pattaya Naklua Road)",
  date: "2016-09-17T18:28:00Z",
  items: [
    { name: "Khaw phad in saparot", amount: 210.00 },
    { name: "PANAENG KAI", amount: 210.00 },
    { name: "Water", amount: 55.00 },
    { name: "STEAMED RICE", amount: 45.00 }
  ],
  subtotal: 485.98,
  tax: 34.02,
  discount: 0,
  totalAmount: 520.00,
  currency: "THB"
};

export const sampleReceipt3_TongNorthern: ReceiptData = {
  merchant: "ต๋อง อาหารพื้นเมือง (Tong Northern Thai Cuisine, เชียงใหม่)",
  date: "2012-04-16T13:52:51Z",
  items: [
    { name: "ลาบหมูคั่ว", amount: 52.00 },
    { name: "แกงฮังเล", amount: 62.00 },
    { name: "ข้าวเหนียว", amount: 15.00 },
    { name: "ยำยอดมะขาม", amount: 62.00 },
    { name: "ข้าวสวย", amount: 15.00 },
    { name: "น้ำดื่ม", amount: 12.00 },
    { name: "น้ำแข็ง S", amount: 10.00 }
  ],
  subtotal: 228.00,
  tax: 0,
  discount: 0.00,
  totalAmount: 228.00,
  currency: "THB"
};

describe("Integration: Real Receipts OCR & Bill Splitting Flow", () => {
  let mockOCRService: MockOCRService;
  let fakeNotificationService: FakeLineNotificationService;
  let billService: BillService;

  const testOwnerId = "11111111-1111-1111-1111-111111111111";
  const friend1 = "22222222-2222-2222-2222-222222222222";
  const friend2 = "33333333-3333-3333-3333-333333333333";
  const friend3 = "44444444-4444-4444-4444-444444444444";
  const friend4 = "55555555-5555-5555-5555-555555555555";

  beforeEach(() => {
    mockOCRService = new MockOCRService();
    fakeNotificationService = new FakeLineNotificationService();
    billService = new BillService(fakeNotificationService, mockOCRService);
  });

  /* -------------------------------------------------------------------------- */
  /* RECEIPT 1: The Local (2,836.57 THB)                                        */
  /* -------------------------------------------------------------------------- */
  describe("Receipt 1: The Local By Oamthong Thai Cuisine (2,836.57 THB)", () => {
    it("should process OCR draft and create bill evenly split among 4 friends", async () => {
      mockOCRService.setCustomResponse(sampleReceipt1_TheLocal);

      const fakeImage = new Blob(["image1"], { type: "image/jpeg" }) as File;
      const draft = await billService.processOCRReceipt(fakeImage);

      expect(draft.merchant).toBe("THE LOCAL BY OAMTHONG THAI CUISINE");
      expect(draft.totalAmount).toBe(2836.57);
      expect(draft.items.length).toBe(9);

      // Confirm draft & create bill split among 4 friends
      const bill = await billService.createBill(testOwnerId, {
        title: draft.merchant,
        totalAmount: draft.totalAmount,
        currency: draft.currency,
        participants: [
          { userId: friend1 },
          { userId: friend2 },
          { userId: friend3 },
          { userId: friend4 },
        ],
        allocationMethod: "evenly",
      });

      expect(bill.totalAmount).toBe("2836.57");

      // Verify deterministic split: 2836.57 / 4 = 709.15, 709.14, 709.14, 709.14
      const split = BillAllocationService.allocateEvenly(2836.57, 4);
      expect(split).toEqual([709.15, 709.14, 709.14, 709.14]);
      const sum = Math.round(split.reduce((a, b) => a + b, 0) * 100) / 100;
      expect(sum).toBe(2836.57);
    });
  });

  /* -------------------------------------------------------------------------- */
  /* RECEIPT 2: Mai Thai (520.00 THB)                                           */
  /* -------------------------------------------------------------------------- */
  describe("Receipt 2: Mai Thai Pattaya (520.00 THB)", () => {
    it("should process OCR draft and split with item-specific exact amounts", async () => {
      mockOCRService.setCustomResponse(sampleReceipt2_MaiThai);

      const fakeImage = new Blob(["image2"], { type: "image/png" }) as File;
      const draft = await billService.processOCRReceipt(fakeImage);

      expect(draft.merchant).toContain("MAI THAI");
      expect(draft.totalAmount).toBe(520.00);

      // Friend 1 ate Khaw Phad (210) + Steamed Rice (45) + Half Water (27.5) = 282.50
      // Friend 2 ate Panaeng Kai (210) + Half Water (27.5) = 237.50
      // Sum = 282.50 + 237.50 = 520.00
      const bill = await billService.createBill(testOwnerId, {
        title: "Mai Thai Dinner",
        totalAmount: 520.00,
        currency: "THB",
        participants: [
          { userId: friend1, amount: 282.50 },
          { userId: friend2, amount: 237.50 },
        ],
        allocationMethod: "exact",
      });

      expect(bill.totalAmount).toBe("520.00");
    });
  });

  /* -------------------------------------------------------------------------- */
  /* RECEIPT 3: Tong Northern Cuisine (228.00 THB)                              */
  /* -------------------------------------------------------------------------- */
  describe("Receipt 3: ต๋อง อาหารพื้นเมือง เชียงใหม่ (228.00 THB)", () => {
    it("should process Thai receipts accurately and handle 3-way split", async () => {
      mockOCRService.setCustomResponse(sampleReceipt3_TongNorthern);

      const fakeImage = new Blob(["image3"], { type: "image/jpeg" }) as File;
      const draft = await billService.processOCRReceipt(fakeImage);

      expect(draft.merchant).toContain("ต๋อง อาหารพื้นเมือง");
      expect(draft.items.length).toBe(7);
      expect(draft.totalAmount).toBe(228.00);

      // 3 friends split evenly: 228 / 3 = 76.00 each
      const split = BillAllocationService.allocateEvenly(228.00, 3);
      expect(split).toEqual([76.00, 76.00, 76.00]);

      const bill = await billService.createBill(testOwnerId, {
        title: draft.merchant,
        totalAmount: draft.totalAmount,
        currency: "THB",
        participants: [
          { userId: friend1 },
          { userId: friend2 },
          { userId: friend3 }
        ],
        allocationMethod: "evenly",
      });

      expect(bill.totalAmount).toBe("228.00");
    });
  });
});
