<script lang="ts">
  import { getActivityLogs, purgeActivityLogs, clearAllActivityLogs, deleteActivityLog } from '$lib/api/client';
  import { onMount } from 'svelte';
  import Pagination from '$lib/components/Pagination.svelte';

  let rows = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');
  let selectedLog = $state<any>(null);

  let filters = $state({
    userId: '',
    action: '',
    dateFrom: '',
    dateTo: '',
    page: 1,
    limit: 20,
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getActivityLogs(filters);
      rows = res.data.rows;
      total = res.data.total;
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  onMount(load);

  function applyFilters() {
    filters.page = 1;
    load();
  }

  function changePage(p: number) {
    filters.page = p;
    load();
  }

  async function handlePurge() {
    if (!confirm('Delete all regular activity logs older than 1 month?\n\nNOTE: Flagged/suspicious logs are retained permanently and will NOT be deleted.')) return;
    try {
      await purgeActivityLogs();
      actionMessage = 'Old regular activity logs (>1 month) purged successfully.';
      load();
    } catch (e: any) {
      error = `Purge failed: ${e.message}`;
    }
  }

  async function handleClearAll() {
    if (!confirm('WARNING: Are you sure you want to delete ALL regular activity logs?\n\nThis cannot be undone. Suspicious logs will remain safe.')) return;
    try {
      await clearAllActivityLogs();
      actionMessage = 'All regular activity logs have been cleared.';
      load();
    } catch (e: any) {
      error = `Clear failed: ${e.message}`;
    }
  }

  async function handleDeleteSingle(id: string) {
    if (!confirm('Delete this activity log entry?')) return;
    try {
      await deleteActivityLog(id);
      actionMessage = 'Activity log deleted.';
      load();
    } catch (e: any) {
      error = `Delete failed: ${e.message}`;
    }
  }
</script>

<div>
  <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Activity Logs</h1>
      <p class="mt-1 text-sm text-gray-500">Per-user and system activity tracking with automated 1-month retention policy.</p>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <a href="/suspicious" class="rounded border border-red-300 bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-700 hover:bg-red-100">
        Suspicious Logs &rarr;
      </a>
      <button onclick={handlePurge} class="rounded bg-yellow-600 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-yellow-700">
        Purge Old (&gt;1 mo)
      </button>
      <button onclick={handleClearAll} class="rounded bg-red-600 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-red-700">
        Clear All Regular Logs
      </button>
    </div>
  </div>

  <!-- Retention Policy Notice -->
  <div class="mb-6 rounded-lg border border-blue-200 bg-blue-50 p-4">
    <div class="flex">
      <div class="flex-shrink-0">
        <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
        </svg>
      </div>
      <div class="ml-3 text-xs text-blue-800">
        <span class="font-semibold">Retention Policy:</span> Regular activity logs auto-purge after 1 month. Flagged & suspicious logs are kept indefinitely. You can manually purge or clear logs anytime using the buttons above.
      </div>
    </div>
  </div>

  {#if actionMessage}
    <div class="mb-4 rounded-md bg-green-50 p-3 text-sm text-green-700 flex justify-between items-center">
      <span>{actionMessage}</span>
      <button onclick={() => actionMessage = ''} class="text-green-500 hover:text-green-800 font-bold">&times;</button>
    </div>
  {/if}

  {#if error}
    <div class="mb-4 rounded-md bg-red-50 p-3 text-sm text-red-700 flex justify-between items-center">
      <span>{error}</span>
      <button onclick={() => error = ''} class="text-red-500 hover:text-red-800 font-bold">&times;</button>
    </div>
  {/if}

  <div class="mb-6 rounded-lg bg-white p-4 shadow">
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <div>
        <label for="act-user-id" class="block text-xs font-medium text-gray-600">User ID / Code</label>
        <input id="act-user-id" type="text" bind:value={filters.userId} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" placeholder="UUID or User Code" />
      </div>
      <div>
        <label for="act-action" class="block text-xs font-medium text-gray-600">Action Type</label>
        <input id="act-action" type="text" bind:value={filters.action} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" placeholder="e.g. login, create_bill, writeoff" />
      </div>
      <div>
        <label for="act-from" class="block text-xs font-medium text-gray-600">From Date</label>
        <input id="act-from" type="date" bind:value={filters.dateFrom} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" />
      </div>
      <div>
        <label for="act-to" class="block text-xs font-medium text-gray-600">To Date</label>
        <input id="act-to" type="date" bind:value={filters.dateTo} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" />
      </div>
    </div>
    <div class="mt-4 flex justify-between items-center">
      <button onclick={applyFilters} class="rounded bg-blue-600 px-4 py-1.5 text-sm font-medium text-white hover:bg-blue-700">Filter</button>
      <span class="text-xs text-gray-500">Showing {rows.length} of {total} logs</span>
    </div>
  </div>

  {#if loading}
    <p class="text-gray-500">Loading...</p>
  {:else}
    <div class="overflow-x-auto rounded-lg bg-white shadow">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">User</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Action</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Metadata</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Timestamp</th>
            <th class="px-4 py-3 text-right text-xs font-medium uppercase text-gray-500">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          {#each rows as row}
            <tr class="hover:bg-gray-50">
              <td class="px-4 py-3 text-sm font-medium text-gray-900">
                {row.userName || row.userCode || (row.userId ? row.userId.slice(0, 8) + '...' : 'System')}
              </td>
              <td class="px-4 py-3 text-sm font-mono text-blue-700">{row.action}</td>
              <td class="px-4 py-3 text-sm text-gray-500 max-w-xs truncate">
                {#if row.metadata}
                  <code class="rounded bg-gray-100 px-1 py-0.5 text-xs">{JSON.stringify(row.metadata)}</code>
                {:else}
                  -
                {/if}
              </td>
              <td class="px-4 py-3 text-sm text-gray-500">{new Date(row.createdAt).toLocaleString()}</td>
              <td class="px-4 py-3 text-right space-x-1">
                <button
                  onclick={() => selectedLog = row}
                  class="rounded bg-gray-100 px-2.5 py-1 text-xs font-medium text-gray-700 hover:bg-gray-200"
                >
                  View
                </button>
                <button
                  onclick={() => handleDeleteSingle(row.id)}
                  class="rounded bg-red-50 px-2 py-1 text-xs font-medium text-red-600 hover:bg-red-100"
                  title="Delete this log"
                >
                  Delete
                </button>
              </td>
            </tr>
          {:else}
            <tr><td colspan="5" class="px-4 py-8 text-center text-gray-500">No activity logs found</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    <Pagination page={filters.page} {total} limit={filters.limit} onPageChange={changePage} />
  {/if}
</div>

<!-- Metadata Detail Modal -->
{#if selectedLog}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
    <div class="w-full max-w-lg rounded-lg bg-white p-6 shadow-xl">
      <div class="flex items-center justify-between border-b pb-3">
        <h3 class="text-lg font-bold text-gray-900">Log Details</h3>
        <button onclick={() => selectedLog = null} class="text-gray-400 hover:text-gray-600">&times;</button>
      </div>
      <div class="mt-4 space-y-3 text-sm">
        <div class="flex justify-between">
          <span class="text-gray-500">Action:</span>
          <span class="font-mono font-semibold text-blue-600">{selectedLog.action}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-500">User:</span>
          <span>{selectedLog.userName || selectedLog.userCode || selectedLog.userId}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-500">Timestamp:</span>
          <span>{new Date(selectedLog.createdAt).toLocaleString()}</span>
        </div>
        <div>
          <span class="text-gray-500">Raw Metadata:</span>
          <pre class="mt-1 max-h-60 overflow-y-auto rounded bg-gray-900 p-3 font-mono text-xs text-green-400">{JSON.stringify(selectedLog.metadata, null, 2)}</pre>
        </div>
      </div>
      <div class="mt-6 flex justify-end gap-2">
        <button
          onclick={() => { const id = selectedLog.id; selectedLog = null; handleDeleteSingle(id); }}
          class="rounded bg-red-600 px-3 py-2 text-sm font-medium text-white hover:bg-red-700"
        >
          Delete This Log
        </button>
        <button onclick={() => selectedLog = null} class="rounded bg-gray-200 px-4 py-2 text-sm font-medium text-gray-800 hover:bg-gray-300">
          Close
        </button>
      </div>
    </div>
  </div>
{/if}
