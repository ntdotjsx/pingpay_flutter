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

  // ── 4. Real User Account Distribution ─────────────────────────────
  const userDistribution = $derived.by(() => {
    if (!stats) return [];
    return [
      { label: 'Active', value: stats.activeUsers || 0, color: '#1aae39' },
      { label: 'Suspended', value: stats.suspendedUsers || 0, color: '#dd5b00' },
      { label: 'Banned', value: stats.bannedUsers || 0, color: '#c53030' },
    ];
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

  // ── 6. Real Calculated Behavioral KPIs ─────────────────────────────
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

<div>
  <div class="mb-6 flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">System & Behavioral Analytics</h1>
      <p class="text-xs text-[#615d59] mt-0.5">Live operational telemetry, user payback speed, payment channel adoption, and system health metrics from real database.</p>
    </div>
  </div>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
      <LoadingLottie text="Analyzing system metrics and user behavior from database..." size={160} />
    </div>
  {:else if error}
    <div class="rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030]">{error}</div>
  {:else if stats}
    <!-- High-Level KPI Stat Cards Grid (Real Counts) -->
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard label="Total Registered Users" value={stats.totalUsers} color="blue" />
      <StatCard label="Active Users" value={stats.activeUsers} color="green" />
      <StatCard label="Total Transactions" value={stats.totalTransactions} color="blue" />
      <StatCard label="Open Disputes" value={stats.openDisputes} color="yellow" />
      <StatCard label="Catalog Gift Items" value={stats.totalRewardItems ?? 0} color="green" />
      <StatCard label="Pending Redemptions" value={stats.pendingRedemptions ?? 0} color="yellow" />
      <StatCard label="Queued FCM Push" value={stats.pendingNotifications ?? 0} color="blue" />
      <StatCard label="Security Threat Events" value={(stats.securityEventsCount ?? 0) + (stats.suspiciousLogs ?? 0)} color="red" />
    </div>

    <!-- Real User Behavioral Insights Row -->
    <div class="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
      <!-- Behavioral Insight 1: PromptPay Adoption -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm flex items-center justify-between">
        <div>
          <span class="text-[10px] font-semibold uppercase tracking-wider text-[#615d59]">PromptPay In-App Adoption</span>
          <div class="mt-1 flex items-baseline gap-2">
            <span class="text-2xl font-bold text-[#0075de] tracking-tight">{promptPayAdoptionRate}%</span>
            <span class="text-xs text-[#615d59] font-medium font-mono">{promptPayAdoptionRate > 50 ? 'QR Dominant' : 'Cash/Transfer'}</span>
          </div>
          <p class="mt-1 text-[11px] text-[#615d59]">Payers using auto-generated PromptPay QR in-app</p>
        </div>
        <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[#e8f3fc] text-[#0075de]">
          <Icon name="card" class="h-5 w-5" />
        </div>
      </div>

      <!-- Behavioral Insight 2: Debt Acknowledgement Rate -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm flex items-center justify-between">
        <div>
          <span class="text-[10px] font-semibold uppercase tracking-wider text-[#615d59]">Debt Acceptance Index</span>
          <div class="mt-1 flex items-baseline gap-2">
            <span class="text-2xl font-bold text-[#1aae39] tracking-tight">{acknowledgementRate}%</span>
            <span class="text-xs text-[#1aae39] font-medium font-mono">{acknowledgementRate >= 70 ? 'High Trust' : 'Moderate'}</span>
          </div>
          <p class="mt-1 text-[11px] text-[#615d59]">Friends who acknowledged their assigned bill item</p>
        </div>
        <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[#e8f8eb] text-[#1aae39]">
          <Icon name="check" class="h-5 w-5" />
        </div>
      </div>

      <!-- Behavioral Insight 3: Payback Settlement Speed -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm flex items-center justify-between">
        <div>
          <span class="text-[10px] font-semibold uppercase tracking-wider text-[#615d59]">Average Payback Speed</span>
          <div class="mt-1 flex items-baseline gap-2">
            <span class="text-2xl font-bold text-[#000000] tracking-tight">{settlementSpeedText}</span>
            <span class="text-xs text-[#0075de] font-medium">From creation to payment</span>
          </div>
          <p class="mt-1 text-[11px] text-[#615d59]">Time debtor takes to settle confirmed payments</p>
        </div>
        <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[#f6f5f4] text-[#31302e]">
          <Icon name="zap" class="h-5 w-5 text-[#dd5b00]" />
        </div>
      </div>
    </div>

    <!-- Charts Row 1: Financial Trajectory & Payment Channels -->
    <div class="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
      <!-- 7-Day Financial Volume Area Chart -->
      <div class="lg:col-span-2">
        <AreaTrendChart
          data={trendData}
          title="7-Day Financial Settlement Volume"
          subtitle="Real daily transaction amount (THB) recorded in database"
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

    <!-- Charts Row 2: Bill Status Lifecycle & FCM Health -->
    <div class="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
      <!-- Bill Status Distribution Bar Chart -->
      <div class="lg:col-span-2">
        {#if billStatusItems.length > 0}
          <BarDistributionChart
            items={billStatusItems}
            title="Bill Lifecycle & Resolution Status"
            subtitle="Actual breakdown of bills in database"
            unit="bills"
          />
        {:else}
          <div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm h-full flex flex-col justify-center items-center text-center">
            <Icon name="transactions" class="h-8 w-8 text-[#a39e98] mb-2" />
            <h3 class="font-bold text-xs text-[#000000]">Bill Lifecycle & Resolution Status</h3>
            <p class="text-[11px] text-[#615d59] mt-1">No bills recorded in database yet.</p>
          </div>
        {/if}
      </div>

      <!-- Notification & Delivery Reliability -->
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

    <!-- Quick Management Hub -->
    <div class="mt-6">
      <h2 class="text-sm font-bold text-[#000000] mb-3">Management Quick Hub</h2>
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <a href="/rewards" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#1aae39] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#e8f8eb] text-[#1aae39] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="rewards" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#1aae39] transition-colors">Rewards Store</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Manage gift catalog and track shipment fulfillments.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#1aae39] group-hover:underline">Open Store &rarr;</span>
        </a>

        <a href="/notifications" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#0075de] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="notifications" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#0075de] transition-colors">FCM Notifications</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Broadcast push messages and monitor delivery queue.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#0075de] group-hover:underline">Open Outbox &rarr;</span>
        </a>

        <a href="/security" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#dd5b00] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#fef2e8] text-[#dd5b00] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="security" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#dd5b00] transition-colors">Security Events</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Inspect PIN lockout events and IP anomalies.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#dd5b00] group-hover:underline">View Events &rarr;</span>
        </a>

        <a href="/disputes" class="rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm hover:border-[#c53030] hover:shadow transition-all group flex flex-col justify-between">
          <div>
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#fde8e8] text-[#c53030] mb-2.5 group-hover:scale-105 transition-transform">
              <Icon name="disputes" class="h-4 w-4" />
            </div>
            <h3 class="font-bold text-xs text-[#000000] group-hover:text-[#c53030] transition-colors">Disputes</h3>
            <p class="mt-1 text-[11px] text-[#615d59]">Audit slip verifications and resolve bill conflicts.</p>
          </div>
          <span class="mt-3 text-[11px] font-semibold text-[#c53030] group-hover:underline">Review Cases &rarr;</span>
        </a>
      </div>
    </div>
  {/if}
</div>
