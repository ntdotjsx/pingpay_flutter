<script lang="ts">
  import { getTransactions } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import ThSort from '$lib/components/datatable/ThSort.svelte';
  import SearchInput from '$lib/components/datatable/SearchInput.svelte';
  import DataTablePagination from '$lib/components/datatable/DataTablePagination.svelte';
  import ExportCsvButton from '$lib/components/datatable/ExportCsvButton.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let rawRows = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');

  const table = new TableHandler<any>([], { rowsPerPage: 20 });

  let filters = $state({
    userId: '',
    type: '',
    dateFrom: '',
    dateTo: '',
    limit: 100,
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getTransactions(filters);
      rawRows = res.data.rows;
      total = res.data.total;
      table.setRows(rawRows);
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  onMount(load);
</script>

<div>
  <div class="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Transactions Explorer</h1>
      <p class="text-xs text-[#615d59] mt-0.5">Filter financial movements with interactive DataTables sorting, search, and CSV export.</p>
    </div>
  </div>

  {#if error}
    <div class="mb-4 rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030] flex items-center justify-between">
      <span>{error}</span>
      <button onclick={() => error = ''} class="text-[#c53030] font-bold">&times;</button>
    </div>
  {/if}

  <!-- Unified DataTable Card with Integrated Controls -->
  <div class="overflow-hidden rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
    <!-- Integrated Header & Filter Toolbar -->
    <div class="flex flex-col gap-3 border-b border-[#e6e6e6] bg-[#fbfbfa] p-4 lg:flex-row lg:items-center lg:justify-between">
      <SearchInput {table} placeholder="Search transactions by type, bill, user..." class="w-full lg:w-72" />

      <!-- Integrated Filter Selectors -->
      <div class="flex flex-wrap items-center gap-2.5">
        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">Type:</span>
          <select
            bind:value={filters.type}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          >
            <option value="">All Types</option>
            <option value="debt_created">Debt Created</option>
            <option value="debt_adjusted">Debt Adjusted</option>
            <option value="payment">Payment</option>
            <option value="refund">Refund</option>
            <option value="write_off">Write Off</option>
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

        <ExportCsvButton {table} filename="transactions-export.csv" />
      </div>
    </div>

    {#if loading}
      <div class="p-8">
        <LoadingLottie text="Loading transactions..." size={150} />
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-[#e6e6e6]">
          <thead class="bg-[#f6f5f4]">
            <tr>
              <ThSort {table} field="type">Type</ThSort>
              <ThSort {table} field={(row) => Number(row.amount)}>Amount</ThSort>
              <ThSort {table} field="billTitle">Bill Title</ThSort>
              <ThSort {table} field="creatorName">Created By</ThSort>
              <ThSort {table} field="createdAt">Date & Time</ThSort>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e6e6e6] bg-white">
            {#each table.rows as row}
              <tr class="hover:bg-[#faf9f8] transition-colors">
                <td class="px-4 py-3"><StatusBadge status={row.type} /></td>
                <td class="px-4 py-3 text-xs font-semibold text-[#000000]">{row.amount} {row.currency}</td>
                <td class="px-4 py-3 text-xs text-[#31302e]">{row.billTitle || row.billId?.slice(0, 8)}</td>
                <td class="px-4 py-3 text-xs text-[#615d59]">{row.creatorName || row.creatorCode || '-'}</td>
                <td class="px-4 py-3 text-xs text-[#615d59]">{new Date(row.createdAt).toLocaleString()}</td>
              </tr>
            {:else}
              <tr><td colspan="5" class="px-4 py-8 text-center text-xs text-[#615d59]">No matching transactions found</td></tr>
            {/each}
          </tbody>
        </table>
      </div>
      <DataTablePagination {table} />
    {/if}
  </div>
</div>
