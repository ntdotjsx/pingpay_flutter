# Developer Console UI Redesign Specification (Notion Design Language)

- **Date:** 2026-08-21
- **Status:** Approved
- **Target App:** `developer-console` (SvelteKit + Tailwind CSS v4)
- **Reference:** `developer-console/DESIGN.md` (Notion Analysis)

---

## 1. Objective

Refactor the `developer-console` web administration portal to align with the Notion design language specified in `DESIGN.md`:
- Replace clinical gray (`bg-gray-100`) with warm paper canvas (`#f6f5f4`).
- Replace dark sidebar and generic green/emerald accents with clean Notion light document chrome, Notion Blue (`#0075de`), and playful sticker accents.
- Implement strict typography hierarchy using `Inter` with tight negative letter tracking on headings.
- Unify borders (`#e6e6e6`), border radiuses (`rounded-xs: 4px`, `rounded-sm: 5px`, `rounded-md: 8px`, `rounded-lg: 12px`, `rounded-xl: 16px`, `rounded-full: 9999px`), and layered micro-shadows.

---

## 2. Design Tokens & Theme Configuration

### 2.1 CSS Variables & Tailwind Theme (`src/routes/layout.css`)

```css
@import 'tailwindcss';
@plugin '@tailwindcss/forms';
@plugin '@tailwindcss/typography';

@theme {
  --font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;

  /* Notion Core Palette */
  --color-primary: #0075de;
  --color-primary-active: #005bab;
  --color-secondary: #213183;
  --color-canvas: #ffffff;
  --color-canvas-soft: #f6f5f4;
  --color-surface: #ffffff;
  --color-hairline: #e6e6e6;

  /* Ink Ramp */
  --color-ink: #000000;
  --color-ink-secondary: #31302e;
  --color-ink-muted: #615d59;
  --color-ink-faint: #a39e98;

  /* Decorative Sticker Palette */
  --color-sticker-sky: #62aef0;
  --color-sticker-purple: #d6b6f6;
  --color-sticker-purple-deep: #391c57;
  --color-sticker-pink: #ff64c8;
  --color-sticker-orange: #dd5b00;
  --color-sticker-orange-deep: #793400;
  --color-sticker-teal: #2a9d99;
  --color-sticker-green: #1aae39;
  --color-sticker-brown: #523410;

  /* Corner Radii */
  --radius-xs: 4px;
  --radius-sm: 5px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-xl: 16px;
  --radius-full: 9999px;
}
```

### 2.2 Global HTML Shell (`src/app.html`)
- Load `Inter` font weights (400, 500, 600, 700) via Google Fonts or CSS import.
- Apply `bg-[#f6f5f4] text-[#000000] antialiased` on `<body>`.

---

## 3. Component Architecture & Specifications

### 3.1 App Shell & Navigation (`src/routes/+layout.svelte`)
- **Container**: Full-height desktop app layout with warm canvas ground (`bg-[#f6f5f4]`).
- **Sidebar**:
  - Width: `w-64`, background `bg-[#f6f5f4]` (or `bg-white` with 1px right border `border-[#e6e6e6]`).
  - Brand Header: PingPay logo with Notion Blue `#0075de` icon badge and clean Inter typography.
  - Nav Rows:
    - Default: `text-[#31302e] hover:bg-[#eae8e5] rounded-[5px] px-3 py-2 text-sm font-medium transition-colors`.
    - Active: `bg-[#e8f3fc] text-[#0075de] font-semibold rounded-[5px]`.
  - User Badge & Sign-Out: Minimal card at bottom with avatar, user role badge, and utility sign-out action.

### 3.2 Login Page (`src/routes/login/+page.svelte`)
- Centered auth card on `#f6f5f4` canvas.
- Card chrome: `bg-white border border-[#e6e6e6] rounded-[16px] p-8 shadow-sm`.
- Buttons:
  - LINE Login: Pill CTA (`rounded-full bg-[#06C755] text-white font-bold`).
  - Mock Dev Login: Utility button (`rounded-[8px] border border-[#e6e6e6] bg-white text-[#31302e] hover:bg-[#f6f5f4] font-medium`).
  - Manual Token Login: Notion input styling (`rounded-[4px] border-[#e6e6e6]`).

### 3.3 Stat Card (`src/lib/components/StatCard.svelte`)
- Card surface: `bg-white border border-[#e6e6e6] rounded-[12px] p-5 shadow-sm`.
- Typography:
  - Metric label: `text-xs font-semibold text-[#615d59] uppercase tracking-wider`.
  - Value: `text-3xl font-bold text-[#000000] tracking-tight mt-2`.
- Sticker indicators: Decorative dot/badge matching the metric type (`#1aae39` for active, `#0075de` for total, `#dd5b00` for open/pending, `#e03e3e` for threat/banned).

### 3.4 Status Badge (`src/lib/components/StatusBadge.svelte`)
- Structure: Pill badge `rounded-full px-2.5 py-0.5 text-xs font-medium`.
- Color mapping:
  - `active`, `confirmed`, `paid`, `resolved_paid`, `payment`: `bg-[#e8f8eb] text-[#138029]`.
  - `pending_*`, `under_review`, `open`, `suspended`: `bg-[#fef2e8] text-[#b34900]`.
  - `banned`, `rejected`, `verification_failed`, `duplicate_slip`, `fake_slip_manipulation`, `multi_account_ip`: `bg-[#fde8e8] text-[#c53030]`.
  - `user`, `developer`, `debt_created`, `debt_adjusted`: `bg-[#e8f3fc] text-[#005bab]`.
  - `written_off`, `write_off`, `resolved_written_off`, `cancelled`: `bg-[#f0efed] text-[#45423f]`.
  - `refund`, `frequent_writeoff`: `bg-[#faeee3] text-[#793400]`.

### 3.5 Pagination (`src/lib/components/Pagination.svelte`)
- Structure: Quiet bottom bar with document page indicators.
- Utility buttons: `border border-[#e6e6e6] rounded-[8px] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] disabled:opacity-40`.
- Text: `text-xs text-[#615d59] font-mono`.

### 3.6 Data Tables & Filter Panels (All Routes)
- Filter Box: `bg-white border border-[#e6e6e6] rounded-[12px] p-4 shadow-sm mb-6`.
- Form Controls: `rounded-[4px] border border-[#e6e6e6] text-sm text-[#000000] focus:ring-1 focus:ring-[#0075de] focus:border-[#0075de]`.
- Table Container: `bg-white border border-[#e6e6e6] rounded-[12px] overflow-hidden shadow-sm`.
- Header (`thead`): `bg-[#f6f5f4] border-b border-[#e6e6e6] text-[11px] font-semibold uppercase text-[#615d59] tracking-wider`.
- Rows (`tbody`): Row border `border-b border-[#e6e6e6] last:border-b-0 hover:bg-[#faf9f8] transition-colors`.

---

## 4. Pages to Overhaul

1. `src/routes/+page.svelte` (Dashboard)
2. `src/routes/login/+page.svelte` (Login & Auth)
3. `src/routes/transactions/+page.svelte` (Transactions Explorer)
4. `src/routes/users/+page.svelte` (User Management)
5. `src/routes/users/[id]/+page.svelte` (User Detail)
6. `src/routes/disputes/+page.svelte` (Disputes List)
7. `src/routes/disputes/[id]/+page.svelte` (Dispute Detail & Determination)
8. `src/routes/activity-logs/+page.svelte` (Activity Logs)
9. `src/routes/suspicious/+page.svelte` (Suspicious Threat Logs & Flagging)
10. `src/routes/audit-logs/+page.svelte` (Admin Audit Log)
11. `src/routes/maintenance/+page.svelte` (Data Maintenance & Cleanup)

---

## 5. Verification Plan

- Run `npm run check` inside `developer-console` to ensure zero Svelte/TypeScript compiler errors.
- Run `npm run build` inside `developer-console` to ensure successful production build with Tailwind v4.
- Verify visually that all pages load with warm canvas (`#f6f5f4`), Notion Blue accents, and proper component hierarchy.
