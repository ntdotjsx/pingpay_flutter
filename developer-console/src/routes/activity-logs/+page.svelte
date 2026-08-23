<script lang="ts">
  import { getActivityLogs, purgeActivityLogs, clearAllActivityLogs, deleteActivityLog } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler, ThSort, SearchInput, DataTablePagination, ExportCsvButton } from '$lib/components/datatable';
  import Icon from '$lib/components/Icon.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let rawLogs = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');
  let selectedLog = $state<any>(null);

  const table = new TableHandler<any>([], { rowsPerPage: 20 });

  let filters = $state({
    userId: '',
    action: '',
    dateFrom: '',
    dateTo: '',
    limit: 100,
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getActivityLogs(filters);
      rawLogs = res.data.rows;
      total = res.data.total;
      table.setRows(rawLogs);
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  onMount(load);

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
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Activity Logs</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Per-user and system activity tracking with automated 1-month retention policy and interactive DataTables.</p>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <button onclick={handlePurge} class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#dd5b00] hover:bg-[#fef2e8] transition-colors">
        Purge Old (&gt;1 mo)
      </button>
      <button onclick={handleClearAll} class="rounded-md bg-[#c53030] px-3 py-1.5 text-xs font-medium text-white hover:bg-[#a82525] transition-colors">
        Clear All Regular Logs
      </button>
    </div>
  </div>

  {#if actionMessage}
    <div class="mb-4 rounded-md bg-[#e8f8eb] border border-[#e8f8eb] p-3 text-xs text-[#138029] flex justify-between items-center">
      <span>{actionMessage}</span>
      <button onclick={() => actionMessage = ''} class="text-[#138029] font-bold">&times;</button>
    </div>
  {/if}

  {#if error}
    <div class="mb-4 rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030] flex justify-between items-center">
      <span>{error}</span>
      <button onclick={() => error = ''} class="text-[#c53030] font-bold">&times;</button>
    </div>
  {/if}

  <!-- Unified DataTable Card with Integrated Controls -->
  <div class="overflow-hidden rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
    <!-- Integrated Header & Filter Toolbar -->
    <div class="flex flex-col gap-3 border-b border-[#e6e6e6] bg-[#fbfbfa] p-4 lg:flex-row lg:items-center lg:justify-between">
      <SearchInput {table} placeholder="Search user, action, metadata..." class="w-full lg:w-72" />

      <!-- Integrated Filters -->
      <div class="flex flex-wrap items-center gap-2.5">
        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">Action:</span>
          <input
            type="text"
            bind:value={filters.action}
            placeholder="e.g. login, create_bill..."
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none w-36"
          />
        </div>

        <button
          onclick={load}
          class="inline-flex h-7 items-center justify-center rounded border border-[#e6e6e6] bg-white px-2.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
        >
          Refresh
        </button>

        <ExportCsvButton {table} filename="activity-logs.csv" />
      </div>
    </div>

    {#if loading}
      <div class="p-8">
        <LoadingLottie text="Loading activity logs..." size={150} />
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-[#e6e6e6]">
          <thead class="bg-[#f6f5f4]">
            <tr>
              <ThSort {table} field={(row) => row.userName || row.userCode || row.userId || ''}>User</ThSort>
              <ThSort {table} field="action">Action</ThSort>
              <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Metadata</th>
              <ThSort {table} field="createdAt">Timestamp</ThSort>
              <th class="px-4 py-2.5 text-right text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e6e6e6] bg-white">
            {#each table.rows as row}
              <tr class="hover:bg-[#faf9f8] transition-colors">
                <td class="px-4 py-3 text-xs font-medium text-[#000000]">
                  {row.userName || row.userCode || (row.userId ? row.userId.slice(0, 8) + '...' : 'System')}
                </td>
                <td class="px-4 py-3 text-xs font-mono text-[#0075de]">{row.action}</td>
                <td class="px-4 py-3 text-xs text-[#615d59] max-w-xs truncate">
                  {#if row.metadata}
                    <code class="rounded bg-[#f0efed] px-1.5 py-0.5 text-[11px] text-[#31302e] font-mono">{JSON.stringify(row.metadata)}</code>
                  {:else}
                    -
                  {/if}
                </td>
                <td class="px-4 py-3 text-xs text-[#615d59]">{new Date(row.createdAt).toLocaleString()}</td>
                <td class="px-4 py-3 text-right space-x-1">
                  <button
                    onclick={() => selectedLog = row}
                    class="rounded border border-[#e6e6e6] bg-white px-2.5 py-1 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
                  >
                    View
                  </button>
                  <button
                    onclick={() => handleDeleteSingle(row.id)}
                    class="rounded bg-[#fde8e8] px-2 py-1 text-xs font-medium text-[#c53030] hover:bg-[#fbd5d5] transition-colors"
                    title="Delete this log"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            {:else}
              <tr><td colspan="5" class="px-4 py-8 text-center text-xs text-[#615d59]">No matching activity logs found</td></tr>
            {/each}
          </tbody>
        </table>
      </div>
      <DataTablePagination {table} />
    {/if}
  </div>
</div>

<!-- Metadata Detail Modal -->
{#if selectedLog}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
    <div class="w-full max-w-lg rounded-xl bg-white p-6 shadow-xl border border-[#e6e6e6]">
      <div class="flex items-center justify-between border-b border-[#e6e6e6] pb-3">
        <h3 class="text-base font-bold text-[#000000]">Log Details</h3>
        <button onclick={() => selectedLog = null} class="text-[#615d59] hover:text-[#000000] text-lg font-bold">&times;</button>
      </div>
      <div class="mt-4 space-y-2.5 text-xs">
        <div class="flex justify-between">
          <span class="text-[#615d59]">Action:</span>
          <span class="font-mono font-semibold text-[#0075de]">{selectedLog.action}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-[#615d59]">User:</span>
          <span class="text-[#000000]">{selectedLog.userName || selectedLog.userCode || selectedLog.userId}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-[#615d59]">Timestamp:</span>
          <span class="text-[#000000]">{new Date(selectedLog.createdAt).toLocaleString()}</span>
        </div>
        <div>
          <span class="text-[#615d59] block mb-1">Raw Metadata:</span>
          <pre class="max-h-60 overflow-y-auto rounded-lg bg-[#fbfbfa] p-3 font-mono text-xs text-[#31302e] border border-[#e6e6e6]">{JSON.stringify(selectedLog.metadata, null, 2)}</pre>
        </div>
      </div>
      <div class="mt-6 flex justify-end gap-2 border-t border-[#e6e6e6] pt-3">
        <button
          onclick={() => { const id = selectedLog.id; selectedLog = null; handleDeleteSingle(id); }}
          class="rounded-md bg-[#c53030] px-3 py-1.5 text-xs font-medium text-white hover:bg-[#a82525] transition-colors"
        >
          Delete This Log
        </button>
        <button onclick={() => selectedLog = null} class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors">
          Close
        </button>
      </div>
    </div>
  </div>
{/if}
