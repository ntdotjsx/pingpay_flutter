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
  <h1 class="mb-6 text-2xl font-bold text-gray-900">Transactions Explorer</h1>

  <div class="mb-6 rounded-lg bg-white p-4 shadow">
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-5">
      <div>
        <label for="filter-user-id" class="block text-xs font-medium text-gray-600">User ID</label>
        <input id="filter-user-id" type="text" bind:value={filters.userId} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" placeholder="User UUID" />
      </div>
      <div>
        <label for="filter-group-id" class="block text-xs font-medium text-gray-600">Group ID</label>
        <input id="filter-group-id" type="text" bind:value={filters.groupId} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" placeholder="Group UUID" />
      </div>
      <div>
        <label for="filter-type" class="block text-xs font-medium text-gray-600">Transaction Type</label>
        <select id="filter-type" bind:value={filters.type} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm">
          <option value="">All Types</option>
          <option value="debt_created">Debt Created</option>
          <option value="debt_adjusted">Debt Adjusted</option>
          <option value="payment">Payment</option>
          <option value="refund">Refund</option>
          <option value="write_off">Write Off</option>
        </select>
      </div>
      <div>
        <label for="filter-from-date" class="block text-xs font-medium text-gray-600">From Date</label>
        <input id="filter-from-date" type="date" bind:value={filters.dateFrom} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" />
      </div>
      <div>
        <label for="filter-to-date" class="block text-xs font-medium text-gray-600">To Date</label>
        <input id="filter-to-date" type="date" bind:value={filters.dateTo} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" />
      </div>
    </div>
    <div class="mt-4 flex justify-between items-center">
      <button onclick={applyFilters} class="rounded bg-blue-600 px-4 py-1.5 text-sm font-medium text-white hover:bg-blue-700">
        Filter
      </button>
      <span class="text-xs text-gray-500">Total: {total} transactions</span>
    </div>
  </div>

  {#if loading}
    <p class="text-gray-500">Loading...</p>
  {:else if error}
    <div class="rounded-md bg-red-50 p-4 text-red-700">{error}</div>
  {:else}
    <div class="overflow-x-auto rounded-lg bg-white shadow">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Type</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Amount</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Bill Title</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Created By</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Date & Time</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          {#each rows as row}
            <tr class="hover:bg-gray-50">
              <td class="px-4 py-3"><StatusBadge status={row.type} /></td>
              <td class="px-4 py-3 text-sm font-semibold text-gray-900">{row.amount} {row.currency}</td>
              <td class="px-4 py-3 text-sm text-gray-600">{row.billTitle || row.billId?.slice(0, 8)}</td>
              <td class="px-4 py-3 text-sm text-gray-600">{row.creatorName || row.creatorCode || '-'}</td>
              <td class="px-4 py-3 text-sm text-gray-500">{new Date(row.createdAt).toLocaleString()}</td>
            </tr>
          {:else}
            <tr><td colspan="5" class="px-4 py-8 text-center text-gray-500">No transactions found</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    <Pagination page={filters.page} {total} limit={filters.limit} onPageChange={changePage} />
  {/if}
</div>
