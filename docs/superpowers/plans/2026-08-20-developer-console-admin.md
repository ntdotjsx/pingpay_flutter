# Developer Console Admin Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a comprehensive back-office Developer Console and Elysia backend admin suite covering transactions explorer, 1-month retention activity logs, account ban/suspension, suspicious activity monitoring, and dispute determination.

**Architecture:** ElysiaJS backend with Drizzle ORM queries and an admin guard requiring `developer` role. SvelteKit frontend (Svelte 5 runes) with TailwindCSS, connecting via typed API client in `$lib/api/client.ts`.

**Tech Stack:** SvelteKit 2, Svelte 5, Tailwind CSS, TypeScript, ElysiaJS, Drizzle ORM, PostgreSQL.

---

### Task 1: Transactions Explorer (Filterable by User, Group, Period, Status)

**Files:**
- Modify: `elysia-api/src/modules/admin/admin.repository.ts`
- Modify: `elysia-api/src/modules/admin/admin.service.ts`
- Modify: `developer-console/src/routes/transactions/+page.svelte`

**Interfaces:**
- `getTransactions(filters: { userId?: string; groupId?: string; type?: string; dateFrom?: string; dateTo?: string; page?: number; limit?: number })`

- [ ] **Step 1: Update `admin.repository.ts` to support combined group, user, type, and date filters**
- [ ] **Step 2: Update `transactions/+page.svelte` with reactive filters, clean table formatting, pagination**
- [ ] **Step 3: Test transactions filtering by user, group, date, and status**

---

### Task 2: Activity Logs & Retention Policy (1-Month Auto-Purge vs Suspicious Retention)

**Files:**
- Modify: `elysia-api/src/modules/admin/admin.repository.ts`
- Modify: `elysia-api/src/modules/admin/admin.service.ts`
- Modify: `developer-console/src/routes/activity-logs/+page.svelte`

**Interfaces:**
- `getActivityLogs(filters: { userId?: string; action?: string; dateFrom?: string; dateTo?: string; page?: number; limit?: number })`
- `purgeActivityLogs()` (purges regular activity logs older than 30 days without deleting suspicious logs)

- [ ] **Step 1: Verify `deleteOldActivityLogs` only deletes `activityLogs`, leaving `suspiciousActivityLogs` untouched**
- [ ] **Step 2: Enhance `activity-logs/+page.svelte` with filter inputs, JSON metadata modal/formatter, and purge action**
- [ ] **Step 3: Test activity logs loading and purge functionality**

---

### Task 3: Account Suspension and Banning System

**Files:**
- Modify: `developer-console/src/routes/users/+page.svelte`
- Modify: `developer-console/src/routes/users/[id]/+page.svelte`
- Modify: `elysia-api/src/modules/admin/admin.service.ts`

**Interfaces:**
- `suspendUser(id: string, reason: string, durationDays?: number)`
- `banUser(id: string, reason: string)`
- `unsuspendUser(id: string, reason: string)`

- [ ] **Step 1: Ensure user detail page allows suspending with custom duration (e.g. 7 days, 30 days) or permanent ban with reason**
- [ ] **Step 2: Ensure developer accounts cannot be banned or suspended**
- [ ] **Step 3: Display account status badge, suspension end date, and audit log entries on user detail page**

---

### Task 4: Suspicious Activity Detection and Logging

**Files:**
- Modify: `elysia-api/src/modules/admin/admin.service.ts`
- Modify: `elysia-api/src/modules/payments/slip-verification.service.ts`
- Modify: `developer-console/src/routes/suspicious/+page.svelte`

**Interfaces:**
- `getSuspiciousLogs(filters: { userId?: string; type?: string; dateFrom?: string; dateTo?: string; page?: number; limit?: number })`
- `flagSuspicious(data: { userId?: string; type: string; description: string; metadata?: any })`

- [ ] **Step 1: Check automatic flagging for duplicate slips, multi-account IP, frequent write-offs, and frequent bill edits**
- [ ] **Step 2: Enhance `suspicious/+page.svelte` UI with filter badges, manual flag creation, and metadata inspector**
- [ ] **Step 3: Test querying and creating suspicious logs**

---

### Task 5: Dispute Management System & Slip/Log Determination

**Files:**
- Modify: `developer-console/src/routes/disputes/+page.svelte`
- Modify: `developer-console/src/routes/disputes/[id]/+page.svelte`
- Modify: `elysia-api/src/modules/admin/admin.service.ts`

**Interfaces:**
- `getDisputes(filters: { status?: string; dateFrom?: string; dateTo?: string; page?: number; limit?: number })`
- `getDisputeDetail(id: string)` -> returns `{ dispute, editHistory }`
- `resolveDispute(id: string, status: 'resolved_paid' | 'resolved_written_off' | 'resolved_rejected', note: string)`

- [ ] **Step 1: Provide full dispute context: debtor claim, bill owner, amount, slip images, slipok hash/reference, verification records, bill edit logs**
- [ ] **Step 2: Provide review state transition (`under_review`) and final determination (`resolved_paid`, `resolved_written_off`, `resolved_rejected`) with mandatory note**
- [ ] **Step 3: Test dispute resolution flow and audit logging**
