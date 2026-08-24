<script lang="ts">
  import { getActivityLogs, purgeActivityLogs, clearAllActivityLogs, deleteActivityLog } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler, ThSort, SearchInput, DataTablePagination, ExportCsvButton } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
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
    if (!confirm('Delete all regular activity logs older than 1 month?\n\nNOTE: Threat and audit logs are retained separately and will NOT be deleted.')) return;
    try {
      await purgeActivityLogs();
      actionMessage = 'Old regular activity logs (>1 month) purged successfully.';
      load();
    } catch (e: any) {
      error = `Purge failed: ${e.message}`;
    }
  }

  async function handleClearAll() {
    if (!confirm('WARNING: Are you sure you want to delete ALL regular user activity logs?\n\nThis action cannot be undone.')) return;
    try {
      await clearAllActivityLogs();
      actionMessage = 'All regular user activity logs have been cleared.';
      load();
    } catch (e: any) {
      error = `Clear failed: ${e.message}`;
    }
  }

  async function handleDeleteSingle(id: string) {
    if (!confirm('Delete this activity log record?')) return;
    try {
      await deleteActivityLog(id);
      actionMessage = 'Activity log record deleted.';
      if (selectedLog?.id === id) selectedLog = null;
      load();
    } catch (e: any) {
      error = `Delete failed: ${e.message}`;
    }
  }
</script>

<div>
  <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">User Activity Logs</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Real-time audit log of user logins, bill creations, payments, debts, and social friend actions.</p>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <button onclick={handlePurge} class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#dd5b00] hover:bg-[#fef2e8] transition-colors">
        Purge Old (&gt;1 mo)
      </button>
      <button onclick={handleClearAll} class="rounded-md bg-[#c53030] px-3 py-1.5 text-xs font-medium text-white hover:bg-[#a82525] transition-colors">
        Clear All Logs
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
          <select
            bind:value={filters.action}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none max-w-[160px]"
          >
            <option value="">All Actions</option>
            <optgroup label="Auth & Profile">
              <option value="user_login">user_login</option>
              <option value="user_registered">user_registered</option>
              <option value="pin_setup">pin_setup</option>
              <option value="pin_verified">pin_verified</option>
              <option value="profile_updated">profile_updated</option>
            </optgroup>
            <optgroup label="Bills & Debts">
              <option value="bill_created">bill_created</option>
              <option value="bill_updated">bill_updated</option>
              <option value="bill_cancelled">bill_cancelled</option>
              <option value="debt_acknowledged">debt_acknowledged</option>
            </optgroup>
            <optgroup label="Payments">
              <option value="slip_uploaded">slip_uploaded</option>
              <option value="payment_confirmed">payment_confirmed</option>
              <option value="payment_rejected">payment_rejected</option>
            </optgroup>
            <optgroup label="Social & Rewards">
              <option value="friend_request_sent">friend_request_sent</option>
              <option value="friend_request_accepted">friend_request_accepted</option>
              <option value="friend_removed">friend_removed</option>
              <option value="reward_redeemed">reward_redeemed</option>
            </optgroup>
          </select>
        </div>

        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">From:</span>
          <input
            type="date"
            bind:value={filters.dateFrom}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          />
        </div>

        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">To:</span>
          <input
            type="date"
            bind:value={filters.dateTo}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
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
              <ThSort {table} field="createdAt">Timestamp</ThSort>
              <ThSort {table} field={(row) => row.userName || row.userCode || row.userId || ''}>User</ThSort>
              <ThSort {table} field="action">Action Type</ThSort>
              <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Metadata Snapshot</th>
              <th class="px-4 py-2.5 text-right text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e6e6e6] bg-white">
            {#each table.rows as row}
              <tr class="hover:bg-[#faf9f8] transition-colors">
                <td class="px-4 py-3 text-xs text-[#615d59] font-mono whitespace-nowrap">
                  {new Date(row.createdAt).toLocaleDateString()}
                  <span class="text-[10px] text-[#a39e98] block">{new Date(row.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
                </td>
                <td class="px-4 py-3 text-xs font-medium text-[#000000]">
                  {#if row.userId}
                    <a href="/users/{row.userId}" class="hover:text-[#0075de] hover:underline font-bold">
                      {row.userName || row.userCode || row.userId.slice(0, 8) + '...'}
                    </a>
                  {:else}
                    <span class="text-[#615d59]">System / Anonymous</span>
                  {/if}
                </td>
                <td class="px-4 py-3">
                  <StatusBadge status={row.action} />
                </td>
                <td class="px-4 py-3 text-xs text-[#615d59] max-w-sm truncate">
                  {#if row.metadata && Object.keys(row.metadata).length > 0}
                    <code class="rounded bg-[#f0efed] px-1.5 py-0.5 text-[10px] text-[#31302e] font-mono">{JSON.stringify(row.metadata)}</code>
                  {:else}
                    <span class="text-[#a39e98] text-[11px]">-</span>
                  {/if}
                </td>
                <td class="px-4 py-3 text-right space-x-1.5 whitespace-nowrap">
                  <button
                    onclick={() => selectedLog = row}
                    class="rounded border border-[#e6e6e6] bg-white px-2.5 py-1 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
                  >
                    Inspect
                  </button>
                  <button
                    onclick={() => handleDeleteSingle(row.id)}
                    class="rounded bg-[#fde8e8] px-2 py-1 text-xs font-medium text-[#c53030] hover:bg-[#fbd5d5] transition-colors"
                    title="Delete this record"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            {:else}
              <tr><td colspan="5" class="px-4 py-8 text-center text-xs text-[#615d59]">No matching activity logs found. Activities will appear in real time as users interact with the app.</td></tr>
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
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-xs p-4">
    <div class="w-full max-w-lg rounded-2xl bg-white p-6 shadow-2xl border border-[#e6e6e6]">
      <div class="flex items-center justify-between border-b border-[#e6e6e6] pb-3">
        <div class="flex items-center gap-2">
          <h3 class="text-base font-bold text-[#000000]">Activity Event Detail</h3>
          <StatusBadge status={selectedLog.action} />
        </div>
        <button onclick={() => selectedLog = null} class="text-[#615d59] hover:text-[#000000] text-lg font-bold">&times;</button>
      </div>

      <div class="mt-4 space-y-3 text-xs">
        <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
          <span class="text-[#615d59]">Action Key:</span>
          <span class="font-mono font-bold text-[#0075de]">{selectedLog.action}</span>
        </div>
        <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
          <span class="text-[#615d59]">Actor User:</span>
          <span class="text-[#000000] font-medium">{selectedLog.userName || selectedLog.userCode || selectedLog.userId}</span>
        </div>
        <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
          <span class="text-[#615d59]">Timestamp:</span>
          <span class="text-[#000000] font-mono">{new Date(selectedLog.createdAt).toLocaleString()}</span>
        </div>
        <div>
          <span class="text-[#615d59] font-bold block mb-1.5">Event Metadata Payload:</span>
          <pre class="max-h-60 overflow-y-auto rounded-lg bg-[#fbfbfa] p-3 font-mono text-xs text-[#31302e] border border-[#e6e6e6]">{JSON.stringify(selectedLog.metadata, null, 2)}</pre>
        </div>
      </div>

      <div class="mt-6 flex justify-end gap-2 border-t border-[#e6e6e6] pt-4">
        <button
          onclick={() => { const id = selectedLog.id; handleDeleteSingle(id); }}
          class="rounded-md bg-[#c53030] px-3.5 py-1.5 text-xs font-medium text-white hover:bg-[#a82525] transition-colors"
        >
          Delete Record
        </button>
        <button onclick={() => selectedLog = null} class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors">
          Close
        </button>
      </div>
    </div>
  </div>
{/if}
