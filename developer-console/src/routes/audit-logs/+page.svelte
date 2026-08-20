<script lang="ts">
  import { getAuditLogs, clearAllAuditLogs } from '$lib/api/client';
  import { onMount } from 'svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import Pagination from '$lib/components/Pagination.svelte';

  let rows = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');

  let filters = $state({
    adminId: '',
    page: 1,
    limit: 20,
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getAuditLogs(filters);
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

  async function handleClearAll() {
    if (!confirm('WARNING: Are you sure you want to clear ALL admin audit trail logs?')) return;
    try {
      await clearAllAuditLogs();
      actionMessage = 'All admin audit logs have been cleared.';
      load();
    } catch (e: any) {
      error = `Clear failed: ${e.message}`;
    }
  }
</script>

<div>
  <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Admin Audit Log</h1>
      <p class="mt-1 text-sm text-gray-500">Record of actions taken by administrators and developers</p>
    </div>
    <button onclick={handleClearAll} class="rounded bg-red-600 px-3.5 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-red-700">
      Clear All Audit Logs
    </button>
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
    <div class="flex gap-4">
      <div class="flex-1">
        <label for="filter-admin-id" class="block text-xs font-medium text-gray-600">Admin User ID</label>
        <input id="filter-admin-id" type="text" bind:value={filters.adminId} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" placeholder="Filter by admin UUID" />
      </div>
      <div class="flex items-end">
        <button onclick={applyFilters} class="rounded bg-blue-600 px-4 py-1.5 text-sm font-medium text-white hover:bg-blue-700">Filter</button>
      </div>
    </div>
  </div>

  {#if loading}
    <p class="text-gray-500">Loading...</p>
  {:else}
    <div class="overflow-x-auto rounded-lg bg-white shadow">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Action</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Admin</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Target User</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Reason</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Date</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          {#each rows as log}
            <tr class="hover:bg-gray-50">
              <td class="px-4 py-3"><StatusBadge status={log.actionType} /></td>
              <td class="px-4 py-3 text-sm font-medium">{log.adminName || log.adminCode || (log.adminId ? log.adminId.slice(0, 8) : '-')}</td>
              <td class="px-4 py-3 text-sm text-gray-600 font-mono text-xs">{log.targetUserId ? log.targetUserId.slice(0, 8) + '...' : '-'}</td>
              <td class="px-4 py-3 text-sm text-gray-600 max-w-xs truncate">{log.reason || '-'}</td>
              <td class="px-4 py-3 text-sm text-gray-500">{new Date(log.createdAt).toLocaleString()}</td>
            </tr>
          {:else}
            <tr><td colspan="5" class="px-4 py-8 text-center text-gray-500">No audit logs found</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    <Pagination page={filters.page} {total} limit={filters.limit} onPageChange={changePage} />
  {/if}
</div>
