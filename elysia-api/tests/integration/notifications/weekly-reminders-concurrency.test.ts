import { describe, test, expect, beforeEach } from "bun:test";
import { DebtReminderSchedulerService } from "../../../src/modules/notifications/debt-reminder-scheduler.service";
import { NotificationOutboxService } from "../../../src/modules/notifications/notification-outbox.service";

describe("E2E & Concurrency: Weekly Debt Reminders & Full Notification Flow", () => {
  let store: any;
  let fakeDb: any;
  let outboxService: NotificationOutboxService;
  let scheduler: DebtReminderSchedulerService;

  beforeEach(() => {
    store = {
      users: new Map<string, any>(),
      bills: new Map<string, any>(),
      billItems: new Map<string, any>(),
      notificationOutbox: new Map<string, any>(),
    };

    fakeDb = {
      _store: store,
      query: {
        billItems: {
          findMany: async () => {
            return Array.from(store.billItems.values()).map((item: any) => ({
              ...item,
              bill: store.bills.get(item.billId),
              debtor: store.users.get(item.debtorId),
            }));
          },
        },
        notificationOutbox: {
          findFirst: async (params?: any) => {
            const all = Array.from(store.notificationOutbox.values());
            if (!params || !params.where) {
              return all[0] || null;
            }
            // For Drizzle eq(notificationOutbox.deduplicationKey, key)
            const queryKey = params.where?.queryChunks?.find((c: any) => typeof c?.value === "string")?.value
              || params.where?.value
              || params.where?.right?.value;

            if (queryKey) {
              return all.find((o: any) => o.deduplicationKey === queryKey) || null;
            }

            // If expression check matches any existing record's deduplicationKey
            for (const item of all) {
              if (params.where.toString().includes(item.deduplicationKey)) {
                return item;
              }
            }

            return null;
          },
        },
      },
      insert: (table: any) => ({
        values: (vals: any) => {
          const arr = Array.isArray(vals) ? vals : [vals];
          const inserted: any[] = [];
          for (const v of arr) {
            const id = v.id || `id-${crypto.randomUUID()}`;
            // Enforce UNIQUE deduplicationKey
            const existingWithKey = Array.from(store.notificationOutbox.values()).find(
              (o: any) => o.deduplicationKey === v.deduplicationKey
            );
            if (existingWithKey) {
              throw new Error(`UNIQUE_CONSTRAINT_VIOLATION: duplicate key ${v.deduplicationKey}`);
            }
            const record = { ...v, id, createdAt: new Date(), updatedAt: new Date() };
            store.notificationOutbox.set(id, record);
            inserted.push(record);
          }
          return {
            returning: async () => inserted,
          };
        },
      }),
      transaction: async (cb: any) => {
        return await cb(fakeDb);
      },
    };

    outboxService = new NotificationOutboxService(fakeDb);
    scheduler = new DebtReminderSchedulerService(outboxService, fakeDb, "Asia/Bangkok");

    // Setup initial data
    store.users.set("user-debtor-1", { id: "user-debtor-1", displayName: "Debtor 1" });
    store.users.set("user-debtor-2", { id: "user-debtor-2", displayName: "Debtor 2" });

    store.bills.set("bill-1", {
      id: "bill-1",
      title: "Team Party",
      currency: "THB",
      cancelledAt: null,
    });
  });

  test("5.16 & 5.18 Weekly Scheduler: Enqueues reminder for unpaid debts, then deduplicates on immediate second run", async () => {
    store.billItems.set("item-1", {
      id: "item-1",
      billId: "bill-1",
      debtorId: "user-debtor-1",
      originalAmount: "1000.00",
      currentAmount: "1000.00",
      amountPaid: "0.00",
      amountWrittenOff: "0.00",
      status: "unpaid",
    });

    const fixedDate = new Date("2026-08-18T10:00:00Z");

    // Run 1 -> Enqueues 1 reminder
    const run1 = await scheduler.runWeeklyReminderJob(fixedDate);
    expect(run1.eligibleCount).toBe(1);
    expect(run1.enqueuedCount).toBe(1);
    expect(run1.weekKey).toBe("2026-W34");

    // Run 2 immediately -> Skipped due to deduplicationKey
    const run2 = await scheduler.runWeeklyReminderJob(fixedDate);
    expect(run2.eligibleCount).toBe(1);
    expect(run2.enqueuedCount).toBe(0);
    expect(run2.skippedCount).toBe(1);

    expect(store.notificationOutbox.size).toBe(1);
  });

  test("5.50 Advance 1 Week: Produces exactly 1 new reminder with next weekKey", async () => {
    store.billItems.set("item-1", {
      id: "item-1",
      billId: "bill-1",
      debtorId: "user-debtor-1",
      originalAmount: "1000.00",
      currentAmount: "1000.00",
      amountPaid: "0.00",
      amountWrittenOff: "0.00",
      status: "unpaid",
    });

    // Week 34
    await scheduler.runWeeklyReminderJob(new Date("2026-08-18T10:00:00Z"));
    expect(store.notificationOutbox.size).toBe(1);

    // Week 35 (+7 days)
    const runNextWeek = await scheduler.runWeeklyReminderJob(new Date("2026-08-25T10:00:00Z"));
    expect(runNextWeek.enqueuedCount).toBe(1);
    expect(runNextWeek.weekKey).toBe("2026-W35");
    expect(store.notificationOutbox.size).toBe(2);
  });

  test("5.23 & 5.24 Reminder Stops: Once debt is fully paid or written off, scheduler stops enqueuing", async () => {
    // 1. Debt becomes fully paid
    store.billItems.set("item-paid", {
      id: "item-paid",
      billId: "bill-1",
      debtorId: "user-debtor-1",
      originalAmount: "1000.00",
      currentAmount: "1000.00",
      amountPaid: "1000.00",
      amountWrittenOff: "0.00",
      status: "paid",
    });

    // 2. Debt becomes fully written off
    store.billItems.set("item-written-off", {
      id: "item-written-off",
      billId: "bill-1",
      debtorId: "user-debtor-2",
      originalAmount: "500.00",
      currentAmount: "500.00",
      amountPaid: "0.00",
      amountWrittenOff: "500.00",
      status: "written_off",
    });

    const runResult = await scheduler.runWeeklyReminderJob(new Date("2026-08-18T10:00:00Z"));
    expect(runResult.eligibleCount).toBe(0);
    expect(runResult.enqueuedCount).toBe(0);
    expect(store.notificationOutbox.size).toBe(0);
  });

  test("5.25 Partial Write-Off + Payment: Reminders continue showing exact remaining balance", async () => {
    store.billItems.set("item-partial", {
      id: "item-partial",
      billId: "bill-1",
      debtorId: "user-debtor-1",
      originalAmount: "1000.00",
      currentAmount: "1000.00",
      amountPaid: "300.00",
      amountWrittenOff: "200.00",
      status: "partially_paid",
    });

    const runResult = await scheduler.runWeeklyReminderJob(new Date("2026-08-18T10:00:00Z"));
    expect(runResult.eligibleCount).toBe(1);
    expect(runResult.enqueuedCount).toBe(1);

    const outboxItem = Array.from(store.notificationOutbox.values())[0];
    expect(outboxItem.payload.remainingDebt).toBe("500.00");
    expect(outboxItem.payload.amountPaid).toBe("300.00");
    expect(outboxItem.payload.amountWrittenOff).toBe("200.00");
  });

  test("5.63 Multi-Scheduler Concurrency: Parallel executions produce exactly 1 reminder outbox record", async () => {
    store.billItems.set("item-1", {
      id: "item-1",
      billId: "bill-1",
      debtorId: "user-debtor-1",
      originalAmount: "1000.00",
      currentAmount: "1000.00",
      amountPaid: "0.00",
      amountWrittenOff: "0.00",
      status: "unpaid",
    });

    const fixedDate = new Date("2026-08-18T10:00:00Z");

    // Simulate 3 server instances running scheduler simultaneously
    const [res1, res2, res3] = await Promise.all([
      scheduler.runWeeklyReminderJob(fixedDate),
      scheduler.runWeeklyReminderJob(fixedDate),
      scheduler.runWeeklyReminderJob(fixedDate),
    ]);

    const totalEnqueued = res1.enqueuedCount + res2.enqueuedCount + res3.enqueuedCount;
    expect(totalEnqueued).toBe(1);
    expect(store.notificationOutbox.size).toBe(1);
  });
});
