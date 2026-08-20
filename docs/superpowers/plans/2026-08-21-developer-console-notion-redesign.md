# Developer Console Notion Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the `developer-console` administration web app to strictly match the Notion design system specified in `developer-console/DESIGN.md` and the design spec `docs/superpowers/specs/2026-08-21-developer-console-notion-design.md`.

**Architecture:** Implement design tokens in Tailwind v4 CSS variables (`src/routes/layout.css`), apply Inter typography and warm paper background (`#f6f5f4`) in `src/app.html`, redesign base primitives (`StatCard`, `StatusBadge`, `Pagination`), update the App Shell (`+layout.svelte`) with a clean light sidebar, and update all individual administrative page views.

**Tech Stack:** SvelteKit 2, Svelte 5 (Runes `$state`, `$derived`, `$props`), Tailwind CSS v4, TypeScript, Vite.

**Spec:** `docs/superpowers/specs/2026-08-21-developer-console-notion-design.md`

## Global Constraints

- Ground canvas color must be `--color-canvas-soft: #f6f5f4` (Warm Paper).
- Primary structural accent must be `--color-primary: #0075de` (Notion Blue).
- Hairline borders must be `--color-hairline: #e6e6e6`.
- Card surfaces must be pure white (`#ffffff`) with 1px hairline border and `rounded-[12px]`.
- Text inputs must be `rounded-[4px]`, border `border-[#e6e6e6]`, with Notion Blue focus rings.
- Utility buttons must be `rounded-[8px]`, `border-[#e6e6e6]`, text `#31302e`.
- Pill CTAs must be `rounded-full`.
- All Svelte 5 rune syntax must be valid (`$state`, `$derived`, `$props`, `let { ... } = $props()`).

---

### Task 1: Design Tokens and Global HTML Skeleton

**Files:**
- Modify: `developer-console/src/routes/layout.css`
- Modify: `developer-console/src/app.html`

- [ ] **Step 1: Update Tailwind theme variables in `src/routes/layout.css`**

Configure `@theme` block with Notion tokens:

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

- [ ] **Step 2: Update `src/app.html` with Inter font and document base style**

```html
<!doctype html>
<html lang="en">
	<head>
		<meta charset="utf-8" />
		<meta name="viewport" content="width=device-width, initial-scale=1" />
		<link rel="preconnect" href="https://fonts.googleapis.com">
		<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
		<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
		%sveltekit.head%
	</head>
	<body data-sveltekit-preload-data="hover" class="bg-[#f6f5f4] text-[#000000] antialiased selection:bg-[#cce5ff]">
		<div style="display: contents">%sveltekit.body%</div>
	</body>
</html>
```

- [ ] **Step 3: Verify TypeScript and Svelte compilation**

Run in `developer-console`: `npm run check`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add developer-console/src/routes/layout.css developer-console/src/app.html
git commit -m "style: configure notion design tokens and inter font"
```

---

### Task 2: Shared Component Primitives (`StatCard`, `StatusBadge`, `Pagination`)

**Files:**
- Modify: `developer-console/src/lib/components/StatCard.svelte`
- Modify: `developer-console/src/lib/components/StatusBadge.svelte`
- Modify: `developer-console/src/lib/components/Pagination.svelte`

- [ ] **Step 1: Rewrite `StatCard.svelte` to use Notion card chrome and sticker indicators**

```svelte
<script lang="ts">
  let { label, value, color = 'blue' }: { label: string; value: number | string; color?: string } = $props();

  const stickerMap: Record<string, { dot: string; bg: string }> = {
    blue: { dot: 'bg-[#0075de]', bg: 'bg-[#e8f3fc]' },
    green: { dot: 'bg-[#1aae39]', bg: 'bg-[#e8f8eb]' },
    yellow: { dot: 'bg-[#dd5b00]', bg: 'bg-[#fef2e8]' },
    red: { dot: 'bg-[#e03e3e]', bg: 'bg-[#fde8e8]' },
    purple: { dot: 'bg-[#d6b6f6]', bg: 'bg-[#f5eefc]' },
    gray: { dot: 'bg-[#615d59]', bg: 'bg-[#f0efed]' },
  };

  let sticker = $derived(stickerMap[color] || stickerMap.blue);
</script>

<div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm transition-all hover:border-[#d0d0d0]">
  <div class="flex items-center justify-between">
    <p class="text-xs font-semibold uppercase tracking-wider text-[#615d59]">{label}</p>
    <div class="h-2 w-2 rounded-full {sticker.dot}"></div>
  </div>
  <p class="mt-3 text-3xl font-bold tracking-tight text-[#000000]">{value}</p>
</div>
```

- [ ] **Step 2: Rewrite `StatusBadge.svelte` to match Notion badge pill spec**

```svelte
<script lang="ts">
  let { status, size = 'sm' }: { status: string; size?: 'sm' | 'md' } = $props();

  const colorMap: Record<string, string> = {
    active: 'bg-[#e8f8eb] text-[#138029]',
    confirmed: 'bg-[#e8f8eb] text-[#138029]',
    resolved_paid: 'bg-[#e8f8eb] text-[#138029]',
    paid: 'bg-[#e8f8eb] text-[#138029]',
    payment: 'bg-[#e8f8eb] text-[#138029]',
    user: 'bg-[#e8f3fc] text-[#005bab]',
    developer: 'bg-[#f5eefc] text-[#6e2fb5]',
    suspended: 'bg-[#fef2e8] text-[#b34900]',
    pending_verification: 'bg-[#fef2e8] text-[#b34900]',
    pending_owner_confirmation: 'bg-[#fef2e8] text-[#b34900]',
    under_review: 'bg-[#fef2e8] text-[#b34900]',
    open: 'bg-[#fef2e8] text-[#b34900]',
    debt_created: 'bg-[#e8f3fc] text-[#005bab]',
    debt_adjusted: 'bg-[#e8f3fc] text-[#005bab]',
    banned: 'bg-[#fde8e8] text-[#c53030]',
    rejected: 'bg-[#fde8e8] text-[#c53030]',
    verification_failed: 'bg-[#fde8e8] text-[#c53030]',
    resolved_rejected: 'bg-[#fde8e8] text-[#c53030]',
    duplicate_slip: 'bg-[#fde8e8] text-[#c53030]',
    multi_account_ip: 'bg-[#fde8e8] text-[#c53030]',
    fake_slip_manipulation: 'bg-[#fde8e8] text-[#c53030]',
    frequent_writeoff: 'bg-[#faeee3] text-[#793400]',
    frequent_bill_edit: 'bg-[#fef2e8] text-[#b34900]',
    cancelled: 'bg-[#f0efed] text-[#45423f]',
    written_off: 'bg-[#f0efed] text-[#45423f]',
    write_off: 'bg-[#f0efed] text-[#45423f]',
    resolved_written_off: 'bg-[#f0efed] text-[#45423f]',
    refund: 'bg-[#faeee3] text-[#793400]',
  };

  let sizeClass = $derived(size === 'md' ? 'px-3 py-1 text-xs font-semibold' : 'px-2.5 py-0.5 text-[11px] font-medium');
  let color = $derived(colorMap[status] || 'bg-[#e8f3fc] text-[#005bab]');
</script>

<span class="inline-flex items-center rounded-full {sizeClass} {color}">
  {status ? status.replace(/_/g, ' ') : '-'}
</span>
```

- [ ] **Step 3: Rewrite `Pagination.svelte` to match Notion utility controls**

```svelte
<script lang="ts">
  let { page = 1, total = 0, limit = 20, onPageChange }: {
    page: number; total: number; limit: number; onPageChange: (p: number) => void
  } = $props();

  const totalPages = $derived(Math.ceil(total / limit));
  const canPrev = $derived(page > 1);
  const canNext = $derived(page < totalPages);
</script>

{#if totalPages > 1}
<div class="mt-4 flex items-center justify-between px-2 py-3">
  <div class="text-xs text-[#615d59]">
    Showing <span class="font-medium text-[#000000]">{(page - 1) * limit + 1}</span> to
    <span class="font-medium text-[#000000]">{Math.min(page * limit, total)}</span> of
    <span class="font-medium text-[#000000]">{total}</span>
  </div>
  <div class="flex items-center gap-2">
    <button
      class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
      disabled={!canPrev}
      onclick={() => onPageChange(page - 1)}
    >
      Previous
    </button>
    <span class="px-2 text-xs font-mono text-[#615d59]">
      {page} / {totalPages}
    </span>
    <button
      class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
      disabled={!canNext}
      onclick={() => onPageChange(page + 1)}
    >
      Next
    </button>
  </div>
</div>
{/if}
```

- [ ] **Step 4: Verify type check**

Run: `npm run check`
Expected: 0 errors

- [ ] **Step 5: Commit**

```bash
git add developer-console/src/lib/components/StatCard.svelte developer-console/src/lib/components/StatusBadge.svelte developer-console/src/lib/components/Pagination.svelte
git commit -m "style: update StatCard, StatusBadge, and Pagination to Notion design"
```

---

### Task 3: App Shell & Sidebar (`src/routes/+layout.svelte`)

**Files:**
- Modify: `developer-console/src/routes/+layout.svelte`

- [ ] **Step 1: Rewrite `+layout.svelte` with light Notion sidebar and warm canvas**

```svelte
<script lang="ts">
  import './layout.css';
  import { page } from '$app/stores';
  import { isAuthenticated, clearToken, getMe } from '$lib/api/client';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  let { children } = $props();
  let mounted = $state(false);
  let authenticated = $state(false);
  let currentUser = $state<any>(null);

  const navItems = [
    { label: 'Dashboard', href: '/', icon: '📊' },
    { label: 'Transactions', href: '/transactions', icon: '💰' },
    { label: 'Activity Logs', href: '/activity-logs', icon: '📋' },
    { label: 'Suspicious', href: '/suspicious', icon: '🚨' },
    { label: 'Users', href: '/users', icon: '👥' },
    { label: 'Disputes', href: '/disputes', icon: '⚖️' },
    { label: 'Audit Log', href: '/audit-logs', icon: '🔍' },
    { label: 'Maintenance', href: '/maintenance', icon: '🧹' },
  ];

  function checkAuth() {
    if (typeof window === 'undefined') return;
    authenticated = isAuthenticated();
    if (!authenticated && $page.url.pathname !== '/login') {
      goto('/login');
    } else if (authenticated && !currentUser) {
      getMe().then((res) => {
        currentUser = res;
      }).catch(() => {});
    }
  }

  onMount(() => {
    mounted = true;
    checkAuth();
  });

  $effect(() => {
    if (mounted && $page.url.pathname) {
      checkAuth();
    }
  });

  function logout() {
    clearToken();
    currentUser = null;
    authenticated = false;
    goto('/login');
  }

  function isActive(href: string, currentPath: string): boolean {
    if (href === '/') return currentPath === '/';
    return currentPath.startsWith(href);
  }
</script>

<svelte:head>
  <title>PingPay Developer Console</title>
</svelte:head>

{#if !mounted}
  <div class="flex h-screen items-center justify-center bg-[#f6f5f4]">
    <p class="text-sm font-medium text-[#615d59]">Loading console...</p>
  </div>
{:else if !authenticated && $page.url.pathname !== '/login'}
  <div class="flex h-screen items-center justify-center bg-[#f6f5f4]">
    <p class="text-sm font-medium text-[#615d59]">Redirecting to login...</p>
  </div>
{:else if $page.url.pathname === '/login'}
  {@render children()}
{:else}
  <div class="flex h-screen bg-[#f6f5f4]">
    <!-- Notion Document Sidebar -->
    <aside class="flex w-64 flex-col border-r border-[#e6e6e6] bg-[#fbfbfa] text-[#000000]">
      <!-- Header / Brand -->
      <div class="flex h-14 items-center gap-3 border-b border-[#e6e6e6] px-5 bg-white">
        <div class="flex h-7 w-7 items-center justify-center rounded-[6px] bg-[#0075de] text-sm text-white shadow-sm font-bold">
          💳
        </div>
        <div class="min-w-0">
          <h1 class="text-sm font-bold tracking-tight text-[#000000]">PingPay</h1>
          <span class="block text-[10px] font-semibold text-[#0075de] uppercase tracking-wider">Console</span>
        </div>
      </div>

      <!-- Navigation Links -->
      <nav class="flex-1 space-y-0.5 px-3 py-3 overflow-y-auto">
        {#each navItems as item}
          <a
            href={item.href}
            class="flex items-center gap-2.5 rounded-[5px] px-2.5 py-1.5 text-xs font-medium transition-colors {isActive(item.href, $page.url.pathname) ? 'bg-[#e8f3fc] text-[#0075de] font-semibold' : 'text-[#31302e] hover:bg-[#eae8e5]'}"
          >
            <span class="text-sm">{item.icon}</span>
            <span>{item.label}</span>
          </a>
        {/each}
      </nav>

      <!-- Current User Section -->
      {#if currentUser}
        <div class="border-t border-[#e6e6e6] bg-white p-3">
          <div class="flex items-center gap-2.5">
            {#if currentUser.avatarUrl}
              <img src={currentUser.avatarUrl} alt="" class="h-8 w-8 rounded-full object-cover border border-[#e6e6e6]" />
            {:else}
              <div class="flex h-8 w-8 items-center justify-center rounded-full bg-[#0075de] text-xs font-bold text-white">
                {(currentUser.displayName || 'A')[0]}
              </div>
            {/if}
            <div class="flex-1 min-w-0">
              <div class="text-xs font-semibold text-[#000000] truncate">{currentUser.displayName || 'Developer Admin'}</div>
              <div class="flex items-center gap-1 mt-0.5">
                <span class="inline-block h-1.5 w-1.5 rounded-full bg-[#1aae39]"></span>
                <span class="text-[10px] text-[#615d59] uppercase font-mono">{currentUser.role || 'developer'}</span>
              </div>
            </div>
          </div>
        </div>
      {/if}

      <!-- Sign Out -->
      <div class="border-t border-[#e6e6e6] p-2 bg-[#fbfbfa]">
        <button
          onclick={logout}
          class="flex w-full items-center gap-2 rounded-[5px] px-2.5 py-1.5 text-left text-xs font-medium text-[#c53030] hover:bg-[#fde8e8] transition-colors"
        >
          <span>🚪</span>
          <span>Sign Out</span>
        </button>
      </div>
    </aside>

    <!-- Main Content Area -->
    <main class="flex-1 overflow-auto p-8">
      {@render children()}
    </main>
  </div>
{/if}
```

- [ ] **Step 2: Verify type check**

Run: `npm run check`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add developer-console/src/routes/+layout.svelte
git commit -m "style: restyle app shell and sidebar with Notion aesthetic"
```

---

### Task 4: Login & Authentication Page (`src/routes/login/+page.svelte`)

**Files:**
- Modify: `developer-console/src/routes/login/+page.svelte`

- [ ] **Step 1: Restyle `login/+page.svelte` with Notion auth card chrome**

```svelte
<script lang="ts">
  import { setToken, verifyLineToken } from '$lib/api/client';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';

  let token = $state('');
  let error = $state('');
  let loading = $state(false);
  let showAdvanced = $state(false);

  let mockDevUser = $state({
    mockLineUserId: 'line_admin_dev_001',
    mockDisplayName: 'Admin Developer',
  });

  onMount(async () => {
    const queryToken = $page.url.searchParams.get('token');
    const queryError = $page.url.searchParams.get('error');

    if (queryError) {
      error = decodeURIComponent(queryError);
    } else if (queryToken) {
      setToken(queryToken);
      window.location.replace('/');
    }
  });

  function handleLineOAuthRedirect() {
    window.location.href = 'http://localhost:3000/api/v1/auth/line';
  }

  async function handleMockLineLogin() {
    loading = true;
    error = '';
    try {
      const res = await verifyLineToken({
        mockLineUserId: mockDevUser.mockLineUserId,
        mockDisplayName: mockDevUser.mockDisplayName,
      });
      if (res.accessToken) {
        goto('/');
      }
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  function handleManualTokenLogin() {
    if (!token.trim()) {
      error = 'Please enter an access token';
      return;
    }
    setToken(token.trim());
    goto('/');
  }
</script>

<div class="flex min-h-screen items-center justify-center bg-[#f6f5f4] p-4">
  <div class="w-full max-w-md rounded-2xl bg-white p-8 shadow-sm border border-[#e6e6e6]">
    <div class="text-center mb-6">
      <div class="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-xl bg-[#0075de] text-xl text-white shadow-sm">
        💳
      </div>
      <h1 class="text-xl font-bold text-[#000000] tracking-tight">PingPay Developer Console</h1>
      <p class="mt-1 text-xs text-[#615d59]">Administration & developer portal</p>
    </div>

    {#if error}
      <div class="mb-5 rounded-md border border-[#fde8e8] bg-[#fde8e8] p-3 text-xs text-[#c53030] flex items-center gap-2">
        <svg class="h-4 w-4 flex-shrink-0" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
        <span>{error}</span>
      </div>
    {/if}

    <div class="space-y-3.5">
      <!-- Primary LINE Login Button -->
      <button
        onclick={handleLineOAuthRedirect}
        disabled={loading}
        class="flex w-full items-center justify-center gap-2.5 rounded-full bg-[#06C755] px-5 py-3 text-sm font-bold text-white shadow-sm transition-all hover:bg-[#05B34C] active:scale-[0.99] disabled:opacity-50"
      >
        <svg class="h-5 w-5 fill-current" viewBox="0 0 24 24">
          <path d="M24 10.304c0-5.369-5.383-9.738-12-9.738-6.616 0-12 4.369-12 9.738 0 4.814 4.269 8.846 10.019 9.587.39.084.922.258 1.057.592.121.303.079.778.039 1.085l-.171 1.027c-.053.303-.242 1.186 1.039.647 1.281-.54 6.911-4.069 9.428-6.967 1.739-1.907 2.589-3.844 2.589-5.971z"/>
        </svg>
        <span>Log in with LINE</span>
      </button>

      <!-- Mock LINE Dev Login -->
      <div class="relative my-3">
        <div class="absolute inset-0 flex items-center"><div class="w-full border-t border-[#e6e6e6]"></div></div>
        <div class="relative flex justify-center text-[10px] uppercase"><span class="bg-white px-2 text-[#a39e98] font-mono">Dev Mode</span></div>
      </div>

      <button
        onclick={handleMockLineLogin}
        disabled={loading}
        class="flex w-full items-center justify-center gap-2 rounded-md border border-[#e6e6e6] bg-white px-4 py-2.5 text-xs font-semibold text-[#31302e] shadow-sm hover:bg-[#f6f5f4] active:scale-[0.99] disabled:opacity-50 transition-colors"
      >
        <span>⚡ Mock LINE Developer Login</span>
      </button>

      <!-- Advanced JWT Token Input Toggle -->
      <div class="pt-2 text-center">
        <button
          onclick={() => showAdvanced = !showAdvanced}
          class="text-[11px] text-[#615d59] hover:text-[#000000] underline"
        >
          {showAdvanced ? 'Hide manual JWT token login' : 'Advanced: Paste JWT access token directly'}
        </button>

        {#if showAdvanced}
          <div class="mt-3 space-y-3 rounded-lg bg-[#fbfbfa] p-3.5 border border-[#e6e6e6] text-left">
            <div>
              <label for="token-input" class="block text-[11px] font-medium text-[#615d59]">Access Token (JWT)</label>
              <textarea
                id="token-input"
                bind:value={token}
                rows={3}
                class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs font-mono shadow-sm focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none"
                placeholder="eyJhbGciOiJIUzI1NiIs..."
              ></textarea>
            </div>
            <button
              onclick={handleManualTokenLogin}
              class="w-full rounded-md bg-[#0075de] px-3 py-1.5 text-xs font-medium text-white hover:bg-[#005bab] transition-colors"
            >
              Sign In with Token
            </button>
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Commit**

```bash
git add developer-console/src/routes/login/+page.svelte
git commit -m "style: apply Notion card and button styling to login page"
```

---

### Task 5: Dashboard Overview Page (`src/routes/+page.svelte`)

**Files:**
- Modify: `developer-console/src/routes/+page.svelte`

- [ ] **Step 1: Restyle `+page.svelte` overview metrics and quick action cards**

```svelte
<script lang="ts">
  import { getDashboard } from '$lib/api/client';
  import { onMount } from 'svelte';
  import StatCard from '$lib/components/StatCard.svelte';

  let stats = $state<any>(null);
  let loading = $state(true);
  let error = $state('');

  onMount(async () => {
    try {
      const res = await getDashboard();
      stats = res.data;
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  });
</script>

<div>
  <div class="mb-6 flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Dashboard Overview</h1>
      <p class="text-xs text-[#615d59] mt-0.5">Live operational metrics and monitoring across PingPay</p>
    </div>
  </div>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-8 text-center shadow-sm">
      <p class="text-xs text-[#615d59]">Loading system metrics...</p>
    </div>
  {:else if error}
    <div class="rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030]">{error}</div>
  {:else if stats}
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard label="Total Users" value={stats.totalUsers} color="blue" />
      <StatCard label="Active Users" value={stats.activeUsers} color="green" />
      <StatCard label="Suspended Users" value={stats.suspendedUsers} color="yellow" />
      <StatCard label="Banned Users" value={stats.bannedUsers} color="red" />
      <StatCard label="Open Disputes" value={stats.openDisputes} color="yellow" />
      <StatCard label="Total Transactions" value={stats.totalTransactions} color="blue" />
      <StatCard label="Suspicious Threat Logs" value={stats.suspiciousLogs} color="red" />
    </div>

    <!-- Quick Navigation Panels -->
    <div class="mt-6 grid grid-cols-1 gap-4 md:grid-cols-3">
      <a href="/transactions" class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm hover:border-[#0075de] hover:shadow transition-all group">
        <div class="text-2xl mb-2">💰</div>
        <h3 class="font-bold text-sm text-[#000000] group-hover:text-[#0075de] transition-colors">Transactions Explorer</h3>
        <p class="mt-1 text-xs text-[#615d59] leading-relaxed">Filter financial movements by user, group, date, and transaction type.</p>
      </a>

      <a href="/disputes" class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm hover:border-[#dd5b00] hover:shadow transition-all group">
        <div class="text-2xl mb-2">⚖️</div>
        <h3 class="font-bold text-sm text-[#000000] group-hover:text-[#dd5b00] transition-colors">Dispute Management</h3>
        <p class="mt-1 text-xs text-[#615d59] leading-relaxed">Review transfer slips, check SlipOK verification hashes, and make determinations.</p>
      </a>

      <a href="/suspicious" class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm hover:border-[#e03e3e] hover:shadow transition-all group">
        <div class="text-2xl mb-2">🚨</div>
        <h3 class="font-bold text-sm text-[#000000] group-hover:text-[#e03e3e] transition-colors">Suspicious Activity Logs</h3>
        <p class="mt-1 text-xs text-[#615d59] leading-relaxed">Investigate duplicate slips, multi-account abuse, and unusual write-offs.</p>
      </a>
    </div>
  {/if}
</div>
```

- [ ] **Step 2: Commit**

```bash
git add developer-console/src/routes/+page.svelte
git commit -m "style: apply Notion overview card layout to dashboard"
```

---

### Task 6: Transactions, Activity Logs, and Suspicious Logs Pages

**Files:**
- Modify: `developer-console/src/routes/transactions/+page.svelte`
- Modify: `developer-console/src/routes/activity-logs/+page.svelte`
- Modify: `developer-console/src/routes/suspicious/+page.svelte`

- [ ] **Step 1: Update `transactions/+page.svelte` filters, tables, and pagination**

Update inputs (`rounded-[4px] border-[#e6e6e6]`), filter card (`rounded-xl border border-[#e6e6e6] bg-white`), button (`rounded-md bg-[#0075de] hover:bg-[#005bab]`), table headers (`bg-[#f6f5f4] text-[#615d59] border-b border-[#e6e6e6]`), and table rows.

- [ ] **Step 2: Update `activity-logs/+page.svelte` with Notion styling**

Update event stream view with clean Notion table styling, inputs, and filters.

- [ ] **Step 3: Update `suspicious/+page.svelte` with Notion modal, cards, and threat badges**

Update filter boxes, threat flagging form (`rounded-xl bg-white border border-[#e6e6e6]`), inspect modal (`bg-white rounded-xl border border-[#e6e6e6] shadow-lg`), and table chrome.

- [ ] **Step 4: Verify type check**

Run: `npm run check`
Expected: 0 errors

- [ ] **Step 5: Commit**

```bash
git add developer-console/src/routes/transactions/+page.svelte developer-console/src/routes/activity-logs/+page.svelte developer-console/src/routes/suspicious/+page.svelte
git commit -m "style: apply Notion design to transactions, activity logs, and suspicious logs"
```

---

### Task 7: User Management and User Detail Pages

**Files:**
- Modify: `developer-console/src/routes/users/+page.svelte`
- Modify: `developer-console/src/routes/users/[id]/+page.svelte`

- [ ] **Step 1: Update `users/+page.svelte` list, filter panel, and action modals**

Update table, filter inputs, action buttons (Suspend, Ban, Restore), and action confirmation modal with Notion utility buttons and inputs.

- [ ] **Step 2: Update `users/[id]/+page.svelte` detail cards, metadata view, and tabs**

Style user profile card, financial summary cards, account status chips, and action triggers according to Notion component specs.

- [ ] **Step 3: Verify type check**

Run: `npm run check`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add developer-console/src/routes/users/+page.svelte developer-console/src/routes/users/\[id\]/+page.svelte
git commit -m "style: apply Notion design to user list and user detail screens"
```

---

### Task 8: Disputes and Dispute Detail Pages

**Files:**
- Modify: `developer-console/src/routes/disputes/+page.svelte`
- Modify: `developer-console/src/routes/disputes/[id]/+page.svelte`

- [ ] **Step 1: Update `disputes/+page.svelte` dispute table and status filters**

Update dispute cards, status pills, and review links.

- [ ] **Step 2: Update `disputes/[id]/+page.svelte` determination panel, slip inspector, and evidence viewer**

Update slip image viewer (`rounded-xl border border-[#e6e6e6] bg-white`), SlipOK verification hash cards, and resolution action buttons (Approve Payment, Write Off, Reject Dispute).

- [ ] **Step 3: Verify type check**

Run: `npm run check`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add developer-console/src/routes/disputes/+page.svelte developer-console/src/routes/disputes/\[id\]/+page.svelte
git commit -m "style: apply Notion design to disputes list and dispute resolution detail"
```

---

### Task 9: Audit Logs and System Maintenance Pages

**Files:**
- Modify: `developer-console/src/routes/audit-logs/+page.svelte`
- Modify: `developer-console/src/routes/maintenance/+page.svelte`

- [ ] **Step 1: Update `audit-logs/+page.svelte` admin action log table and metadata viewers**

Update audit log table, timestamp formatting, filter controls, and action badges.

- [ ] **Step 2: Update `maintenance/+page.svelte` cleanup cards and purge controls**

Update maintenance feature cards (`rounded-xl border border-[#e6e6e6] bg-white`), warning alerts, and purge action buttons (`rounded-md bg-[#c53030] hover:bg-[#a82525]`).

- [ ] **Step 3: Verify type check**

Run: `npm run check`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add developer-console/src/routes/audit-logs/+page.svelte developer-console/src/routes/maintenance/+page.svelte
git commit -m "style: apply Notion design to audit logs and maintenance screens"
```

---

### Task 10: Full Build & End-to-End Verification

**Files:**
- Test: All SvelteKit routes and components in `developer-console/`

- [ ] **Step 1: Run type checking and Svelte compiler check**

Run in `developer-console`:
`npm run check`
Expected: 0 errors, 0 warnings

- [ ] **Step 2: Run production build**

Run in `developer-console`:
`npm run build`
Expected: Successful build output in `.svelte-kit/output`

- [ ] **Step 3: Run existing unit tests**

Run in `developer-console`:
`npm run test`
Expected: All tests pass

- [ ] **Step 4: Final commit and verify git status**

```bash
git status
```
