import { db } from "../../db";
import {
  financialTransactions,
  activityLogs,
  suspiciousActivityLogs,
  adminActionLogs,
  disputes,
  users,
  bills,
  billItems,
  payments,
  paymentVerifications,
  editLogs,
  rewardItems,
  rewardRedemptions,
  notificationOutbox,
  notificationDeliveries,
  securityEvents,
  deviceTokens,
  friendships,
  consentRecords,
  userCredentials,
  authIdentities,
  authSessions,
} from "../../db/schema";
import { eq, and, gte, lte, desc, sql, ilike, or, asc } from "drizzle-orm";

export interface PaginationParams {
  page: number;
  limit: number;
}

export interface BillFilters {
  ownerId?: string;
  status?: string;
  search?: string;
  dateFrom?: Date;
  dateTo?: Date;
}

export interface PaymentFilters {
  payerId?: string;
  status?: string;
  channel?: string;
  method?: string;
  dateFrom?: Date;
  dateTo?: Date;
}

export interface TransactionFilters {
  userId?: string;
  type?: string;
  dateFrom?: Date;
  dateTo?: Date;
}

export interface ActivityLogFilters {
  userId?: string;
  action?: string;
  dateFrom?: Date;
  dateTo?: Date;
}

export interface SuspiciousLogFilters {
  userId?: string;
  type?: string;
  dateFrom?: Date;
  dateTo?: Date;
}

export interface DisputeFilters {
  status?: string;
  dateFrom?: Date;
  dateTo?: Date;
}

export interface UserFilters {
  search?: string;
  accountStatus?: string;
  role?: string;
}

export class AdminRepository {
  // ── Transactions ──────────────────────────────────────────────────

  async getTransactions(filters: TransactionFilters, pagination: PaginationParams) {
    const conditions: any[] = [];

    if (filters.userId) {
      conditions.push(eq(financialTransactions.createdById, filters.userId));
    }
    if (filters.type) {
      conditions.push(eq(financialTransactions.type, filters.type as any));
    }
    if (filters.dateFrom) {
      conditions.push(gte(financialTransactions.createdAt, filters.dateFrom));
    }
    if (filters.dateTo) {
      conditions.push(lte(financialTransactions.createdAt, filters.dateTo));
    }

    const where = conditions.length > 0 ? and(...conditions) : undefined;

    const [rows, countResult] = await Promise.all([
      db
        .select({
          id: financialTransactions.id,
          billId: financialTransactions.billId,
          billItemId: financialTransactions.billItemId,
          type: financialTransactions.type,
          amount: financialTransactions.amount,
          currency: financialTransactions.currency,
          referenceId: financialTransactions.referenceId,
          createdById: financialTransactions.createdById,
          createdAt: financialTransactions.createdAt,
          metadata: financialTransactions.metadata,
          creatorName: users.displayName,
          creatorCode: users.userCode,
          billTitle: bills.title,
        })
        .from(financialTransactions)
        .leftJoin(users, eq(financialTransactions.createdById, users.id))
        .leftJoin(bills, eq(financialTransactions.billId, bills.id))
        .where(where)
        .orderBy(desc(financialTransactions.createdAt))
        .limit(pagination.limit)
        .offset((pagination.page - 1) * pagination.limit),
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(financialTransactions)
        .leftJoin(bills, eq(financialTransactions.billId, bills.id))
        .where(where),
    ]);

    return { rows, total: countResult[0]?.count ?? 0 };
  }

  // ── Activity Logs ─────────────────────────────────────────────────

  async getActivityLogs(filters: ActivityLogFilters, pagination: PaginationParams) {
    const conditions: any[] = [];

    if (filters.userId) {
      conditions.push(eq(activityLogs.userId, filters.userId));
    }
    if (filters.action) {
      conditions.push(eq(activityLogs.action, filters.action));
    }
    if (filters.dateFrom) {
      conditions.push(gte(activityLogs.createdAt, filters.dateFrom));
    }
    if (filters.dateTo) {
      conditions.push(lte(activityLogs.createdAt, filters.dateTo));
    }

    const where = conditions.length > 0 ? and(...conditions) : undefined;

    const [rows, countResult] = await Promise.all([
      db
        .select({
          id: activityLogs.id,
          userId: activityLogs.userId,
          action: activityLogs.action,
          metadata: activityLogs.metadata,
          createdAt: activityLogs.createdAt,
          userName: users.displayName,
          userCode: users.userCode,
        })
        .from(activityLogs)
        .leftJoin(users, eq(activityLogs.userId, users.id))
        .where(where)
        .orderBy(desc(activityLogs.createdAt))
        .limit(pagination.limit)
        .offset((pagination.page - 1) * pagination.limit),
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(activityLogs)
        .where(where),
    ]);

    return { rows, total: countResult[0]?.count ?? 0 };
  }

  async deleteOldActivityLogs(olderThan: Date) {
    return db
      .delete(activityLogs)
      .where(lte(activityLogs.createdAt, olderThan));
  }

  async clearAllActivityLogs() {
    return db.delete(activityLogs);
  }

  async deleteActivityLogById(id: string) {
    return db.delete(activityLogs).where(eq(activityLogs.id, id));
  }

  // ── Suspicious Activity Logs ──────────────────────────────────────

  async getSuspiciousLogs(filters: SuspiciousLogFilters, pagination: PaginationParams) {
    const conditions: any[] = [];

    if (filters.userId) {
      conditions.push(eq(suspiciousActivityLogs.userId, filters.userId));
    }
    if (filters.type) {
      conditions.push(eq(suspiciousActivityLogs.type, filters.type));
    }
    if (filters.dateFrom) {
      conditions.push(gte(suspiciousActivityLogs.createdAt, filters.dateFrom));
    }
    if (filters.dateTo) {
      conditions.push(lte(suspiciousActivityLogs.createdAt, filters.dateTo));
    }

    const where = conditions.length > 0 ? and(...conditions) : undefined;

    const [rows, countResult] = await Promise.all([
      db
        .select({
          id: suspiciousActivityLogs.id,
          userId: suspiciousActivityLogs.userId,
          type: suspiciousActivityLogs.type,
          description: suspiciousActivityLogs.description,
          metadata: suspiciousActivityLogs.metadata,
          createdAt: suspiciousActivityLogs.createdAt,
          userName: users.displayName,
          userCode: users.userCode,
        })
        .from(suspiciousActivityLogs)
        .leftJoin(users, eq(suspiciousActivityLogs.userId, users.id))
        .where(where)
        .orderBy(desc(suspiciousActivityLogs.createdAt))
        .limit(pagination.limit)
        .offset((pagination.page - 1) * pagination.limit),
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(suspiciousActivityLogs)
        .where(where),
    ]);

    return { rows, total: countResult[0]?.count ?? 0 };
  }

  async createSuspiciousLog(data: {
    userId?: string;
    type: string;
    description: string;
    metadata?: any;
  }) {
    const [row] = await db
      .insert(suspiciousActivityLogs)
      .values(data)
      .returning();
    return row;
  }

  async deleteSuspiciousLogById(id: string) {
    return db.delete(suspiciousActivityLogs).where(eq(suspiciousActivityLogs.id, id));
  }

  async clearAllSuspiciousLogs() {
    return db.delete(suspiciousActivityLogs);
  }

  // ── Users ─────────────────────────────────────────────────────────

  async getUsers(filters: UserFilters, pagination: PaginationParams) {
    const conditions: any[] = [];

    if (filters.search) {
      conditions.push(
        or(
          ilike(users.displayName, `%${filters.search}%`),
          ilike(users.fullName, `%${filters.search}%`),
          ilike(users.userCode, `%${filters.search}%`),
          ilike(users.phoneNumber, `%${filters.search}%`)
        )
      );
    }
    if (filters.accountStatus) {
      conditions.push(eq(users.accountStatus, filters.accountStatus as any));
    }
    if (filters.role) {
      conditions.push(eq(users.role, filters.role as any));
    }

    const where = conditions.length > 0 ? and(...conditions) : undefined;

    const [rows, countResult] = await Promise.all([
      db
        .select()
        .from(users)
        .where(where)
        .orderBy(desc(users.createdAt))
        .limit(pagination.limit)
        .offset((pagination.page - 1) * pagination.limit),
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(users)
        .where(where),
    ]);

    return { rows, total: countResult[0]?.count ?? 0 };
  }

  async getUserById(userId: string) {
    return db.query.users.findFirst({
      where: eq(users.id, userId),
      with: {
        deviceTokens: true,
        sessions: true,
        consentRecords: true,
      },
    });
  }

  async updateUserStatus(
    userId: string,
    status: "active" | "suspended" | "banned",
    suspendedUntil?: Date
  ) {
    const [updated] = await db
      .update(users)
      .set({
        accountStatus: status,
        suspendedUntil: suspendedUntil ?? null,
        updatedAt: new Date(),
      })
      .where(eq(users.id, userId))
      .returning();
    return updated;
  }

  // ── Disputes ──────────────────────────────────────────────────────

  async getDisputes(filters: DisputeFilters, pagination: PaginationParams) {
    const conditions: any[] = [];

    if (filters.status) {
      conditions.push(eq(disputes.status, filters.status as any));
    }
    if (filters.dateFrom) {
      conditions.push(gte(disputes.createdAt, filters.dateFrom));
    }
    if (filters.dateTo) {
      conditions.push(lte(disputes.createdAt, filters.dateTo));
    }

    const where = conditions.length > 0 ? and(...conditions) : undefined;

    const [rows, countResult] = await Promise.all([
      db.query.disputes.findMany({
        where,
        with: {
          raisedBy: true,
          billItem: {
            with: {
              bill: { with: { owner: true } },
              debtor: true,
            },
          },
        },
        orderBy: [desc(disputes.createdAt)],
        limit: pagination.limit,
        offset: (pagination.page - 1) * pagination.limit,
      }),
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(disputes)
        .where(where),
    ]);

    return { rows, total: countResult[0]?.count ?? 0 };
  }

  async getDisputeById(disputeId: string) {
    return db.query.disputes.findFirst({
      where: eq(disputes.id, disputeId),
      with: {
        raisedBy: true,
        billItem: {
          with: {
            bill: { with: { owner: true } },
            debtor: true,
            payments: {
              with: { verifications: true },
            },
          },
        },
      },
    });
  }

  async resolveDispute(
    disputeId: string,
    resolvedById: string,
    status: "resolved_paid" | "resolved_written_off" | "resolved_rejected",
    note: string
  ) {
    const [updated] = await db
      .update(disputes)
      .set({
        status,
        resolvedById,
        resolutionNote: note,
        resolvedAt: new Date(),
      })
      .where(eq(disputes.id, disputeId))
      .returning();
    return updated;
  }

  async updateDisputeStatus(disputeId: string, status: string) {
    const [updated] = await db
      .update(disputes)
      .set({ status: status as any })
      .where(eq(disputes.id, disputeId))
      .returning();
    return updated;
  }

  // ── Admin Action Logs (audit) ─────────────────────────────────────

  async logAdminAction(data: {
    adminId: string;
    actionType: "view_transactions" | "view_logs" | "suspend_account" | "ban_account" | "unsuspend_account" | "flag_suspicious" | "resolve_dispute";
    targetUserId?: string;
    reason?: string;
    metadata?: any;
  }) {
    const [row] = await db
      .insert(adminActionLogs)
      .values(data)
      .returning();
    return row;
  }

  async getAdminAuditLogs(pagination: PaginationParams, adminId?: string) {
    const where = adminId ? eq(adminActionLogs.adminId, adminId) : undefined;

    const [rows, countResult] = await Promise.all([
      db
        .select({
          id: adminActionLogs.id,
          adminId: adminActionLogs.adminId,
          actionType: adminActionLogs.actionType,
          targetUserId: adminActionLogs.targetUserId,
          reason: adminActionLogs.reason,
          metadata: adminActionLogs.metadata,
          createdAt: adminActionLogs.createdAt,
          adminName: users.displayName,
          adminCode: users.userCode,
        })
        .from(adminActionLogs)
        .leftJoin(users, eq(adminActionLogs.adminId, users.id))
        .where(where)
        .orderBy(desc(adminActionLogs.createdAt))
        .limit(pagination.limit)
        .offset((pagination.page - 1) * pagination.limit),
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(adminActionLogs)
        .where(where),
    ]);

    return { rows, total: countResult[0]?.count ?? 0 };
  }

  async clearAllAdminActionLogs() {
    return db.delete(adminActionLogs);
  }

  // ── Edit Logs (for dispute review) ────────────────────────────────

  async getEditLogsByBill(billId: string) {
    return db.query.editLogs.findMany({
      where: eq(editLogs.billId, billId),
      with: {
        performedBy: true,
        affectedUser: true,
      },
      orderBy: [desc(editLogs.createdAt)],
    });
  }

  // ── Rewards Catalog & Redemptions ─────────────────────────────────

  async getRewardItems() {
    return db.query.rewardItems.findMany({
      orderBy: [desc(rewardItems.createdAt)],
    });
  }

  async getRewardItemById(id: string) {
    return db.query.rewardItems.findFirst({
      where: eq(rewardItems.id, id),
    });
  }

  async createRewardItem(data: {
    title: string;
    description?: string;
    pointsCost: number;
    category?: string;
    imageUrl?: string;
    inStock: number;
    isActive?: boolean;
  }) {
    const [item] = await db.insert(rewardItems).values(data).returning();
    return item;
  }

  async updateRewardItem(id: string, data: Partial<{
    title: string;
    description: string;
    pointsCost: number;
    category: string;
    imageUrl: string;
    inStock: number;
    isActive: boolean;
  }>) {
    const [item] = await db
      .update(rewardItems)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(rewardItems.id, id))
      .returning();
    return item;
  }

  async deleteRewardItem(id: string) {
    return db.delete(rewardItems).where(eq(rewardItems.id, id));
  }

  async getRewardRedemptions(pagination: PaginationParams, status?: string) {
    const where = status ? eq(rewardRedemptions.status, status as any) : undefined;

    const [rows, countResult] = await Promise.all([
      db.query.rewardRedemptions.findMany({
        where,
        with: {
          user: true,
          rewardItem: true,
        },
        orderBy: [desc(rewardRedemptions.createdAt)],
        limit: pagination.limit,
        offset: (pagination.page - 1) * pagination.limit,
      }),
      db.select({ count: sql<number>`count(*)::int` }).from(rewardRedemptions).where(where),
    ]);

    return { rows, total: countResult[0]?.count ?? 0 };
  }

  async updateRedemptionStatus(
    id: string,
    status: "pending_delivery" | "shipped" | "delivered" | "cancelled",
    trackingNumber?: string
  ) {
    const [updated] = await db
      .update(rewardRedemptions)
      .set({
        status,
        trackingNumber: trackingNumber ?? null,
        updatedAt: new Date(),
      })
      .where(eq(rewardRedemptions.id, id))
      .returning();
    return updated;
  }

  // ── Notifications Outbox ──────────────────────────────────────────

  async getNotificationOutbox(
    pagination: PaginationParams,
    status?: string,
    eventType?: string
  ) {
    const conditions: any[] = [];
    if (status) conditions.push(eq(notificationOutbox.status, status));
    if (eventType) conditions.push(eq(notificationOutbox.eventType, eventType));

    const where = conditions.length > 0 ? and(...conditions) : undefined;

    const [rows, countResult] = await Promise.all([
      db.query.notificationOutbox.findMany({
        where,
        with: {
          recipient: true,
          deliveries: true,
        },
        orderBy: [desc(notificationOutbox.createdAt)],
        limit: pagination.limit,
        offset: (pagination.page - 1) * pagination.limit,
      }),
      db.select({ count: sql<number>`count(*)::int` }).from(notificationOutbox).where(where),
    ]);

    return { rows, total: countResult[0]?.count ?? 0 };
  }

  async retryNotification(id: string) {
    const [updated] = await db
      .update(notificationOutbox)
      .set({
        status: "PENDING",
        attempts: 0,
        availableAt: new Date(),
        updatedAt: new Date(),
      })
      .where(eq(notificationOutbox.id, id))
      .returning();
    return updated;
  }

  async getUsersWithFcm(search?: string) {
    const tokens = await db.query.deviceTokens.findMany({
      with: {
        user: true,
      },
      orderBy: [desc(deviceTokens.updatedAt)],
    });

    const userMap = new Map<string, any>();
    for (const t of tokens) {
      if (!t.user) continue;
      const u = t.user;
      if (search && search.trim()) {
        const q = search.toLowerCase().trim();
        const matches =
          (u.displayName && u.displayName.toLowerCase().includes(q)) ||
          (u.fullName && u.fullName.toLowerCase().includes(q)) ||
          (u.userCode && u.userCode.toLowerCase().includes(q)) ||
          (u.phoneNumber && u.phoneNumber.toLowerCase().includes(q));
        if (!matches) continue;
      }

      if (!userMap.has(u.id)) {
        userMap.set(u.id, {
          id: u.id,
          userCode: u.userCode,
          displayName: u.displayName,
          fullName: u.fullName,
          avatarUrl: u.avatarUrl,
          phoneNumber: u.phoneNumber,
          role: u.role,
          accountStatus: u.accountStatus,
          tokenCount: 1,
          platforms: t.platform ? [t.platform] : ["android"],
          lastTokenAt: t.updatedAt,
        });
      } else {
        const existing = userMap.get(u.id);
        existing.tokenCount++;
        if (t.platform && !existing.platforms.includes(t.platform)) {
          existing.platforms.push(t.platform);
        }
      }
    }

    return Array.from(userMap.values()).slice(0, 50);
  }

  // ── Security Events ───────────────────────────────────────────────

  async getSecurityEvents(pagination: PaginationParams, userId?: string, event?: string) {
    const conditions: any[] = [];
    if (userId) conditions.push(eq(securityEvents.userId, userId));
    if (event) conditions.push(eq(securityEvents.event, event));

    const where = conditions.length > 0 ? and(...conditions) : undefined;

    const [rows, countResult] = await Promise.all([
      db
        .select({
          id: securityEvents.id,
          userId: securityEvents.userId,
          event: securityEvents.event,
          ipAddress: securityEvents.ipAddress,
          metadata: securityEvents.metadata,
          createdAt: securityEvents.createdAt,
          userName: users.displayName,
          userCode: users.userCode,
        })
        .from(securityEvents)
        .leftJoin(users, eq(securityEvents.userId, users.id))
        .where(where)
        .orderBy(desc(securityEvents.createdAt))
        .limit(pagination.limit)
        .offset((pagination.page - 1) * pagination.limit),
      db.select({ count: sql<number>`count(*)::int` }).from(securityEvents).where(where),
    ]);

    return { rows, total: countResult[0]?.count ?? 0 };
  }

  // ── Dashboard stats ───────────────────────────────────────────────

  async getDashboardStats() {
    const [
      totalUsersResult,
      activeUsersResult,
      suspendedUsersResult,
      bannedUsersResult,
      openDisputesResult,
      totalTransactionsResult,
      suspiciousLogsResult,
      totalRewardItemsResult,
      pendingRedemptionsResult,
      pendingNotificationsResult,
      securityEventsResult,
    ] = await Promise.all([
      db.select({ count: sql<number>`count(*)::int` }).from(users),
      db.select({ count: sql<number>`count(*)::int` }).from(users).where(eq(users.accountStatus, "active")),
      db.select({ count: sql<number>`count(*)::int` }).from(users).where(eq(users.accountStatus, "suspended")),
      db.select({ count: sql<number>`count(*)::int` }).from(users).where(eq(users.accountStatus, "banned")),
      db.select({ count: sql<number>`count(*)::int` }).from(disputes).where(or(eq(disputes.status, "open"), eq(disputes.status, "under_review"))),
      db.select({ count: sql<number>`count(*)::int` }).from(financialTransactions),
      db.select({ count: sql<number>`count(*)::int` }).from(suspiciousActivityLogs),
      db.select({ count: sql<number>`count(*)::int` }).from(rewardItems),
      db.select({ count: sql<number>`count(*)::int` }).from(rewardRedemptions).where(eq(rewardRedemptions.status, "pending_delivery")),
      db.select({ count: sql<number>`count(*)::int` }).from(notificationOutbox).where(eq(notificationOutbox.status, "PENDING")),
      db.select({ count: sql<number>`count(*)::int` }).from(securityEvents),
    ]);

    return {
      totalUsers: totalUsersResult[0]?.count ?? 0,
      activeUsers: activeUsersResult[0]?.count ?? 0,
      suspendedUsers: suspendedUsersResult[0]?.count ?? 0,
      bannedUsers: bannedUsersResult[0]?.count ?? 0,
      openDisputes: openDisputesResult[0]?.count ?? 0,
      totalTransactions: totalTransactionsResult[0]?.count ?? 0,
      suspiciousLogs: suspiciousLogsResult[0]?.count ?? 0,
      totalRewardItems: totalRewardItemsResult[0]?.count ?? 0,
      pendingRedemptions: pendingRedemptionsResult[0]?.count ?? 0,
      pendingNotifications: pendingNotificationsResult[0]?.count ?? 0,
      securityEventsCount: securityEventsResult[0]?.count ?? 0,
    };
  }

  // ── System & Behavioral Analytics ─────────────────────────────────

  async getSystemAnalytics() {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const [
      dailyTxRows,
      paymentChannelRows,
      billStatusRows,
      acknowledgementRows,
      methodRows,
      redemptionsCatRows,
      fcmStatusRows,
      settlementDurationResult,
    ] = await Promise.all([
      // 1. Daily volume
      db
        .select({
          date: sql<string>`DATE(created_at)`,
          type: financialTransactions.type,
          sum: sql<number>`COALESCE(SUM(amount::numeric), 0)::float`,
          count: sql<number>`COUNT(*)::int`,
        })
        .from(financialTransactions)
        .where(gte(financialTransactions.createdAt, sevenDaysAgo))
        .groupBy(sql`DATE(created_at)`, financialTransactions.type)
        .orderBy(sql`DATE(created_at)`),

      // 2. Payment channels
      db
        .select({
          channel: payments.channel,
          count: sql<number>`COUNT(*)::int`,
          totalAmount: sql<number>`COALESCE(SUM(amount::numeric), 0)::float`,
        })
        .from(payments)
        .groupBy(payments.channel),

      // 3. Bill status breakdown
      db
        .select({
          status: bills.status,
          count: sql<number>`COUNT(*)::int`,
          totalAmount: sql<number>`COALESCE(SUM(total_amount::numeric), 0)::float`,
        })
        .from(bills)
        .groupBy(bills.status),

      // 4. Debtor acknowledgement rate
      db
        .select({
          isAcknowledged: billItems.isAcknowledged,
          count: sql<number>`COUNT(*)::int`,
        })
        .from(billItems)
        .groupBy(billItems.isAcknowledged),

      // 5. Payment method: full vs installment
      db
        .select({
          method: payments.method,
          count: sql<number>`COUNT(*)::int`,
        })
        .from(payments)
        .groupBy(payments.method),

      // 6. Reward redemption categories
      db
        .select({
          category: rewardItems.category,
          count: sql<number>`COUNT(*)::int`,
          pointsSpent: sql<number>`COALESCE(SUM(reward_redemptions.points_spent), 0)::int`,
        })
        .from(rewardRedemptions)
        .leftJoin(rewardItems, eq(rewardRedemptions.rewardItemId, rewardItems.id))
        .groupBy(rewardItems.category),

      // 7. FCM notification delivery status
      db
        .select({
          status: notificationOutbox.status,
          count: sql<number>`COUNT(*)::int`,
        })
        .from(notificationOutbox)
        .groupBy(notificationOutbox.status),

      // 8. Real average settlement duration from creation to payment (in hours)
      db
        .select({
          avgHours: sql<number>`COALESCE(AVG(EXTRACT(EPOCH FROM (payments.created_at - bill_items.created_at)) / 3600), 0)::float`,
          settledCount: sql<number>`COUNT(*)::int`,
        })
        .from(payments)
        .innerJoin(billItems, eq(payments.billItemId, billItems.id))
        .where(eq(payments.status, "confirmed")),
    ]);

    // Build true 7 consecutive dates (YYYY-MM-DD)
    const consecutiveDays: Array<{ date: string; sum: number; count: number }> = [];
    const dateMap = new Map<string, { sum: number; count: number }>();
    for (const r of dailyTxRows) {
      const d = String(r.date);
      const curr = dateMap.get(d) || { sum: 0, count: 0 };
      curr.sum += Number(r.sum || 0);
      curr.count += Number(r.count || 0);
      dateMap.set(d, curr);
    }

    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const key = d.toISOString().slice(0, 10);
      const val = dateMap.get(key) || { sum: 0, count: 0 };
      consecutiveDays.push({
        date: key,
        sum: Math.round(val.sum * 100) / 100,
        count: val.count,
      });
    }

    return {
      dailyTransactions: consecutiveDays,
      paymentChannels: paymentChannelRows,
      billStatuses: billStatusRows,
      acknowledgementStats: acknowledgementRows,
      paymentMethods: methodRows,
      rewardsCategories: redemptionsCatRows,
      fcmStatuses: fcmStatusRows,
      settlementDuration: settlementDurationResult[0] || { avgHours: 0, settledCount: 0 },
    };
  }

  // ── Bills Explorer ────────────────────────────────────────────────
  async getBills(filters: BillFilters, pagination: PaginationParams) {
    const conditions: any[] = [];

    if (filters.ownerId) {
      conditions.push(eq(bills.ownerId, filters.ownerId));
    }
    if (filters.status) {
      conditions.push(eq(bills.status, filters.status as any));
    }
    if (filters.search) {
      conditions.push(ilike(bills.title, `%${filters.search}%`));
    }
    if (filters.dateFrom) {
      conditions.push(gte(bills.createdAt, filters.dateFrom));
    }
    if (filters.dateTo) {
      conditions.push(lte(bills.createdAt, filters.dateTo));
    }

    const where = conditions.length > 0 ? and(...conditions) : undefined;

    const [rows, countResult] = await Promise.all([
      db.query.bills.findMany({
        where,
        with: {
          owner: true,
          items: {
            with: {
              debtor: true,
            },
          },
        },
        orderBy: [desc(bills.createdAt)],
        limit: pagination.limit,
        offset: (pagination.page - 1) * pagination.limit,
      }),
      db.select({ count: sql<number>`count(*)::int` }).from(bills).where(where),
    ]);

    return { rows, total: countResult[0]?.count ?? 0 };
  }

  async getBillById(billId: string) {
    return db.query.bills.findFirst({
      where: eq(bills.id, billId),
      with: {
        owner: true,
        items: {
          with: {
            debtor: true,
            payments: {
              with: {
                verifications: true,
              },
            },
          },
        },
      },
    });
  }

  // ── Payments & Slips Explorer ─────────────────────────────────────
  async getPayments(filters: PaymentFilters, pagination: PaginationParams) {
    const conditions: any[] = [];

    if (filters.payerId) {
      conditions.push(eq(payments.payerId, filters.payerId));
    }
    if (filters.status) {
      conditions.push(eq(payments.status, filters.status as any));
    }
    if (filters.channel) {
      conditions.push(eq(payments.channel, filters.channel as any));
    }
    if (filters.method) {
      conditions.push(eq(payments.method, filters.method as any));
    }
    if (filters.dateFrom) {
      conditions.push(gte(payments.createdAt, filters.dateFrom));
    }
    if (filters.dateTo) {
      conditions.push(lte(payments.createdAt, filters.dateTo));
    }

    const where = conditions.length > 0 ? and(...conditions) : undefined;

    const [rows, countResult] = await Promise.all([
      db.query.payments.findMany({
        where,
        with: {
          payer: true,
          verifications: {
            orderBy: [desc(paymentVerifications.createdAt)],
          },
          billItem: {
            with: {
              bill: {
                with: {
                  owner: true,
                },
              },
              debtor: true,
            },
          },
        },
        orderBy: [desc(payments.createdAt)],
        limit: pagination.limit,
        offset: (pagination.page - 1) * pagination.limit,
      }),
      db.select({ count: sql<number>`count(*)::int` }).from(payments).where(where),
    ]);

    return { rows, total: countResult[0]?.count ?? 0 };
  }

  async getPaymentById(paymentId: string) {
    return db.query.payments.findFirst({
      where: eq(payments.id, paymentId),
      with: {
        payer: true,
        verifications: {
          orderBy: [desc(paymentVerifications.createdAt)],
        },
        billItem: {
          with: {
            bill: {
              with: {
                owner: true,
              },
            },
            debtor: true,
          },
        },
      },
    });
  }

  // ── Live Database Table Row Counts ────────────────────────────────
  async getDatabaseStats() {
    const [
      usersCount,
      billsCount,
      billItemsCount,
      paymentsCount,
      verificationsCount,
      financialTxCount,
      disputesCount,
      friendshipsCount,
      editLogsCount,
      activityLogsCount,
      suspiciousLogsCount,
      adminLogsCount,
      notificationOutboxCount,
      notificationDeliveriesCount,
      deviceTokensCount,
      securityEventsCount,
      rewardItemsCount,
      rewardRedemptionsCount,
      consentRecordsCount,
      authIdentitiesCount,
      authSessionsCount,
    ] = await Promise.all([
      db.select({ count: sql<number>`count(*)::int` }).from(users),
      db.select({ count: sql<number>`count(*)::int` }).from(bills),
      db.select({ count: sql<number>`count(*)::int` }).from(billItems),
      db.select({ count: sql<number>`count(*)::int` }).from(payments),
      db.select({ count: sql<number>`count(*)::int` }).from(paymentVerifications),
      db.select({ count: sql<number>`count(*)::int` }).from(financialTransactions),
      db.select({ count: sql<number>`count(*)::int` }).from(disputes),
      db.select({ count: sql<number>`count(*)::int` }).from(friendships),
      db.select({ count: sql<number>`count(*)::int` }).from(editLogs),
      db.select({ count: sql<number>`count(*)::int` }).from(activityLogs),
      db.select({ count: sql<number>`count(*)::int` }).from(suspiciousActivityLogs),
      db.select({ count: sql<number>`count(*)::int` }).from(adminActionLogs),
      db.select({ count: sql<number>`count(*)::int` }).from(notificationOutbox),
      db.select({ count: sql<number>`count(*)::int` }).from(notificationDeliveries),
      db.select({ count: sql<number>`count(*)::int` }).from(deviceTokens),
      db.select({ count: sql<number>`count(*)::int` }).from(securityEvents),
      db.select({ count: sql<number>`count(*)::int` }).from(rewardItems),
      db.select({ count: sql<number>`count(*)::int` }).from(rewardRedemptions),
      db.select({ count: sql<number>`count(*)::int` }).from(consentRecords),
      db.select({ count: sql<number>`count(*)::int` }).from(authIdentities),
      db.select({ count: sql<number>`count(*)::int` }).from(authSessions),
    ]);

    return {
      users: usersCount[0]?.count ?? 0,
      bills: billsCount[0]?.count ?? 0,
      billItems: billItemsCount[0]?.count ?? 0,
      payments: paymentsCount[0]?.count ?? 0,
      paymentVerifications: verificationsCount[0]?.count ?? 0,
      financialTransactions: financialTxCount[0]?.count ?? 0,
      disputes: disputesCount[0]?.count ?? 0,
      friendships: friendshipsCount[0]?.count ?? 0,
      editLogs: editLogsCount[0]?.count ?? 0,
      activityLogs: activityLogsCount[0]?.count ?? 0,
      suspiciousActivityLogs: suspiciousLogsCount[0]?.count ?? 0,
      adminActionLogs: adminLogsCount[0]?.count ?? 0,
      notificationOutbox: notificationOutboxCount[0]?.count ?? 0,
      notificationDeliveries: notificationDeliveriesCount[0]?.count ?? 0,
      deviceTokens: deviceTokensCount[0]?.count ?? 0,
      securityEvents: securityEventsCount[0]?.count ?? 0,
      rewardItems: rewardItemsCount[0]?.count ?? 0,
      rewardRedemptions: rewardRedemptionsCount[0]?.count ?? 0,
      consentRecords: consentRecordsCount[0]?.count ?? 0,
      authIdentities: authIdentitiesCount[0]?.count ?? 0,
      authSessions: authSessionsCount[0]?.count ?? 0,
    };
  }
}
