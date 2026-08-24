import { Elysia, t } from "elysia";
import { AdminService } from "./admin.service";

const adminService = new AdminService();

const PaginationQuery = {
  page: t.Optional(t.Numeric({ default: 1 })),
  limit: t.Optional(t.Numeric({ default: 20 })),
};

export const adminRoutes = new Elysia()
  // ── Dashboard ───────────────────────────────────────────────────
  .get("/dashboard", async ({ adminUser }) => {
    const stats = await adminService.getDashboardStats(adminUser.id);
    return { success: true, data: stats };
  }, {
    detail: {
      tags: ["Admin"],
      summary: "Get dashboard stats",
      description: "Overview counts: users, disputes, transactions, suspicious activity.",
    },
  })

  // ── Analytics ───────────────────────────────────────────────────
  .get("/analytics", async ({ adminUser }) => {
    const analytics = await adminService.getAnalytics(adminUser.id);
    return { success: true, data: analytics };
  }, {
    detail: {
      tags: ["Admin"],
      summary: "Get system & user behavior analytics",
      description: "Comprehensive financial volume, payment channels, settlement duration, and user behavior metrics.",
    },
  })

  // ── Transactions ────────────────────────────────────────────────
  .get("/transactions", async ({ adminUser, query }) => {
    const result = await adminService.getTransactions(
      adminUser.id,
      {
        userId: query.userId,
        type: query.type,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
      },
      query.page,
      query.limit
    );
    return { success: true, data: result };
  }, {
    query: t.Object({
      ...PaginationQuery,
      userId: t.Optional(t.String()),
      type: t.Optional(t.String()),
      dateFrom: t.Optional(t.String()),
      dateTo: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "List financial transactions",
      description: "Filterable by user, type, date range. Paginated.",
    },
  })

  // ── Activity Logs ───────────────────────────────────────────────
  .get("/activity-logs", async ({ adminUser, query }) => {
    const result = await adminService.getActivityLogs(
      adminUser.id,
      {
        userId: query.userId,
        action: query.action,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
      },
      query.page,
      query.limit
    );
    return { success: true, data: result };
  }, {
    query: t.Object({
      ...PaginationQuery,
      userId: t.Optional(t.String()),
      action: t.Optional(t.String()),
      dateFrom: t.Optional(t.String()),
      dateTo: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "List activity logs",
      description: "Regular activity logs. Auto-deleted monthly. Filterable by user, action, date.",
    },
  })

  .post("/activity-logs/purge", async ({ adminUser }) => {
    await adminService.purgeOldActivityLogs(adminUser.id);
    return { success: true, message: "Old activity logs purged" };
  }, {
    detail: {
      tags: ["Admin"],
      summary: "Purge activity logs older than 1 month",
    },
  })

  .delete("/activity-logs/clear-all", async ({ adminUser }) => {
    await adminService.clearAllActivityLogs(adminUser.id);
    return { success: true, message: "All activity logs cleared" };
  }, {
    detail: {
      tags: ["Admin"],
      summary: "Clear all activity logs",
    },
  })

  .delete("/activity-logs/:id", async ({ adminUser, params: { id } }) => {
    await adminService.deleteActivityLog(adminUser.id, id);
    return { success: true, message: "Activity log deleted" };
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Admin"],
      summary: "Delete specific activity log",
    },
  })

  // ── Suspicious Activity ─────────────────────────────────────────
  .get("/suspicious-logs", async ({ adminUser, query }) => {
    const result = await adminService.getSuspiciousLogs(
      adminUser.id,
      {
        userId: query.userId,
        type: query.type,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
      },
      query.page,
      query.limit
    );
    return { success: true, data: result };
  }, {
    query: t.Object({
      ...PaginationQuery,
      userId: t.Optional(t.String()),
      type: t.Optional(t.String()),
      dateFrom: t.Optional(t.String()),
      dateTo: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "List suspicious activity logs",
      description: "Flagged/suspicious logs retained longer than regular logs.",
    },
  })

  .post("/suspicious-logs", async ({ adminUser, body, set }) => {
    try {
      const log = await adminService.flagSuspiciousActivity(adminUser.id, body);
      set.status = 201;
      return { success: true, data: log };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    body: t.Object({
      userId: t.Optional(t.String({ format: "uuid" })),
      type: t.String(),
      description: t.String(),
      metadata: t.Optional(t.Any()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "Flag suspicious activity",
      description: "Record suspicious activity: duplicate slips, multi-account IP, frequent write-offs, etc.",
    },
  })

  .delete("/suspicious-logs/clear-all", async ({ adminUser }) => {
    await adminService.clearAllSuspiciousLogs(adminUser.id);
    return { success: true, message: "All suspicious logs cleared" };
  }, {
    detail: {
      tags: ["Admin"],
      summary: "Clear all suspicious activity logs",
    },
  })

  .delete("/suspicious-logs/:id", async ({ adminUser, params: { id } }) => {
    await adminService.deleteSuspiciousLog(adminUser.id, id);
    return { success: true, message: "Suspicious log deleted" };
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Admin"],
      summary: "Delete specific suspicious log",
    },
  })

  // ── Users ───────────────────────────────────────────────────────
  .get("/users", async ({ query }) => {
    const result = await adminService.getUsers(
      {
        search: query.search,
        accountStatus: query.accountStatus,
        role: query.role,
      },
      query.page,
      query.limit
    );
    return { success: true, data: result };
  }, {
    query: t.Object({
      ...PaginationQuery,
      search: t.Optional(t.String()),
      accountStatus: t.Optional(t.String()),
      role: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "List users",
      description: "Search and filter users by name, code, status, role.",
    },
  })

  .get("/users/:id", async ({ params: { id }, set }) => {
    try {
      const user = await adminService.getUserDetail(id);
      return { success: true, data: user };
    } catch (e: any) {
      set.status = 404;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Admin"],
      summary: "Get user detail",
    },
  })

  .patch("/users/:id/suspend", async ({ params: { id }, body, adminUser, set }) => {
    try {
      const result = await adminService.suspendAccount(adminUser.id, id, body.reason, body.durationDays);
      return { success: true, data: result };
    } catch (e: any) {
      if (e.message.includes("NOT_FOUND")) set.status = 404;
      else if (e.message.includes("CANNOT_SUSPEND")) set.status = 403;
      else set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    body: t.Object({
      reason: t.String(),
      durationDays: t.Optional(t.Number()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "Suspend user account",
      description: "Temporarily suspend. Optional duration in days; omit for indefinite.",
    },
  })

  .patch("/users/:id/ban", async ({ params: { id }, body, adminUser, set }) => {
    try {
      const result = await adminService.banAccount(adminUser.id, id, body.reason);
      return { success: true, data: result };
    } catch (e: any) {
      if (e.message.includes("NOT_FOUND")) set.status = 404;
      else if (e.message.includes("CANNOT_BAN")) set.status = 403;
      else set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    body: t.Object({ reason: t.String() }),
    detail: {
      tags: ["Admin"],
      summary: "Ban user account",
      description: "Permanently ban user account.",
    },
  })

  .patch("/users/:id/unsuspend", async ({ params: { id }, body, adminUser, set }) => {
    try {
      const result = await adminService.unsuspendAccount(adminUser.id, id, body.reason);
      return { success: true, data: result };
    } catch (e: any) {
      if (e.message.includes("NOT_FOUND")) set.status = 404;
      else set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    body: t.Object({ reason: t.String() }),
    detail: {
      tags: ["Admin"],
      summary: "Unsuspend/unban user account",
      description: "Restore account to active status.",
    },
  })

  // ── Disputes ────────────────────────────────────────────────────
  .get("/disputes", async ({ adminUser, query }) => {
    const result = await adminService.getDisputes(
      adminUser.id,
      {
        status: query.status,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
      },
      query.page,
      query.limit
    );
    return { success: true, data: result };
  }, {
    query: t.Object({
      ...PaginationQuery,
      status: t.Optional(t.String()),
      dateFrom: t.Optional(t.String()),
      dateTo: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "List disputes",
      description: "All disputes. Filter by status, date range.",
    },
  })

  .get("/disputes/:id", async ({ params: { id }, adminUser, set }) => {
    try {
      const detail = await adminService.getDisputeDetail(adminUser.id, id);
      return { success: true, data: detail };
    } catch (e: any) {
      set.status = 404;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Admin"],
      summary: "Get dispute detail",
      description: "Full dispute detail with slip images, payment history, edit logs.",
    },
  })

  .patch("/disputes/:id/review", async ({ params: { id }, adminUser, set }) => {
    try {
      const result = await adminService.markDisputeUnderReview(adminUser.id, id);
      return { success: true, data: result };
    } catch (e: any) {
      if (e.message.includes("NOT_FOUND")) set.status = 404;
      else set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Admin"],
      summary: "Mark dispute as under review",
    },
  })

  .patch("/disputes/:id/resolve", async ({ params: { id }, body, adminUser, set }) => {
    try {
      const result = await adminService.resolveDispute(adminUser.id, id, body);
      return { success: true, data: result };
    } catch (e: any) {
      if (e.message.includes("NOT_FOUND")) set.status = 404;
      else if (e.message.includes("ALREADY_RESOLVED")) set.status = 409;
      else set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    body: t.Object({
      status: t.Union([
        t.Literal("resolved_paid"),
        t.Literal("resolved_written_off"),
        t.Literal("resolved_rejected"),
      ]),
      note: t.String(),
    }),
    detail: {
      tags: ["Admin"],
      summary: "Resolve dispute",
      description: "Admin determines outcome: paid, written off, or rejected.",
    },
  })

  // ── Admin Audit Logs ────────────────────────────────────────────
  .get("/audit-logs", async ({ query }) => {
    const result = await adminService.getAdminAuditLogs(
      query.page,
      query.limit,
      query.adminId
    );
    return { success: true, data: result };
  }, {
    query: t.Object({
      ...PaginationQuery,
      adminId: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "Admin action audit trail",
      description: "View all admin actions. Optionally filter by admin user.",
    },
  })

  .delete("/audit-logs/clear-all", async () => {
    await adminService.clearAllAuditLogs();
    return { success: true, message: "All admin audit logs cleared" };
  }, {
    detail: {
      tags: ["Admin"],
      summary: "Clear all admin audit logs",
    },
  })

  // ── Rewards Catalog & Redemptions ─────────────────────────────────
  .get("/rewards/items", async ({ adminUser }) => {
    const items = await adminService.getRewardItems(adminUser.id);
    return { success: true, data: { items } };
  }, {
    detail: {
      tags: ["Admin"],
      summary: "Get all reward items (active and inactive)",
    },
  })

  .post("/rewards/items", async ({ adminUser, body, set }) => {
    try {
      const item = await adminService.createRewardItem(adminUser.id, body);
      set.status = 201;
      return { success: true, data: item };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    body: t.Object({
      title: t.String({ minLength: 1 }),
      description: t.Optional(t.String()),
      pointsCost: t.Number({ minimum: 1 }),
      category: t.Optional(t.String()),
      imageUrl: t.Optional(t.String()),
      inStock: t.Number({ minimum: 0 }),
      isActive: t.Optional(t.Boolean()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "Create reward item",
    },
  })

  .patch("/rewards/items/:id", async ({ adminUser, params: { id }, body, set }) => {
    try {
      const item = await adminService.updateRewardItem(adminUser.id, id, body);
      return { success: true, data: item };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    body: t.Object({
      title: t.Optional(t.String({ minLength: 1 })),
      description: t.Optional(t.String()),
      pointsCost: t.Optional(t.Number({ minimum: 1 })),
      category: t.Optional(t.String()),
      imageUrl: t.Optional(t.String()),
      inStock: t.Optional(t.Number({ minimum: 0 })),
      isActive: t.Optional(t.Boolean()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "Update reward item",
    },
  })

  .delete("/rewards/items/:id", async ({ adminUser, params: { id }, set }) => {
    try {
      await adminService.deleteRewardItem(adminUser.id, id);
      return { success: true, message: "Reward item deleted" };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Admin"],
      summary: "Delete reward item",
    },
  })

  .get("/rewards/redemptions", async ({ adminUser, query }) => {
    const result = await adminService.getRewardRedemptions(
      adminUser.id,
      query.status,
      query.page,
      query.limit
    );
    return { success: true, data: result };
  }, {
    query: t.Object({
      ...PaginationQuery,
      status: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "List reward redemptions",
    },
  })

  .patch("/rewards/redemptions/:id/status", async ({ adminUser, params: { id }, body, set }) => {
    try {
      const result = await adminService.updateRedemptionStatus(
        adminUser.id,
        id,
        body.status,
        body.trackingNumber
      );
      return { success: true, data: result };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    body: t.Object({
      status: t.Union([
        t.Literal("pending_delivery"),
        t.Literal("shipped"),
        t.Literal("delivered"),
        t.Literal("cancelled"),
      ]),
      trackingNumber: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "Update reward redemption delivery status",
    },
  })

  // ── Notification Outbox ───────────────────────────────────────────
  .get("/notifications/outbox", async ({ adminUser, query }) => {
    const result = await adminService.getNotificationOutbox(
      adminUser.id,
      query.status,
      query.eventType,
      query.page,
      query.limit
    );
    return { success: true, data: result };
  }, {
    query: t.Object({
      ...PaginationQuery,
      status: t.Optional(t.String()),
      eventType: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "List notification outbox records",
    },
  })

  .post("/notifications/outbox/:id/retry", async ({ adminUser, params: { id }, set }) => {
    try {
      const result = await adminService.retryNotification(adminUser.id, id);
      return { success: true, data: result };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Admin"],
      summary: "Retry failed notification outbox item",
    },
  })

  .post("/notifications/send-fcm", async ({ adminUser, body, set }) => {
    try {
      const result = await adminService.sendFcmNotification(adminUser.id, body);
      return {
        success: true,
        message: `FCM message processed: ${result.sentCount} sent, ${result.failedCount} failed.`,
        data: result,
      };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    body: t.Object({
      target: t.Union([t.Literal("all"), t.Literal("user"), t.Literal("token")]),
      userId: t.Optional(t.String({ format: "uuid" })),
      deviceToken: t.Optional(t.String()),
      title: t.String({ minLength: 1 }),
      body: t.String({ minLength: 1 }),
      dataPayload: t.Optional(t.Any()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "Send custom Firebase Cloud Messaging (FCM) push notification",
    },
  })

  .get("/notifications/fcm-users", async ({ adminUser, query }) => {
    const users = await adminService.getFcmUsers(adminUser.id, query.search);
    return { success: true, data: { users } };
  }, {
    query: t.Object({
      search: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "Get list of registered users who have active FCM device tokens",
    },
  })

  // ── Security Events ───────────────────────────────────────────────
  .get("/security-events", async ({ adminUser, query }) => {
    const result = await adminService.getSecurityEvents(
      adminUser.id,
      query.userId,
      query.event,
      query.page,
      query.limit
    );
    return { success: true, data: result };
  }, {
    query: t.Object({
      ...PaginationQuery,
      userId: t.Optional(t.String()),
      event: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "List security events (e.g. PIN brute-force, suspicious attempts)",
    },
  })

  // ── Bills Explorer ────────────────────────────────────────────────
  .get("/bills", async ({ adminUser, query }) => {
    const result = await adminService.getBills(
      adminUser.id,
      {
        ownerId: query.ownerId,
        status: query.status,
        search: query.search,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
      },
      query.page,
      query.limit
    );
    return { success: true, data: result };
  }, {
    query: t.Object({
      ...PaginationQuery,
      ownerId: t.Optional(t.String()),
      status: t.Optional(t.String()),
      search: t.Optional(t.String()),
      dateFrom: t.Optional(t.String()),
      dateTo: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "List all bills with split items & debtor status",
    },
  })

  .get("/bills/:id", async ({ adminUser, params: { id }, set }) => {
    try {
      const bill = await adminService.getBillDetail(adminUser.id, id);
      return { success: true, data: bill };
    } catch (e: any) {
      set.status = 404;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Admin"],
      summary: "Get detailed bill information including OCR raw data and debtor breakdowns",
    },
  })

  // ── Payments Explorer ─────────────────────────────────────────────
  .get("/payments", async ({ adminUser, query }) => {
    const result = await adminService.getPayments(
      adminUser.id,
      {
        payerId: query.payerId,
        status: query.status,
        channel: query.channel,
        method: query.method,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
      },
      query.page,
      query.limit
    );
    return { success: true, data: result };
  }, {
    query: t.Object({
      ...PaginationQuery,
      payerId: t.Optional(t.String()),
      status: t.Optional(t.String()),
      channel: t.Optional(t.String()),
      method: t.Optional(t.String()),
      dateFrom: t.Optional(t.String()),
      dateTo: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "List all payment transactions, slips, and verification statuses",
    },
  })

  .get("/payments/:id", async ({ adminUser, params: { id }, set }) => {
    try {
      const payment = await adminService.getPaymentDetail(adminUser.id, id);
      return { success: true, data: payment };
    } catch (e: any) {
      set.status = 404;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Admin"],
      summary: "Get detailed payment information including EasySlip/SlipOK verification payload",
    },
  })

  // ── Database Table Live Counts & Health ───────────────────────────
  .get("/maintenance/db-stats", async ({ adminUser }) => {
    const stats = await adminService.getDatabaseStats(adminUser.id);
    return { success: true, data: stats };
  }, {
    detail: {
      tags: ["Admin"],
      summary: "Get live row counts for all database tables",
    },
  });
