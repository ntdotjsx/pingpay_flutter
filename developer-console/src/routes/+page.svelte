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
      <h1 class="text-2xl font-bold text-gray-900">Dashboard Overview</h1>
      <p class="text-sm text-gray-500">Live operational metrics and monitoring across PingPay</p>
    </div>
  </div>

  {#if loading}
    <div class="rounded-lg bg-white p-8 text-center shadow-sm">
      <p class="text-gray-500">Loading system metrics...</p>
    </div>
  {:else if error}
    <div class="rounded-md bg-red-50 p-4 text-red-700">{error}</div>
  {:else if stats}
    <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard label="Total Users" value={stats.totalUsers} color="blue" />
      <StatCard label="Active Users" value={stats.activeUsers} color="green" />
      <StatCard label="Suspended Users" value={stats.suspendedUsers} color="yellow" />
      <StatCard label="Banned Users" value={stats.bannedUsers} color="red" />
      <StatCard label="Open Disputes" value={stats.openDisputes} color="yellow" />
      <StatCard label="Total Transactions" value={stats.totalTransactions} color="blue" />
      <StatCard label="Suspicious Threat Logs" value={stats.suspiciousLogs} color="red" />
    </div>

    <!-- Quick Navigation Panels -->
    <div class="mt-8 grid grid-cols-1 gap-6 md:grid-cols-3">
      <a href="/transactions" class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm hover:border-blue-300 hover:shadow transition">
        <div class="text-2xl mb-2">💰</div>
        <h3 class="font-bold text-gray-900">Transactions Explorer</h3>
        <p class="mt-1 text-xs text-gray-500">Filter financial movements by user, group, date, and transaction type.</p>
      </a>

      <a href="/disputes" class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm hover:border-yellow-300 hover:shadow transition">
        <div class="text-2xl mb-2">⚖️</div>
        <h3 class="font-bold text-gray-900">Dispute Management</h3>
        <p class="mt-1 text-xs text-gray-500">Review transfer slips, check SlipOK verification hashes, and make determinations.</p>
      </a>

      <a href="/suspicious" class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm hover:border-red-300 hover:shadow transition">
        <div class="text-2xl mb-2">🚨</div>
        <h3 class="font-bold text-gray-900">Suspicious Activity Logs</h3>
        <p class="mt-1 text-xs text-gray-500">Investigate duplicate slips, multi-account abuse, and unusual write-offs.</p>
      </a>
    </div>
  {/if}
</div>
