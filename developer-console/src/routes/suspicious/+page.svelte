<script lang="ts">
  import { getSuspiciousLogs, flagSuspicious, clearAllSuspiciousLogs, deleteSuspiciousLog } from '$lib/api/client';
  import { onMount } from 'svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import Pagination from '$lib/components/Pagination.svelte';

  let rows = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');
  let showForm = $state(false);
  let selectedLog = $state<any>(null);

  let filters = $state({
    userId: '',
    type: '',
    dateFrom: '',
    dateTo: '',
    page: 1,
    limit: 20,
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
      <h1 class="text-2xl font-bold text-gray-900">Suspicious Activity Logs</h1>
      <p class="mt-1 text-sm text-gray-500">Security audit trail retained permanently for dispute investigations and fraud analysis.</p>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <button onclick={() => showForm = !showForm} class="rounded bg-emerald-600 px-3.5 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-emerald-700">
        {showForm ? 'Cancel' : '+ Flag Suspicious Activity'}
      </button>
      <button onclick={handleClearAll} class="rounded bg-red-600 px-3.5 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-red-700">
        Clear All Suspicious Logs
      </button>
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

  {#if showForm}
    <div class="mb-6 rounded-lg border border-red-200 bg-red-50 p-5 shadow-sm">
      <h3 class="mb-3 font-semibold text-red-900">Manually Flag Suspicious Activity</h3>
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div>
          <label for="flag-user-id" class="block text-xs font-medium text-gray-700">User ID (optional)</label>
          <input id="flag-user-id" type="text" bind:value={newFlag.userId} class="mt-1 block w-full rounded border border-gray-300 bg-white px-3 py-1.5 text-sm" placeholder="User UUID" />
        </div>
        <div>
          <label for="flag-threat-type" class="block text-xs font-medium text-gray-700">Threat Type</label>
          <select id="flag-threat-type" bind:value={newFlag.type} class="mt-1 block w-full rounded border border-gray-300 bg-white px-3 py-1.5 text-sm">
            <option value="duplicate_slip">Duplicate Slip</option>
            <option value="multi_account_ip">Multi-Account from Same IP</option>
            <option value="frequent_writeoff">Frequent / Unusual Write-offs</option>
            <option value="frequent_bill_edit">Frequent Bill Edits</option>
            <option value="fake_slip_manipulation">Slip Manipulation / Amount Mismatch</option>
            <option value="other">Other Suspicious Activity</option>
          </select>
        </div>
        <div>
          <label for="flag-description" class="block text-xs font-medium text-gray-700">Description / Evidence</label>
          <input id="flag-description" type="text" bind:value={newFlag.description} class="mt-1 block w-full rounded border border-gray-300 bg-white px-3 py-1.5 text-sm" placeholder="Details and observations..." />
        </div>
      </div>
      <div class="mt-4 flex justify-end gap-2">
        <button onclick={() => showForm = false} class="rounded bg-gray-200 px-3 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-300">Cancel</button>
        <button onclick={submitFlag} class="rounded bg-red-600 px-4 py-1.5 text-xs font-medium text-white hover:bg-red-700">Submit Security Flag</button>
      </div>
    </div>
  {/if}

  <div class="mb-6 rounded-lg bg-white p-4 shadow">
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <div>
        <label for="filter-suspicious-user" class="block text-xs font-medium text-gray-600">User ID / Code</label>
        <input id="filter-suspicious-user" type="text" bind:value={filters.userId} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" placeholder="Filter by User ID" />
      </div>
      <div>
        <label for="filter-suspicious-type" class="block text-xs font-medium text-gray-600">Threat Type</label>
        <select id="filter-suspicious-type" bind:value={filters.type} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm">
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
        <label for="filter-suspicious-from" class="block text-xs font-medium text-gray-600">From Date</label>
        <input id="filter-suspicious-from" type="date" bind:value={filters.dateFrom} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" />
      </div>
      <div>
        <label for="filter-suspicious-to" class="block text-xs font-medium text-gray-600">To Date</label>
        <input id="filter-suspicious-to" type="date" bind:value={filters.dateTo} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" />
      </div>
    </div>
    <div class="mt-4 flex justify-between items-center">
      <button onclick={applyFilters} class="rounded bg-blue-600 px-4 py-1.5 text-sm font-medium text-white hover:bg-blue-700">Filter</button>
      <span class="text-xs text-gray-500">Showing {rows.length} of {total} records</span>
    </div>
  </div>

  {#if loading}
    <p class="text-gray-500">Loading...</p>
  {:else}
    <div class="overflow-x-auto rounded-lg bg-white shadow">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Threat Type</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">User</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Description</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Recorded Date</th>
            <th class="px-4 py-3 text-right text-xs font-medium uppercase text-gray-500">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          {#each rows as row}
            <tr class="hover:bg-gray-50">
              <td class="px-4 py-3"><StatusBadge status={row.type} /></td>
              <td class="px-4 py-3 text-sm">
                {#if row.userId}
                  <a href="/users/{row.userId}" class="font-medium text-blue-600 hover:underline">
                    {row.userName || row.userCode || row.userId.slice(0, 8) + '...'}
                  </a>
                {:else}
                  <span class="text-gray-400">Unknown / Unregistered</span>
                {/if}
              </td>
              <td class="px-4 py-3 text-sm text-gray-700 max-w-sm">{row.description}</td>
              <td class="px-4 py-3 text-sm text-gray-500">{new Date(row.createdAt).toLocaleString()}</td>
              <td class="px-4 py-3 text-right space-x-1">
                <button
                  onclick={() => selectedLog = row}
                  class="rounded bg-gray-100 px-2.5 py-1 text-xs font-medium text-gray-700 hover:bg-gray-200"
                >
                  Inspect
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
            <tr><td colspan="5" class="px-4 py-8 text-center text-gray-500">No suspicious activity logs found</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    <Pagination page={filters.page} {total} limit={filters.limit} onPageChange={changePage} />
  {/if}
</div>

<!-- Inspect Modal -->
{#if selectedLog}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
    <div class="w-full max-w-lg rounded-lg bg-white p-6 shadow-xl">
      <div class="flex items-center justify-between border-b pb-3">
        <h3 class="text-lg font-bold text-red-800">Suspicious Activity Record</h3>
        <button onclick={() => selectedLog = null} class="text-gray-400 hover:text-gray-600">&times;</button>
      </div>
      <div class="mt-4 space-y-3 text-sm">
        <div class="flex justify-between">
          <span class="text-gray-500">Type:</span>
          <StatusBadge status={selectedLog.type} />
        </div>
        <div class="flex justify-between">
          <span class="text-gray-500">User:</span>
          <span>{selectedLog.userName || selectedLog.userCode || selectedLog.userId || 'N/A'}</span>
        </div>
        <div>
          <span class="text-gray-500">Description:</span>
          <p class="mt-1 rounded bg-gray-50 p-2 text-sm text-gray-800">{selectedLog.description}</p>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-500">Timestamp:</span>
          <span>{new Date(selectedLog.createdAt).toLocaleString()}</span>
        </div>
        <div>
          <span class="text-gray-500">Metadata:</span>
          <pre class="mt-1 max-h-56 overflow-y-auto rounded bg-gray-900 p-3 font-mono text-xs text-red-300">{JSON.stringify(selectedLog.metadata, null, 2)}</pre>
        </div>
      </div>
      <div class="mt-6 flex justify-between items-center">
        <div>
          {#if selectedLog.userId}
            <a href="/users/{selectedLog.userId}" class="rounded bg-yellow-100 px-3 py-1.5 text-xs font-semibold text-yellow-800 hover:bg-yellow-200">
              View / Suspend User &rarr;
            </a>
          {/if}
        </div>
        <div class="flex gap-2">
          <button
            onclick={() => { const id = selectedLog.id; selectedLog = null; handleDeleteSingle(id); }}
            class="rounded bg-red-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-red-700"
          >
            Delete Log
          </button>
          <button onclick={() => selectedLog = null} class="rounded bg-gray-200 px-4 py-1.5 text-xs font-medium text-gray-800 hover:bg-gray-300">
            Close
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
