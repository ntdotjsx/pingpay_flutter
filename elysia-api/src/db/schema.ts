import {
  pgTable,
  pgEnum,
  uuid,
  text,
  varchar,
  boolean,
  timestamp,
  numeric,
  integer,
  jsonb,
  uniqueIndex,
  index,
} from "drizzle-orm/pg-core";
import { relations } from "drizzle-orm";

/* -------------------------------------------------------------------------- */
/* ENUMS                                                                      */
/* -------------------------------------------------------------------------- */

export const friendStatusEnum = pgEnum("friend_status", [
  "pending",
  "accepted",
  "blocked",
  "rejected",
  "cancelled",
]);

export const billStatusEnum = pgEnum("bill_status", [
  "unpaid",
  "partially_paid",
  "fully_paid",
  "partially_written_off",
  "fully_written_off",
]);

export const billItemStatusEnum = pgEnum("bill_item_status", [
  "unpaid",
  "partially_paid",
  "paid",
  "written_off",
]);

export const paymentMethodEnum = pgEnum("payment_method", [
  "full",
  "installment",
]);

// how the payer actually transferred the money
export const paymentChannelEnum = pgEnum("payment_channel", [
  "promptpay_qr", // generated in-app from creditor's PromptPay ID
  "bank_transfer", // manual transfer, no in-app QR
  "cash",
]);

export const promptPayIdTypeEnum = pgEnum("promptpay_id_type", [
  "mobile_number",
  "national_id",
  "ewallet_id",
]);

export const paymentStatusEnum = pgEnum("payment_status", [
  "pending_verification", // slip uploaded, SlipOK not yet confirmed
  "slip_verified", // SlipOK confirmed, waiting for creditor confirmation
  "confirmed", // creditor manually confirmed receipt
  "rejected", // creditor rejected (fake / mismatched slip)
]);

export const editActionEnum = pgEnum("edit_action", [
  "bill_created",
  "bill_amount_edited",
  "bill_item_edited",
  "debt_written_off",
  "bill_cancelled",
  "friend_added",
  "friend_removed",
]);

export const accountStatusEnum = pgEnum("account_status", [
  "active",
  "suspended",
  "banned",
]);

export const userRoleEnum = pgEnum("user_role", [
  "user", // normal end-user (USER ROLE in the spec)
  "developer", // DEVELOPER ROLE - admin/back-office access
]);

export const adminActionTypeEnum = pgEnum("admin_action_type", [
  "view_transactions",
  "view_logs",
  "suspend_account",
  "ban_account",
  "unsuspend_account",
  "flag_suspicious",
  "resolve_dispute",
]);

export const disputeStatusEnum = pgEnum("dispute_status", [
  "open",
  "under_review",
  "resolved_paid",
  "resolved_written_off",
  "resolved_rejected",
]);

/* -------------------------------------------------------------------------- */
/* USERS                                                                      */
/* -------------------------------------------------------------------------- */

export const users = pgTable(
  "users",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userCode: varchar("user_code", { length: 32 }).notNull().unique(), // Public friend code (e.g. USR-XXXXXX)
    displayName: varchar("display_name", { length: 128 }), // from LINE, pre-profile
    fullName: varchar("full_name", { length: 128 }),
    address: text("address"),
    phoneNumber: varchar("phone_number", { length: 32 }),
    bankAccountNumber: varchar("bank_account_number", { length: 32 }),

    // PromptPay ID used to generate a QR for anyone who owes this user money.
    // promptPayIdType tells the QR generator how to format the payload
    // (mobile number / national ID / e-wallet ID use different EMVCo formats).
    promptPayId: varchar("prompt_pay_id", { length: 32 }),
    promptPayIdType: promptPayIdTypeEnum("prompt_pay_id_type"),
    promptPayVerifiedAt: timestamp("prompt_pay_verified_at"), // set after first successful SlipOK match to this ID

    avatarUrl: text("avatar_url"),

    profileCompletedAt: timestamp("profile_completed_at"),

    // 'developer' = has back-office/admin access (view transactions & logs,
    // suspend/ban accounts, view suspicious activity). Kept on the same
    // users table (not a separate admin table) since a developer still
    // logs in the same way via LINE + PIN.
    role: userRoleEnum("role").notNull().default("user"),

    accountStatus: accountStatusEnum("account_status")
      .notNull()
      .default("active"),
    suspendedUntil: timestamp("suspended_until"), // null = not suspended / permanent ban

    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow(),
  }
);

/* Records every consent acceptance so PDPA acceptance history is preserved.
   A new row is added each time policy version changes and user re-accepts. */
export const consentRecords = pgTable(
  "consent_records",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    policyVersion: varchar("policy_version", { length: 32 }).notNull(),
    acceptedAt: timestamp("accepted_at").notNull().defaultNow(),
    ipAddress: varchar("ip_address", { length: 64 }),
  },
  (table) => ({
    userIdx: index("consent_records_user_idx").on(table.userId),
  })
);

/* -------------------------------------------------------------------------- */
/* FRIENDS                                                                    */
/* -------------------------------------------------------------------------- */

/* Directional request row: requester -> addressee.
   status flips to 'accepted' once addressee confirms. Symmetric friendship
   is derived by checking either direction is 'accepted'. */
export const friendships = pgTable(
  "friendships",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    requesterId: uuid("requester_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    addresseeId: uuid("addressee_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    status: friendStatusEnum("status").notNull().default("pending"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    respondedAt: timestamp("responded_at"),
    removedAt: timestamp("removed_at"), // soft delete, keeps history for old bills
  },
  (table) => ({
    pairIdx: uniqueIndex("friendships_pair_idx").on(
      table.requesterId,
      table.addresseeId
    ),
  })
);

/* -------------------------------------------------------------------------- */
/* BILLS                                                                      */
/* -------------------------------------------------------------------------- */

export const bills = pgTable(
  "bills",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    ownerId: uuid("owner_id") // creditor - the person who paid upfront
      .notNull()
      .references(() => users.id, { onDelete: "restrict" }),
    title: varchar("title", { length: 128 }),
    totalAmount: numeric("total_amount", { precision: 12, scale: 2 }).notNull(),
    receiptImageUrl: text("receipt_image_url"), // original bill photo
    ocrRawData: jsonb("ocr_raw_data"), // raw OCR extraction result, for audit
    status: billStatusEnum("status").notNull().default("unpaid"),

    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow(),
    cancelledAt: timestamp("cancelled_at"),
  },
  (table) => ({
    ownerIdx: index("bills_owner_idx").on(table.ownerId),
  })
);

/* One row per debtor per bill = the amount that specific friend owes on
   that bill. This is the row that gets adjusted, locked, or written off. */
export const billItems = pgTable(
  "bill_items",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    billId: uuid("bill_id")
      .notNull()
      .references(() => bills.id, { onDelete: "cascade" }),
    debtorId: uuid("debtor_id")
      .notNull()
      .references(() => users.id, { onDelete: "restrict" }),

    originalAmount: numeric("original_amount", {
      precision: 12,
      scale: 2,
    }).notNull(), // amount at time of bill creation, never changes
    currentAmount: numeric("current_amount", {
      precision: 12,
      scale: 2,
    }).notNull(), // live amount owed, reflects edits/write-offs

    amountPaid: numeric("amount_paid", { precision: 12, scale: 2 })
      .notNull()
      .default("0"),
    amountWrittenOff: numeric("amount_written_off", {
      precision: 12,
      scale: 2,
    })
      .notNull()
      .default("0"),

    status: billItemStatusEnum("status").notNull().default("unpaid"),

    // once true, currentAmount can no longer be edited directly;
    // corrections must go through a refund/adjustment flow instead
    isLocked: boolean("is_locked").notNull().default(false),

    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow(),
  },
  (table) => ({
    billIdx: index("bill_items_bill_idx").on(table.billId),
    debtorIdx: index("bill_items_debtor_idx").on(table.debtorId),
    billDebtorIdx: uniqueIndex("bill_items_bill_debtor_idx").on(
      table.billId,
      table.debtorId
    ),
  })
);

/* -------------------------------------------------------------------------- */
/* PAYMENTS                                                                   */
/* -------------------------------------------------------------------------- */

export const payments = pgTable(
  "payments",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    billItemId: uuid("bill_item_id")
      .notNull()
      .references(() => billItems.id, { onDelete: "cascade" }),
    payerId: uuid("payer_id")
      .notNull()
      .references(() => users.id, { onDelete: "restrict" }),

    method: paymentMethodEnum("method").notNull(),
    channel: paymentChannelEnum("channel").notNull().default("promptpay_qr"),
    amount: numeric("amount", { precision: 12, scale: 2 }).notNull(),
    installmentNumber: integer("installment_number"), // null if method = full

    // snapshot of the PromptPay QR shown to the payer for this specific
    // payment (amount is embedded in the QR payload so it can't be edited
    // after generation - kept here for audit even if the creditor's
    // promptPayId on `users` changes later)
    promptPayQrPayload: text("prompt_pay_qr_payload"), // raw EMVCo string encoded into the QR
    promptPayQrImageUrl: text("prompt_pay_qr_image_url"),
    promptPayQrGeneratedAt: timestamp("prompt_pay_qr_generated_at"),

    slipImageUrl: text("slip_image_url"),
    slipOkReferenceId: varchar("slip_ok_reference_id", { length: 128 }),
    slipOkVerifiedAt: timestamp("slip_ok_verified_at"),
    slipOkRawResponse: jsonb("slip_ok_raw_response"),

    status: paymentStatusEnum("status")
      .notNull()
      .default("pending_verification"),
    confirmedByOwnerAt: timestamp("confirmed_by_owner_at"),
    rejectedReason: text("rejected_reason"),

    createdAt: timestamp("created_at").notNull().defaultNow(),
  },
  (table) => ({
    billItemIdx: index("payments_bill_item_idx").on(table.billItemId),
    payerIdx: index("payments_payer_idx").on(table.payerId),
  })
);

/* -------------------------------------------------------------------------- */
/* EDIT LOG (bill edits, write-offs, friend changes, etc.)                    */
/* -------------------------------------------------------------------------- */

export const editLogs = pgTable(
  "edit_logs",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    action: editActionEnum("action").notNull(),
    billId: uuid("bill_id").references(() => bills.id, {
      onDelete: "cascade",
    }),
    billItemId: uuid("bill_item_id").references(() => billItems.id, {
      onDelete: "cascade",
    }),
    performedById: uuid("performed_by_id")
      .notNull()
      .references(() => users.id, { onDelete: "restrict" }),
    affectedUserId: uuid("affected_user_id").references(() => users.id, {
      onDelete: "set null",
    }),

    previousValue: jsonb("previous_value"), // e.g. { amount: "300.00" }
    newValue: jsonb("new_value"), // e.g. { amount: "250.00" }
    note: text("note"),

    notifiedAt: timestamp("notified_at"), // when LINE notification was sent
    createdAt: timestamp("created_at").notNull().defaultNow(),
  },
  (table) => ({
    billIdx: index("edit_logs_bill_idx").on(table.billId),
    performedByIdx: index("edit_logs_performed_by_idx").on(
      table.performedById
    ),
  })
);

/* -------------------------------------------------------------------------- */
/* DISPUTES                                                                   */
/* -------------------------------------------------------------------------- */

export const disputes = pgTable(
  "disputes",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    billItemId: uuid("bill_item_id")
      .notNull()
      .references(() => billItems.id, { onDelete: "cascade" }),
    raisedById: uuid("raised_by_id")
      .notNull()
      .references(() => users.id, { onDelete: "restrict" }),

    reason: text("reason").notNull(),
    status: disputeStatusEnum("status").notNull().default("open"),

    resolvedById: uuid("resolved_by_id").references(() => users.id, {
      onDelete: "set null",
    }), // must be a user with role = 'developer'
    resolutionNote: text("resolution_note"),
    resolvedAt: timestamp("resolved_at"),

    createdAt: timestamp("created_at").notNull().defaultNow(),
  },
  (table) => ({
    billItemIdx: index("disputes_bill_item_idx").on(table.billItemId),
    statusIdx: index("disputes_status_idx").on(table.status),
  })
);

/* -------------------------------------------------------------------------- */
/* ADMIN ACTIVITY (developer role actions + suspicious activity)              */
/* -------------------------------------------------------------------------- */

/* Every action a developer/admin takes: viewing transactions or logs,
   suspending/banning accounts, resolving disputes, etc. This is the audit
   trail proving what admin access was used for. */
export const adminActionLogs = pgTable(
  "admin_action_logs",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    adminId: uuid("admin_id")
      .notNull()
      .references(() => users.id, { onDelete: "restrict" }), // must have role = 'developer'
    actionType: adminActionTypeEnum("action_type").notNull(),
    targetUserId: uuid("target_user_id").references(() => users.id, {
      onDelete: "set null",
    }), // account acted upon, if applicable
    reason: text("reason"),
    metadata: jsonb("metadata"), // e.g. { suspendedUntil, disputeId, filterCriteria }
    createdAt: timestamp("created_at").notNull().defaultNow(),
  },
  (table) => ({
    adminIdx: index("admin_action_logs_admin_idx").on(table.adminId),
    targetUserIdx: index("admin_action_logs_target_user_idx").on(
      table.targetUserId
    ),
  })
);

/* Kept separate from edit_logs / regular activity logs so it can be exempted
   from the 1-month auto-deletion rule that applies to normal logs. */
export const suspiciousActivityLogs = pgTable(
  "suspicious_activity_logs",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, {
      onDelete: "set null",
    }),
    type: varchar("type", { length: 64 }).notNull(), // e.g. "duplicate_slip", "multi_account_ip"
    description: text("description").notNull(),
    metadata: jsonb("metadata"), // ip address, device id, related record ids, etc.
    createdAt: timestamp("created_at").notNull().defaultNow(),
  },
  (table) => ({
    userIdx: index("suspicious_logs_user_idx").on(table.userId),
    typeIdx: index("suspicious_logs_type_idx").on(table.type),
  })
);

/* Regular per-user/group action log. Auto-purged every 1 month by a
   scheduled job (not enforced by the schema itself). */
export const activityLogs = pgTable(
  "activity_logs",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, {
      onDelete: "set null",
    }),
    action: varchar("action", { length: 64 }).notNull(),
    metadata: jsonb("metadata"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
  },
  (table) => ({
    userIdx: index("activity_logs_user_idx").on(table.userId),
    createdAtIdx: index("activity_logs_created_at_idx").on(table.createdAt),
  })
);

/* -------------------------------------------------------------------------- */
/* WEEKLY REMINDER TRACKING (optional, avoids duplicate sends)                */
/* -------------------------------------------------------------------------- */

export const reminderLogs = pgTable(
  "reminder_logs",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    billItemId: uuid("bill_item_id")
      .notNull()
      .references(() => billItems.id, { onDelete: "cascade" }),
    sentAt: timestamp("sent_at").notNull().defaultNow(),
    channel: varchar("channel", { length: 32 }).notNull().default("line"),
  },
  (table) => ({
    billItemIdx: index("reminder_logs_bill_item_idx").on(table.billItemId),
  })
);

/* -------------------------------------------------------------------------- */
/* RELATIONS                                                                  */
/* -------------------------------------------------------------------------- */

export const usersRelations = relations(users, ({ one, many }) => ({
  authIdentity: one(authIdentities),
  credentials: one(userCredentials),
  sessions: many(authSessions),
  consentRecords: many(consentRecords),
  ownedBills: many(bills),
  billItems: many(billItems),
  payments: many(payments),
  friendRequestsSent: many(friendships, { relationName: "requester" }),
  friendRequestsReceived: many(friendships, { relationName: "addressee" }),
}));

export const consentRecordsRelations = relations(consentRecords, ({ one }) => ({
  user: one(users, {
    fields: [consentRecords.userId],
    references: [users.id],
  }),
}));

export const friendshipsRelations = relations(friendships, ({ one }) => ({
  requester: one(users, {
    fields: [friendships.requesterId],
    references: [users.id],
    relationName: "requester",
  }),
  addressee: one(users, {
    fields: [friendships.addresseeId],
    references: [users.id],
    relationName: "addressee",
  }),
}));

export const billsRelations = relations(bills, ({ one, many }) => ({
  owner: one(users, {
    fields: [bills.ownerId],
    references: [users.id],
  }),
  items: many(billItems),
  editLogs: many(editLogs),
}));

export const billItemsRelations = relations(billItems, ({ one, many }) => ({
  bill: one(bills, {
    fields: [billItems.billId],
    references: [bills.id],
  }),
  debtor: one(users, {
    fields: [billItems.debtorId],
    references: [users.id],
  }),
  payments: many(payments),
  disputes: many(disputes),
  reminderLogs: many(reminderLogs),
}));

export const paymentsRelations = relations(payments, ({ one }) => ({
  billItem: one(billItems, {
    fields: [payments.billItemId],
    references: [billItems.id],
  }),
  payer: one(users, {
    fields: [payments.payerId],
    references: [users.id],
  }),
}));

export const editLogsRelations = relations(editLogs, ({ one }) => ({
  bill: one(bills, {
    fields: [editLogs.billId],
    references: [bills.id],
  }),
  billItem: one(billItems, {
    fields: [editLogs.billItemId],
    references: [billItems.id],
  }),
  performedBy: one(users, {
    fields: [editLogs.performedById],
    references: [users.id],
  }),
  affectedUser: one(users, {
    fields: [editLogs.affectedUserId],
    references: [users.id],
  }),
}));

export const disputesRelations = relations(disputes, ({ one }) => ({
  billItem: one(billItems, {
    fields: [disputes.billItemId],
    references: [billItems.id],
  }),
  raisedBy: one(users, {
    fields: [disputes.raisedById],
    references: [users.id],
  }),
}));

export const reminderLogsRelations = relations(reminderLogs, ({ one }) => ({
  billItem: one(billItems, {
    fields: [reminderLogs.billItemId],
    references: [billItems.id],
  }),
}));

export const adminActionLogsRelations = relations(
  adminActionLogs,
  ({ one }) => ({
    admin: one(users, {
      fields: [adminActionLogs.adminId],
      references: [users.id],
      relationName: "admin",
    }),
    targetUser: one(users, {
      fields: [adminActionLogs.targetUserId],
      references: [users.id],
      relationName: "targetUser",
    }),
  })
);

/* -------------------------------------------------------------------------- */
/* AUTHENTICATION                                                             */
/* -------------------------------------------------------------------------- */

export const authIdentities = pgTable(
  "auth_identities",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .unique()
      .references(() => users.id, { onDelete: "cascade" }),
    provider: varchar("provider", { length: 32 }).notNull().default("line"),
    providerUserId: varchar("provider_user_id", { length: 128 }).notNull(),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow(),
  },
  (table) => ({
    providerUserIdIdx: uniqueIndex("auth_identities_provider_user_id_idx").on(
      table.provider,
      table.providerUserId
    ),
  })
);

export const userCredentials = pgTable(
  "user_credentials",
  {
    userId: uuid("user_id")
      .primaryKey()
      .references(() => users.id, { onDelete: "cascade" }),
    pinHash: text("pin_hash"), // Hashed PIN
    failedAttempts: integer("failed_attempts").notNull().default(0),
    lockedUntil: timestamp("locked_until"),
    updatedAt: timestamp("updated_at").notNull().defaultNow(),
  }
);

export const authSessions = pgTable(
  "auth_sessions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    refreshTokenHash: text("refresh_token_hash").notNull(),
    deviceInfo: text("device_info"),
    ipAddress: varchar("ip_address", { length: 64 }),
    expiresAt: timestamp("expires_at").notNull(),
    createdAt: timestamp("created_at").notNull().defaultNow(),
  },
  (table) => ({
    userIdx: index("auth_sessions_user_idx").on(table.userId),
  })
);

export const authOauthStates = pgTable(
  "auth_oauth_states",
  {
    state: varchar("state", { length: 64 }).primaryKey(),
    codeVerifier: text("code_verifier"),
    redirectUri: text("redirect_uri"),
    expiresAt: timestamp("expires_at").notNull(),
    createdAt: timestamp("created_at").notNull().defaultNow(),
  }
);

export const securityEvents = pgTable(
  "security_events",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, { onDelete: "set null" }),
    event: varchar("event", { length: 64 }).notNull(), // e.g. "pin_brute_force", "suspicious_login"
    ipAddress: varchar("ip_address", { length: 64 }),
    metadata: jsonb("metadata"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
  },
  (table) => ({
    userIdx: index("security_events_user_idx").on(table.userId),
  })
);

export const authIdentitiesRelations = relations(authIdentities, ({ one }) => ({
  user: one(users, {
    fields: [authIdentities.userId],
    references: [users.id],
  }),
}));

export const userCredentialsRelations = relations(userCredentials, ({ one }) => ({
  user: one(users, {
    fields: [userCredentials.userId],
    references: [users.id],
  }),
}));

export const authSessionsRelations = relations(authSessions, ({ one }) => ({
  user: one(users, {
    fields: [authSessions.userId],
    references: [users.id],
  }),
}));