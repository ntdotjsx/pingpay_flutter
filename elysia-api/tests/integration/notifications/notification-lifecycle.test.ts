import { describe, test, expect, beforeEach } from "bun:test";
import { NotificationOutboxService } from "../../../src/modules/notifications/notification-outbox.service";
import { NotificationWorkerService } from "../../../src/modules/notifications/notification-worker.service";
import { LineNotificationProvider } from "../../../src/modules/notifications/line-notification.provider";
import { DebtReminderSchedulerService } from "../../../src/modules/notifications/debt-reminder-scheduler.service";

// In-Memory Database Simulator for Notification Testing
function createFakeNotificationDb() {
  const store = {
    users: new Map<string, any>(),
    authIdentities: new Map<string, any>(),
    bills: new Map<string, any>(),
    billItems: new Map<string, any>(),
    notificationOutbox: new Map<string, any>(),
    notificationDeliveries: new Map<string, any>(),
  };

  const fakeDb: any = {
    _store: store,
    query: {
      users: {
        findFirst: async ({ where }: any) => {
          return Array.from(store.users.values())[0] || null;
        },
      },
      authIdentities: {
        findFirst: async ({ where }: any) => {
          return Array.from(store.authIdentities.values())[0] || null;
        },
      },
      billItems: {
        findMany: async () => {
          return Array.from(store.billItems.values()).map((item) => ({
            ...item,
            bill: store.bills.get(item.billId),
            debtor: store.users.get(item.debtorId),
          }));
        },
      },
      notificationOutbox: {
        findFirst: async ({ where }: any) => {
          return Array.from(store.notificationOutbox.values())[0] || null;
        },
        findMany: async () => {
          return Array.from(store.notificationOutbox.values());
        },
      },
    },
    transaction: async (cb: any) => {
      const tx = {
        ...fakeDb,
        insert: (table: any) => ({
          values: (vals: any) => {
            const arr = Array.isArray(vals) ? vals : [vals];
            const inserted: any[] = [];
            for (const v of arr) {
              const id = v.id || `id-${crypto.randomUUID()}`;
              const record = { ...v, id, createdAt: new Date(), updatedAt: new Date() };
              if (v.status && v.deduplicationKey) {
                // Outbox table
                store.notificationOutbox.set(id, record);
              } else if (v.notificationId) {
                // Deliveries table
                store.notificationDeliveries.set(id, record);
              } else {
                store.notificationOutbox.set(id, record);
              }
              inserted.push(record);
            }
            return {
              returning: async () => inserted,
            };
          },
        }),
        update: (table: any) => ({
          set: (changes: any) => ({
            where: (whereClause: any) => {
              // Update all or specific
              for (const [id, record] of store.notificationOutbox.entries()) {
                store.notificationOutbox.set(id, { ...record, ...changes });
              }
              return {
                returning: async () => Array.from(store.notificationOutbox.values()),
              };
            },
          }),
        }),
        select: () => ({
          from: () => ({
            where: () => ({
              limit: (n: number) => ({
                for: () => Array.from(store.notificationOutbox.values()).slice(0, n),
              }),
            }),
          }),
        }),
      };
      return await cb(tx);
    },
    insert: (table: any) => ({
      values: (vals: any) => {
        const arr = Array.isArray(vals) ? vals : [vals];
        const inserted: any[] = [];
        for (const v of arr) {
          const id = v.id || `id-${crypto.randomUUID()}`;
          const record = { ...v, id, createdAt: new Date(), updatedAt: new Date() };
          store.notificationOutbox.set(id, record);
          inserted.push(record);
        }
        return {
          returning: async () => inserted,
        };
      },
    }),
  };

  return fakeDb;
}

describe("Integration: Notification Outbox, Worker & Delivery Lifecycle", () => {
  let fakeDb: any;
  let outboxService: NotificationOutboxService;
  let lineProvider: LineNotificationProvider;
  let worker: NotificationWorkerService;

  beforeEach(() => {
    fakeDb = createFakeNotificationDb();
    outboxService = new NotificationOutboxService(fakeDb);
    lineProvider = new LineNotificationProvider();
    worker = new NotificationWorkerService(lineProvider, fakeDb);

    // Setup initial user & LINE identity
    fakeDb._store.users.set("user-1", {
      id: "user-1",
      displayName: "Nut Thanapon",
    });
    fakeDb._store.authIdentities.set("auth-1", {
      id: "auth-1",
      userId: "user-1",
      provider: "line",
      providerUserId: "line-user-12345",
    });
  });

  test("5.4 Outbox Enqueue & Worker Delivery: successfully sends LINE push and marks SENT", async () => {
    // 1. Enqueue outbox job
    const created = await outboxService.enqueue({
      eventType: "BILL_CREATED",
      recipientUserId: "user-1",
      deduplicationKey: "BILL_CREATED:bill-1:user-1",
      payload: {
        billId: "bill-1",
        billTitle: "KBBQ Dinner",
        creatorId: "user-owner",
        creatorName: "Nut",
        participantId: "item-1",
        participantDebtAmount: "500.00",
        totalAmount: "1000.00",
        currency: "THB",
      },
    });

    expect(created).toBeDefined();
    expect(created.status).toBe("PENDING");

    // 2. Process batch with worker
    const processResult = await worker.processBatch();
    expect(processResult.processedCount).toBe(1);
    expect(processResult.successCount).toBe(1);

    // 3. Verify outbox is marked SENT
    const jobInDb = fakeDb._store.notificationOutbox.get(created.id);
    expect(jobInDb.status).toBe("SENT");
    expect(jobInDb.attempts).toBe(1);

    // 4. Verify LINE provider received message
    const sentMessages = lineProvider.getSentMessages();
    expect(sentMessages.length).toBe(1);
    expect(sentMessages[0].recipientId).toBe("line-user-12345");
    expect(sentMessages[0].text).toContain("KBBQ Dinner");
  });

  test("5.30 Retry Strategy: LINE API failure triggers retry backoff, then succeeds on retry", async () => {
    // Simulate LINE API failure for 1 attempt
    lineProvider.setSimulateFailure(true, 1);

    const created = await outboxService.enqueue({
      eventType: "PAYMENT_CONFIRMED",
      recipientUserId: "user-1",
      deduplicationKey: "PAYMENT_CONFIRMED:pay-1:user-1",
      payload: {
        billId: "bill-1",
        billTitle: "Lunch",
        paymentId: "pay-1",
        participantId: "item-1",
        payerId: "user-1",
        confirmerId: "user-owner",
        confirmerName: "Nut",
        amount: "200.00",
        currency: "THB",
        installmentNumber: 1,
        remainingDebt: "0.00",
        isFullyPaid: true,
      },
    });

    // 1. Worker attempt 1 -> Fails
    const res1 = await worker.processBatch();
    expect(res1.failedCount).toBe(1);

    let jobInDb = fakeDb._store.notificationOutbox.get(created.id);
    expect(jobInDb.status).toBe("PENDING"); // Pending next retry
    expect(jobInDb.attempts).toBe(1);
    expect(jobInDb.lastError).toContain("LINE_API_ERROR");

    // 2. Worker attempt 2 -> Succeeds
    const res2 = await worker.processBatch();
    expect(res2.successCount).toBe(1);

    jobInDb = fakeDb._store.notificationOutbox.get(created.id);
    expect(jobInDb.status).toBe("SENT");
    expect(jobInDb.attempts).toBe(2);
  });

  test("5.56 Maximum Retries: permanently fails after maxAttempts is reached", async () => {
    // Simulate continuous failure
    lineProvider.setSimulateFailure(true, 10);

    const created = await outboxService.enqueue({
      eventType: "PAYMENT_REJECTED",
      recipientUserId: "user-1",
      deduplicationKey: "PAYMENT_REJECTED:pay-2:user-1",
      payload: {
        billId: "bill-1",
        billTitle: "Lunch",
        paymentId: "pay-2",
        participantId: "item-1",
        payerId: "user-1",
        rejecterId: "user-owner",
        rejecterName: "Nut",
        amount: "200.00",
        currency: "THB",
        reason: "Fake slip",
      },
    });

    // Run 5 attempts
    for (let i = 0; i < 5; i++) {
      await worker.processBatch();
    }

    const jobInDb = fakeDb._store.notificationOutbox.get(created.id);
    expect(jobInDb.attempts).toBe(5);
    expect(jobInDb.status).toBe("FAILED");
    expect(jobInDb.failedAt).toBeDefined();
  });

  test("5.8 User Without LINE Identity: gracefully marked as SKIPPED without throwing error", async () => {
    // Clear LINE identity for user
    fakeDb._store.authIdentities.clear();

    const created = await outboxService.enqueue({
      eventType: "BILL_CREATED",
      recipientUserId: "user-1",
      deduplicationKey: "BILL_CREATED:bill-no-line:user-1",
      payload: {
        billId: "bill-2",
        billTitle: "Coffee",
        creatorId: "user-owner",
        creatorName: "Nut",
        participantId: "item-2",
        participantDebtAmount: "120.00",
        totalAmount: "120.00",
        currency: "THB",
      },
    });

    const res = await worker.processBatch();
    expect(res.skippedCount).toBe(1);

    const jobInDb = fakeDb._store.notificationOutbox.get(created.id);
    expect(jobInDb.status).toBe("SKIPPED");
    expect(jobInDb.lastError).toContain("NO_LINE_ID");
  });
});
