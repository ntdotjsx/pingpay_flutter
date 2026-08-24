import { describe, it, expect } from "bun:test";
import { AdminService } from "../../../src/modules/admin/admin.service";
import type { AdminRepository } from "../../../src/modules/admin/admin.repository";

describe("Admin Service Explorer & DB Stats", () => {
  it("should get bills list with filters and pagination", async () => {
    const mockRepo: Partial<AdminRepository> = {
      getBills: async (filters, pagination) => {
        return {
          rows: [
            {
              id: "bill-1",
              title: "Dinner Party",
              totalAmount: "1200.00",
              status: "partially_paid",
              createdAt: new Date(),
              owner: { displayName: "Alice", userCode: "USR-001" },
              items: [
                {
                  id: "item-1",
                  debtorId: "user-2",
                  currentAmount: "600.00",
                  isAcknowledged: true,
                  status: "unpaid",
                  debtor: { displayName: "Bob", userCode: "USR-002" },
                },
              ],
            },
          ] as any,
          total: 1,
        };
      },
    };

    const service = new AdminService(mockRepo as AdminRepository);
    const res = await service.getBills("admin-1", { status: "partially_paid" }, 1, 20);

    expect(res.total).toBe(1);
    expect(res.rows.length).toBe(1);
    expect(res.rows[0].title).toBe("Dinner Party");
    expect(res.rows[0].items[0].isAcknowledged).toBe(true);
  });

  it("should get payment detail with EasySlip / SlipOK verifications", async () => {
    const mockRepo: Partial<AdminRepository> = {
      getPaymentById: async (paymentId) => {
        if (paymentId === "pay-1") {
          return {
            id: "pay-1",
            amount: "600.00",
            status: "confirmed",
            channel: "promptpay_qr",
            method: "full",
            slipImageUrl: "https://storage.pingpay.app/slips/slip1.jpg",
            verifications: [
              {
                id: "v-1",
                provider: "easyslip",
                status: "success",
                providerReference: "ES-12345",
                verifiedAmount: "600.00",
                senderInfo: { name: "Bob", bank: "KBANK" },
                receiverInfo: { name: "Alice", bank: "SCB" },
              },
            ],
          } as any;
        }
        return null;
      },
    };

    const service = new AdminService(mockRepo as AdminRepository);
    const payment = await service.getPaymentDetail("admin-1", "pay-1");

    expect(payment.id).toBe("pay-1");
    expect(payment.verifications.length).toBe(1);
    expect(payment.verifications[0].provider).toBe("easyslip");
    expect(payment.verifications[0].status).toBe("success");
  });

  it("should get live database row count metrics across all tables", async () => {
    const mockRepo: Partial<AdminRepository> = {
      getDatabaseStats: async () => {
        return {
          users: 42,
          bills: 10,
          billItems: 25,
          payments: 18,
          paymentVerifications: 18,
          financialTransactions: 30,
          disputes: 2,
          friendships: 15,
          editLogs: 8,
          activityLogs: 120,
          suspiciousActivityLogs: 3,
          adminActionLogs: 45,
          notificationOutbox: 50,
          notificationDeliveries: 48,
          deviceTokens: 40,
          securityEvents: 4,
          rewardItems: 5,
          rewardRedemptions: 2,
          consentRecords: 42,
          authIdentities: 42,
          authSessions: 12,
        };
      },
    };

    const service = new AdminService(mockRepo as AdminRepository);
    const dbStats = await service.getDatabaseStats("admin-1");

    expect(dbStats.users).toBe(42);
    expect(dbStats.bills).toBe(10);
    expect(dbStats.paymentVerifications).toBe(18);
    expect(dbStats.notificationOutbox).toBe(50);
  });
});
