import { db } from "../../db";
import { billItems, bills, users } from "../../db/schema";
import { eq, and, sql, notInArray } from "drizzle-orm";
import { NotificationOutboxService, defaultNotificationOutboxService } from "./notification-outbox.service";
import { DebtWeeklyReminderPayload } from "./notification.types";

export interface SchedulerRunResult {
  eligibleCount: number;
  enqueuedCount: number;
  skippedCount: number;
  weekKey: string;
}

export class DebtReminderSchedulerService {
  constructor(
    private outboxService: NotificationOutboxService = defaultNotificationOutboxService,
    private customDb: any = db,
    private timezone: string = "Asia/Bangkok"
  ) {}

  private get db() {
    return this.customDb;
  }

  /**
   * 5.42 & 5.19 Compute deterministic ISO Week Key for the target timezone (Asia/Bangkok)
   * Example: "2026-W34"
   */
  static getWeekKey(date = new Date(), timezone = "Asia/Bangkok"): string {
    // Format in target timezone
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });

    const parts = formatter.formatToParts(date);
    const year = parseInt(parts.find((p) => p.type === "year")!.value, 10);
    const month = parseInt(parts.find((p) => p.type === "month")!.value, 10) - 1;
    const day = parseInt(parts.find((p) => p.type === "day")!.value, 10);

    const tzDate = new Date(Date.UTC(year, month, day));

    // ISO week date calculation
    const dayNum = tzDate.getUTCDay() || 7;
    tzDate.setUTCDate(tzDate.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(tzDate.getUTCFullYear(), 0, 1));
    const weekNo = Math.ceil(((tzDate.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);

    return `${tzDate.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
  }

  /**
   * 5.17 Reminder Eligibility Check
   * Eligible ONLY if:
   * 1. Bill is not cancelled
   * 2. Participant status != 'paid' and != 'written_off'
   * 3. Remaining debt (currentAmount - amountPaid - amountWrittenOff) > 0
   */
  static isEligible(item: {
    status: string;
    originalAmount: string;
    currentAmount: string;
    amountPaid: string;
    amountWrittenOff: string;
    billCancelledAt?: Date | null;
  }): { eligible: boolean; remainingDebt: string } {
    if (item.billCancelledAt) {
      return { eligible: false, remainingDebt: "0.00" };
    }

    if (item.status === "paid" || item.status === "written_off") {
      return { eligible: false, remainingDebt: "0.00" };
    }

    const currentCents = Math.round(Number(item.currentAmount) * 100);
    const paidCents = Math.round(Number(item.amountPaid) * 100);
    const writtenOffCents = Math.round(Number(item.amountWrittenOff) * 100);

    const remainingCents = Math.max(0, currentCents - paidCents - writtenOffCents);
    const remainingDebt = (remainingCents / 100).toFixed(2);

    return {
      eligible: remainingCents > 0,
      remainingDebt,
    };
  }

  /**
   * 5.16, 5.18, 5.19, 5.20 Run Weekly Reminder Scheduler
   * - Queries outstanding debts
   * - Filters by eligibility rules
   * - Deduplicates atomically via DEBT_WEEKLY_REMINDER:{billItemId}:{weekKey}
   */
  async runWeeklyReminderJob(now = new Date()): Promise<SchedulerRunResult> {
    const weekKey = DebtReminderSchedulerService.getWeekKey(now, this.timezone);
    const result: SchedulerRunResult = {
      eligibleCount: 0,
      enqueuedCount: 0,
      skippedCount: 0,
      weekKey,
    };

    // Query active bill items where status not in ('paid', 'written_off')
    const candidateItems = await this.db.query.billItems.findMany({
      with: {
        bill: true,
        debtor: true,
      },
    });

    for (const item of candidateItems) {
      const { eligible, remainingDebt } = DebtReminderSchedulerService.isEligible({
        status: item.status,
        originalAmount: item.originalAmount,
        currentAmount: item.currentAmount,
        amountPaid: item.amountPaid,
        amountWrittenOff: item.amountWrittenOff,
        billCancelledAt: item.bill?.cancelledAt,
      });

      if (!eligible) {
        continue;
      }

      result.eligibleCount++;

      const deduplicationKey = `DEBT_WEEKLY_REMINDER:${item.id}:${weekKey}`;

      const payload: DebtWeeklyReminderPayload = {
        billId: item.billId,
        billTitle: item.bill?.title || "Bill",
        billItemId: item.id,
        debtorId: item.debtorId,
        originalDebt: Number(item.originalAmount).toFixed(2),
        remainingDebt,
        amountPaid: Number(item.amountPaid).toFixed(2),
        amountWrittenOff: Number(item.amountWrittenOff).toFixed(2),
        currency: item.bill?.currency || "THB",
        weekKey,
      };

      try {
        const enqueued = await this.outboxService.enqueue({
          eventType: "DEBT_WEEKLY_REMINDER",
          recipientUserId: item.debtorId,
          payload,
          deduplicationKey,
          availableAt: now,
        });

        if (enqueued?.isNew) {
          result.enqueuedCount++;
        } else {
          result.skippedCount++;
        }
      } catch (err: any) {
        // Duplicate key or constraint violation -> already enqueued for this week
        result.skippedCount++;
      }
    }

    return result;
  }
}

export const defaultDebtReminderSchedulerService = new DebtReminderSchedulerService();
