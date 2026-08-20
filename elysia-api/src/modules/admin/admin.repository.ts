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
  editLogs,
  groups,
} from "../../db/schema";
import { eq, and, gte, lte, desc, sql, ilike, or, inArray, asc } from "drizzle-orm";

export interface PaginationParams {
  page: number;
  limit: number;
}

export interface TransactionFilters {
  userId?: string;
  groupId?: string;
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
    if (filters.groupId) {
      conditions.push(eq(bills.groupId, filters.groupId));
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

  // Filter transactions by groupId (bills that belong to a group)
  async getTransactionsByGroup(groupId: string, pagination: PaginationParams) {
    const groupBills = db
      .select({ id: bills.id })
      .from(bills)
      .where(eq(bills.groupId, groupId));

    const where = inArray(financialTransactions.billId, groupBills);

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
    ] = await Promise.all([
      db.select({ count: sql<number>`count(*)::int` }).from(users),
      db.select({ count: sql<number>`count(*)::int` }).from(users).where(eq(users.accountStatus, "active")),
      db.select({ count: sql<number>`count(*)::int` }).from(users).where(eq(users.accountStatus, "suspended")),
      db.select({ count: sql<number>`count(*)::int` }).from(users).where(eq(users.accountStatus, "banned")),
      db.select({ count: sql<number>`count(*)::int` }).from(disputes).where(or(eq(disputes.status, "open"), eq(disputes.status, "under_review"))),
      db.select({ count: sql<number>`count(*)::int` }).from(financialTransactions),
      db.select({ count: sql<number>`count(*)::int` }).from(suspiciousActivityLogs),
    ]);

    return {
      totalUsers: totalUsersResult[0]?.count ?? 0,
      activeUsers: activeUsersResult[0]?.count ?? 0,
      suspendedUsers: suspendedUsersResult[0]?.count ?? 0,
      bannedUsers: bannedUsersResult[0]?.count ?? 0,
      openDisputes: openDisputesResult[0]?.count ?? 0,
      totalTransactions: totalTransactionsResult[0]?.count ?? 0,
      suspiciousLogs: suspiciousLogsResult[0]?.count ?? 0,
    };
  }
}
