import { AdminRepository } from "./admin.repository";
import { defaultFcmNotificationProvider } from "../notifications/fcm-notification.provider";
import { db } from "../../db";
import { deviceTokens, notificationOutbox } from "../../db/schema";
import { eq } from "drizzle-orm";
import crypto from "crypto";

export class AdminService {
  private repo: AdminRepository;

  constructor(repo?: AdminRepository) {
    this.repo = repo || new AdminRepository();
  }

  // ── Dashboard ─────────────────────────────────────────────────────

  async getDashboardStats(adminId: string) {
    return this.repo.getDashboardStats();
  }

  // ── Transactions ──────────────────────────────────────────────────

  async getTransactions(
    adminId: string,
    filters: {
      userId?: string;
      type?: string;
      dateFrom?: string;
      dateTo?: string;
    },
    page = 1,
    limit = 20
  ) {
    return this.repo.getTransactions(
      {
        userId: filters.userId,
        type: filters.type,
        dateFrom: filters.dateFrom ? new Date(filters.dateFrom) : undefined,
        dateTo: filters.dateTo ? new Date(filters.dateTo) : undefined,
      },
      { page, limit }
    );
  }

  // ── Activity Logs ─────────────────────────────────────────────────

  async getActivityLogs(
    adminId: string,
    filters: {
      userId?: string;
      action?: string;
      dateFrom?: string;
      dateTo?: string;
    },
    page = 1,
    limit = 20
  ) {
    return this.repo.getActivityLogs(
      {
        userId: filters.userId,
        action: filters.action,
        dateFrom: filters.dateFrom ? new Date(filters.dateFrom) : undefined,
        dateTo: filters.dateTo ? new Date(filters.dateTo) : undefined,
      },
      { page, limit }
    );
  }

  async purgeOldActivityLogs(adminId: string) {
    const oneMonthAgo = new Date();
    oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1);

    const result = await this.repo.deleteOldActivityLogs(oneMonthAgo);

    await this.repo.logAdminAction({
      adminId,
      actionType: "view_logs",
      metadata: { action: "purge_old_logs", olderThan: oneMonthAgo.toISOString() },
    });

    return result;
  }

  async clearAllActivityLogs(adminId: string) {
    const result = await this.repo.clearAllActivityLogs();
    await this.repo.logAdminAction({
      adminId,
      actionType: "view_logs",
      metadata: { action: "clear_all_activity_logs" },
    });
    return result;
  }

  async deleteActivityLog(adminId: string, id: string) {
    const result = await this.repo.deleteActivityLogById(id);
    return result;
  }

  // ── Suspicious Activity ───────────────────────────────────────────

  async getSuspiciousLogs(
    adminId: string,
    filters: {
      userId?: string;
      type?: string;
      dateFrom?: string;
      dateTo?: string;
    },
    page = 1,
    limit = 20
  ) {
    const result = await this.repo.getSuspiciousLogs(
      {
        userId: filters.userId,
        type: filters.type,
        dateFrom: filters.dateFrom ? new Date(filters.dateFrom) : undefined,
        dateTo: filters.dateTo ? new Date(filters.dateTo) : undefined,
      },
      { page, limit }
    );

    return result;
  }

  async flagSuspiciousActivity(
    adminId: string,
    data: {
      userId?: string;
      type: string;
      description: string;
      metadata?: any;
    }
  ) {
    const log = await this.repo.createSuspiciousLog(data);

    await this.repo.logAdminAction({
      adminId,
      actionType: "flag_suspicious",
      targetUserId: data.userId,
      reason: data.description,
      metadata: { suspiciousLogId: log.id, type: data.type },
    });

    return log;
  }

  async deleteSuspiciousLog(adminId: string, id: string) {
    const result = await this.repo.deleteSuspiciousLogById(id);
    await this.repo.logAdminAction({
      adminId,
      actionType: "flag_suspicious",
      metadata: { action: "delete_suspicious_log", suspiciousLogId: id },
    });
    return result;
  }

  async clearAllSuspiciousLogs(adminId: string) {
    const result = await this.repo.clearAllSuspiciousLogs();
    await this.repo.logAdminAction({
      adminId,
      actionType: "flag_suspicious",
      metadata: { action: "clear_all_suspicious_logs" },
    });
    return result;
  }

  // ── User Management ───────────────────────────────────────────────

  async getUsers(
    filters: { search?: string; accountStatus?: string; role?: string },
    page = 1,
    limit = 20
  ) {
    return this.repo.getUsers(filters, { page, limit });
  }

  async getUserDetail(userId: string) {
    const user = await this.repo.getUserById(userId);
    if (!user) throw new Error("USER_NOT_FOUND");
    return user;
  }

  async suspendAccount(adminId: string, targetUserId: string, reason: string, durationDays?: number) {
    const target = await this.repo.getUserById(targetUserId);
    if (!target) throw new Error("USER_NOT_FOUND");
    if (target.role === "developer") throw new Error("CANNOT_SUSPEND_DEVELOPER");

    let suspendedUntil: Date | undefined;
    if (durationDays) {
      suspendedUntil = new Date();
      suspendedUntil.setDate(suspendedUntil.getDate() + durationDays);
    }

    const updated = await this.repo.updateUserStatus(targetUserId, "suspended", suspendedUntil);

    await this.repo.logAdminAction({
      adminId,
      actionType: "suspend_account",
      targetUserId,
      reason,
      metadata: { durationDays, suspendedUntil: suspendedUntil?.toISOString() },
    });

    return updated;
  }

  async banAccount(adminId: string, targetUserId: string, reason: string) {
    const target = await this.repo.getUserById(targetUserId);
    if (!target) throw new Error("USER_NOT_FOUND");
    if (target.role === "developer") throw new Error("CANNOT_BAN_DEVELOPER");

    const updated = await this.repo.updateUserStatus(targetUserId, "banned");

    await this.repo.logAdminAction({
      adminId,
      actionType: "ban_account",
      targetUserId,
      reason,
    });

    return updated;
  }

  async unsuspendAccount(adminId: string, targetUserId: string, reason: string) {
    const target = await this.repo.getUserById(targetUserId);
    if (!target) throw new Error("USER_NOT_FOUND");

    const updated = await this.repo.updateUserStatus(targetUserId, "active");

    await this.repo.logAdminAction({
      adminId,
      actionType: "unsuspend_account",
      targetUserId,
      reason,
    });

    return updated;
  }

  // ── Disputes ──────────────────────────────────────────────────────

  async getDisputes(
    adminId: string,
    filters: { status?: string; dateFrom?: string; dateTo?: string },
    page = 1,
    limit = 20
  ) {
    const result = await this.repo.getDisputes(
      {
        status: filters.status,
        dateFrom: filters.dateFrom ? new Date(filters.dateFrom) : undefined,
        dateTo: filters.dateTo ? new Date(filters.dateTo) : undefined,
      },
      { page, limit }
    );

    return result;
  }

  async getDisputeDetail(adminId: string, disputeId: string) {
    const dispute = await this.repo.getDisputeById(disputeId);
    if (!dispute) throw new Error("DISPUTE_NOT_FOUND");

    const editHistory = await this.repo.getEditLogsByBill(dispute.billItem.billId);

    return { dispute, editHistory };
  }

  async resolveDispute(
    adminId: string,
    disputeId: string,
    resolution: {
      status: "resolved_paid" | "resolved_written_off" | "resolved_rejected";
      note: string;
    }
  ) {
    const dispute = await this.repo.getDisputeById(disputeId);
    if (!dispute) throw new Error("DISPUTE_NOT_FOUND");

    if (dispute.status !== "open" && dispute.status !== "under_review") {
      throw new Error("DISPUTE_ALREADY_RESOLVED");
    }

    const resolved = await this.repo.resolveDispute(
      disputeId,
      adminId,
      resolution.status,
      resolution.note
    );

    await this.repo.logAdminAction({
      adminId,
      actionType: "resolve_dispute",
      metadata: {
        disputeId,
        resolution: resolution.status,
        note: resolution.note,
      },
    });

    return resolved;
  }

  async markDisputeUnderReview(adminId: string, disputeId: string) {
    const dispute = await this.repo.getDisputeById(disputeId);
    if (!dispute) throw new Error("DISPUTE_NOT_FOUND");
    if (dispute.status !== "open") throw new Error("DISPUTE_NOT_OPEN");

    return this.repo.updateDisputeStatus(disputeId, "under_review");
  }

  // ── Admin Audit Logs ──────────────────────────────────────────────

  async getAdminAuditLogs(page = 1, limit = 20, adminId?: string) {
    return this.repo.getAdminAuditLogs({ page, limit }, adminId);
  }

  async clearAllAuditLogs() {
    return this.repo.clearAllAdminActionLogs();
  }

  // ── Rewards Catalog & Redemptions ─────────────────────────────────

  async getRewardItems(adminId: string) {
    return this.repo.getRewardItems();
  }

  async createRewardItem(
    adminId: string,
    data: {
      title: string;
      description?: string;
      pointsCost: number;
      category?: string;
      imageUrl?: string;
      inStock: number;
      isActive?: boolean;
    }
  ) {
    const item = await this.repo.createRewardItem(data);
    await this.repo.logAdminAction({
      adminId,
      actionType: "view_logs",
      metadata: { action: "create_reward_item", itemId: item.id },
    });
    return item;
  }

  async updateRewardItem(
    adminId: string,
    id: string,
    data: Partial<{
      title: string;
      description: string;
      pointsCost: number;
      category: string;
      imageUrl: string;
      inStock: number;
      isActive: boolean;
    }>
  ) {
    const item = await this.repo.updateRewardItem(id, data);
    await this.repo.logAdminAction({
      adminId,
      actionType: "view_logs",
      metadata: { action: "update_reward_item", itemId: id },
    });
    return item;
  }

  async deleteRewardItem(adminId: string, id: string) {
    const result = await this.repo.deleteRewardItem(id);
    await this.repo.logAdminAction({
      adminId,
      actionType: "view_logs",
      metadata: { action: "delete_reward_item", itemId: id },
    });
    return result;
  }

  async getRewardRedemptions(adminId: string, status?: string, page = 1, limit = 20) {
    return this.repo.getRewardRedemptions({ page, limit }, status);
  }

  async updateRedemptionStatus(
    adminId: string,
    id: string,
    status: "pending_delivery" | "shipped" | "delivered" | "cancelled",
    trackingNumber?: string
  ) {
    const result = await this.repo.updateRedemptionStatus(id, status, trackingNumber);
    await this.repo.logAdminAction({
      adminId,
      actionType: "view_logs",
      metadata: { action: "update_redemption_status", redemptionId: id, status, trackingNumber },
    });
    return result;
  }

  // ── Notification Outbox ───────────────────────────────────────────

  async getNotificationOutbox(
    adminId: string,
    status?: string,
    eventType?: string,
    page = 1,
    limit = 20
  ) {
    return this.repo.getNotificationOutbox({ page, limit }, status, eventType);
  }

  async retryNotification(adminId: string, id: string) {
    const result = await this.repo.retryNotification(id);
    await this.repo.logAdminAction({
      adminId,
      actionType: "view_logs",
      metadata: { action: "retry_notification", notificationId: id },
    });
    return result;
  }

  async sendFcmNotification(
    adminId: string,
    params: {
      target: "all" | "user" | "token";
      userId?: string;
      deviceToken?: string;
      title: string;
      body: string;
      dataPayload?: any;
    }
  ) {
    let sentCount = 0;
    let failedCount = 0;
    const errors: string[] = [];

    if (params.target === "user" && params.userId) {
      const userTokens = await db.query.deviceTokens.findMany({
        where: eq(deviceTokens.userId, params.userId),
      });

      // Record in notification outbox
      const dedupKey = `admin-manual-${params.userId}-${Date.now()}`;
      await db.insert(notificationOutbox).values({
        eventType: "ADMIN_BROADCAST",
        recipientUserId: params.userId,
        channel: "fcm",
        payload: {
          title: params.title,
          body: params.body,
          data: params.dataPayload || {},
        },
        deduplicationKey: dedupKey,
        status: "SENT",
        sentAt: new Date(),
      });

      const res = await defaultFcmNotificationProvider.send(
        params.userId,
        null,
        {
          title: params.title,
          body: params.body,
        }
      );

      if (res.success) {
        sentCount = userTokens.length || 1;
      } else {
        failedCount = 1;
        if (res.error) errors.push(res.error);
        if (res.skippedReason) errors.push(res.skippedReason);
      }
    } else if (params.target === "token" && params.deviceToken) {
      const res = await defaultFcmNotificationProvider.send(
        "direct-token-target",
        params.deviceToken,
        {
          title: params.title,
          body: params.body,
        }
      );

      if (res.success) {
        sentCount = 1;
      } else {
        failedCount = 1;
        if (res.error) errors.push(res.error);
      }
    } else if (params.target === "all") {
      const allTokens = await db.query.deviceTokens.findMany();
      const uniqueUsers = Array.from(new Set(allTokens.map((t) => t.userId)));

      for (const uid of uniqueUsers) {
        try {
          const res = await defaultFcmNotificationProvider.send(
            uid,
            null,
            {
              title: params.title,
              body: params.body,
            }
          );
          if (res.success) sentCount++;
          else failedCount++;
        } catch (err: any) {
          failedCount++;
          errors.push(err.message);
        }
      }
    }

    await this.repo.logAdminAction({
      adminId,
      actionType: "view_logs",
      metadata: {
        action: "send_fcm_notification",
        target: params.target,
        title: params.title,
        sentCount,
        failedCount,
      },
    });

    return {
      sentCount,
      failedCount,
      errors: errors.slice(0, 5),
    };
  }

  // ── Security Events ───────────────────────────────────────────────

  async getSecurityEvents(
    adminId: string,
    userId?: string,
    event?: string,
    page = 1,
    limit = 20
  ) {
    return this.repo.getSecurityEvents({ page, limit }, userId, event);
  }

  // ── Analytics ─────────────────────────────────────────────────────

  async getAnalytics(adminId: string) {
    return this.repo.getSystemAnalytics();
  }

  async getFcmUsers(adminId: string, search?: string) {
    return this.repo.getUsersWithFcm(search);
  }
}
