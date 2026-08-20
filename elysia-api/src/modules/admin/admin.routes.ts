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

  // ── Transactions ────────────────────────────────────────────────
  .get("/transactions", async ({ adminUser, query }) => {
    const result = await adminService.getTransactions(
      adminUser.id,
      {
        userId: query.userId,
        groupId: query.groupId,
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
      groupId: t.Optional(t.String()),
      type: t.Optional(t.String()),
      dateFrom: t.Optional(t.String()),
      dateTo: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Admin"],
      summary: "List financial transactions",
      description: "Filterable by user, group, type, date range. Paginated.",
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
  });
