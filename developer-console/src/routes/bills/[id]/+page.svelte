<script lang="ts">
  import { getBillDetail } from '$lib/api/client';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let billId = $derived($page.params.id || '');
  let bill = $state<any>(null);
  let loading = $state(true);
  let error = $state('');
  let showOcrRaw = $state(false);
  let showBreakdownRaw = $state(false);

  async function load() {
    if (!billId) return;
    loading = true;
    error = '';
    try {
      const res = await getBillDetail(billId);
      bill = res.data;
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  onMount(load);
</script>

<div>
  <a href="/bills" class="mb-4 inline-flex items-center gap-1 text-xs font-medium text-[#0075de] hover:underline">&larr; Back to Bills</a>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-8 text-center shadow-sm">
      <LoadingLottie text="Loading bill details..." size={160} />
    </div>
  {:else if error}
    <div class="rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030]">{error}</div>
  {:else if bill}
    <!-- Bill Header -->
    <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold tracking-tight text-[#000000]">{bill.title || 'Untitled Bill'}</h1>
          <StatusBadge status={bill.status} size="md" />
        </div>
        <p class="mt-0.5 text-xs text-[#615d59] font-mono">Bill ID: {bill.id}</p>
      </div>

      <div class="text-right">
        <span class="text-xs text-[#615d59]">Total Bill Amount</span>
        <div class="text-2xl font-bold text-[#000000]">
          ฿{Number(bill.totalAmount || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} {bill.currency || 'THB'}
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
      <!-- Left 2 Cols: Debtors & Split Items -->
      <div class="space-y-6 lg:col-span-2">
        <!-- Debtors Table Card -->
        <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h2 class="text-sm font-bold text-[#000000]">Debtors & Share Split</h2>
              <p class="text-[11px] text-[#615d59]">Debtor payment progress, acknowledgements, and lock status</p>
            </div>
            <span class="rounded-full bg-[#f0efed] px-2 py-0.5 font-mono text-[11px] font-medium text-[#31302e]">
              {bill.items?.length || 0} debtor(s)
            </span>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full text-left text-xs text-[#31302e]">
              <thead class="border-b border-[#e6e6e6] bg-[#fbfbfa] text-[11px] font-semibold uppercase text-[#615d59]">
                <tr>
                  <th class="px-3 py-2.5">Debtor</th>
                  <th class="px-3 py-2.5">Owed / Paid</th>
                  <th class="px-3 py-2.5">Acknowledgement</th>
                  <th class="px-3 py-2.5">Status</th>
                  <th class="px-3 py-2.5 text-right">Payments</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-[#f0efed]">
                {#each bill.items || [] as item}
                  <tr class="hover:bg-[#f6f5f4] transition-colors">
                    <td class="px-3 py-3">
                      {#if item.debtor}
                        <div class="font-medium text-[#000000]">{item.debtor.displayName || item.debtor.fullName || item.debtor.userCode}</div>
                        <div class="font-mono text-[10px] text-[#615d59]">{item.debtor.userCode}</div>
                      {:else}
                        <span class="text-[#615d59]">-</span>
                      {/if}
                    </td>
                    <td class="px-3 py-3">
                      <div class="font-semibold text-[#000000]">
                        ฿{Number(item.currentAmount || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                      </div>
                      <div class="text-[10px] text-[#615d59]">
                        Paid: ฿{Number(item.amountPaid || 0).toFixed(2)} | Off: ฿{Number(item.amountWrittenOff || 0).toFixed(2)}
                      </div>
                    </td>
                    <td class="px-3 py-3">
                      {#if item.isAcknowledged}
                        <span class="inline-flex items-center gap-1 text-[11px] font-semibold text-[#138029]">
                          <span>✓ Ack'd</span>
                          {#if item.acknowledgedAt}
                            <span class="text-[10px] text-[#615d59] font-normal font-mono">({new Date(item.acknowledgedAt).toLocaleDateString()})</span>
                          {/if}
                        </span>
                      {:else}
                        <span class="text-[11px] font-medium text-[#dd5b00]">Pending Ack</span>
                      {/if}
                      {#if item.isLocked}
                        <span class="ml-1.5 rounded bg-[#f0efed] px-1.5 py-0.5 text-[9px] font-mono text-[#615d59]" title="Locked against direct edits">Locked</span>
                      {/if}
                    </td>
                    <td class="px-3 py-3">
                      <StatusBadge status={item.status} />
                    </td>
                    <td class="px-3 py-3 text-right">
                      <span class="font-mono text-[11px] text-[#0075de]">
                        {item.payments?.length || 0} tx
                      </span>
                    </td>
                  </tr>
                {:else}
                  <tr>
                    <td colspan="5" class="px-3 py-6 text-center text-xs text-[#615d59]">No debtor items attached.</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        </div>

        <!-- OCR Breakdown / Items Breakdown Card -->
        <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h2 class="text-sm font-bold text-[#000000]">Receipt OCR & Calculation Breakdown</h2>
              <p class="text-[11px] text-[#615d59]">Subtotal, Service Charge, VAT, and line items formula</p>
            </div>
            <button
              onclick={() => showBreakdownRaw = !showBreakdownRaw}
              class="text-[11px] font-medium text-[#0075de] hover:underline"
            >
              {showBreakdownRaw ? 'Show Formatted' : 'View Raw JSON'}
            </button>
          </div>

          {#if showBreakdownRaw}
            <pre class="max-h-80 overflow-auto rounded-lg bg-[#fbfbfa] p-4 text-[11px] font-mono text-[#31302e] border border-[#e6e6e6]">{JSON.stringify(bill.itemsBreakdown || {}, null, 2)}</pre>
          {:else if bill.itemsBreakdown}
            {@const breakdown = bill.itemsBreakdown}
            <div class="space-y-3">
              {#if breakdown.items && Array.isArray(breakdown.items)}
                <div class="space-y-1.5">
                  {#each breakdown.items as lineItem}
                    <div class="flex justify-between border-b border-[#f6f5f4] pb-1.5 text-xs">
                      <span class="text-[#31302e] font-medium">{lineItem.name || lineItem.title || 'Item'} (x{lineItem.quantity || 1})</span>
                      <span class="font-mono text-[#000000]">฿{Number(lineItem.price || lineItem.amount || 0).toFixed(2)}</span>
                    </div>
                  {/each}
                </div>
              {/if}

              <div class="border-t border-[#e6e6e6] pt-3 space-y-1.5 text-xs">
                {#if breakdown.subtotal}
                  <div class="flex justify-between text-[#615d59]">
                    <span>Subtotal</span>
                    <span class="font-mono">฿{Number(breakdown.subtotal).toFixed(2)}</span>
                  </div>
                {/if}
                {#if breakdown.serviceCharge}
                  <div class="flex justify-between text-[#615d59]">
                    <span>Service Charge ({breakdown.serviceChargeRate || '10'}%)</span>
                    <span class="font-mono">฿{Number(breakdown.serviceCharge).toFixed(2)}</span>
                  </div>
                {/if}
                {#if breakdown.vat || breakdown.tax}
                  <div class="flex justify-between text-[#615d59]">
                    <span>VAT ({breakdown.vatRate || '7'}%)</span>
                    <span class="font-mono">฿{Number(breakdown.vat || breakdown.tax).toFixed(2)}</span>
                  </div>
                {/if}
                <div class="flex justify-between font-bold text-[#000000] border-t border-[#f0efed] pt-2">
                  <span>Grand Total</span>
                  <span class="font-mono text-sm">฿{Number(bill.totalAmount || 0).toFixed(2)}</span>
                </div>
              </div>
            </div>
          {:else}
            <p class="text-xs text-[#615d59] py-4 text-center">No structured items breakdown available for this bill.</p>
          {/if}
        </div>
      </div>

      <!-- Right 1 Col: Owner & Receipt Photo -->
      <div class="space-y-6">
        <!-- Bill Owner Details -->
        <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
          <h2 class="mb-4 text-sm font-bold text-[#000000]">Creditor (Bill Owner)</h2>
          {#if bill.owner}
            <div class="flex items-center gap-3 mb-4">
              {#if bill.owner.avatarUrl}
                <img src={bill.owner.avatarUrl} alt="" class="h-10 w-10 rounded-full object-cover border border-[#e6e6e6]" />
              {:else}
                <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[#0075de] text-sm font-bold text-white">
                  {(bill.owner.displayName || bill.owner.fullName || 'U')[0]}
                </div>
              {/if}
              <div>
                <a href="/users/{bill.owner.id}" class="text-xs font-bold text-[#000000] hover:text-[#0075de] hover:underline">
                  {bill.owner.displayName || bill.owner.fullName || bill.owner.userCode}
                </a>
                <p class="text-[10px] font-mono text-[#615d59]">{bill.owner.userCode}</p>
              </div>
            </div>

            <dl class="space-y-2 text-xs border-t border-[#f0efed] pt-3">
              <div class="flex justify-between">
                <dt class="text-[#615d59]">PromptPay ID:</dt>
                <dd class="font-mono text-[#000000]">{bill.owner.promptPayId || '-'}</dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-[#615d59]">Phone:</dt>
                <dd class="text-[#000000]">{bill.owner.phoneNumber || '-'}</dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-[#615d59]">Created Date:</dt>
                <dd class="text-[#000000]">{new Date(bill.createdAt).toLocaleString()}</dd>
              </div>
            </dl>
          {:else}
            <p class="text-xs text-[#615d59]">Owner data not found.</p>
          {/if}
        </div>

        <!-- Receipt Image Preview -->
        <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-sm font-bold text-[#000000]">Receipt Photo</h2>
            {#if bill.receiptImageUrl}
              <a href={bill.receiptImageUrl} target="_blank" rel="noreferrer" class="text-[11px] text-[#0075de] hover:underline">
                Open Full &rarr;
              </a>
            {/if}
          </div>

          {#if bill.receiptImageUrl}
            <div class="overflow-hidden rounded-lg border border-[#e6e6e6] bg-[#fbfbfa]">
              <img src={bill.receiptImageUrl} alt="Receipt" class="max-h-72 w-full object-contain" />
            </div>
          {:else}
            <div class="flex h-36 items-center justify-center rounded-lg border border-dashed border-[#e6e6e6] bg-[#fbfbfa] text-xs text-[#615d59]">
              No receipt image uploaded
            </div>
          {/if}

          <!-- OCR Raw Data Accordion -->
          {#if bill.ocrRawData}
            <div class="mt-4 border-t border-[#e6e6e6] pt-3">
              <button
                onclick={() => showOcrRaw = !showOcrRaw}
                class="flex w-full items-center justify-between text-xs font-semibold text-[#31302e] hover:text-[#0075de]"
              >
                <span>Raw OCR Extracted Text</span>
                <span>{showOcrRaw ? '▲' : '▼'}</span>
              </button>
              {#if showOcrRaw}
                <pre class="mt-2 max-h-48 overflow-auto rounded bg-[#f6f5f4] p-3 text-[10px] font-mono text-[#31302e] border border-[#e6e6e6]">{JSON.stringify(bill.ocrRawData, null, 2)}</pre>
              {/if}
            </div>
          {/if}
        </div>
      </div>
    </div>
  {/if}
</div>
