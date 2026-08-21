<script lang="ts">
  import { getSuspiciousLogs, flagSuspicious, clearAllSuspiciousLogs, deleteSuspiciousLog } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler, ThSort, SearchInput, DataTablePagination, ExportCsvButton } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let rawLogs = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');
  let showForm = $state(false);
  let selectedLog = $state<any>(null);

  const table = new TableHandler<any>([], { rowsPerPage: 20 });

  let filters = $state({
    userId: '',
    type: '',
    dateFrom: '',
    dateTo: '',
    limit: 100,
  });

  let newFlag = $state({
    userId: '',
    type: 'duplicate_slip',
    description: '',
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getSuspiciousLogs(filters);
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

  function applyFilters() {
    load();
  }

  async function submitFlag() {
    if (!newFlag.description.trim()) {
      alert('Please enter a description');
      return;
    }
    try {
      await flagSuspicious({
        userId: newFlag.userId || undefined,
        type: newFlag.type,
        description: newFlag.description,
      });
      actionMessage = 'Suspicious activity successfully flagged.';
      showForm = false;
      newFlag = { userId: '', type: 'duplicate_slip', description: '' };
      load();
    } catch (e: any) {
      error = e.message;
    }
  }

  async function handleClearAll() {
    if (!confirm('WARNING: Are you sure you want to delete ALL suspicious activity logs?\n\nThis will permanently delete all recorded threat and fraud logs.')) return;
    try {
      await clearAllSuspiciousLogs();
      actionMessage = 'All suspicious activity logs have been cleared.';
      load();
    } catch (e: any) {
      error = `Clear failed: ${e.message}`;
    }
  }

  async function handleDeleteSingle(id: string) {
    if (!confirm('Delete this suspicious log entry?')) return;
    try {
      await deleteSuspiciousLog(id);
      actionMessage = 'Suspicious log entry deleted.';
      load();
    } catch (e: any) {
      error = `Delete failed: ${e.message}`;
    }
  }
</script>

<div>
  <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Suspicious Activity Logs</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Security audit trail retained permanently for dispute investigations and fraud analysis with interactive DataTables.</p>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <ExportCsvButton {table} filename="suspicious-logs.csv" />
      <button onclick={() => showForm = !showForm} class="rounded-md bg-[#0075de] px-3.5 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-[#005bab] transition-colors">
        {showForm ? 'Cancel' : '+ Flag Suspicious Activity'}
      </button>
      <button onclick={handleClearAll} class="rounded-md bg-[#c53030] px-3.5 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-[#a82525] transition-colors">
        Clear All Suspicious Logs
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

  {#if showForm}
    <div class="mb-6 rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm">
      <h3 class="mb-3 font-bold text-sm text-[#c53030]">Manually Flag Suspicious Activity</h3>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <div>
          <label for="flag-user-id" class="block text-[11px] font-medium text-[#615d59]">User ID (optional)</label>
          <input id="flag-user-id" type="text" bind:value={newFlag.userId} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" placeholder="User UUID" />
        </div>
        <div>
          <label for="flag-threat-type" class="block text-[11px] font-medium text-[#615d59]">Threat Type</label>
          <select id="flag-threat-type" bind:value={newFlag.type} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none">
            <option value="duplicate_slip">Duplicate Slip</option>
            <option value="multi_account_ip">Multi-Account from Same IP</option>
            <option value="frequent_writeoff">Frequent / Unusual Write-offs</option>
            <option value="frequent_bill_edit">Frequent Bill Edits</option>
            <option value="fake_slip_manipulation">Slip Manipulation / Amount Mismatch</option>
            <option value="other">Other Suspicious Activity</option>
          </select>
        </div>
        <div>
          <label for="flag-description" class="block text-[11px] font-medium text-[#615d59]">Description / Evidence</label>
          <input id="flag-description" type="text" bind:value={newFlag.description} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" placeholder="Details and observations..." />
        </div>
      </div>
      <div class="mt-4 flex justify-end gap-2 border-t border-[#e6e6e6] pt-3">
        <button onclick={() => showForm = false} class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors">Cancel</button>
        <button onclick={submitFlag} class="rounded-md bg-[#0075de] px-4 py-1.5 text-xs font-medium text-white hover:bg-[#005bab] transition-colors">Submit Security Flag</button>
      </div>
    </div>
  {/if}

  <div class="mb-6 rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm">
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <div>
        <label for="filter-suspicious-user" class="block text-[11px] font-medium text-[#615d59]">User ID / Code</label>
        <input id="filter-suspicious-user" type="text" bind:value={filters.userId} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" placeholder="Filter by User ID" />
      </div>
      <div>
        <label for="filter-suspicious-type" class="block text-[11px] font-medium text-[#615d59]">Threat Type</label>
        <select id="filter-suspicious-type" bind:value={filters.type} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none">
          <option value="">All Types</option>
          <option value="duplicate_slip">Duplicate Slip</option>
          <option value="multi_account_ip">Multi-Account IP</option>
          <option value="frequent_writeoff">Frequent Write-offs</option>
          <option value="frequent_bill_edit">Frequent Bill Edits</option>
          <option value="fake_slip_manipulation">Slip Manipulation</option>
          <option value="other">Other</option>
        </select>
      </div>
      <div>
        <label for="filter-suspicious-from" class="block text-[11px] font-medium text-[#615d59]">From Date</label>
        <input id="filter-suspicious-from" type="date" bind:value={filters.dateFrom} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" />
      </div>
      <div>
        <label for="filter-suspicious-to" class="block text-[11px] font-medium text-[#615d59]">To Date</label>
        <input id="filter-suspicious-to" type="date" bind:value={filters.dateTo} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" />
      </div>
    </div>
    <div class="mt-4 flex items-center justify-between border-t border-[#e6e6e6] pt-3">
      <button onclick={applyFilters} class="rounded-md bg-[#0075de] px-4 py-1.5 text-xs font-medium text-white hover:bg-[#005bab] transition-colors">Apply Filters</button>
      <span class="text-xs text-[#615d59] font-mono">Backend Total: {total} records</span>
    </div>
  </div>

  <div class="mb-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
    <SearchInput {table} placeholder="Search threat logs by type, user, description..." class="w-full sm:w-80" />
    <span class="text-xs text-[#615d59] font-mono">Filtered: {table.rowCount.total} records</span>
  </div>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
      <LoadingLottie text="Loading suspicious activity logs..." size={150} />
    </div>
  {:else}
    <div class="overflow-x-auto rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
      <table class="min-w-full divide-y divide-[#e6e6e6]">
        <thead class="bg-[#f6f5f4]">
          <tr>
            <ThSort {table} field="type">Threat Type</ThSort>
            <ThSort {table} field={(row) => row.userName || row.userCode || row.userId || ''}>User</ThSort>
            <ThSort {table} field="description">Description</ThSort>
            <ThSort {table} field="createdAt">Recorded Date</ThSort>
            <th class="px-4 py-2.5 text-right text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e6e6e6] bg-white">
          {#each table.rows as row}
            <tr class="hover:bg-[#faf9f8] transition-colors">
              <td class="px-4 py-3"><StatusBadge status={row.type} /></td>
              <td class="px-4 py-3 text-xs">
                {#if row.userId}
                  <a href="/users/{row.userId}" class="font-medium text-[#0075de] hover:underline">
                    {row.userName || row.userCode || row.userId.slice(0, 8) + '...'}
                  </a>
                {:else}
                  <span class="text-[#a39e98]">Unknown / Unregistered</span>
                {/if}
              </td>
              <td class="px-4 py-3 text-xs text-[#31302e] max-w-sm">{row.description}</td>
              <td class="px-4 py-3 text-xs text-[#615d59]">{new Date(row.createdAt).toLocaleString()}</td>
              <td class="px-4 py-3 text-right space-x-1">
                <button
                  onclick={() => selectedLog = row}
                  class="rounded border border-[#e6e6e6] bg-white px-2.5 py-1 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
                >
                  Inspect
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
            <tr><td colspan="5" class="px-4 py-8 text-center text-xs text-[#615d59]">No matching suspicious logs found</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    <DataTablePagination {table} class="mt-2" />
  {/if}
</div>

<!-- Inspect Modal -->
{#if selectedLog}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
    <div class="w-full max-w-lg rounded-xl bg-white p-6 shadow-xl border border-[#e6e6e6]">
      <div class="flex items-center justify-between border-b border-[#e6e6e6] pb-3">
        <h3 class="text-base font-bold text-[#c53030]">Suspicious Activity Record</h3>
        <button onclick={() => selectedLog = null} class="text-[#615d59] hover:text-[#000000] text-lg font-bold">&times;</button>
      </div>
      <div class="mt-4 space-y-2.5 text-xs">
        <div class="flex justify-between items-center">
          <span class="text-[#615d59]">Type:</span>
          <StatusBadge status={selectedLog.type} />
        </div>
        <div class="flex justify-between">
          <span class="text-[#615d59]">User:</span>
          <span class="text-[#000000] font-medium">{selectedLog.userName || selectedLog.userCode || selectedLog.userId || 'N/A'}</span>
        </div>
        <div>
          <span class="text-[#615d59] block mb-1">Description:</span>
          <p class="rounded-lg bg-[#fbfbfa] p-2.5 text-xs text-[#31302e] border border-[#e6e6e6]">{selectedLog.description}</p>
        </div>
        <div class="flex justify-between">
          <span class="text-[#615d59]">Timestamp:</span>
          <span class="text-[#000000]">{new Date(selectedLog.createdAt).toLocaleString()}</span>
        </div>
        <div>
          <span class="text-[#615d59] block mb-1">Metadata:</span>
          <pre class="max-h-56 overflow-y-auto rounded-lg bg-[#fbfbfa] p-3 font-mono text-xs text-[#31302e] border border-[#e6e6e6]">{JSON.stringify(selectedLog.metadata, null, 2)}</pre>
        </div>
      </div>
      <div class="mt-6 flex justify-between items-center border-t border-[#e6e6e6] pt-3">
        <div>
          {#if selectedLog.userId}
            <a href="/users/{selectedLog.userId}" class="rounded-md bg-[#fef2e8] px-3 py-1.5 text-xs font-semibold text-[#b34900] hover:bg-[#faeee3] transition-colors">
              View / Suspend User &rarr;
            </a>
          {/if}
        </div>
        <div class="flex gap-2">
          <button
            onclick={() => { const id = selectedLog.id; selectedLog = null; handleDeleteSingle(id); }}
            class="rounded-md bg-[#c53030] px-3 py-1.5 text-xs font-medium text-white hover:bg-[#a82525] transition-colors"
          >
            Delete Log
          </button>
          <button onclick={() => selectedLog = null} class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors">
            Close
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
