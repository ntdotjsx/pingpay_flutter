<script lang="ts">
  import { getDisputeDetail, markDisputeUnderReview, resolveDispute } from '$lib/api/client';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';

  let disputeId = $derived($page.params.id || '');
  let data = $state<any>(null);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');
  let previewSlipUrl = $state<string | null>(null);

  let resolveForm = $state({
    show: false,
    status: 'resolved_paid' as 'resolved_paid' | 'resolved_written_off' | 'resolved_rejected',
    note: '',
  });

  onMount(async () => {
    await load();
  });

  async function load() {
    if (!disputeId) return;
    loading = true;
    try {
      const res = await getDisputeDetail(disputeId);
      data = res.data;
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  async function startReview() {
    if (!disputeId) return;
    try {
      await markDisputeUnderReview(disputeId);
      actionMessage = 'Dispute marked as under review';
      load();
    } catch (e: any) {
      error = e.message;
    }
  }

  async function submitResolve() {
    if (!disputeId) return;
    if (!resolveForm.note.trim()) {
      alert('Please provide a determination note explaining the resolution rationale.');
      return;
    }
    try {
      await resolveDispute(disputeId, resolveForm.status, resolveForm.note);
      actionMessage = 'Dispute determination successfully submitted.';
      resolveForm.show = false;
      load();
    } catch (e: any) {
      error = e.message;
    }
  }
</script>

<div>
  <a href="/disputes" class="mb-4 inline-flex items-center gap-1 text-xs font-medium text-[#0075de] hover:underline">&larr; Back to Disputes</a>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-8 text-center shadow-sm">
      <p class="text-xs text-[#615d59]">Loading dispute details...</p>
    </div>
  {:else if error}
    <div class="rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030]">{error}</div>
  {:else if data}
    {@const dispute = data.dispute}
    {@const editHistory = data.editHistory}

    <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Dispute Investigation</h1>
          <StatusBadge status={dispute.status} size="md" />
        </div>
        <p class="mt-0.5 text-xs text-[#615d59] font-mono">Dispute ID: {dispute.id}</p>
      </div>

      <div class="flex gap-2">
        {#if dispute.status === 'open'}
          <button onclick={startReview} class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#dd5b00] hover:bg-[#fef2e8] transition-colors">
            Start Investigation
          </button>
        {/if}
        {#if dispute.status === 'open' || dispute.status === 'under_review'}
          <button onclick={() => resolveForm.show = true} class="rounded-md bg-[#1aae39] px-3.5 py-1.5 text-xs font-medium text-white hover:bg-[#138029] transition-colors">
            Make Determination
          </button>
        {/if}
      </div>
    </div>

    {#if actionMessage}
      <div class="mb-4 rounded-md bg-[#e8f8eb] border border-[#e8f8eb] p-3 text-xs text-[#138029]">{actionMessage}</div>
    {/if}

    <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <!-- Dispute Claim & Summary -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
        <h2 class="mb-4 text-sm font-bold text-[#000000]">Claimant Statement & Status</h2>
        <dl class="space-y-3">
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Raised By</dt>
            <dd class="text-xs font-medium text-[#000000]">{dispute.raisedBy?.displayName || dispute.raisedBy?.userCode || dispute.raisedById}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Filing Date</dt>
            <dd class="text-xs text-[#000000]">{new Date(dispute.createdAt).toLocaleString()}</dd>
          </div>
          <div>
            <dt class="text-xs text-[#615d59] mb-1">Claim Details / Reason</dt>
            <dd class="rounded-lg border border-[#e6e6e6] bg-[#fbfbfa] p-3 text-xs text-[#31302e] leading-relaxed">{dispute.reason}</dd>
          </div>
          {#if dispute.resolutionNote}
            <div class="mt-4 border-t border-[#e6e6e6] pt-3">
              <dt class="text-xs font-semibold text-[#138029]">Admin Determination Note</dt>
              <dd class="mt-1.5 rounded-lg bg-[#e8f8eb] p-3 text-xs text-[#138029] border border-[#d2f3d7]">
                <p class="font-medium">{dispute.resolutionNote}</p>
                <p class="mt-2 text-[11px] opacity-80">Resolved at: {new Date(dispute.resolvedAt).toLocaleString()}</p>
              </dd>
            </div>
          {/if}
        </dl>
      </div>

      <!-- Bill & Debt Context -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
        <h2 class="mb-4 text-sm font-bold text-[#000000]">Bill & Debt Context</h2>
        <dl class="space-y-3">
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Bill Title</dt>
            <dd class="text-xs font-medium text-[#000000]">{dispute.billItem?.bill?.title || '-'}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Creditor / Bill Owner</dt>
            <dd class="text-xs font-medium text-[#000000]">{dispute.billItem?.bill?.owner?.displayName || dispute.billItem?.bill?.owner?.userCode || '-'}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Debtor (Payer)</dt>
            <dd class="text-xs font-medium text-[#000000]">{dispute.billItem?.debtor?.displayName || dispute.billItem?.debtor?.userCode || '-'}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Original Assigned Amount</dt>
            <dd class="text-xs font-semibold text-[#000000]">{dispute.billItem?.originalAmount} THB</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Current Adjusted Amount</dt>
            <dd class="text-xs font-semibold text-[#000000]">{dispute.billItem?.currentAmount} THB</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Recorded Amount Paid</dt>
            <dd class="text-xs font-semibold text-[#138029]">{dispute.billItem?.amountPaid} THB</dd>
          </div>
          <div class="flex justify-between pt-1">
            <dt class="text-xs text-[#615d59]">Amount Written Off</dt>
            <dd class="text-xs text-[#a39e98]">{dispute.billItem?.amountWrittenOff} THB</dd>
          </div>
        </dl>
      </div>
    </div>

    <!-- Slips & Payment Evidence -->
    <div class="mt-6 rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
      <h2 class="mb-4 text-sm font-bold text-[#000000]">Payment Attempts & Slip Verification Evidence</h2>
      {#if dispute.billItem?.payments?.length > 0}
        <div class="space-y-4">
          {#each dispute.billItem.payments as payment}
            <div class="rounded-xl border border-[#e6e6e6] p-4 bg-[#fbfbfa]">
              <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div class="space-y-1.5">
                  <div class="flex items-center gap-2">
                    <StatusBadge status={payment.status} />
                    <span class="text-sm font-bold text-[#000000]">{payment.amount} THB</span>
                    <span class="text-xs text-[#615d59]">via {payment.channel}</span>
                  </div>
                  <div class="text-xs text-[#615d59] space-y-0.5">
                    <div>Submitted: {new Date(payment.createdAt).toLocaleString()}</div>
                    {#if payment.slipOkReferenceId}
                      <div class="font-mono text-[#0075de]">SlipOK Ref: {payment.slipOkReferenceId}</div>
                    {/if}
                    {#if payment.slipHash}
                      <div class="font-mono text-[#a39e98]">SHA256 Hash: {payment.slipHash}</div>
                    {/if}
                  </div>
                </div>

                {#if payment.slipImageUrl}
                  <div class="flex items-center gap-3">
                    <button
                      onclick={() => previewSlipUrl = payment.slipImageUrl}
                      class="group relative overflow-hidden rounded-lg border border-[#e6e6e6] shadow-sm"
                    >
                      <img src={payment.slipImageUrl} alt="Transfer Slip" class="h-20 w-20 object-cover group-hover:opacity-80 transition-opacity" />
                      <div class="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 group-hover:opacity-100 text-white text-[11px] font-bold transition-opacity">
                        Zoom
                      </div>
                    </button>
                  </div>
                {/if}
              </div>

              <!-- SlipOK Verification Details -->
              {#if payment.verifications?.length > 0}
                <div class="mt-3 border-t border-[#e6e6e6] pt-3">
                  <h4 class="text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Verification History</h4>
                  <div class="mt-1.5 space-y-1">
                    {#each payment.verifications as v}
                      <div class="flex items-center justify-between rounded-md bg-white px-3 py-1.5 text-xs border border-[#e6e6e6]">
                        <span class="font-medium text-[#000000]">{v.provider} - {v.status}</span>
                        <span class="text-[#31302e]">Amount: {v.verifiedAmount ?? '-'} THB</span>
                        <span class="text-[#615d59]">{new Date(v.createdAt).toLocaleTimeString()}</span>
                      </div>
                    {/each}
                  </div>
                </div>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        <p class="text-xs text-[#615d59]">No payment submissions found for this bill item.</p>
      {/if}
    </div>

    <!-- Edit History Logs -->
    <div class="mt-6 rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
      <h2 class="mb-4 text-sm font-bold text-[#000000]">Bill Edit History & Modifications</h2>
      {#if editHistory?.length > 0}
        <div class="space-y-3">
          {#each editHistory as log}
            <div class="rounded-xl border border-[#e6e6e6] p-3.5 bg-white">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <StatusBadge status={log.action} />
                  <span class="text-xs font-semibold text-[#000000]">{log.performedBy?.displayName || log.performedBy?.userCode || 'User'}</span>
                </div>
                <span class="text-xs text-[#615d59]">{new Date(log.createdAt).toLocaleString()}</span>
              </div>
              {#if log.note}
                <p class="mt-2 text-xs text-[#31302e] bg-[#fbfbfa] p-2 rounded-md border border-[#e6e6e6]">{log.note}</p>
              {/if}
              {#if log.previousValue || log.newValue}
                <div class="mt-2 flex flex-wrap gap-2 text-[11px] font-mono">
                  <span class="text-[#c53030] bg-[#fde8e8] px-2 py-0.5 rounded">Before: {JSON.stringify(log.previousValue)}</span>
                  <span class="text-[#138029] bg-[#e8f8eb] px-2 py-0.5 rounded">After: {JSON.stringify(log.newValue)}</span>
                </div>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        <p class="text-xs text-[#615d59]">No modifications logged on this bill.</p>
      {/if}
    </div>
  {/if}
</div>

<!-- Resolution Modal -->
{#if resolveForm.show}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
    <div class="w-full max-w-md rounded-xl bg-white p-6 shadow-xl border border-[#e6e6e6]">
      <h3 class="mb-3 text-base font-bold text-[#000000]">Make Dispute Determination</h3>
      <div class="space-y-3">
        <div>
          <label for="resolve-decision" class="block text-[11px] font-medium text-[#615d59]">Determination Decision</label>
          <select id="resolve-decision" bind:value={resolveForm.status} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none">
            <option value="resolved_paid">Confirmed Paid (Valid Slip / Verified Payment)</option>
            <option value="resolved_written_off">Write Off Debt (Mutual Agreement / Adjustment)</option>
            <option value="resolved_rejected">Reject Debtor Claim (Invalid Slip / Unverified)</option>
          </select>
        </div>
        <div>
          <label for="resolve-note" class="block text-[11px] font-medium text-[#615d59]">Official Determination Reason / Note</label>
          <textarea id="resolve-note" bind:value={resolveForm.note} rows={4} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" placeholder="Provide clear determination rationale based on slip verification and bill edit evidence..."></textarea>
        </div>
      </div>
      <div class="mt-6 flex justify-end gap-2 border-t border-[#e6e6e6] pt-3">
        <button onclick={() => resolveForm.show = false} class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors">Cancel</button>
        <button
          onclick={submitResolve}
          disabled={!resolveForm.note.trim()}
          class="rounded-md bg-[#1aae39] px-3.5 py-1.5 text-xs font-medium text-white hover:bg-[#138029] disabled:opacity-50 transition-colors"
        >
          Confirm Determination
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Image Zoom Modal -->
{#if previewSlipUrl}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4" onclick={() => previewSlipUrl = null} role="presentation">
    <div class="relative max-h-screen max-w-2xl overflow-auto rounded-xl bg-white p-3 shadow-2xl border border-[#e6e6e6]" onclick={(e) => e.stopPropagation()} role="presentation">
      <img src={previewSlipUrl} alt="Transfer Slip Full Preview" class="max-h-[85vh] w-auto mx-auto rounded-lg" />
      <button
        onclick={() => previewSlipUrl = null}
        class="absolute top-4 right-4 rounded-full bg-black/60 px-3 py-1 text-xs text-white hover:bg-black transition-colors"
      >
        &times; Close
      </button>
    </div>
  </div>
{/if}
