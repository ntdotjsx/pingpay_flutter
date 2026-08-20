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
  <a href="/disputes" class="mb-4 inline-block text-sm text-blue-600 hover:underline">&larr; Back to Disputes</a>

  {#if loading}
    <p class="text-gray-500">Loading dispute details...</p>
  {:else if error}
    <div class="rounded-md bg-red-50 p-4 text-red-700">{error}</div>
  {:else if data}
    {@const dispute = data.dispute}
    {@const editHistory = data.editHistory}

    <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-gray-900">Dispute Investigation</h1>
          <StatusBadge status={dispute.status} size="md" />
        </div>
        <p class="mt-1 text-sm text-gray-500 font-mono">Dispute ID: {dispute.id}</p>
      </div>

      <div class="flex gap-2">
        {#if dispute.status === 'open'}
          <button onclick={startReview} class="rounded bg-yellow-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-yellow-700">
            Start Investigation
          </button>
        {/if}
        {#if dispute.status === 'open' || dispute.status === 'under_review'}
          <button onclick={() => resolveForm.show = true} class="rounded bg-green-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-green-700">
            Make Determination
          </button>
        {/if}
      </div>
    </div>

    {#if actionMessage}
      <div class="mb-4 rounded-md bg-green-50 p-3 text-sm text-green-700">{actionMessage}</div>
    {/if}

    <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <!-- Dispute Claim & Summary -->
      <div class="rounded-lg bg-white p-6 shadow">
        <h2 class="mb-4 text-lg font-semibold text-gray-800">Claimant Statement & Status</h2>
        <dl class="space-y-3">
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Raised By</dt>
            <dd class="text-sm font-medium">{dispute.raisedBy?.displayName || dispute.raisedBy?.userCode || dispute.raisedById}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Filing Date</dt>
            <dd class="text-sm">{new Date(dispute.createdAt).toLocaleString()}</dd>
          </div>
          <div>
            <dt class="text-sm text-gray-500">Claim Details / Reason</dt>
            <dd class="mt-1 rounded border border-gray-200 bg-gray-50 p-3 text-sm text-gray-800 leading-relaxed">{dispute.reason}</dd>
          </div>
          {#if dispute.resolutionNote}
            <div class="mt-4 border-t pt-3">
              <dt class="text-sm font-semibold text-green-800">Admin Determination Note</dt>
              <dd class="mt-1 rounded bg-green-50 p-3 text-sm text-green-900 border border-green-200">
                <p class="font-medium">{dispute.resolutionNote}</p>
                <p class="mt-2 text-xs text-green-700">Resolved at: {new Date(dispute.resolvedAt).toLocaleString()}</p>
              </dd>
            </div>
          {/if}
        </dl>
      </div>

      <!-- Bill & Debt Snapshot -->
      <div class="rounded-lg bg-white p-6 shadow">
        <h2 class="mb-4 text-lg font-semibold text-gray-800">Bill & Debt Context</h2>
        <dl class="space-y-3">
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Bill Title</dt>
            <dd class="text-sm font-medium text-gray-900">{dispute.billItem?.bill?.title || '-'}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Creditor / Bill Owner</dt>
            <dd class="text-sm font-medium">{dispute.billItem?.bill?.owner?.displayName || dispute.billItem?.bill?.owner?.userCode || '-'}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Debtor (Payer)</dt>
            <dd class="text-sm font-medium">{dispute.billItem?.debtor?.displayName || dispute.billItem?.debtor?.userCode || '-'}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Original Assigned Amount</dt>
            <dd class="text-sm font-semibold">{dispute.billItem?.originalAmount} THB</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Current Adjusted Amount</dt>
            <dd class="text-sm font-semibold">{dispute.billItem?.currentAmount} THB</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Recorded Amount Paid</dt>
            <dd class="text-sm font-semibold text-green-600">{dispute.billItem?.amountPaid} THB</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Amount Written Off</dt>
            <dd class="text-sm text-gray-500">{dispute.billItem?.amountWrittenOff} THB</dd>
          </div>
        </dl>
      </div>
    </div>

    <!-- Slips & Payment Evidence -->
    <div class="mt-6 rounded-lg bg-white p-6 shadow">
      <h2 class="mb-4 text-lg font-semibold text-gray-800">Payment Attempts & Slip Verification Evidence</h2>
      {#if dispute.billItem?.payments?.length > 0}
        <div class="space-y-4">
          {#each dispute.billItem.payments as payment}
            <div class="rounded-lg border border-gray-200 p-4 bg-gray-50">
              <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div class="space-y-1">
                  <div class="flex items-center gap-2">
                    <StatusBadge status={payment.status} />
                    <span class="text-base font-bold text-gray-900">{payment.amount} THB</span>
                    <span class="text-xs text-gray-500">via {payment.channel}</span>
                  </div>
                  <div class="text-xs text-gray-600 space-y-0.5">
                    <div>Submitted: {new Date(payment.createdAt).toLocaleString()}</div>
                    {#if payment.slipOkReferenceId}
                      <div class="font-mono text-blue-700">SlipOK Ref: {payment.slipOkReferenceId}</div>
                    {/if}
                    {#if payment.slipHash}
                      <div class="font-mono text-gray-500">SHA256 Hash: {payment.slipHash}</div>
                    {/if}
                  </div>
                </div>

                {#if payment.slipImageUrl}
                  <div class="flex items-center gap-3">
                    <button
                      onclick={() => previewSlipUrl = payment.slipImageUrl}
                      class="group relative overflow-hidden rounded border border-gray-300"
                    >
                      <img src={payment.slipImageUrl} alt="Transfer Slip" class="h-20 w-20 object-cover group-hover:opacity-80" />
                      <div class="absolute inset-0 flex items-center justify-center bg-black/30 opacity-0 group-hover:opacity-100 text-white text-xs font-bold">
                        Zoom
                      </div>
                    </button>
                  </div>
                {/if}
              </div>

              <!-- SlipOK Verification Details -->
              {#if payment.verifications?.length > 0}
                <div class="mt-3 border-t border-gray-200 pt-3">
                  <h4 class="text-xs font-semibold uppercase tracking-wider text-gray-500">Verification History</h4>
                  <div class="mt-1 space-y-1">
                    {#each payment.verifications as v}
                      <div class="flex items-center justify-between rounded bg-white px-3 py-1.5 text-xs border border-gray-200">
                        <span class="font-medium">{v.provider} - {v.status}</span>
                        <span>Amount: {v.verifiedAmount ?? '-'} THB</span>
                        <span class="text-gray-500">{new Date(v.createdAt).toLocaleTimeString()}</span>
                      </div>
                    {/each}
                  </div>
                </div>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        <p class="text-sm text-gray-500">No payment submissions found for this bill item.</p>
      {/if}
    </div>

    <!-- Edit History Logs -->
    <div class="mt-6 rounded-lg bg-white p-6 shadow">
      <h2 class="mb-4 text-lg font-semibold text-gray-800">Bill Edit History & Modifications</h2>
      {#if editHistory?.length > 0}
        <div class="space-y-3">
          {#each editHistory as log}
            <div class="rounded border border-gray-200 p-3 bg-white">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <StatusBadge status={log.action} />
                  <span class="text-sm font-medium">{log.performedBy?.displayName || log.performedBy?.userCode || 'User'}</span>
                </div>
                <span class="text-xs text-gray-500">{new Date(log.createdAt).toLocaleString()}</span>
              </div>
              {#if log.note}
                <p class="mt-2 text-sm text-gray-700 bg-gray-50 p-2 rounded">{log.note}</p>
              {/if}
              {#if log.previousValue || log.newValue}
                <div class="mt-2 flex flex-wrap gap-4 text-xs font-mono">
                  <span class="text-red-700 bg-red-50 px-2 py-1 rounded">Before: {JSON.stringify(log.previousValue)}</span>
                  <span class="text-green-700 bg-green-50 px-2 py-1 rounded">After: {JSON.stringify(log.newValue)}</span>
                </div>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        <p class="text-sm text-gray-500">No modifications logged on this bill.</p>
      {/if}
    </div>
  {/if}
</div>

<!-- Resolution Modal -->
{#if resolveForm.show}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
    <div class="w-full max-w-md rounded-lg bg-white p-6 shadow-xl">
      <h3 class="mb-4 text-lg font-bold text-gray-900">Make Dispute Determination</h3>
      <div class="space-y-4">
        <div>
          <label for="resolve-decision" class="block text-sm font-medium text-gray-700">Determination Decision</label>
          <select id="resolve-decision" bind:value={resolveForm.status} class="mt-1 block w-full rounded border border-gray-300 px-3 py-2 text-sm">
            <option value="resolved_paid">Confirmed Paid (Valid Slip / Verified Payment)</option>
            <option value="resolved_written_off">Write Off Debt (Mutual Agreement / Adjustment)</option>
            <option value="resolved_rejected">Reject Debtor Claim (Invalid Slip / Unverified)</option>
          </select>
        </div>
        <div>
          <label for="resolve-note" class="block text-sm font-medium text-gray-700">Official Determination Reason / Note</label>
          <textarea id="resolve-note" bind:value={resolveForm.note} rows={4} class="mt-1 block w-full rounded border border-gray-300 px-3 py-2 text-sm" placeholder="Provide clear determination rationale based on slip verification and bill edit evidence..."></textarea>
        </div>
      </div>
      <div class="mt-6 flex justify-end gap-3">
        <button onclick={() => resolveForm.show = false} class="rounded border border-gray-300 px-4 py-2 text-sm">Cancel</button>
        <button
          onclick={submitResolve}
          disabled={!resolveForm.note.trim()}
          class="rounded bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50"
        >
          Confirm Determination
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Image Zoom Modal -->
{#if previewSlipUrl}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4" onclick={() => previewSlipUrl = null} role="presentation">
    <div class="relative max-h-screen max-w-2xl overflow-auto rounded bg-white p-2" onclick={(e) => e.stopPropagation()} role="presentation">
      <img src={previewSlipUrl} alt="Transfer Slip Full Preview" class="max-h-[85vh] w-auto mx-auto rounded" />
      <button
        onclick={() => previewSlipUrl = null}
        class="absolute top-4 right-4 rounded-full bg-black/60 px-3 py-1 text-white hover:bg-black"
      >
        &times; Close
      </button>
    </div>
  </div>
{/if}
