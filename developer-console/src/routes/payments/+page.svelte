<script lang="ts">
  import { getPayments } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import ThSort from '$lib/components/datatable/ThSort.svelte';
  import SearchInput from '$lib/components/datatable/SearchInput.svelte';
  import DataTablePagination from '$lib/components/datatable/DataTablePagination.svelte';
  import ExportCsvButton from '$lib/components/datatable/ExportCsvButton.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';
  import Icon from '$lib/components/Icon.svelte';

  let rawPayments = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');
  let previewSlipUrl = $state<string | null>(null);

  const table = new TableHandler<any>([], { rowsPerPage: 20 });

  let filters = $state({
    status: '',
    channel: '',
    method: '',
    dateFrom: '',
    dateTo: '',
    limit: 100,
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getPayments(filters);
      rawPayments = res.data.rows;
      total = res.data.total;
      table.setRows(rawPayments);
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
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Payments & Slips Explorer</h1>
      <p class="text-xs text-[#615d59] mt-0.5">Inspect payment slips, EasySlip v2 verification payloads, and transfer confirmation statuses.</p>
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
      <SearchInput {table} placeholder="Search payments by payer, bill, ref..." class="w-full lg:w-72" />

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
            <option value="pending_verification">Pending Verification</option>
            <option value="verification_failed">Verification Failed</option>
            <option value="pending_owner_confirmation">Pending Owner Confirmation</option>
            <option value="confirmed">Confirmed</option>
            <option value="rejected">Rejected</option>
            <option value="cancelled">Cancelled</option>
            <option value="refunded">Refunded</option>
          </select>
        </div>

        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">Channel:</span>
          <select
            bind:value={filters.channel}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          >
            <option value="">All Channels</option>
            <option value="promptpay_qr">PromptPay QR</option>
            <option value="bank_transfer">Bank Transfer</option>
            <option value="cash">Cash</option>
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

        <ExportCsvButton {table} filename="payments-export.csv" />
      </div>
    </div>

    {#if loading}
      <div class="p-8">
        <LoadingLottie text="Loading payments dataset..." size={160} />
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="w-full text-left text-xs text-[#31302e]">
          <thead class="border-b border-[#e6e6e6] bg-[#fbfbfa] text-[11px] font-semibold uppercase text-[#615d59]">
            <tr>
              <ThSort {table} field="createdAt">Created</ThSort>
              <th class="px-4 py-3">Payer</th>
              <th class="px-4 py-3">Bill Title</th>
              <ThSort {table} field="amount">Amount</ThSort>
              <th class="px-4 py-3">Channel / Method</th>
              <th class="px-4 py-3">Slip & Verification</th>
              <ThSort {table} field="status">Status</ThSort>
              <th class="px-4 py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#f0efed] bg-white font-normal">
            {#each table.rows as payment}
              {@const latestVerif = payment.verifications?.[0]}
              <tr class="hover:bg-[#f6f5f4] transition-colors">
                <td class="px-4 py-3 font-mono text-[11px] text-[#615d59] whitespace-nowrap">
                  {new Date(payment.createdAt).toLocaleDateString()}
                  <span class="text-[10px] text-[#a39e98] block">{new Date(payment.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                </td>
                <td class="px-4 py-3">
                  {#if payment.payer}
                    <div class="font-medium text-[#000000]">{payment.payer.displayName || payment.payer.fullName || payment.payer.userCode}</div>
                    <div class="font-mono text-[10px] text-[#615d59]">{payment.payer.userCode}</div>
                  {:else}
                    <span class="text-[#615d59]">-</span>
                  {/if}
                </td>
                <td class="px-4 py-3 font-medium text-[#000000]">
                  {#if payment.billItem?.bill}
                    <a href="/bills/{payment.billItem.bill.id}" class="hover:text-[#0075de] hover:underline">
                      {payment.billItem.bill.title || 'Untitled Bill'}
                    </a>
                  {:else}
                    <span class="text-[#615d59]">-</span>
                  {/if}
                </td>
                <td class="px-4 py-3 font-semibold text-[#000000]">
                  ฿{Number(payment.amount || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </td>
                <td class="px-4 py-3">
                  <div class="flex flex-col gap-0.5">
                    <span class="font-medium text-[#31302e] capitalize">{payment.channel ? payment.channel.replace(/_/g, ' ') : '-'}</span>
                    <span class="text-[10px] text-[#615d59]">{payment.method === 'installment' ? `Installment #${payment.installmentNumber || 1}` : 'Full Payment'}</span>
                  </div>
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center gap-2">
                    {#if payment.slipImageUrl}
                      <button
                        onclick={() => previewSlipUrl = payment.slipImageUrl}
                        class="inline-flex h-6 w-6 items-center justify-center rounded border border-[#e6e6e6] bg-[#fbfbfa] text-xs hover:border-[#0075de] transition-colors"
                        title="View slip photo"
                      >
                        🧾
                      </button>
                    {/if}
                    {#if latestVerif}
                      <span class="rounded px-1.5 py-0.5 text-[10px] font-mono font-medium {latestVerif.status === 'success' ? 'bg-[#e8f8eb] text-[#138029]' : 'bg-[#fde8e8] text-[#c53030]'}">
                        {latestVerif.provider || 'easyslip'}: {latestVerif.status}
                      </span>
                    {:else if payment.slipImageUrl}
                      <span class="text-[10px] text-[#615d59]">Slip Uploaded</span>
                    {:else}
                      <span class="text-[10px] text-[#a39e98]">No Slip</span>
                    {/if}
                  </div>
                </td>
                <td class="px-4 py-3">
                  <StatusBadge status={payment.status} />
                </td>
                <td class="px-4 py-3 text-right">
                  <a
                    href="/payments/{payment.id}"
                    class="inline-flex items-center gap-1 rounded-md border border-[#e6e6e6] bg-white px-2.5 py-1 text-[11px] font-medium text-[#0075de] hover:bg-[#e8f3fc] hover:border-[#0075de] transition-colors"
                  >
                    <span>Inspect</span>
                    <span>&rarr;</span>
                  </a>
                </td>
              </tr>
            {:else}
              <tr>
                <td colspan="8" class="px-4 py-8 text-center text-xs text-[#615d59]">
                  No payments found matching current filters.
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

  <!-- Slip Image Preview Modal -->
  {#if previewSlipUrl}
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div class="relative max-h-[90vh] max-w-lg rounded-2xl bg-white p-4 shadow-xl">
        <button
          onclick={() => previewSlipUrl = null}
          class="absolute right-3 top-3 flex h-7 w-7 items-center justify-center rounded-full bg-[#f0efed] text-xs font-bold text-[#31302e] hover:bg-[#e6e6e6]"
        >
          &times;
        </button>
        <h3 class="mb-3 text-xs font-bold text-[#000000]">Transfer Slip Inspection</h3>
        <div class="max-h-[75vh] overflow-auto rounded-lg border border-[#e6e6e6] bg-[#fbfbfa]">
          <img src={previewSlipUrl} alt="Transfer Slip" class="w-full object-contain" />
        </div>
      </div>
    </div>
  {/if}
</div>
