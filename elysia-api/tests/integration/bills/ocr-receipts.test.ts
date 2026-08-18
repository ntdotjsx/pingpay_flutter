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
    { name: "Appetizer set", amount: 250.00, quantity: 1 },
    { name: "Pomelo Salad", amount: 250.00, quantity: 1 },
    { name: "Bai cha kram local vegeta", amount: 500.00, quantity: 2 },
    { name: "Grill Beef with homemade", amount: 850.00, quantity: 1 },
    { name: "Chicken in Pandanus Leave", amount: 220.00, quantity: 1 },
    { name: "Rice", amount: 80.00, quantity: 2 },
    { name: "Mango Blended", amount: 120.00, quantity: 1 },
    { name: "Cold Butt&Passion", amount: 85.00, quantity: 1 },
    { name: "Soda", amount: 55.00, quantity: 1 },
  ],
  subtotal: 2410.00,
  serviceCharge: { ratePercent: 10, amount: 241.00 },
  vat: { ratePercent: 7, amount: 185.57 },
  discount: 0,
  totalAmount: 2836.57, // Subtotal (2410) + Service Charge (241) + VAT (185.57) = 2836.57
  currency: "THB",
  formulaExplanation: "Subtotal (2410.00) + Service Charge 10% (241.00) + VAT 7% (185.57) = Total (2836.57 THB)",
};

export const sampleReceipt2_MaiThai: ReceiptData = {
  merchant: "MAI THAI (Pattaya Naklua Road)",
  date: "2016-09-17T18:28:00Z",
  items: [
    { name: "Khaw phad in saparot", amount: 210.00, quantity: 1 },
    { name: "PANAENG KAI", amount: 210.00, quantity: 1 },
    { name: "Water", amount: 55.00, quantity: 1 },
    { name: "STEAMED RICE", amount: 45.00, quantity: 1 }
  ],
  subtotal: 485.98,
  vat: { ratePercent: 7, amount: 34.02 },
  discount: 0,
  totalAmount: 520.00,
  currency: "THB",
  formulaExplanation: "Subtotal (485.98) + VAT 7% (34.02) = Total (520.00 THB)",
};

export const sampleReceipt3_TongNorthern: ReceiptData = {
  merchant: "ต๋อง อาหารพื้นเมือง (Tong Northern Thai Cuisine, เชียงใหม่)",
  date: "2012-04-16T13:52:51Z",
  items: [
    { name: "ลาบหมูคั่ว", amount: 52.00, quantity: 1 },
    { name: "แกงฮังเล", amount: 62.00, quantity: 1 },
    { name: "ข้าวเหนียว", amount: 15.00, quantity: 1 },
    { name: "ยำยอดมะขาม", amount: 62.00, quantity: 1 },
    { name: "ข้าวสวย", amount: 15.00, quantity: 1 },
    { name: "น้ำดื่ม", amount: 12.00, quantity: 1 },
    { name: "น้ำแข็ง S", amount: 10.00, quantity: 1 }
  ],
  subtotal: 228.00,
  discount: 0.00,
  totalAmount: 228.00,
  currency: "THB",
  formulaExplanation: "Subtotal (228.00) = Total (228.00 THB)",
};

import { bills, billItems, financialTransactions, editLogs } from "../../../src/db/schema";

const createFakeDb = () => {
  const dbState = {
    bills: new Map<string, any>(),
    billItems: new Map<string, any>(),
    financialTransactions: [] as any[],
    editLogs: [] as any[],
  };

  const fakeTx = {
    insert: (table: any) => ({
      values: (val: any) => ({
        returning: async () => {
          const items = Array.isArray(val) ? val : [val];
          const created = items.map((item) => {
            const row = { id: crypto.randomUUID(), createdAt: new Date(), updatedAt: new Date(), ...item };
            if (table === bills || item.ownerId !== undefined || (item.totalAmount !== undefined && item.debtorId === undefined)) {
              dbState.bills.set(row.id, row);
            } else if (table === billItems || item.debtorId !== undefined) {
              dbState.billItems.set(row.id, row);
            } else if (table === financialTransactions || item.type !== undefined) {
              dbState.financialTransactions.push(row);
            } else if (table === editLogs || item.action !== undefined) {
              dbState.editLogs.push(row);
            }
            return row;
          });
          return created;
        },
      }),
    }),
    update: (table: any) => ({
      set: (val: any) => ({
        where: (condition: any) => ({
          returning: async () => {
            for (const [id, bill] of dbState.bills.entries()) {
              Object.assign(bill, val);
              return [bill];
            }
            for (const [id, item] of dbState.billItems.entries()) {
              Object.assign(item, val);
              return [item];
            }
            return [val];
          },
        }),
      }),
    }),
    delete: (table: any) => {
      const p: any = Promise.resolve();
      p.where = (cond: any) => Promise.resolve();
      return p;
    },
    select: () => ({
      from: (table: any) => ({
        where: (cond: any) => Array.from(dbState.billItems.values()),
      }),
    }),
    query: {
      bills: {
        findFirst: async (q: any) => {
          const firstBill = Array.from(dbState.bills.values())[0];
          if (!firstBill) return undefined;
          const items = Array.from(dbState.billItems.values()).filter((i) => i.billId === firstBill.id);
          return {
            ...firstBill,
            items,
            owner: { id: firstBill.ownerId, displayName: "Test Owner", fullName: "Test Owner Full" },
          };
        },
      },
      billItems: {
        findFirst: async (q: any) => {
          const firstItem = Array.from(dbState.billItems.values())[0];
          if (!firstItem) return undefined;
          const bill = dbState.bills.get(firstItem.billId);
          return { ...firstItem, bill };
        },
        findMany: async (q: any) => {
          return Array.from(dbState.billItems.values());
        },
      },
    },
  };

  return {
    ...fakeTx,
    transaction: async (cb: any) => cb(fakeTx),
  };
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
    const fakeDb = createFakeDb();
    billService = new BillService(fakeNotificationService, mockOCRService, fakeDb);
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
