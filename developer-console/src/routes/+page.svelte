<script lang="ts">
  import { getDashboard, getAnalytics } from '$lib/api/client';
  import { onMount } from 'svelte';
  import StatCard from '$lib/components/StatCard.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';
  import AreaTrendChart from '$lib/components/charts/AreaTrendChart.svelte';
  import BarDistributionChart from '$lib/components/charts/BarDistributionChart.svelte';
  import DonutBreakdownChart from '$lib/components/charts/DonutBreakdownChart.svelte';

  let stats = $state<any>(null);
  let analytics = $state<any>(null);
  let loading = $state(true);
  let error = $state('');

  onMount(async () => {
    try {
      const [dashRes, analyticsRes] = await Promise.all([
        getDashboard(),
        getAnalytics().catch(() => ({ success: true, data: null })),
      ]);
      stats = dashRes.data;
      analytics = analyticsRes?.data || null;
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  });

  // ── 1. 7-Day Real Financial Volume Trend (from DB transactions) ──
  const trendData = $derived.by(() => {
    if (analytics?.dailyTransactions && analytics.dailyTransactions.length > 0) {
      return analytics.dailyTransactions.map((row: any) => ({
        label: String(row.date).slice(5), // MM-DD
        value: Number(row.sum || 0),
      }));
    }
    return [];
  });

  const total7DayVolume = $derived.by(() => {
    if (!analytics?.dailyTransactions) return 0;
    return analytics.dailyTransactions.reduce((acc: number, row: any) => acc + Number(row.sum || 0), 0);
  });

  const total7DayCount = $derived.by(() => {
    if (!analytics?.dailyTransactions) return 0;
    return analytics.dailyTransactions.reduce((acc: number, row: any) => acc + Number(row.count || 0), 0);
  });

  // ── 2. Real Payment Channels Distribution (User Behavior) ────────
  const paymentChannelSlices = $derived.by(() => {
    if (analytics?.paymentChannels && analytics.paymentChannels.length > 0) {
      const colorMap: Record<string, string> = {
        promptpay_qr: '#0075de',
        bank_transfer: '#8c52ff',
        cash: '#1aae39',
      };
      const labelMap: Record<string, string> = {
        promptpay_qr: 'PromptPay QR (In-App)',
        bank_transfer: 'Manual Bank Transfer',
        cash: 'Cash / Handover',
      };
      return analytics.paymentChannels.map((c: any) => ({
        label: labelMap[c.channel] || c.channel,
        value: Number(c.count || 0),
        color: colorMap[c.channel] || '#0075de',
      }));
    }
    return [];
  });

  // ── 3. Real Bill Settlement Status Breakdown ──────────────────────
  const billStatusItems = $derived.by(() => {
    if (analytics?.billStatuses && analytics.billStatuses.length > 0) {
      const colorMap: Record<string, string> = {
        fully_paid: '#1aae39',
        partially_paid: '#0075de',
        unpaid: '#dd5b00',
        partially_written_off: '#793400',
        fully_written_off: '#615d59',
        cancelled: '#a39e98',
      };
      return analytics.billStatuses.map((b: any) => ({
        label: b.status.replace(/_/g, ' '),
        value: Number(b.count || 0),
        color: colorMap[b.status] || '#0075de',
      }));
    }
    return [];
  });

  // ── 4. Real Payment Methods: Full vs Installment ──────────────────
  const paymentMethodSlices = $derived.by(() => {
    if (analytics?.paymentMethods && analytics.paymentMethods.length > 0) {
      const colorMap: Record<string, string> = {
        full: '#0075de',
        installment: '#dd5b00',
      };
      return analytics.paymentMethods.map((m: any) => ({
        label: m.method === 'full' ? 'Full Settlement' : 'Installment Split',
        value: Number(m.count || 0),
        color: colorMap[m.method] || '#0075de',
      }));
    }
    return [];
  });

  // ── 5. Real Notification Delivery Health ──────────────────────────
  const fcmDeliverySlices = $derived.by(() => {
    if (analytics?.fcmStatuses && analytics.fcmStatuses.length > 0) {
      const colorMap: Record<string, string> = {
        SENT: '#1aae39',
        PENDING: '#0075de',
        PROCESSING: '#dd5b00',
        FAILED: '#c53030',
        SKIPPED: '#615d59',
      };
      return analytics.fcmStatuses.map((f: any) => ({
        label: f.status,
        value: Number(f.count || 0),
        color: colorMap[f.status] || '#0075de',
      }));
    }
    return [];
  });

  // ── 6. Rewards Points Breakdown by Category ───────────────────────
  const rewardsCategoryItems = $derived.by(() => {
    if (analytics?.rewardsCategories && analytics.rewardsCategories.length > 0) {
      const colorMap: Record<string, string> = {
        physical: '#ff64c8',
        voucher: '#0075de',
        digital: '#1aae39',
      };
      return analytics.rewardsCategories.map((r: any) => ({
        label: r.category || 'General',
        value: Number(r.pointsSpent || 0),
        color: colorMap[r.category] || '#ff64c8',
      }));
    }
    return [];
  });

  // ── 7. Real Calculated Behavioral KPIs ─────────────────────────────
  const promptPayAdoptionRate = $derived.by(() => {
    if (!paymentChannelSlices.length) return 0;
    const total = paymentChannelSlices.reduce((acc: number, it: { value: number }) => acc + it.value, 0);
    const qr = paymentChannelSlices.find((it: { label: string; value: number }) => it.label.includes('PromptPay'))?.value || 0;
    return total > 0 ? Math.round((qr / total) * 100) : 0;
  });

  const acknowledgementRate = $derived.by(() => {
    if (analytics?.acknowledgementStats && analytics.acknowledgementStats.length > 0) {
      const ack = analytics.acknowledgementStats.find((s: any) => s.isAcknowledged === true)?.count || 0;
      const unack = analytics.acknowledgementStats.find((s: any) => s.isAcknowledged === false)?.count || 0;
      const tot = ack + unack;
      return tot > 0 ? Math.round((ack / tot) * 100) : 0;
    }
    return 0;
  });

  const settlementSpeedText = $derived.by(() => {
    const avgHours = analytics?.settlementDuration?.avgHours;
    if (!avgHours || avgHours <= 0) return 'No data';
    if (avgHours < 24) return `${Math.round(avgHours)} hrs`;
    return `${(avgHours / 24).toFixed(1)} days`;
  });
</script>

<div class="space-y-6">
  <!-- Header Title -->
  <div class="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">System & Behavioral Analytics</h1>
      <p class="text-xs text-[#615d59] mt-0.5">Live operational telemetry, financial settlement volume, debtor behavior indices, and database health.</p>
    </div>
  </div>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-8 shadow-sm">
      <LoadingLottie text="Querying database metrics and synthesizing behavioral analytics..." size={160} />
    </div>
  {:else if error}
    <div class="rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030]">{error}</div>
  {:else if stats}
    <!-- High-Level Primary KPI Stat Cards (10 Core Metrics) -->
    <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
      <StatCard label="Total Users" value={stats.totalUsers} color="blue" />
      <StatCard label="Active Users" value={stats.activeUsers} color="green" />
      <StatCard label="Financial Tx" value={stats.totalTransactions} color="blue" />
      <StatCard label="Open Disputes" value={stats.openDisputes} color="yellow" />
      <StatCard label="Security Threats" value={(stats.securityEventsCount ?? 0) + (stats.suspiciousLogs ?? 0)} color="red" />
      <StatCard label="Catalog Gifts" value={stats.totalRewardItems ?? 0} color="green" />
      <StatCard label="Pending Delivery" value={stats.pendingRedemptions ?? 0} color="yellow" />
      <StatCard label="Queued Push" value={stats.pendingNotifications ?? 0} color="blue" />
      <StatCard label="Suspended Users" value={stats.suspendedUsers ?? 0} color="yellow" />
      <StatCard label="Banned Accounts" value={stats.bannedUsers ?? 0} color="red" />
    </div>

    <!-- Real Behavioral Indices Row (High Trust & Financial Velocity) -->
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <!-- Behavioral Insight 1: PromptPay In-App QR Adoption -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm flex items-center justify-between">
        <div>
          <span class="text-[10px] font-semibold uppercase tracking-wider text-[#615d59]">PromptPay In-App Adoption</span>
          <div class="mt-1 flex items-baseline gap-2">
            <span class="text-2xl font-bold text-[#0075de] tracking-tight">{promptPayAdoptionRate}%</span>
            <span class="text-xs text-[#615d59] font-medium font-mono">{promptPayAdoptionRate > 50 ? 'QR Preferred' : 'Cash/Transfer'}</span>
          </div>
          <p class="mt-1 text-[11px] text-[#615d59]">Payers using auto-generated EMVCo PromptPay QR in-app</p>
        </div>
        <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-[#e8f3fc] text-[#0075de]">
          <Icon name="card" class="h-6 w-6" />
        </div>
      </div>

      <!-- Behavioral Insight 2: Debt Acknowledgement Acceptance Rate -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm flex items-center justify-between">
        <div>
          <span class="text-[10px] font-semibold uppercase tracking-wider text-[#615d59]">Debt Acceptance Index</span>
          <div class="mt-1 flex items-baseline gap-2">
            <span class="text-2xl font-bold text-[#1aae39] tracking-tight">{acknowledgementRate}%</span>
            <span class="text-xs text-[#1aae39] font-medium font-mono">{acknowledgementRate >= 70 ? 'High Trust' : 'Moderate'}</span>
          </div>
          <p class="mt-1 text-[11px] text-[#615d59]">Debtors who acknowledged/swiped their assigned debt item</p>
        </div>
        <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-[#e8f8eb] text-[#1aae39]">
          <Icon name="check" class="h-6 w-6" />
        </div>
      </div>

      <!-- Behavioral Insight 3: Payback Settlement Velocity -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm flex items-center justify-between">
        <div>
          <span class="text-[10px] font-semibold uppercase tracking-wider text-[#615d59]">Avg Payback Duration</span>
          <div class="mt-1 flex items-baseline gap-2">
            <span class="text-2xl font-bold text-[#000000] tracking-tight">{settlementSpeedText}</span>
            <span class="text-xs text-[#0075de] font-medium font-mono">From bill to payment</span>
          </div>
          <p class="mt-1 text-[11px] text-[#615d59]">Average elapsed time from debt creation to confirmed settlement</p>
        </div>
        <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-[#f6f5f4] text-[#31302e]">
          <Icon name="zap" class="h-6 w-6 text-[#dd5b00]" />
        </div>
      </div>
    </div>

    <!-- Financial Volume & Performance Bar Summary -->
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div class="flex items-center gap-3">
        <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[#e8f8eb] text-[#138029]">
          <span class="text-lg">💰</span>
        </div>
        <div>
          <h3 class="text-xs font-bold text-[#000000]">7-Day Settlement Velocity</h3>
          <p class="text-[11px] text-[#615d59]">Aggregate money moved across group bills in the last 7 days</p>
        </div>
      </div>
      <div class="flex items-center gap-6">
        <div>
          <span class="text-[10px] uppercase text-[#615d59] font-semibold block">7-Day Volume</span>
          <span class="text-lg font-bold font-mono text-[#000000]">฿{total7DayVolume.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
        </div>
        <div>
          <span class="text-[10px] uppercase text-[#615d59] font-semibold block">Total Movements</span>
          <span class="text-lg font-bold font-mono text-[#0075de]">{total7DayCount} tx</span>
        </div>
        <div>
          <span class="text-[10px] uppercase text-[#615d59] font-semibold block">Avg Tx Size</span>
          <span class="text-lg font-bold font-mono text-[#1aae39]">฿{total7DayCount > 0 ? (total7DayVolume / total7DayCount).toFixed(2) : '0.00'}</span>
        </div>
      </div>
    </div>

    <!-- Charts Grid Row 1: Financial Settlement Trend & Payment Channels -->
    <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
      <!-- 7-Day Financial Volume Area Trend Chart -->
      <div class="lg:col-span-2">
        <AreaTrendChart
          data={trendData}
          title="7-Day Financial Settlement Volume"
          subtitle="Daily transaction volume (THB) aggregated across all payments"
          unit="THB"
        />
      </div>

      <!-- Payment Channel Preference Donut Chart -->
      <div>
        {#if paymentChannelSlices.length > 0}
          <DonutBreakdownChart
            slices={paymentChannelSlices}
            title="User Payment Channel Preference"
            subtitle="Actual payment channels chosen by users in database"
            unit="payments"
          />
        {:else}
          <div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm h-full flex flex-col justify-center items-center text-center">
            <Icon name="card" class="h-8 w-8 text-[#a39e98] mb-2" />
            <h3 class="font-bold text-xs text-[#000000]">Payment Channel Preference</h3>
            <p class="text-[11px] text-[#615d59] mt-1">No payment transactions recorded in database yet.</p>
          </div>
        {/if}
      </div>
    </div>

    <!-- Charts Grid Row 2: Bill Status Lifecycle, Payment Method & FCM Delivery Health -->
    <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
      <!-- Bill Status Distribution Bar Chart -->
      <div>
        {#if billStatusItems.length > 0}
          <BarDistributionChart
            items={billStatusItems}
            title="Bill Lifecycle & Resolution Status"
            subtitle="Breakdown of bills recorded in database"
            unit="bills"
          />
        {:else}
          <div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm h-full flex flex-col justify-center items-center text-center">
            <Icon name="bills" class="h-8 w-8 text-[#a39e98] mb-2" />
            <h3 class="font-bold text-xs text-[#000000]">Bill Lifecycle & Resolution Status</h3>
            <p class="text-[11px] text-[#615d59] mt-1">No bills recorded in database yet.</p>
          </div>
        {/if}
      </div>

      <!-- Payment Method Split (Full vs Installment) -->
      <div>
        {#if paymentMethodSlices.length > 0}
          <DonutBreakdownChart
            slices={paymentMethodSlices}
            title="Settlement Method: Full vs Installment"
            subtitle="Debtor preference for paying in full vs multi-step installments"
            unit="tx"
          />
        {:else}
          <div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm h-full flex flex-col justify-center items-center text-center">
            <Icon name="payments" class="h-8 w-8 text-[#a39e98] mb-2" />
            <h3 class="font-bold text-xs text-[#000000]">Payment Methods Distribution</h3>
            <p class="text-[11px] text-[#615d59] mt-1">No payment records yet.</p>
          </div>
        {/if}
      </div>

      <!-- FCM Push Delivery Reliability -->
      <div>
        {#if fcmDeliverySlices.length > 0}
          <DonutBreakdownChart
            slices={fcmDeliverySlices}
            title="FCM Delivery Health"
            subtitle="Push notification status counts from outbox"
            unit="messages"
          />
        {:else}
          <div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm h-full flex flex-col justify-center items-center text-center">
            <Icon name="notifications" class="h-8 w-8 text-[#a39e98] mb-2" />
            <h3 class="font-bold text-xs text-[#000000]">FCM Delivery Health</h3>
            <p class="text-[11px] text-[#615d59] mt-1">No push notification records in database yet.</p>
          </div>
        {/if}
      </div>
    </div>

    <!-- Core Operational Domain Management Hub (8 Domain Shortcuts) -->
    <div class="space-y-3">
      <h2 class="text-sm font-bold text-[#000000]">Operational Domains Quick Hub</h2>
      <div class="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-4">
        <!-- Bills Explorer -->
        <a href="/bills" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#0075de] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="bills" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#0075de] transition-colors">Bills & OCR Split</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Inspect group receipts, itemized shares, and debtor allocations.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#0075de] group-hover:underline">Open Bills &rarr;</span>
        </a>

        <!-- Payments Explorer -->
        <a href="/payments" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#1aae39] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#e8f8eb] text-[#1aae39] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="payments" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#1aae39] transition-colors">Payments & Slips</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Examine EasySlip v2 verification payloads and PromptPay QR.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#1aae39] group-hover:underline">Open Payments &rarr;</span>
        </a>

        <!-- User Accounts -->
        <a href="/users" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#0075de] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="users" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#0075de] transition-colors">Users & Devices</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Inspect registered client hardware specs and manage account bans.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#0075de] group-hover:underline">Manage Users &rarr;</span>
        </a>

        <!-- Disputes -->
        <a href="/disputes" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#c53030] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#fde8e8] text-[#c53030] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="disputes" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#c53030] transition-colors">Dispute Cases</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Investigate payment conflicts and record official determinations.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#c53030] group-hover:underline">Review Cases ({stats.openDisputes}) &rarr;</span>
        </a>

        <!-- Rewards Store -->
        <a href="/rewards" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#ff64c8] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#fdf0f9] text-[#b82d8c] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="rewards" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#b82d8c] transition-colors">Rewards Store</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Manage gift catalog and update shipping delivery tracking numbers.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#b82d8c] group-hover:underline">Rewards Store &rarr;</span>
        </a>

        <!-- Notifications -->
        <a href="/notifications" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#0075de] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="notifications" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#0075de] transition-colors">FCM Push Outbox</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Broadcast push messages with banner images and retry failed outbox items.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#0075de] group-hover:underline">FCM Outbox &rarr;</span>
        </a>

        <!-- Security Events -->
        <a href="/security" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#dd5b00] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#fef2e8] text-[#dd5b00] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="security" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#dd5b00] transition-colors">Security Events</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Monitor PIN brute-force attempts, lockouts, and IP access patterns.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#dd5b00] group-hover:underline">Security Logs &rarr;</span>
        </a>

        <!-- Activity Logs -->
        <a href="/activity-logs" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#0075de] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="activity" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#0075de] transition-colors">Activity Stream</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Live feed of logins, bill splits, debt acceptances, and payments.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#0075de] group-hover:underline">Activity Stream &rarr;</span>
        </a>
      </div>
    </div>
  {/if}
</div>
