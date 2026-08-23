import { db } from "../../db";
import {
  notificationOutbox,
  notificationDeliveries,
  authIdentities,
} from "../../db/schema";
import { eq, and, lte, sql, or, lt } from "drizzle-orm";
import { NotificationProvider } from "./notification-provider.interface";
import { defaultFcmNotificationProvider } from "./fcm-notification.provider";
import { NotificationTemplateService } from "./notification-template.service";

export interface WorkerProcessResult {
  processedCount: number;
  successCount: number;
  failedCount: number;
  skippedCount: number;
}

export class NotificationWorkerService {
  private isRunning = false;
  private timer: any = null;

  constructor(
    private provider: NotificationProvider = defaultFcmNotificationProvider,
    private customDb: any = db,
    private leaseTimeoutMs: number = 5 * 60 * 1000 // 5 minutes lease timeout for crash recovery
  ) {}

  private get db() {
    return this.customDb;
  }

  /**
   * 5.30 Exponential backoff delay calculation
   * Attempt 1: 10 seconds
   * Attempt 2: 60 seconds (1 min)
   * Attempt 3: 300 seconds (5 min)
   * Attempt 4: 900 seconds (15 min)
   * Attempt 5: 1800 seconds (30 min)
   */
  static calculateNextAvailableAt(attemptNumber: number): Date {
    const delaysInSeconds = [0, 10, 60, 300, 900, 1800];
    const delay = delaysInSeconds[Math.min(attemptNumber, delaysInSeconds.length - 1)] || 1800;
    return new Date(Date.now() + delay * 1000);
  }

  /**
   * 5.39, 5.40, 5.41 Notification Worker Batch Processor
   * - Uses SELECT ... FOR UPDATE SKIP LOCKED (or transactional status flipping)
   * - Recovers stuck jobs where lockedAt < NOW() - leaseTimeout
   * - Dispatches formatted message via Provider
   * - Records delivery logs in notification_deliveries table
   */
  async processBatch(batchSize = 10): Promise<WorkerProcessResult> {
    const result: WorkerProcessResult = {
      processedCount: 0,
      successCount: 0,
      failedCount: 0,
      skippedCount: 0,
    };

    const now = new Date();
    const leaseExpirationThreshold = new Date(now.getTime() - this.leaseTimeoutMs);

    if (!this.db || typeof this.db.transaction !== "function") {
      return result;
    }

    // 1. Claim eligible jobs atomically using transaction with SKIP LOCKED
    const claimedJobs = await this.db.transaction(async (tx: any) => {
      // Find candidate jobs: (PENDING and availableAt <= now) OR (PROCESSING and lockedAt <= leaseExpirationThreshold)
      const eligible = await tx
        .select()
        .from(notificationOutbox)
        .where(
          and(
            or(
              and(
                eq(notificationOutbox.status, "PENDING"),
                lte(notificationOutbox.availableAt, now)
              ),
              and(
                eq(notificationOutbox.status, "PROCESSING"),
                lt(notificationOutbox.lockedAt, leaseExpirationThreshold)
              )
            ),
            lt(notificationOutbox.attempts, notificationOutbox.maxAttempts)
          )
        )
        .limit(batchSize)
        .for("update", { skipLocked: true });

      if (!eligible || eligible.length === 0) {
        return [];
      }

      // Mark claimed jobs as PROCESSING with lockedAt = now
      const ids = eligible.map((j: any) => j.id);
      for (const job of eligible) {
        await tx
          .update(notificationOutbox)
          .set({
            status: "PROCESSING",
            lockedAt: now,
            updatedAt: now,
          })
          .where(eq(notificationOutbox.id, job.id));
      }

      return eligible;
    });

    if (claimedJobs.length === 0) {
      return result;
    }

    result.processedCount = claimedJobs.length;

    // 2. Process each claimed notification sequentially
    for (const job of claimedJobs) {
      const attemptNumber = job.attempts + 1;

      try {
        // Resolve LINE identity from authIdentities
        const identity = await this.db.query.authIdentities.findFirst({
          where: and(
            eq(authIdentities.userId, job.recipientUserId),
            eq(authIdentities.provider, "line")
          ),
        });

        const recipientLineId = identity?.providerUserId || null;

        // Generate formatted message using template engine
        const formattedMsg = NotificationTemplateService.formatMessage(
          job.eventType,
          job.payload,
          "th"
        );

        // Send via provider
        const sendResult = await this.provider.send(
          job.recipientUserId,
          recipientLineId,
          formattedMsg
        );

        if (sendResult.skippedReason) {
          // User has no LINE ID linked -> Mark SKIPPED
          await this.db.transaction(async (tx: any) => {
            await tx
              .update(notificationOutbox)
              .set({
                status: "SKIPPED",
                attempts: attemptNumber,
                sentAt: new Date(),
                lastError: sendResult.skippedReason,
                lockedAt: null,
                updatedAt: new Date(),
              })
              .where(eq(notificationOutbox.id, job.id));

            await tx.insert(notificationDeliveries).values({
              notificationId: job.id,
              provider: this.provider.name,
              recipientLineId: null,
              status: "SKIPPED",
              attemptNumber,
              errorMessage: sendResult.skippedReason,
            });
          });

          result.skippedCount++;
        } else if (sendResult.success) {
          // Success -> Mark SENT
          await this.db.transaction(async (tx: any) => {
            await tx
              .update(notificationOutbox)
              .set({
                status: "SENT",
                attempts: attemptNumber,
                sentAt: new Date(),
                lastError: null,
                lockedAt: null,
                updatedAt: new Date(),
              })
              .where(eq(notificationOutbox.id, job.id));

            await tx.insert(notificationDeliveries).values({
              notificationId: job.id,
              provider: this.provider.name,
              recipientLineId,
              status: "SENT",
              attemptNumber,
              responsePayload: sendResult.responsePayload,
            });
          });

          result.successCount++;
        } else {
          // Delivery failed -> Check if retryable or permanently failed
          const isMaxAttemptsReached = attemptNumber >= job.maxAttempts;
          const nextStatus = isMaxAttemptsReached ? "FAILED" : "PENDING";
          const nextAvailableAt = NotificationWorkerService.calculateNextAvailableAt(attemptNumber);

          await this.db.transaction(async (tx: any) => {
            await tx
              .update(notificationOutbox)
              .set({
                status: nextStatus,
                attempts: attemptNumber,
                failedAt: isMaxAttemptsReached ? new Date() : null,
                availableAt: nextAvailableAt,
                lastError: sendResult.error || "Unknown delivery failure",
                lockedAt: null,
                updatedAt: new Date(),
              })
              .where(eq(notificationOutbox.id, job.id));

            await tx.insert(notificationDeliveries).values({
              notificationId: job.id,
              provider: this.provider.name,
              recipientLineId,
              status: "FAILED",
              attemptNumber,
              errorMessage: sendResult.error,
            });
          });

          result.failedCount++;
        }
      } catch (err: any) {
        // Unexpected processing error -> mark retryable or failed
        const isMaxAttemptsReached = attemptNumber >= job.maxAttempts;
        const nextStatus = isMaxAttemptsReached ? "FAILED" : "PENDING";
        const nextAvailableAt = NotificationWorkerService.calculateNextAvailableAt(attemptNumber);

        await this.db.transaction(async (tx: any) => {
          await tx
            .update(notificationOutbox)
            .set({
              status: nextStatus,
              attempts: attemptNumber,
              failedAt: isMaxAttemptsReached ? new Date() : null,
              availableAt: nextAvailableAt,
              lastError: err?.message || String(err),
              lockedAt: null,
              updatedAt: new Date(),
            })
            .where(eq(notificationOutbox.id, job.id));

          await tx.insert(notificationDeliveries).values({
            notificationId: job.id,
            provider: this.provider.name,
            status: "FAILED",
            attemptNumber,
            errorMessage: err?.message || String(err),
          });
        });

        result.failedCount++;
      }
    }

    return result;
  }

  /**
   * Start polling loop for background processing
   */
  start(intervalMs = 3000) {
    if (this.isRunning) return;
    this.isRunning = true;

    const loop = async () => {
      if (!this.isRunning) return;
      try {
        await this.processBatch();
      } catch (err) {
        console.error("[NotificationWorkerService] Loop error:", err);
      } finally {
        if (this.isRunning) {
          this.timer = setTimeout(loop, intervalMs);
        }
      }
    };

    this.timer = setTimeout(loop, 100);
  }

  stop() {
    this.isRunning = false;
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }
}

export const defaultNotificationWorkerService = new NotificationWorkerService();
