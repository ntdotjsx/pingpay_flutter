import { describe, test, expect } from "bun:test";
import { DebtReminderSchedulerService } from "../../../src/modules/notifications/debt-reminder-scheduler.service";
import { NotificationWorkerService } from "../../../src/modules/notifications/notification-worker.service";

describe("Unit: Scheduler Eligibility, Timezone Week Key & Worker Retry Calculations", () => {
  test("5.42 & 5.19 Timezone Asia/Bangkok calculates consistent ISO week keys", () => {
    // 2026-08-18 is a Tuesday in Week 34
    const d1 = new Date("2026-08-18T10:00:00Z");
    const weekKey1 = DebtReminderSchedulerService.getWeekKey(d1, "Asia/Bangkok");
    expect(weekKey1).toBe("2026-W34");

    // Advance 7 days -> Week 35
    const d2 = new Date("2026-08-25T10:00:00Z");
    const weekKey2 = DebtReminderSchedulerService.getWeekKey(d2, "Asia/Bangkok");
    expect(weekKey2).toBe("2026-W35");
  });

  test("5.17 Eligibility: Active debt with outstanding > 0 is eligible", () => {
    const res = DebtReminderSchedulerService.isEligible({
      status: "unpaid",
      originalAmount: "1000.00",
      currentAmount: "1000.00",
      amountPaid: "0.00",
      amountWrittenOff: "0.00",
    });
    expect(res.eligible).toBe(true);
    expect(res.remainingDebt).toBe("1000.00");
  });

  test("5.23 Eligibility: Fully paid debt (amountPaid >= currentAmount) is NOT eligible", () => {
    const res = DebtReminderSchedulerService.isEligible({
      status: "paid",
      originalAmount: "1000.00",
      currentAmount: "1000.00",
      amountPaid: "1000.00",
      amountWrittenOff: "0.00",
    });
    expect(res.eligible).toBe(false);
    expect(res.remainingDebt).toBe("0.00");
  });

  test("5.24 Eligibility: Fully written-off debt is NOT eligible", () => {
    const res = DebtReminderSchedulerService.isEligible({
      status: "written_off",
      originalAmount: "500.00",
      currentAmount: "500.00",
      amountPaid: "0.00",
      amountWrittenOff: "500.00",
    });
    expect(res.eligible).toBe(false);
    expect(res.remainingDebt).toBe("0.00");
  });

  test("5.25 Eligibility: Partial payment + partial write-off with remaining > 0 remains eligible", () => {
    const res = DebtReminderSchedulerService.isEligible({
      status: "partially_paid",
      originalAmount: "1000.00",
      currentAmount: "1000.00",
      amountPaid: "300.00",
      amountWrittenOff: "200.00",
    });
    expect(res.eligible).toBe(true);
    expect(res.remainingDebt).toBe("500.00");
  });

  test("5.30 Worker Exponential Backoff: delay increases progressively across attempts", () => {
    const now = Date.now();
    const t1 = NotificationWorkerService.calculateNextAvailableAt(1).getTime();
    const t2 = NotificationWorkerService.calculateNextAvailableAt(2).getTime();
    const t3 = NotificationWorkerService.calculateNextAvailableAt(3).getTime();
    const t4 = NotificationWorkerService.calculateNextAvailableAt(4).getTime();

    // Attempt 1 delay ~10s
    expect(t1 - now).toBeGreaterThanOrEqual(9000);
    // Attempt 2 delay ~60s
    expect(t2 - now).toBeGreaterThanOrEqual(58000);
    // Attempt 3 delay ~300s
    expect(t3 - now).toBeGreaterThanOrEqual(295000);
    // Attempt 4 delay ~900s
    expect(t4 - now).toBeGreaterThanOrEqual(895000);
  });
});
