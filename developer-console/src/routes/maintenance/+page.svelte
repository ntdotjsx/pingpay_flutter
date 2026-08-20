<script lang="ts">
  import {
    purgeActivityLogs,
    clearAllActivityLogs,
    clearAllSuspiciousLogs,
    clearAllAuditLogs,
    getDashboard,
  } from '$lib/api/client';
  import { onMount } from 'svelte';

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
    <h1 class="text-2xl font-bold text-gray-900">Data Cleanup & System Maintenance</h1>
    <p class="mt-1 text-sm text-gray-500">Purge, clean, and manage system log records and database state.</p>
  </div>

  {#if message}
    <div class="mb-5 rounded-lg border border-green-200 bg-green-50 p-4 text-sm text-green-800 flex justify-between items-center shadow-sm">
      <div class="flex items-center gap-2">
        <span>✓</span>
        <span>{message}</span>
      </div>
      <button onclick={() => message = ''} class="text-green-600 hover:text-green-900 font-bold">&times;</button>
    </div>
  {/if}

  {#if error}
    <div class="mb-5 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700 flex justify-between items-center shadow-sm">
      <div class="flex items-center gap-2">
        <span>✕</span>
        <span>{error}</span>
      </div>
      <button onclick={() => error = ''} class="text-red-500 hover:text-red-800 font-bold">&times;</button>
    </div>
  {/if}

  <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
    <!-- Activity Logs Cleanup -->
    <div class="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div class="flex items-center gap-3 mb-4">
        <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-100 text-blue-700 text-xl">
          📋
        </div>
        <div>
          <h2 class="text-base font-bold text-gray-900">Activity Logs Cleanup</h2>
          <p class="text-xs text-gray-500">Regular per-user / group event tracking</p>
        </div>
      </div>
      <p class="text-sm text-gray-600 mb-6 leading-relaxed">
        Regular activity logs track logins, bills, and payments. They can be purged on the 1-month retention schedule or wiped completely.
      </p>
      <div class="flex flex-col gap-3">
        <button
          onclick={() => runCleanup('purge_old')}
          disabled={actionLoading}
          class="flex items-center justify-center gap-2 rounded-lg bg-yellow-600 px-4 py-2.5 text-sm font-medium text-white shadow-sm hover:bg-yellow-700 active:scale-[0.99] disabled:opacity-50"
        >
          <span>🧹</span>
          <span>Purge Old Logs (&gt;1 Month)</span>
        </button>
        <button
          onclick={() => runCleanup('clear_activity')}
          disabled={actionLoading}
          class="flex items-center justify-center gap-2 rounded-lg border border-red-300 bg-red-50 px-4 py-2.5 text-sm font-medium text-red-700 hover:bg-red-100 active:scale-[0.99] disabled:opacity-50"
        >
          <span>🗑️</span>
          <span>Clear ALL Regular Activity Logs</span>
        </button>
      </div>
    </div>

    <!-- Suspicious Logs Cleanup -->
    <div class="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div class="flex items-center gap-3 mb-4">
        <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-red-100 text-red-700 text-xl">
          🚨
        </div>
        <div>
          <h2 class="text-base font-bold text-gray-900">Suspicious Threat Logs</h2>
          <p class="text-xs text-gray-500">Security flags, fraud attempts, duplicate slips</p>
        </div>
      </div>
      <p class="text-sm text-gray-600 mb-6 leading-relaxed">
        Suspicious logs are retained permanently by default for dispute evidence. Use this only when resetting test fraud data.
      </p>
      <div class="flex flex-col gap-3">
        <a
          href="/suspicious"
          class="flex items-center justify-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50"
        >
          <span>Inspect Logs ({stats?.suspiciousLogs ?? 0})</span>
        </a>
        <button
          onclick={() => runCleanup('clear_suspicious')}
          disabled={actionLoading}
          class="flex items-center justify-center gap-2 rounded-lg bg-red-600 px-4 py-2.5 text-sm font-medium text-white shadow-sm hover:bg-red-700 active:scale-[0.99] disabled:opacity-50"
        >
          <span>🗑️</span>
          <span>Clear ALL Suspicious Logs</span>
        </button>
      </div>
    </div>

    <!-- Admin Audit Logs Cleanup -->
    <div class="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div class="flex items-center gap-3 mb-4">
        <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-purple-100 text-purple-700 text-xl">
          🔍
        </div>
        <div>
          <h2 class="text-base font-bold text-gray-900">Admin Audit Trail</h2>
          <p class="text-xs text-gray-500">Developer actions, suspensions, dispute determinations</p>
        </div>
      </div>
      <p class="text-sm text-gray-600 mb-6 leading-relaxed">
        Admin action logs record all developer and administrator actions. You can wipe this audit history during local dev testing.
      </p>
      <div class="flex flex-col gap-3">
        <a
          href="/audit-logs"
          class="flex items-center justify-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50"
        >
          <span>View Audit Log History</span>
        </a>
        <button
          onclick={() => runCleanup('clear_audit')}
          disabled={actionLoading}
          class="flex items-center justify-center gap-2 rounded-lg bg-red-600 px-4 py-2.5 text-sm font-medium text-white shadow-sm hover:bg-red-700 active:scale-[0.99] disabled:opacity-50"
        >
          <span>🗑️</span>
          <span>Clear ALL Admin Audit Logs</span>
        </button>
      </div>
    </div>

    <!-- Quick Navigation Card -->
    <div class="rounded-xl border border-emerald-200 bg-emerald-50/50 p-6 shadow-sm flex flex-col justify-between">
      <div>
        <div class="flex items-center gap-3 mb-4">
          <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-emerald-100 text-emerald-700 text-xl">
            ⚡
          </div>
          <div>
            <h2 class="text-base font-bold text-gray-900">Quick Links</h2>
            <p class="text-xs text-emerald-700">Explore and manage platform data</p>
          </div>
        </div>
        <ul class="text-xs text-gray-600 space-y-2 mb-4">
          <li>• <strong>Transactions:</strong> Filter bills and payments by user or group.</li>
          <li>• <strong>Disputes:</strong> Investigate and resolve debtor claims.</li>
          <li>• <strong>Users:</strong> Suspend or ban offending accounts.</li>
        </ul>
      </div>

      <div class="flex gap-2">
        <a href="/transactions" class="flex-1 text-center rounded-lg bg-white border border-emerald-300 px-3 py-2 text-xs font-semibold text-emerald-800 hover:bg-emerald-100">
          Transactions &rarr;
        </a>
        <a href="/users" class="flex-1 text-center rounded-lg bg-white border border-emerald-300 px-3 py-2 text-xs font-semibold text-emerald-800 hover:bg-emerald-100">
          Users &rarr;
        </a>
      </div>
    </div>
  </div>
</div>
