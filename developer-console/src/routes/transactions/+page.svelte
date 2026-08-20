<script lang="ts">
  import { getTransactions } from '$lib/api/client';
  import { onMount } from 'svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import Pagination from '$lib/components/Pagination.svelte';

  let rows = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');

  let filters = $state({
    userId: '',
    groupId: '',
    type: '',
    dateFrom: '',
    dateTo: '',
    page: 1,
    limit: 20,
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getTransactions(filters);
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
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Transactions Explorer</h1>
      <p class="text-xs text-[#615d59] mt-0.5">Filter financial movements by user, group, date, and transaction type.</p>
    </div>
  </div>

  <div class="mb-6 rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm">
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
      <div>
        <label for="filter-user-id" class="block text-[11px] font-medium text-[#615d59]">User ID</label>
        <input id="filter-user-id" type="text" bind:value={filters.userId} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" placeholder="User UUID" />
      </div>
      <div>
        <label for="filter-group-id" class="block text-[11px] font-medium text-[#615d59]">Group ID</label>
        <input id="filter-group-id" type="text" bind:value={filters.groupId} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" placeholder="Group UUID" />
      </div>
      <div>
        <label for="filter-type" class="block text-[11px] font-medium text-[#615d59]">Transaction Type</label>
        <select id="filter-type" bind:value={filters.type} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none">
          <option value="">All Types</option>
          <option value="debt_created">Debt Created</option>
          <option value="debt_adjusted">Debt Adjusted</option>
          <option value="payment">Payment</option>
          <option value="refund">Refund</option>
          <option value="write_off">Write Off</option>
        </select>
      </div>
      <div>
        <label for="filter-from-date" class="block text-[11px] font-medium text-[#615d59]">From Date</label>
        <input id="filter-from-date" type="date" bind:value={filters.dateFrom} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" />
      </div>
      <div>
        <label for="filter-to-date" class="block text-[11px] font-medium text-[#615d59]">To Date</label>
        <input id="filter-to-date" type="date" bind:value={filters.dateTo} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" />
      </div>
    </div>
    <div class="mt-4 flex items-center justify-between border-t border-[#e6e6e6] pt-3">
      <button onclick={applyFilters} class="rounded-md bg-[#0075de] px-4 py-1.5 text-xs font-medium text-white hover:bg-[#005bab] transition-colors">
        Filter
      </button>
      <span class="text-xs text-[#615d59] font-mono">Total: {total} transactions</span>
    </div>
  </div>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-8 text-center shadow-sm">
      <p class="text-xs text-[#615d59]">Loading transactions...</p>
    </div>
  {:else if error}
    <div class="rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030]">{error}</div>
  {:else}
    <div class="overflow-x-auto rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
      <table class="min-w-full divide-y divide-[#e6e6e6]">
        <thead class="bg-[#f6f5f4]">
          <tr>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Type</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Amount</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Bill Title</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Created By</th>
            <th class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Date & Time</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e6e6e6] bg-white">
          {#each rows as row}
            <tr class="hover:bg-[#faf9f8] transition-colors">
              <td class="px-4 py-3"><StatusBadge status={row.type} /></td>
              <td class="px-4 py-3 text-xs font-semibold text-[#000000]">{row.amount} {row.currency}</td>
              <td class="px-4 py-3 text-xs text-[#31302e]">{row.billTitle || row.billId?.slice(0, 8)}</td>
              <td class="px-4 py-3 text-xs text-[#615d59]">{row.creatorName || row.creatorCode || '-'}</td>
              <td class="px-4 py-3 text-xs text-[#615d59]">{new Date(row.createdAt).toLocaleString()}</td>
            </tr>
          {:else}
            <tr><td colspan="5" class="px-4 py-8 text-center text-xs text-[#615d59]">No transactions found</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    <Pagination page={filters.page} {total} limit={filters.limit} onPageChange={changePage} />
  {/if}
</div>
