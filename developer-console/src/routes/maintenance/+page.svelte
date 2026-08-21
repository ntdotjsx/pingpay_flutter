<script lang="ts">
  import {
    purgeActivityLogs,
    clearAllActivityLogs,
    clearAllSuspiciousLogs,
    clearAllAuditLogs,
    getDashboard,
  } from '$lib/api/client';
  import { onMount } from 'svelte';
  import Icon from '$lib/components/Icon.svelte';

  let stats = $state<any>(null);
  let loading = $state(true);
  let actionLoading = $state(false);
  let message = $state('');
  let error = $state('');

  async function loadStats() {
    loading = true;
    try {
      const res = await getDashboard();
      stats = res.data;
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  onMount(loadStats);

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
      await loadStats();
    } catch (e: any) {
      error = e.message;
    } finally {
      actionLoading = false;
    }
  }
</script>

<div>
  <div class="mb-6">
    <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Data Cleanup & System Maintenance</h1>
    <p class="mt-0.5 text-xs text-[#615d59]">Purge, clean, and manage system log records and database state.</p>
  </div>

  {#if message}
    <div class="mb-5 rounded-lg border border-[#e8f8eb] bg-[#e8f8eb] p-3.5 text-xs text-[#138029] flex justify-between items-center shadow-sm">
      <div class="flex items-center gap-2">
        <span>✓</span>
        <span>{message}</span>
      </div>
      <button onclick={() => message = ''} class="text-[#138029] font-bold">&times;</button>
    </div>
  {/if}

  {#if error}
    <div class="mb-5 rounded-lg border border-[#fde8e8] bg-[#fde8e8] p-3.5 text-xs text-[#c53030] flex justify-between items-center shadow-sm">
      <div class="flex items-center gap-2">
        <span>✕</span>
        <span>{error}</span>
      </div>
      <button onclick={() => error = ''} class="text-[#c53030] font-bold">&times;</button>
    </div>
  {/if}

  <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
    <!-- Activity Logs Cleanup -->
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
      <div class="flex items-center gap-3 mb-3">
        <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de]">
          <Icon name="activity" class="h-5 w-5" />
        </div>
        <div>
          <h2 class="text-sm font-bold text-[#000000]">Activity Logs Cleanup</h2>
          <p class="text-[11px] text-[#615d59]">Regular per-user / group event tracking</p>
        </div>
      </div>
      <p class="text-xs text-[#615d59] mb-5 leading-relaxed">
        Regular activity logs track logins, bills, and payments. They can be purged on the 1-month retention schedule or wiped completely.
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
          <p class="text-[11px] text-[#615d59]">Security flags, fraud attempts, duplicate slips</p>
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
          <span>Inspect Logs ({stats?.suspiciousLogs ?? 0})</span>
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
          <p class="text-[11px] text-[#615d59]">Developer actions, suspensions, dispute determinations</p>
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
          <span>View Audit Log History</span>
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

    <!-- Quick Navigation Card -->
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm flex flex-col justify-between">
      <div>
        <div class="flex items-center gap-3 mb-3">
          <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-[#e8f8eb] text-[#138029]">
            <Icon name="zap" class="h-5 w-5" />
          </div>
          <div>
            <h2 class="text-sm font-bold text-[#000000]">Quick Shortcuts</h2>
            <p class="text-[11px] text-[#615d59]">Platform data explorer</p>
          </div>
        </div>
        <ul class="text-xs text-[#615d59] space-y-1.5 mb-4">
          <li>• <strong class="text-[#000000]">Transactions:</strong> Filter bills and payments by user or group.</li>
          <li>• <strong class="text-[#000000]">Disputes:</strong> Investigate and resolve debtor claims.</li>
          <li>• <strong class="text-[#000000]">Users:</strong> Suspend or ban offending accounts.</li>
        </ul>
      </div>

      <div class="flex gap-2 border-t border-[#e6e6e6] pt-3">
        <a href="/transactions" class="flex-1 text-center rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-semibold text-[#0075de] hover:bg-[#e8f3fc] transition-colors">
          Transactions &rarr;
        </a>
        <a href="/users" class="flex-1 text-center rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-semibold text-[#0075de] hover:bg-[#e8f3fc] transition-colors">
          Users &rarr;
        </a>
      </div>
    </div>
  </div>
</div>
