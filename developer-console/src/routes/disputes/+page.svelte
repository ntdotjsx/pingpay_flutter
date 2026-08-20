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
  <h1 class="mb-6 text-2xl font-bold text-gray-900">Dispute Cases</h1>

  <div class="mb-6 rounded-lg bg-white p-4 shadow">
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <div>
        <label for="filter-dispute-status" class="block text-xs font-medium text-gray-600">Dispute Status</label>
        <select id="filter-dispute-status" bind:value={filters.status} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm">
          <option value="">All Statuses</option>
          <option value="open">Open</option>
          <option value="under_review">Under Review</option>
          <option value="resolved_paid">Resolved (Paid)</option>
          <option value="resolved_written_off">Resolved (Written Off)</option>
          <option value="resolved_rejected">Resolved (Rejected)</option>
        </select>
      </div>
      <div>
        <label for="filter-dispute-from" class="block text-xs font-medium text-gray-600">From Date</label>
        <input id="filter-dispute-from" type="date" bind:value={filters.dateFrom} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" />
      </div>
      <div>
        <label for="filter-dispute-to" class="block text-xs font-medium text-gray-600">To Date</label>
        <input id="filter-dispute-to" type="date" bind:value={filters.dateTo} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" />
      </div>
    </div>
    <div class="mt-4 flex justify-between items-center">
      <button onclick={applyFilters} class="rounded bg-blue-600 px-4 py-1.5 text-sm font-medium text-white hover:bg-blue-700">Filter</button>
      <span class="text-xs text-gray-500">Total: {total} disputes</span>
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
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Status</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Raised By</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Bill</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Debtor</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Amount</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Reason</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Date</th>
            <th class="px-4 py-3 text-right text-xs font-medium uppercase text-gray-500">Action</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          {#each rows as dispute}
            <tr class="hover:bg-gray-50">
              <td class="px-4 py-3"><StatusBadge status={dispute.status} /></td>
              <td class="px-4 py-3 text-sm font-medium">{dispute.raisedBy?.displayName || dispute.raisedBy?.userCode || '-'}</td>
              <td class="px-4 py-3 text-sm text-gray-700">{dispute.billItem?.bill?.title || '-'}</td>
              <td class="px-4 py-3 text-sm text-gray-600">{dispute.billItem?.debtor?.displayName || '-'}</td>
              <td class="px-4 py-3 text-sm font-bold text-gray-900">{dispute.billItem?.currentAmount} THB</td>
              <td class="px-4 py-3 text-sm text-gray-600 max-w-xs truncate">{dispute.reason}</td>
              <td class="px-4 py-3 text-sm text-gray-500">{new Date(dispute.createdAt).toLocaleDateString()}</td>
              <td class="px-4 py-3 text-right">
                <a href="/disputes/{dispute.id}" class="rounded bg-blue-600 px-3 py-1 text-xs font-semibold text-white hover:bg-blue-700">Review</a>
              </td>
            </tr>
          {:else}
            <tr><td colspan="8" class="px-4 py-8 text-center text-gray-500">No disputes found</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    <Pagination page={filters.page} {total} limit={filters.limit} onPageChange={changePage} />
  {/if}
</div>
