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
  "cancelled",
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
  "pending_verification", // slip uploaded, SlipOK not yet processed
  "verification_failed", // SlipOK verification failed
  "pending_owner_confirmation", // SlipOK passed, waiting for bill owner confirmation
  "confirmed", // bill owner manually confirmed receipt
  "rejected", // bill owner rejected
  "cancelled", // cancelled prior to confirmation
  "refunded", // refunded after confirmation
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

export const transactionTypeEnum = pgEnum("transaction_type", [
  "debt_created",
  "debt_adjusted",
  "payment",
  "refund",
  "write_off",
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

export const notificationEventTypeEnum = pgEnum("notification_event_type", [
  "BILL_CREATED",
  "BILL_UPDATED",
  "BILL_WRITTEN_OFF",
  "PAYMENT_PENDING_CONFIRMATION",
  "PAYMENT_CONFIRMED",
  "PAYMENT_REJECTED",
  "DEBT_WEEKLY_REMINDER",
  "ADMIN_BROADCAST",
]);

export const notificationStatusEnum = pgEnum("notification_status", [
  "PENDING",
  "PROCESSING",
  "SENT",
  "FAILED",
  "CANCELLED",
  "SKIPPED",
]);

/* -------------------------------------------------------------------------- */
/* USERS                                                                      */
/* -------------------------------------------------------------------------- */

export const users = pgTable(
  "users",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userCode: varchar("user_code", { length: 32 }).notNull().unique(), // Public friend code (e.g. USR-XXXXXX)
    email: varchar("email", { length: 255 }),
    displayName: varchar("display_name", { length: 128 }), // from Google, pre-profile
    fullName: varchar("full_name", { length: 128 }),
    firstName: varchar("first_name", { length: 64 }),
    lastName: varchar("last_name", { length: 64 }),
    address: text("address"),
    phoneNumber: varchar("phone_number", { length: 32 }),
    bankAccountNumber: varchar("bank_account_number", { length: 32 }),
    bankName: varchar("bank_name", { length: 64 }),
    bankCode: varchar("bank_code", { length: 16 }),
    truemoneyPhone: varchar("truemoney_phone", { length: 32 }),

    // PromptPay ID used to generate a QR for anyone who owes this user money.
    // promptPayIdType tells the QR generator how to format the payload
    // (mobile number / national ID / e-wallet ID use different EMVCo formats).
    promptPayId: varchar("prompt_pay_id", { length: 32 }),
    promptPayIdType: promptPayIdTypeEnum("prompt_pay_id_type"),
    promptPayVerifiedAt: timestamp("prompt_pay_verified_at"), // set after first successful SlipOK match to this ID

    avatarUrl: text("avatar_url"),

    // Rewards & Gamification
    rewardPoints: integer("reward_points").notNull().default(0),
    shippingAddress: text("shipping_address"),
    shippingPhone: varchar("shipping_phone", { length: 32 }),
    shippingRecipientName: varchar("shipping_recipient_name", { length: 128 }),

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
    currency: varchar("currency", { length: 3 }).notNull().default("THB"),
    totalAmount: numeric("total_amount", { precision: 12, scale: 2 }).notNull(),
    originalTotalAmount: numeric("original_total_amount", { precision: 12, scale: 2 }), // initial total amount at bill creation, never modified
    receiptImageUrl: text("receipt_image_url"), // original bill photo
    ocrRawData: jsonb("ocr_raw_data"), // raw OCR extraction result, for audit
    itemsBreakdown: jsonb("items_breakdown"), // Detailed breakdown: subtotal, service charge, tax, items list, formula explanation
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

    // Debt Acknowledgement by debtor (Friend swipes to accept debt)
    isAcknowledged: boolean("is_acknowledged").notNull().default(false),
    acknowledgedAt: timestamp("acknowledged_at"),

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
/* PAYMENTS & FINANCIAL TRANSACTIONS                                          */
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
    slipHash: varchar("slip_hash", { length: 64 }), // SHA-256 hash of slip file for deduplication
    slipOkReferenceId: varchar("slip_ok_reference_id", { length: 128 }),
    slipOkVerifiedAt: timestamp("slip_ok_verified_at"),
    slipOkRawResponse: jsonb("slip_ok_raw_response"),

    status: paymentStatusEnum("status")
      .notNull()
      .default("pending_verification"),
    confirmedByOwnerAt: timestamp("confirmed_by_owner_at"),
    confirmedByOwnerId: uuid("confirmed_by_owner_id").references(() => users.id, { onDelete: "set null" }),
    rejectedAt: timestamp("rejected_at"),
    rejectedById: uuid("rejected_by_id").references(() => users.id, { onDelete: "set null" }),
    rejectedReason: text("rejected_reason"),

    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow(),
  },
  (table) => ({
    billItemIdx: index("payments_bill_item_idx").on(table.billItemId),
    payerIdx: index("payments_payer_idx").on(table.payerId),
    slipHashIdx: index("payments_slip_hash_idx").on(table.slipHash),
    slipRefIdx: index("payments_slip_ref_idx").on(table.slipOkReferenceId),
  })
);

/* Audit history for slip verifications (preserves multiple attempts without overwriting) */
export const paymentVerifications = pgTable(
  "payment_verifications",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    paymentId: uuid("payment_id")
      .notNull()
      .references(() => payments.id, { onDelete: "cascade" }),
    provider: varchar("provider", { length: 32 }).notNull().default("slipok"),
    status: varchar("status", { length: 32 }).notNull(), // 'success' | 'failed' | 'error'
    providerReference: varchar("provider_reference", { length: 128 }),
    verifiedAmount: numeric("verified_amount", { precision: 12, scale: 2 }),
    senderInfo: jsonb("sender_info"),
    receiverInfo: jsonb("receiver_info"),
    failureCode: varchar("failure_code", { length: 64 }),
    failureMessage: text("failure_message"),
    rawResponse: jsonb("raw_response"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
  },
  (table) => ({
    paymentIdx: index("payment_verifications_payment_idx").on(table.paymentId),
    providerRefIdx: index("payment_verifications_provider_ref_idx").on(table.providerReference),
  })
);

/* Strict append-only ledger for all financial movements. */
export const financialTransactions = pgTable(
  "financial_transactions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    billId: uuid("bill_id")
      .notNull()
      .references(() => bills.id, { onDelete: "cascade" }),
    billItemId: uuid("bill_item_id")
      .notNull()
      .references(() => billItems.id, { onDelete: "cascade" }),
    type: transactionTypeEnum("type").notNull(),
    amount: numeric("amount", { precision: 12, scale: 2 }).notNull(),
    currency: varchar("currency", { length: 3 }).notNull().default("THB"),
    referenceId: varchar("reference_id", { length: 128 }), // Connects to payments.id, editLogs.id etc.
    createdById: uuid("created_by_id")
      .notNull()
      .references(() => users.id, { onDelete: "restrict" }),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    metadata: jsonb("metadata"),
  },
  (table) => ({
    billIdx: index("fin_tx_bill_idx").on(table.billId),
    billItemIdx: index("fin_tx_bill_item_idx").on(table.billItemId),
    typeIdx: index("fin_tx_type_idx").on(table.type),
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
/* NOTIFICATIONS & OUTBOX (FEATURE 5)                                         */
/* -------------------------------------------------------------------------- */

export const notificationOutbox = pgTable(
  "notification_outbox",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    eventType: varchar("event_type", { length: 64 }).notNull(),
    recipientUserId: uuid("recipient_user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    channel: varchar("channel", { length: 32 }).notNull().default("fcm"),
    payload: jsonb("payload").notNull(),
    deduplicationKey: varchar("deduplication_key", { length: 128 }).notNull(),
    status: varchar("status", { length: 32 }).notNull().default("PENDING"),
    attempts: integer("attempts").notNull().default(0),
    maxAttempts: integer("max_attempts").notNull().default(5),
    availableAt: timestamp("available_at").notNull().defaultNow(),
    lockedAt: timestamp("locked_at"),
    sentAt: timestamp("sent_at"),
    failedAt: timestamp("failed_at"),
    lastError: text("last_error"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow(),
  },
  (table) => ({
    recipientIdx: index("notification_outbox_recipient_idx").on(table.recipientUserId),
    statusAvailableIdx: index("notification_outbox_status_available_idx").on(
      table.status,
      table.availableAt
    ),
    dedupIdx: uniqueIndex("notification_outbox_dedup_idx").on(table.deduplicationKey),
  })
);

export const notificationDeliveries = pgTable(
  "notification_deliveries",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    notificationId: uuid("notification_id")
      .notNull()
      .references(() => notificationOutbox.id, { onDelete: "cascade" }),
    provider: varchar("provider", { length: 32 }).notNull().default("fcm"),
    recipientTarget: varchar("recipient_target", { length: 256 }),
    status: varchar("status", { length: 32 }).notNull(), // 'SENT', 'FAILED', 'SKIPPED'
    attemptNumber: integer("attempt_number").notNull(),
    responsePayload: jsonb("response_payload"),
    errorMessage: text("error_message"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
  },
  (table) => ({
    notificationIdx: index("notification_deliveries_notification_idx").on(table.notificationId),
  })
);

/* -------------------------------------------------------------------------- */
/* RELATIONS                                                                  */
/* -------------------------------------------------------------------------- */

export const usersRelations = relations(users, ({ one, many }) => ({
  authIdentity: one(authIdentities),
  credentials: one(userCredentials),
  sessions: many(authSessions),
  deviceTokens: many(deviceTokens),
  consentRecords: many(consentRecords),
  ownedBills: many(bills),
  billItems: many(billItems),
  paymentsMade: many(payments, { relationName: "payer" }),
  paymentsConfirmed: many(payments, { relationName: "confirmedByOwner" }),
  friendRequestsSent: many(friendships, { relationName: "requester" }),
  friendRequestsReceived: many(friendships, { relationName: "addressee" }),
  editLogsPerformed: many(editLogs, { relationName: "performedBy" }),
  editLogsAffected: many(editLogs, { relationName: "affectedUser" }),
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
  financialTransactions: many(financialTransactions),
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
  financialTransactions: many(financialTransactions),
  disputes: many(disputes),
}));

export const paymentsRelations = relations(payments, ({ one, many }) => ({
  billItem: one(billItems, {
    fields: [payments.billItemId],
    references: [billItems.id],
  }),
  payer: one(users, {
    fields: [payments.payerId],
    references: [users.id],
    relationName: "payer",
  }),
  confirmedByOwner: one(users, {
    fields: [payments.confirmedByOwnerId],
    references: [users.id],
    relationName: "confirmedByOwner",
  }),
  verifications: many(paymentVerifications),
}));

export const paymentVerificationsRelations = relations(paymentVerifications, ({ one }) => ({
  payment: one(payments, {
    fields: [paymentVerifications.paymentId],
    references: [payments.id],
  }),
}));

export const financialTransactionsRelations = relations(financialTransactions, ({ one }) => ({
  bill: one(bills, {
    fields: [financialTransactions.billId],
    references: [bills.id],
  }),
  billItem: one(billItems, {
    fields: [financialTransactions.billItemId],
    references: [billItems.id],
  }),
  createdBy: one(users, {
    fields: [financialTransactions.createdById],
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
    relationName: "performedBy",
  }),
  affectedUser: one(users, {
    fields: [editLogs.affectedUserId],
    references: [users.id],
    relationName: "affectedUser",
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

export const notificationOutboxRelations = relations(notificationOutbox, ({ one, many }) => ({
  recipient: one(users, {
    fields: [notificationOutbox.recipientUserId],
    references: [users.id],
  }),
  deliveries: many(notificationDeliveries),
}));

export const notificationDeliveriesRelations = relations(notificationDeliveries, ({ one }) => ({
  notification: one(notificationOutbox, {
    fields: [notificationDeliveries.notificationId],
    references: [notificationOutbox.id],
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

export const deviceTokens = pgTable(
  "device_tokens",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    token: text("token").notNull().unique(),
    platform: varchar("platform", { length: 32 }).notNull().default("android"),
    deviceName: varchar("device_name", { length: 128 }),
    deviceModel: varchar("device_model", { length: 128 }),
    deviceBrand: varchar("device_brand", { length: 64 }),
    osVersion: varchar("os_version", { length: 64 }),
    appVersion: varchar("app_version", { length: 64 }),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow(),
  },
  (table) => ({
    userIdx: index("device_tokens_user_idx").on(table.userId),
    tokenIdx: uniqueIndex("device_tokens_token_idx").on(table.token),
  })
);

export const deviceTokensRelations = relations(deviceTokens, ({ one }) => ({
  user: one(users, {
    fields: [deviceTokens.userId],
    references: [users.id],
  }),
}));

export const otpVerifications = pgTable(
  "otp_verifications",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    email: varchar("email", { length: 255 }).notNull(),
    otpHash: text("otp_hash").notNull(),
    purpose: varchar("purpose", { length: 32 }).notNull().default("pin_reset"),
    attempts: integer("attempts").notNull().default(0),
    maxAttempts: integer("max_attempts").notNull().default(5),
    expiresAt: timestamp("expires_at").notNull(),
    verifiedAt: timestamp("verified_at"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow(),
  },
  (table) => ({
    userIdx: index("otp_verifications_user_idx").on(table.userId),
    emailIdx: index("otp_verifications_email_idx").on(table.email),
  })
);

export const otpVerificationsRelations = relations(otpVerifications, ({ one }) => ({
  user: one(users, {
    fields: [otpVerifications.userId],
    references: [users.id],
  }),
}));

/* -------------------------------------------------------------------------- */
/* REWARDS & STORE CATALOG                                                    */
/* -------------------------------------------------------------------------- */

export const rewardRedemptionStatusEnum = pgEnum("reward_redemption_status", [
  "pending_delivery",
  "shipped",
  "delivered",
  "cancelled",
]);

export const rewardItems = pgTable(
  "reward_items",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    title: varchar("title", { length: 128 }).notNull(),
    description: text("description"),
    pointsCost: integer("points_cost").notNull(),
    category: varchar("category", { length: 64 }).notNull().default("physical"), // physical, voucher, gadget
    imageUrl: text("image_url"),
    inStock: integer("in_stock").notNull().default(100),
    isActive: boolean("is_active").notNull().default(true),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow(),
  }
);

export const rewardRedemptions = pgTable(
  "reward_redemptions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    rewardItemId: uuid("reward_item_id")
      .notNull()
      .references(() => rewardItems.id, { onDelete: "cascade" }),
    pointsSpent: integer("points_spent").notNull(),
    status: rewardRedemptionStatusEnum("status").notNull().default("pending_delivery"),
    recipientName: varchar("recipient_name", { length: 128 }).notNull(),
    phoneNumber: varchar("phone_number", { length: 32 }).notNull(),
    shippingAddress: text("shipping_address").notNull(),
    trackingNumber: varchar("tracking_number", { length: 64 }),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow(),
  },
  (table) => ({
    userIdx: index("reward_redemptions_user_idx").on(table.userId),
  })
);

export const rewardRedemptionsRelations = relations(rewardRedemptions, ({ one }) => ({
  user: one(users, {
    fields: [rewardRedemptions.userId],
    references: [users.id],
  }),
  rewardItem: one(rewardItems, {
    fields: [rewardRedemptions.rewardItemId],
    references: [rewardItems.id],
  }),
}));