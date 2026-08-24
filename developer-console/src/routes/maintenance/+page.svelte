<script lang="ts">
  import {
    purgeActivityLogs,
    clearAllActivityLogs,
    clearAllSuspiciousLogs,
    clearAllAuditLogs,
    getDashboard,
    getDbStats,
  } from '$lib/api/client';
  import { onMount } from 'svelte';
  import Icon from '$lib/components/Icon.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let stats = $state<any>(null);
  let dbStats = $state<any>(null);
  let loading = $state(true);
  let dbStatsLoading = $state(true);
  let actionLoading = $state(false);
  let message = $state('');
  let error = $state('');

  async function loadData() {
    loading = true;
    dbStatsLoading = true;
    try {
      const [dashRes, dbRes] = await Promise.all([
        getDashboard(),
        getDbStats().catch(() => ({ success: true, data: null })),
      ]);
      stats = dashRes.data;
      dbStats = dbRes?.data || null;
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
      dbStatsLoading = false;
    }
  }

  async function refreshDbStats() {
    dbStatsLoading = true;
    try {
      const dbRes = await getDbStats();
      dbStats = dbRes.data;
    } catch (e: any) {
      error = e.message;
    } finally {
      dbStatsLoading = false;
    }
  }

  onMount(loadData);

  async function runCleanup(action: 'purge_old' | 'clear_activity' | 'clear_suspicious' | 'clear_audit') {
    let confirmText = '';
    if (action === 'purge_old') {
      confirmText = 'Purge regular activity logs older than 1 month? Suspicious logs will NOT be affected.';
    } else if (action === 'clear_activity') {
      confirmText = 'WARNING: Clear ALL regular activity logs? This will delete all user activity history.';
    } else if (action === 'clear_suspicious') {
      confirmText = 'WARNING: Clear ALL suspicious activity threat logs? This deletes all fraud detection records.';
    } else if (action === 'clear_audit') {
      confirmText = 'WARNING: Clear ALL admin audit trail logs?';
    }

    if (!confirm(confirmText)) return;

    actionLoading = true;
    message = '';
    error = '';

    try {
      if (action === 'purge_old') {
        const res = await purgeActivityLogs();
        message = res.message || 'Old regular logs (>1 month) purged successfully.';
      } else if (action === 'clear_activity') {
        const res = await clearAllActivityLogs();
        message = res.message || 'All activity logs cleared.';
      } else if (action === 'clear_suspicious') {
        const res = await clearAllSuspiciousLogs();
        message = res.message || 'All suspicious logs cleared.';
      } else if (action === 'clear_audit') {
        const res = await clearAllAuditLogs();
        message = res.message || 'All admin audit logs cleared.';
      }
      await loadData();
    } catch (e: any) {
      error = e.message;
    } finally {
      actionLoading = false;
    }
  }
</script>

<div class="space-y-6">
  <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">System Health & Maintenance</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Monitor live PostgreSQL database row metrics, purge stale logs, and manage system storage.</p>
    </div>
    <button
      onclick={refreshDbStats}
      disabled={dbStatsLoading}
      class="inline-flex h-8 items-center gap-1.5 rounded-md border border-[#e6e6e6] bg-white px-3 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] disabled:opacity-50 transition-colors self-start"
    >
      <span class={dbStatsLoading ? 'animate-spin' : ''}>🔄</span>
      <span>Refresh DB Counts</span>
    </button>
  </div>

  {#if message}
    <div class="rounded-lg border border-[#e8f8eb] bg-[#e8f8eb] p-3.5 text-xs text-[#138029] flex justify-between items-center shadow-sm">
      <div class="flex items-center gap-2">
        <span>✓</span>
        <span>{message}</span>
      </div>
      <button onclick={() => message = ''} class="text-[#138029] font-bold">&times;</button>
    </div>
  {/if}

  {#if error}
    <div class="rounded-lg border border-[#fde8e8] bg-[#fde8e8] p-3.5 text-xs text-[#c53030] flex justify-between items-center shadow-sm">
      <div class="flex items-center gap-2">
        <span>✕</span>
        <span>{error}</span>
      </div>
      <button onclick={() => error = ''} class="text-[#c53030] font-bold">&times;</button>
    </div>
  {/if}

  <!-- Live Database Metrics Card -->
  <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
    <div class="flex items-center justify-between mb-4">
      <div class="flex items-center gap-2.5">
        <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de]">
          <span class="text-sm font-bold">🗄️</span>
        </div>
        <div>
          <h2 class="text-sm font-bold text-[#000000]">Live Database Schema Table Counts</h2>
          <p class="text-[11px] text-[#615d59]">Actual rows stored across all 21 PostgreSQL tables</p>
        </div>
      </div>
      {#if dbStats}
        <span class="rounded-full bg-[#e8f8eb] px-2.5 py-0.5 text-[11px] font-semibold text-[#138029]">
          DB Connected
        </span>
      {/if}
    </div>

    {#if dbStatsLoading && !dbStats}
      <div class="py-6">
        <LoadingLottie text="Querying database table counts..." size={120} />
      </div>
    {:else if dbStats}
      <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
        <!-- Core Users & Relationships -->
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#615d59]">users</span>
          <div class="text-lg font-bold text-[#000000] mt-0.5">{dbStats.users?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#615d59]">friendships</span>
          <div class="text-lg font-bold text-[#000000] mt-0.5">{dbStats.friendships?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#615d59]">consent_records</span>
          <div class="text-lg font-bold text-[#000000] mt-0.5">{dbStats.consentRecords?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#615d59]">auth_identities</span>
          <div class="text-lg font-bold text-[#000000] mt-0.5">{dbStats.authIdentities?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#615d59]">auth_sessions</span>
          <div class="text-lg font-bold text-[#000000] mt-0.5">{dbStats.authSessions?.toLocaleString() ?? 0}</div>
        </div>

        <!-- Bills & Financial Movements -->
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#0075de]">bills</span>
          <div class="text-lg font-bold text-[#0075de] mt-0.5">{dbStats.bills?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#0075de]">bill_items</span>
          <div class="text-lg font-bold text-[#0075de] mt-0.5">{dbStats.billItems?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#1aae39]">payments</span>
          <div class="text-lg font-bold text-[#1aae39] mt-0.5">{dbStats.payments?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#1aae39]">payment_verifs</span>
          <div class="text-lg font-bold text-[#1aae39] mt-0.5">{dbStats.paymentVerifications?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#1aae39]">fin_transactions</span>
          <div class="text-lg font-bold text-[#1aae39] mt-0.5">{dbStats.financialTransactions?.toLocaleString() ?? 0}</div>
        </div>

        <!-- Logs, Security, Disputes -->
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#dd5b00]">disputes</span>
          <div class="text-lg font-bold text-[#dd5b00] mt-0.5">{dbStats.disputes?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#615d59]">edit_logs</span>
          <div class="text-lg font-bold text-[#000000] mt-0.5">{dbStats.editLogs?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#615d59]">activity_logs</span>
          <div class="text-lg font-bold text-[#000000] mt-0.5">{dbStats.activityLogs?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#c53030]">suspicious_logs</span>
          <div class="text-lg font-bold text-[#c53030] mt-0.5">{dbStats.suspiciousActivityLogs?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#6e2fb5]">admin_logs</span>
          <div class="text-lg font-bold text-[#6e2fb5] mt-0.5">{dbStats.adminActionLogs?.toLocaleString() ?? 0}</div>
        </div>

        <!-- Push, Rewards, Devices -->
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#0075de]">notification_outbox</span>
          <div class="text-lg font-bold text-[#0075de] mt-0.5">{dbStats.notificationOutbox?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#0075de]">notification_deliv</span>
          <div class="text-lg font-bold text-[#0075de] mt-0.5">{dbStats.notificationDeliveries?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#615d59]">device_tokens</span>
          <div class="text-lg font-bold text-[#000000] mt-0.5">{dbStats.deviceTokens?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#c53030]">security_events</span>
          <div class="text-lg font-bold text-[#c53030] mt-0.5">{dbStats.securityEvents?.toLocaleString() ?? 0}</div>
        </div>
        <div class="rounded-lg border border-[#f0efed] bg-[#fbfbfa] p-3">
          <span class="text-[10px] font-semibold uppercase text-[#ff64c8]">rewards (items/rdm)</span>
          <div class="text-lg font-bold text-[#000000] mt-0.5">{(dbStats.rewardItems ?? 0)} / {(dbStats.rewardRedemptions ?? 0)}</div>
        </div>
      </div>
    {:else}
      <p class="text-xs text-[#615d59] py-3 text-center">Unable to load database metrics. Check API connection.</p>
    {/if}
  </div>

  <!-- Cleanup & Maintenance Operations -->
  <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
    <!-- Activity Logs Cleanup -->
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
      <div class="flex items-center gap-3 mb-3">
        <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de]">
          <Icon name="activity" class="h-5 w-5" />
        </div>
        <div>
          <h2 class="text-sm font-bold text-[#000000]">Activity Logs Retention</h2>
          <p class="text-[11px] text-[#615d59]">Regular per-user event tracking ({dbStats?.activityLogs ?? stats?.activityLogs ?? 0} rows)</p>
        </div>
      </div>
      <p class="text-xs text-[#615d59] mb-5 leading-relaxed">
        Regular activity logs track logins, bills, and payments. Purge on the 1-month retention schedule or wipe completely.
      </p>
      <div class="flex flex-col gap-2.5">
        <button
          onclick={() => runCleanup('purge_old')}
          disabled={actionLoading}
          class="flex items-center justify-center gap-2 rounded-md border border-[#e6e6e6] bg-white px-4 py-2 text-xs font-medium text-[#dd5b00] shadow-sm hover:bg-[#fef2e8] active:scale-[0.99] disabled:opacity-50 transition-colors"
        >
          <Icon name="brush" class="h-3.5 w-3.5" />
          <span>Purge Old Logs (&gt;1 Month)</span>
        </button>
        <button
          onclick={() => runCleanup('clear_activity')}
          disabled={actionLoading}
          class="flex items-center justify-center gap-2 rounded-md bg-[#fde8e8] px-4 py-2 text-xs font-medium text-[#c53030] hover:bg-[#fbd5d5] active:scale-[0.99] disabled:opacity-50 transition-colors"
        >
          <Icon name="trash" class="h-3.5 w-3.5" />
          <span>Clear ALL Regular Activity Logs</span>
        </button>
      </div>
    </div>

    <!-- Suspicious Logs Cleanup -->
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
      <div class="flex items-center gap-3 mb-3">
        <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-[#fde8e8] text-[#c53030]">
          <Icon name="suspicious" class="h-5 w-5" />
        </div>
        <div>
          <h2 class="text-sm font-bold text-[#000000]">Suspicious Threat Logs</h2>
          <p class="text-[11px] text-[#615d59]">Security flags and fraud attempts ({dbStats?.suspiciousActivityLogs ?? stats?.suspiciousLogs ?? 0} rows)</p>
        </div>
      </div>
      <p class="text-xs text-[#615d59] mb-5 leading-relaxed">
        Suspicious logs are retained permanently by default for dispute evidence. Use this only when resetting test fraud data.
      </p>
      <div class="flex flex-col gap-2.5">
        <a
          href="/suspicious"
          class="flex items-center justify-center gap-2 rounded-md border border-[#e6e6e6] bg-white px-4 py-2 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
        >
          <span>Inspect Threat Logs &rarr;</span>
        </a>
        <button
          onclick={() => runCleanup('clear_suspicious')}
          disabled={actionLoading}
          class="flex items-center justify-center gap-2 rounded-md bg-[#c53030] px-4 py-2 text-xs font-medium text-white shadow-sm hover:bg-[#a82525] active:scale-[0.99] disabled:opacity-50 transition-colors"
        >
          <Icon name="trash" class="h-3.5 w-3.5" />
          <span>Clear ALL Suspicious Logs</span>
        </button>
      </div>
    </div>

    <!-- Admin Audit Logs Cleanup -->
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
      <div class="flex items-center gap-3 mb-3">
        <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-[#f5eefc] text-[#6e2fb5]">
          <Icon name="audit" class="h-5 w-5" />
        </div>
        <div>
          <h2 class="text-sm font-bold text-[#000000]">Admin Audit Trail</h2>
          <p class="text-[11px] text-[#615d59]">Developer actions & suspensions ({dbStats?.adminActionLogs ?? 0} rows)</p>
        </div>
      </div>
      <p class="text-xs text-[#615d59] mb-5 leading-relaxed">
        Admin action logs record all developer and administrator actions. You can wipe this audit history during local dev testing.
      </p>
      <div class="flex flex-col gap-2.5">
        <a
          href="/audit-logs"
          class="flex items-center justify-center gap-2 rounded-md border border-[#e6e6e6] bg-white px-4 py-2 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
        >
          <span>View Audit Log History &rarr;</span>
        </a>
        <button
          onclick={() => runCleanup('clear_audit')}
          disabled={actionLoading}
          class="flex items-center justify-center gap-2 rounded-md bg-[#c53030] px-4 py-2 text-xs font-medium text-white shadow-sm hover:bg-[#a82525] active:scale-[0.99] disabled:opacity-50 transition-colors"
        >
          <Icon name="trash" class="h-3.5 w-3.5" />
          <span>Clear ALL Admin Audit Logs</span>
        </button>
      </div>
    </div>

    <!-- Quick Navigation Explorer Card -->
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm flex flex-col justify-between">
      <div>
        <div class="flex items-center gap-3 mb-3">
          <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-[#e8f8eb] text-[#138029]">
            <Icon name="zap" class="h-5 w-5" />
          </div>
          <div>
            <h2 class="text-sm font-bold text-[#000000]">Core Domain Explorers</h2>
            <p class="text-[11px] text-[#615d59]">Navigate directly to domain tables</p>
          </div>
        </div>
        <ul class="text-xs text-[#615d59] space-y-1.5 mb-4">
          <li>• <strong class="text-[#000000]">Bills:</strong> Inspect OCR receipts, calculation breakdown, and split debts.</li>
          <li>• <strong class="text-[#000000]">Payments:</strong> Inspect EasySlip v2 verifications, transfer slips, and QR codes.</li>
          <li>• <strong class="text-[#000000]">Disputes:</strong> Investigate debtor claims and make determinations.</li>
          <li>• <strong class="text-[#000000]">Users:</strong> View registered client devices and manage suspensions.</li>
        </ul>
      </div>

      <div class="grid grid-cols-2 gap-2 border-t border-[#e6e6e6] pt-3">
        <a href="/bills" class="text-center rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-semibold text-[#0075de] hover:bg-[#e8f3fc] transition-colors">
          Bills &rarr;
        </a>
        <a href="/payments" class="text-center rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-semibold text-[#0075de] hover:bg-[#e8f3fc] transition-colors">
          Payments &rarr;
        </a>
        <a href="/transactions" class="text-center rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-semibold text-[#0075de] hover:bg-[#e8f3fc] transition-colors">
          Transactions &rarr;
        </a>
        <a href="/users" class="text-center rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-semibold text-[#0075de] hover:bg-[#e8f3fc] transition-colors">
          Users &rarr;
        </a>
      </div>
    </div>
  </div>
</div>
