<script lang="ts">
  import { getDisputes } from '$lib/api/client';
  import { onMount } from 'svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import Pagination from '$lib/components/Pagination.svelte';

  let rows = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');

  let filters = $state({
    status: '',
    dateFrom: '',
    dateTo: '',
    page: 1,
    limit: 20,
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getDisputes(filters);
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
</script>

<div>
  <div class="mb-6 flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Dispute Cases</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Investigate payment conflicts, check SlipOK verification logs, and record determinations.</p>
    </div>
  </div>

  <div class="mb-6 rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm">
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
      <div>
        <label for="filter-dispute-status" class="block text-[11px] font-medium text-[#615d59]">Dispute Status</label>
        <select id="filter-dispute-status" bind:value={filters.status} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none">
          <option value="">All Statuses</option>
          <option value="open">Open</option>
          <option value="under_review">Under Review</option>
          <option value="resolved_paid">Resolved (Paid)</option>
          <option value="resolved_written_off">Resolved (Written Off)</option>
          <option value="resolved_rejected">Resolved (Rejected)</option>
        </select>
      </div>
      <div>
        <label for="filter-dispute-from" class="block text-[11px] font-medium text-[#615d59]">From Date</label>
        <input id="filter-dispute-from" type="date" bind:value={filters.dateFrom} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" />
      </div>
      <div>
        <label for="filter-dispute-to" class="block text-[11px] font-medium text-[#615d59]">To Date</label>
        <input id="filter-dispute-to" type="date" bind:value={filters.dateTo} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" />
      </div>
    </div>
    <div class="mt-4 flex items-center justify-between border-t border-[#e6e6e6] pt-3">
      <button onclick={applyFilters} class="rounded-md bg-[#0075de] px-4 py-1.5 text-xs font-medium text-white hover:bg-[#005bab] transition-colors">Filter</button>
      <span class="text-xs text-[#615d59] font-mono">Total: {total} disputes</span>
    </div>
  </div>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-8 text-center shadow-sm">
      <p class="text-xs text-[#615d59]">Loading disputes...</p>
    </div>
  {:else if error}
    <div class="rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030]">{error}</div>
  {:else}
    <div class="overflow-x-auto rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
      <table class="min-w-full divide-y divide-[#e6e6e6]">
        <thead class="bg-[#f6f5f4]">
          <tr>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Status</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Raised By</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Bill</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Debtor</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Amount</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Reason</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Date</th>
            <th class="px-4 py-2.5 text-right text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Action</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e6e6e6] bg-white">
          {#each rows as dispute}
            <tr class="hover:bg-[#faf9f8] transition-colors">
              <td class="px-4 py-3"><StatusBadge status={dispute.status} /></td>
              <td class="px-4 py-3 text-xs font-semibold text-[#000000]">{dispute.raisedBy?.displayName || dispute.raisedBy?.userCode || '-'}</td>
              <td class="px-4 py-3 text-xs text-[#31302e]">{dispute.billItem?.bill?.title || '-'}</td>
              <td class="px-4 py-3 text-xs text-[#615d59]">{dispute.billItem?.debtor?.displayName || '-'}</td>
              <td class="px-4 py-3 text-xs font-bold text-[#000000]">{dispute.billItem?.currentAmount} THB</td>
              <td class="px-4 py-3 text-xs text-[#615d59] max-w-xs truncate">{dispute.reason}</td>
              <td class="px-4 py-3 text-xs text-[#615d59]">{new Date(dispute.createdAt).toLocaleDateString()}</td>
              <td class="px-4 py-3 text-right">
                <a href="/disputes/{dispute.id}" class="rounded-md bg-[#0075de] px-3 py-1 text-xs font-medium text-white hover:bg-[#005bab] transition-colors">Review</a>
              </td>
            </tr>
          {:else}
            <tr><td colspan="8" class="px-4 py-8 text-center text-xs text-[#615d59]">No disputes found</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    <Pagination page={filters.page} {total} limit={filters.limit} onPageChange={changePage} />
  {/if}
</div>
