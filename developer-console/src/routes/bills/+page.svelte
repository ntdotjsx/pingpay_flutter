<script lang="ts">
  import { getBills } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import ThSort from '$lib/components/datatable/ThSort.svelte';
  import SearchInput from '$lib/components/datatable/SearchInput.svelte';
  import DataTablePagination from '$lib/components/datatable/DataTablePagination.svelte';
  import ExportCsvButton from '$lib/components/datatable/ExportCsvButton.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';
  import Icon from '$lib/components/Icon.svelte';

  let rawBills = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');

  const table = new TableHandler<any>([], { rowsPerPage: 20 });

  let filters = $state({
    search: '',
    status: '',
    dateFrom: '',
    dateTo: '',
    limit: 100,
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getBills(filters);
      rawBills = res.data.rows;
      total = res.data.total;
      table.setRows(rawBills);
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
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Bills Explorer</h1>
      <p class="text-xs text-[#615d59] mt-0.5">Explore group bills, split calculations, OCR extractions, and debtor statuses.</p>
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
      <SearchInput {table} placeholder="Search bills by title, owner, ID..." class="w-full lg:w-72" />

      <!-- Integrated Filter Selectors -->
      <div class="flex flex-wrap items-center gap-2.5">
        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">Status:</span>
          <select
            bind:value={filters.status}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          >
            <option value="">All Statuses</option>
            <option value="unpaid">Unpaid</option>
            <option value="partially_paid">Partially Paid</option>
            <option value="fully_paid">Fully Paid</option>
            <option value="partially_written_off">Partially Written Off</option>
            <option value="fully_written_off">Fully Written Off</option>
            <option value="cancelled">Cancelled</option>
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

        <ExportCsvButton {table} filename="bills-export.csv" />
      </div>
    </div>

    {#if loading}
      <div class="p-8">
        <LoadingLottie text="Loading bills dataset..." size={160} />
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="w-full text-left text-xs text-[#31302e]">
          <thead class="border-b border-[#e6e6e6] bg-[#fbfbfa] text-[11px] font-semibold uppercase text-[#615d59]">
            <tr>
              <ThSort {table} field="createdAt">Created</ThSort>
              <ThSort {table} field="title">Bill Title</ThSort>
              <th class="px-4 py-3">Owner (Creditor)</th>
              <ThSort {table} field="totalAmount">Total Amount</ThSort>
              <th class="px-4 py-3">Debtors Split</th>
              <ThSort {table} field="status">Status</ThSort>
              <th class="px-4 py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#f0efed] bg-white font-normal">
            {#each table.rows as bill}
              {@const debtorsCount = bill.items?.length || 0}
              {@const acknowledgedCount = bill.items?.filter((i: any) => i.isAcknowledged)?.length || 0}
              <tr class="hover:bg-[#f6f5f4] transition-colors">
                <td class="px-4 py-3 font-mono text-[11px] text-[#615d59] whitespace-nowrap">
                  {new Date(bill.createdAt).toLocaleDateString()}
                  <span class="text-[10px] text-[#a39e98] block">{new Date(bill.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                </td>
                <td class="px-4 py-3 font-semibold text-[#000000]">
                  <div class="flex items-center gap-2">
                    {#if bill.receiptImageUrl}
                      <span class="inline-flex h-5 w-5 items-center justify-center rounded bg-[#e8f3fc] text-[#0075de] text-[10px]" title="Has receipt photo">📷</span>
                    {/if}
                    <span>{bill.title || 'Untitled Bill'}</span>
                  </div>
                </td>
                <td class="px-4 py-3">
                  {#if bill.owner}
                    <div class="font-medium text-[#000000]">{bill.owner.displayName || bill.owner.fullName || bill.owner.userCode}</div>
                    <div class="font-mono text-[10px] text-[#615d59]">{bill.owner.userCode}</div>
                  {:else}
                    <span class="text-[#615d59]">-</span>
                  {/if}
                </td>
                <td class="px-4 py-3 font-semibold text-[#000000]">
                  ฿{Number(bill.totalAmount || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center gap-1.5">
                    <span class="rounded bg-[#f0efed] px-1.5 py-0.5 font-mono text-[11px] font-medium text-[#31302e]">
                      {debtorsCount} debtor(s)
                    </span>
                    {#if debtorsCount > 0}
                      <span class="text-[10px] {acknowledgedCount === debtorsCount ? 'text-[#1aae39]' : 'text-[#dd5b00]'}" title="Debtors who acknowledged debt">
                        ({acknowledgedCount}/{debtorsCount} ack'd)
                      </span>
                    {/if}
                  </div>
                </td>
                <td class="px-4 py-3">
                  <StatusBadge status={bill.status} />
                </td>
                <td class="px-4 py-3 text-right">
                  <a
                    href="/bills/{bill.id}"
                    class="inline-flex items-center gap-1 rounded-md border border-[#e6e6e6] bg-white px-2.5 py-1 text-[11px] font-medium text-[#0075de] hover:bg-[#e8f3fc] hover:border-[#0075de] transition-colors"
                  >
                    <span>Inspect</span>
                    <span>&rarr;</span>
                  </a>
                </td>
              </tr>
            {:else}
              <tr>
                <td colspan="7" class="px-4 py-8 text-center text-xs text-[#615d59]">
                  No bills found matching current filters.
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <!-- Integrated Pagination Component -->
      <DataTablePagination {table} />
    {/if}
  </div>
</div>
