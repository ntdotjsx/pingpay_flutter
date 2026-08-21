<script lang="ts">
  import { getAuditLogs, clearAllAuditLogs } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler, ThSort, SearchInput, DataTablePagination, ExportCsvButton } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let rawLogs = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');

  const table = new TableHandler<any>([], { rowsPerPage: 20 });

  let filters = $state({
    adminId: '',
    limit: 100,
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getAuditLogs(filters);
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
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Admin Audit Log</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Record of administrative and developer actions with interactive DataTables sorting and search.</p>
    </div>
    <div class="flex items-center gap-2">
      <ExportCsvButton {table} filename="admin-audit-logs.csv" />
      <button onclick={handleClearAll} class="rounded-md bg-[#c53030] px-3.5 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-[#a82525] transition-colors">
        Clear All Audit Logs
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

  <div class="mb-6 rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm">
    <div class="flex items-end gap-3">
      <div class="flex-1">
        <label for="filter-admin-id" class="block text-[11px] font-medium text-[#615d59]">Admin User ID</label>
        <input id="filter-admin-id" type="text" bind:value={filters.adminId} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" placeholder="Filter by admin UUID" />
      </div>
      <div>
        <button onclick={applyFilters} class="rounded-md bg-[#0075de] px-4 py-1.5 text-xs font-medium text-white hover:bg-[#005bab] transition-colors">Filter</button>
      </div>
    </div>
  </div>

  <div class="mb-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
    <SearchInput {table} placeholder="Search logs by action, admin, target user, reason..." class="w-full sm:w-80" />
    <span class="text-xs text-[#615d59] font-mono">Filtered: {table.rowCount.total} logs</span>
  </div>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
      <LoadingLottie text="Loading audit logs..." size={150} />
    </div>
  {:else}
    <div class="overflow-x-auto rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
      <table class="min-w-full divide-y divide-[#e6e6e6]">
        <thead class="bg-[#f6f5f4]">
          <tr>
            <ThSort {table} field="actionType">Action</ThSort>
            <ThSort {table} field={(row) => row.adminName || row.adminCode || row.adminId || ''}>Admin</ThSort>
            <ThSort {table} field="targetUserId">Target User</ThSort>
            <ThSort {table} field="reason">Reason</ThSort>
            <ThSort {table} field="createdAt">Date</ThSort>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e6e6e6] bg-white">
          {#each table.rows as log}
            <tr class="hover:bg-[#faf9f8] transition-colors">
              <td class="px-4 py-3"><StatusBadge status={log.actionType} /></td>
              <td class="px-4 py-3 text-xs font-semibold text-[#000000]">{log.adminName || log.adminCode || (log.adminId ? log.adminId.slice(0, 8) : '-')}</td>
              <td class="px-4 py-3 text-xs text-[#615d59] font-mono">{log.targetUserId ? log.targetUserId.slice(0, 8) + '...' : '-'}</td>
              <td class="px-4 py-3 text-xs text-[#31302e] max-w-xs truncate">{log.reason || '-'}</td>
              <td class="px-4 py-3 text-xs text-[#615d59]">{new Date(log.createdAt).toLocaleString()}</td>
            </tr>
          {:else}
            <tr><td colspan="5" class="px-4 py-8 text-center text-xs text-[#615d59]">No matching audit logs found</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    <DataTablePagination {table} class="mt-2" />
  {/if}
</div>
