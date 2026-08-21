<script lang="ts">
  import { getDashboard } from '$lib/api/client';
  import { onMount } from 'svelte';
  import StatCard from '$lib/components/StatCard.svelte';
  import Icon from '$lib/components/Icon.svelte';

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
        <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de] mb-3 group-hover:scale-105 transition-transform">
          <Icon name="transactions" class="h-5 w-5" />
        </div>
        <h3 class="font-bold text-sm text-[#000000] group-hover:text-[#0075de] transition-colors">Transactions Explorer</h3>
        <p class="mt-1 text-xs text-[#615d59] leading-relaxed">Filter financial movements by user, group, date, and transaction type.</p>
      </a>

      <a href="/disputes" class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm hover:border-[#dd5b00] hover:shadow transition-all group">
        <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[#fef2e8] text-[#dd5b00] mb-3 group-hover:scale-105 transition-transform">
          <Icon name="disputes" class="h-5 w-5" />
        </div>
        <h3 class="font-bold text-sm text-[#000000] group-hover:text-[#dd5b00] transition-colors">Dispute Management</h3>
        <p class="mt-1 text-xs text-[#615d59] leading-relaxed">Review transfer slips, check SlipOK verification hashes, and make determinations.</p>
      </a>

      <a href="/suspicious" class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm hover:border-[#e03e3e] hover:shadow transition-all group">
        <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[#fde8e8] text-[#e03e3e] mb-3 group-hover:scale-105 transition-transform">
          <Icon name="suspicious" class="h-5 w-5" />
        </div>
        <h3 class="font-bold text-sm text-[#000000] group-hover:text-[#e03e3e] transition-colors">Suspicious Activity Logs</h3>
        <p class="mt-1 text-xs text-[#615d59] leading-relaxed">Investigate duplicate slips, multi-account abuse, and unusual write-offs.</p>
      </a>
    </div>
  {/if}
</div>
