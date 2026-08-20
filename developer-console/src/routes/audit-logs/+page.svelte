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
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Admin Audit Log</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Record of administrative and developer actions performed across PingPay.</p>
    </div>
    <button onclick={handleClearAll} class="rounded-md bg-[#c53030] px-3.5 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-[#a82525] transition-colors">
      Clear All Audit Logs
    </button>
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

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-8 text-center shadow-sm">
      <p class="text-xs text-[#615d59]">Loading audit logs...</p>
    </div>
  {:else}
    <div class="overflow-x-auto rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
      <table class="min-w-full divide-y divide-[#e6e6e6]">
        <thead class="bg-[#f6f5f4]">
          <tr>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Action</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Admin</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Target User</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Reason</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Date</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e6e6e6] bg-white">
          {#each rows as log}
            <tr class="hover:bg-[#faf9f8] transition-colors">
              <td class="px-4 py-3"><StatusBadge status={log.actionType} /></td>
              <td class="px-4 py-3 text-xs font-semibold text-[#000000]">{log.adminName || log.adminCode || (log.adminId ? log.adminId.slice(0, 8) : '-')}</td>
              <td class="px-4 py-3 text-xs text-[#615d59] font-mono">{log.targetUserId ? log.targetUserId.slice(0, 8) + '...' : '-'}</td>
              <td class="px-4 py-3 text-xs text-[#31302e] max-w-xs truncate">{log.reason || '-'}</td>
              <td class="px-4 py-3 text-xs text-[#615d59]">{new Date(log.createdAt).toLocaleString()}</td>
            </tr>
          {:else}
            <tr><td colspan="5" class="px-4 py-8 text-center text-xs text-[#615d59]">No audit logs found</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    <Pagination page={filters.page} {total} limit={filters.limit} onPageChange={changePage} />
  {/if}
</div>
