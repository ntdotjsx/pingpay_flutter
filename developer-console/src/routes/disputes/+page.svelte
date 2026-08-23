<script lang="ts">
  import { getDisputes } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler, ThSort, SearchInput, DataTablePagination, ExportCsvButton } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let rawDisputes = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');

  const table = new TableHandler<any>([], { rowsPerPage: 20 });

  let filters = $state({
    status: '',
    dateFrom: '',
    dateTo: '',
    limit: 100,
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getDisputes(filters);
      rawDisputes = res.data.rows;
      total = res.data.total;
      table.setRows(rawDisputes);
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
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Dispute Cases</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Investigate payment conflicts, check SlipOK verification logs, and record determinations with interactive DataTables.</p>
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
      <SearchInput {table} placeholder="Search disputes by user, bill, reason..." class="w-full lg:w-72" />

      <!-- Integrated Filters -->
      <div class="flex flex-wrap items-center gap-2.5">
        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">Status:</span>
          <select
            bind:value={filters.status}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          >
            <option value="">All Statuses</option>
            <option value="open">Open</option>
            <option value="under_review">Under Review</option>
            <option value="resolved_paid">Resolved (Paid)</option>
            <option value="resolved_written_off">Resolved (Written Off)</option>
            <option value="resolved_rejected">Resolved (Rejected)</option>
          </select>
        </div>

        <button
          onclick={load}
          class="inline-flex h-7 items-center justify-center rounded border border-[#e6e6e6] bg-white px-2.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
        >
          Refresh
        </button>

        <ExportCsvButton {table} filename="disputes-export.csv" />
      </div>
    </div>

    {#if loading}
      <div class="p-8">
        <LoadingLottie text="Loading dispute cases..." size={150} />
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-[#e6e6e6]">
          <thead class="bg-[#f6f5f4]">
            <tr>
              <ThSort {table} field="status">Status</ThSort>
              <ThSort {table} field={(row) => row.raisedBy?.displayName || row.raisedBy?.userCode || ''}>Raised By</ThSort>
              <ThSort {table} field={(row) => row.billItem?.bill?.title || ''}>Bill</ThSort>
              <ThSort {table} field={(row) => row.billItem?.debtor?.displayName || ''}>Debtor</ThSort>
              <ThSort {table} field={(row) => Number(row.billItem?.currentAmount || 0)}>Amount</ThSort>
              <ThSort {table} field="reason">Reason</ThSort>
              <ThSort {table} field="createdAt">Date</ThSort>
              <th class="px-4 py-2.5 text-right text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Action</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e6e6e6] bg-white">
            {#each table.rows as dispute}
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
              <tr><td colspan="8" class="px-4 py-8 text-center text-xs text-[#615d59]">No matching disputes found</td></tr>
            {/each}
          </tbody>
        </table>
      </div>
      <DataTablePagination {table} />
    {/if}
  </div>
</div>
