import { describe, it, expect, beforeEach, mock } from "bun:test";
import { FakeLineNotificationService } from "../../../src/modules/bills/bill-notification.service";
import { MockOCRService } from "../../../src/modules/bills/ocr.service";
import { BillService } from "../../../src/modules/bills/bill.service";

// In-memory relational tables for database simulation
const dbState = {
  bills: new Map<string, any>(),
  billItems: new Map<string, any>(),
  financialTransactions: [] as any[],
  editLogs: [] as any[],
};

// Stateful mock for drizzle db
mock.module("../../../src/db/index.ts", () => {
  const fakeTx = {
    insert: (table: any) => ({
      values: (val: any) => ({
        returning: async () => {
          const items = Array.isArray(val) ? val : [val];
          const created = items.map((item) => {
            const row = { id: crypto.randomUUID(), createdAt: new Date(), updatedAt: new Date(), ...item };
            if (item.totalAmount !== undefined && item.ownerId !== undefined) {
              dbState.bills.set(row.id, row);
            } else if (item.debtorId !== undefined && item.billId !== undefined) {
              dbState.billItems.set(row.id, row);
            } else if (item.type !== undefined) {
              dbState.financialTransactions.push(row);
            } else if (item.action !== undefined) {
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
            // Find target item and update
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
      },
    },
  };

  return {
    db: {
      ...fakeTx,
      transaction: async (cb: any) => cb(fakeTx),
    },
  };
});

describe("Integration & E2E: Bill Management API", () => {
  let fakeNotificationService: FakeLineNotificationService;
  let mockOCRService: MockOCRService;
  let billService: BillService;

  const testOwnerId = "11111111-1111-1111-1111-111111111111";
  const userA = "22222222-2222-2222-2222-222222222222";
  const userB = "33333333-3333-3333-3333-333333333333";
  const userC = "44444444-4444-4444-4444-444444444444";
  const unauthorizedUser = "99999999-9999-9999-9999-999999999999";

  beforeEach(() => {
    dbState.bills.clear();
    dbState.billItems.clear();
    dbState.financialTransactions.length = 0;
    dbState.editLogs.length = 0;

    fakeNotificationService = new FakeLineNotificationService();
    mockOCRService = new MockOCRService();
    billService = new BillService(fakeNotificationService, mockOCRService);
  });

  /* -------------------------------------------------------------------------- */
  /* 1. BILL CREATION TESTS                                                     */
  /* -------------------------------------------------------------------------- */
  describe("1. Bill Creation", () => {
    it("should create a valid bill evenly split among participants", async () => {
      const result = await billService.createBill(testOwnerId, {
        title: "Dinner Party",
        totalAmount: 1500,
        currency: "THB",
        participants: [{ userId: userA }, { userId: userB }, { userId: userC }],
        allocationMethod: "evenly",
      });

      expect(result).toBeDefined();
      expect(result.totalAmount).toBe("1500.00");
      expect(dbState.bills.size).toBe(1);
      expect(dbState.billItems.size).toBe(3);
    });

    it("should create a valid bill with exact custom allocations", async () => {
      const result = await billService.createBill(testOwnerId, {
        title: "Exact Split Dinner",
        totalAmount: 1500,
        currency: "THB",
        participants: [
          { userId: userA, amount: 500 },
          { userId: userB, amount: 400 },
          { userId: userC, amount: 600 },
        ],
        allocationMethod: "exact",
      });

      expect(result).toBeDefined();
      expect(result.totalAmount).toBe("1500.00");
    });

    it("should reject bill creation if exact amounts do not match total (TOTAL_MISMATCH)", async () => {
      expect(
        billService.createBill(testOwnerId, {
          title: "Mismatched Bill",
          totalAmount: 1500,
          currency: "THB",
          participants: [
            { userId: userA, amount: 500 },
            { userId: userB, amount: 400 },
            { userId: userC, amount: 500 },
          ],
          allocationMethod: "exact",
        })
      ).rejects.toThrow("TOTAL_MISMATCH");
    });

    it("should reject bill creation with duplicate participants (DUPLICATE_PARTICIPANT)", async () => {
      expect(
        billService.createBill(testOwnerId, {
          title: "Duplicate User Bill",
          totalAmount: 1000,
          participants: [{ userId: userA }, { userId: userA }],
        })
      ).rejects.toThrow("DUPLICATE_PARTICIPANT");
    });

    it("should reject negative or zero total amounts (INVALID_AMOUNT)", async () => {
      expect(
        billService.createBill(testOwnerId, {
          title: "Zero Bill",
          totalAmount: 0,
          participants: [{ userId: userA }],
        })
      ).rejects.toThrow("INVALID_AMOUNT");

      expect(
        billService.createBill(testOwnerId, {
          title: "Negative Bill",
          totalAmount: -500,
          participants: [{ userId: userA }],
        })
      ).rejects.toThrow("INVALID_AMOUNT");
    });

    it("should reject empty participants list", async () => {
      expect(
        billService.createBill(testOwnerId, {
          title: "Empty Participants",
          totalAmount: 1000,
          participants: [],
        })
      ).rejects.toThrow("INVALID_AMOUNT");
    });
  });

  /* -------------------------------------------------------------------------- */
  /* 2. OCR RECEIPT FLOW                                                        */
  /* -------------------------------------------------------------------------- */
  describe("2. OCR Bill Creation Draft Flow", () => {
    it("should extract receipt data as a draft", async () => {
      const mockFile = new Blob(["fake receipt image content"], { type: "image/jpeg" }) as File;
      const receipt = await billService.processOCRReceipt(mockFile);

      expect(receipt).toBeDefined();
      expect(receipt.merchant).toBe("Restaurant ABC");
      expect(receipt.totalAmount).toBe(428);
      expect(receipt.items.length).toBe(3);
    });

    it("should reject unsupported file types for OCR", async () => {
      const pdfFile = new Blob(["fake pdf"], { type: "application/pdf" }) as File;
      expect(billService.processOCRReceipt(pdfFile)).rejects.toThrow("UNSUPPORTED_FILE_TYPE");
    });

    it("should reject empty file for OCR", async () => {
      const emptyFile = new Blob([], { type: "image/png" }) as File;
      expect(billService.processOCRReceipt(emptyFile)).rejects.toThrow("INVALID_FILE");
    });
  });

  /* -------------------------------------------------------------------------- */
  /* 3. PAID DEBT LOCK & IMMUTABILITY                                          */
  /* -------------------------------------------------------------------------- */
  describe("3. Paid Debt Lock & Immutability", () => {
    it("should reject direct editing of fully paid participant debt (PAID_DEBT_LOCKED)", async () => {
      const bill = await billService.createBill(testOwnerId, {
        title: "Lunch",
        totalAmount: 1000,
        participants: [{ userId: userA, amount: 500 }, { userId: userB, amount: 500 }],
        allocationMethod: "exact",
      });

      const loadedBill = await billService.getBill(bill.id);
      const itemA = loadedBill.items.find((i: any) => i.debtorId === userA);

      itemA.amountPaid = "500.00";
      itemA.isLocked = true;
      itemA.status = "paid";

      expect(
        billService.editBillItem(testOwnerId, bill.id, itemA.id, 400)
      ).rejects.toThrow("PAID_DEBT_LOCKED");
    });
  });

  /* -------------------------------------------------------------------------- */
  /* 4. DEBT WRITE-OFF (FULL, PARTIAL, NOT PAYMENT)                             */
  /* -------------------------------------------------------------------------- */
  describe("4. Debt Write-Off", () => {
    it("should perform partial write-off and preserve invariants", async () => {
      const bill = await billService.createBill(testOwnerId, {
        title: "Trip Expenses",
        totalAmount: 1000,
        participants: [{ userId: userA, amount: 500 }, { userId: userB, amount: 500 }],
        allocationMethod: "exact",
      });

      const loadedBill = await billService.getBill(bill.id);
      const itemA = loadedBill.items.find((i: any) => i.debtorId === userA);

      const writeoffResult = await billService.writeOffDebt(testOwnerId, bill.id, {
        reason: "Friend discount",
        participants: [{ participantId: itemA.id, amount: 200 }],
      });

      expect(writeoffResult.success).toBe(true);

      const notifications = fakeNotificationService.getSentNotifications();
      expect(notifications.length).toBe(1);
      expect(notifications[0].userId).toBe(userA);
      expect(notifications[0].type).toBe("write_off");
      expect(notifications[0].oldAmount).toBe("500.00");
      expect(notifications[0].newAmount).toBe("300.00");
    });

    it("should reject write-off exceeding remaining debt (INSUFFICIENT_REMAINING_DEBT)", async () => {
      const bill = await billService.createBill(testOwnerId, {
        title: "Groceries",
        totalAmount: 500,
        participants: [{ userId: userA, amount: 500 }],
        allocationMethod: "exact",
      });

      const loadedBill = await billService.getBill(bill.id);
      const itemA = loadedBill.items[0];

      expect(
        billService.writeOffDebt(testOwnerId, bill.id, {
          participants: [{ participantId: itemA.id, amount: 600 }],
        })
      ).rejects.toThrow("INSUFFICIENT_REMAINING_DEBT");
    });

    it("should support write-off idempotency", async () => {
      const bill = await billService.createBill(testOwnerId, {
        title: "Snacks",
        totalAmount: 200,
        participants: [{ userId: userA, amount: 200 }],
        allocationMethod: "exact",
      });

      const loadedBill = await billService.getBill(bill.id);
      const itemA = loadedBill.items[0];

      const res1 = await billService.writeOffDebt(testOwnerId, bill.id, {
        idempotencyKey: "key-12345",
        participants: [{ participantId: itemA.id, amount: 50 }],
      });
      expect(res1.success).toBe(true);

      const res2 = await billService.writeOffDebt(testOwnerId, bill.id, {
        idempotencyKey: "key-12345",
        participants: [{ participantId: itemA.id, amount: 50 }],
      });
      expect(res2.message).toContain("idempotently");
    });
  });

  /* -------------------------------------------------------------------------- */
  /* 5. REFUND & ADJUSTMENT FLOW                                               */
  /* -------------------------------------------------------------------------- */
  describe("5. Adjustments & Refunds for Paid Debts", () => {
    it("should create a refund when decreasing a fully paid debt (1000 -> 800 => 200 refund)", async () => {
      const bill = await billService.createBill(testOwnerId, {
        title: "Concert Ticket",
        totalAmount: 1000,
        participants: [{ userId: userA, amount: 1000 }],
        allocationMethod: "exact",
      });

      const loadedBill = await billService.getBill(bill.id);
      const itemA = loadedBill.items[0];
      itemA.amountPaid = "1000.00";

      const adjResult = await billService.adjustPaidDebt(testOwnerId, bill.id, {
        participantId: itemA.id,
        newAmount: 800,
        reason: "Early bird discount applied retroactively",
      });

      expect(adjResult.success).toBe(true);

      const notifications = fakeNotificationService.getSentNotifications();
      expect(notifications.length).toBe(1);
      expect(notifications[0].userId).toBe(userA);
      expect(notifications[0].newAmount).toBe("800.00");
    });

    it("should create additional debt when increasing a paid debt (1000 -> 1200 => 200 additional)", async () => {
      const bill = await billService.createBill(testOwnerId, {
        title: "Hotel Room",
        totalAmount: 1000,
        participants: [{ userId: userA, amount: 1000 }],
        allocationMethod: "exact",
      });

      const loadedBill = await billService.getBill(bill.id);
      const itemA = loadedBill.items[0];
      itemA.amountPaid = "1000.00";

      const adjResult = await billService.adjustPaidDebt(testOwnerId, bill.id, {
        participantId: itemA.id,
        newAmount: 1200,
        reason: "Extra room service added",
      });

      expect(adjResult.success).toBe(true);
    });
  });

  /* -------------------------------------------------------------------------- */
  /* 6. AUTHORIZATION & SECURITY                                               */
  /* -------------------------------------------------------------------------- */
  describe("6. Authorization & Security", () => {
    it("should forbid non-owner from editing bill (Unauthorized)", async () => {
      const bill = await billService.createBill(testOwnerId, {
        title: "Private Bill",
        totalAmount: 500,
        participants: [{ userId: userA, amount: 500 }],
        allocationMethod: "exact",
      });

      expect(
        billService.editBill(unauthorizedUser, bill.id, { title: "Hacked Title" })
      ).rejects.toThrow("Unauthorized");
    });

    it("should forbid non-owner from writing off debts", async () => {
      const bill = await billService.createBill(testOwnerId, {
        title: "Private Bill 2",
        totalAmount: 500,
        participants: [{ userId: userA, amount: 500 }],
        allocationMethod: "exact",
      });

      const loadedBill = await billService.getBill(bill.id);

      expect(
        billService.writeOffDebt(unauthorizedUser, bill.id, {
          participants: [{ participantId: loadedBill.items[0].id, amount: 100 }],
        })
      ).rejects.toThrow("Unauthorized");
    });
  });

  /* -------------------------------------------------------------------------- */
  /* 7. NOTIFICATION RESILIENCE                                                 */
  /* -------------------------------------------------------------------------- */
  describe("7. Notification Resilience", () => {
    it("should commit write-off even if LINE notification delivery fails", async () => {
      fakeNotificationService.setShouldFail(true);

      const bill = await billService.createBill(testOwnerId, {
        title: "Resilience Test Bill",
        totalAmount: 400,
        participants: [{ userId: userA, amount: 400 }],
        allocationMethod: "exact",
      });

      const loadedBill = await billService.getBill(bill.id);

      const result = await billService.writeOffDebt(testOwnerId, bill.id, {
        participants: [{ participantId: loadedBill.items[0].id, amount: 100 }],
      });

      expect(result.success).toBe(true);
    });
  });

  /* -------------------------------------------------------------------------- */
  /* 8. FULL BILL LIFECYCLE E2E                                                */
  /* -------------------------------------------------------------------------- */
  describe("8. Full Bill Lifecycle E2E", () => {
    it("should complete a full lifecycle from creation -> participant edit -> write-off -> adjustment", async () => {
      const bill = await billService.createBill(testOwnerId, {
        title: "Weekend Trip",
        totalAmount: 1200,
        participants: [{ userId: userA }, { userId: userB }, { userId: userC }],
        allocationMethod: "evenly",
      });
      expect(bill.totalAmount).toBe("1200.00");

      const loaded = await billService.getBill(bill.id);
      expect(loaded.items.length).toBe(3);
      expect(loaded.items[0].currentAmount).toBe("400.00");

      const updated = await billService.editBillItem(testOwnerId, bill.id, loaded.items[0].id, 600);
      expect(updated).toBeDefined();

      const itemB = loaded.items[1];
      await billService.writeOffDebt(testOwnerId, bill.id, {
        participants: [{ participantId: itemB.id, amount: 100 }],
      });

      const itemC = loaded.items[2];
      itemC.amountPaid = "300.00";
      const adjRes = await billService.adjustPaidDebt(testOwnerId, bill.id, {
        participantId: itemC.id,
        newAmount: 250,
      });
      expect(adjRes.success).toBe(true);

      const notifications = fakeNotificationService.getSentNotifications();
      expect(notifications.length).toBeGreaterThan(0);
    });
  });
});
