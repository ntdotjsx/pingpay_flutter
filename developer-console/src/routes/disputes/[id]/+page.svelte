<script lang="ts">
  import { getDisputeDetail, markDisputeUnderReview, resolveDispute } from '$lib/api/client';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let disputeId = $derived($page.params.id || '');
  let data = $state<any>(null);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');
  let previewSlipUrl = $state<string | null>(null);
  let expandedRawVerifId = $state<string | null>(null);

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
    error = '';
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
      actionMessage = 'Dispute status updated to Under Review.';
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
      actionMessage = 'Dispute determination successfully executed. Ledger and bill status synchronized.';
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
      <LoadingLottie text="Loading dispute evidence & records..." size={160} />
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
        <p class="mt-0.5 text-xs text-[#615d59] font-mono">Case ID: {dispute.id}</p>
      </div>

      <div class="flex gap-2">
        {#if dispute.status === 'open'}
          <button onclick={startReview} class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#dd5b00] hover:bg-[#fef2e8] transition-colors">
            Start Investigation
          </button>
        {/if}
        {#if dispute.status === 'open' || dispute.status === 'under_review'}
          <button onclick={() => resolveForm.show = true} class="rounded-md bg-[#1aae39] px-3.5 py-1.5 text-xs font-medium text-white hover:bg-[#138029] shadow-sm transition-colors">
            Make Determination &rarr;
          </button>
        {/if}
      </div>
    </div>

    {#if actionMessage}
      <div class="mb-4 rounded-md bg-[#e8f8eb] border border-[#e8f8eb] p-3 text-xs text-[#138029] flex justify-between items-center">
        <span>{actionMessage}</span>
        <button onclick={() => actionMessage = ''} class="font-bold text-[#138029]">&times;</button>
      </div>
    {/if}

    <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <!-- Dispute Claim & Summary -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
        <h2 class="mb-4 text-sm font-bold text-[#000000]">Claimant Statement & Status</h2>
        <dl class="space-y-3">
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Raised By</dt>
            <dd class="text-xs font-medium text-[#000000]">
              {#if dispute.raisedBy}
                <a href="/users/{dispute.raisedBy.id}" class="text-[#0075de] hover:underline font-bold">
                  {dispute.raisedBy.displayName || dispute.raisedBy.fullName || dispute.raisedBy.userCode}
                </a>
              {:else}
                <span class="font-mono">{dispute.raisedById}</span>
              {/if}
            </dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Filing Date</dt>
            <dd class="text-xs text-[#000000]">{new Date(dispute.createdAt).toLocaleString()}</dd>
          </div>
          <div>
            <dt class="text-xs text-[#615d59] mb-1">Claim Details / Reason</dt>
            <dd class="rounded-lg border border-[#e6e6e6] bg-[#fbfbfa] p-3 text-xs text-[#31302e] leading-relaxed font-medium">{dispute.reason}</dd>
          </div>

          {#if dispute.evidenceUrl}
            <div class="mt-3">
              <dt class="text-xs font-medium text-[#615d59] mb-1.5">Debtor's Attached Proof / Evidence</dt>
              <dd class="flex items-center gap-3">
                <a href={dispute.evidenceUrl} target="_blank" rel="noopener noreferrer" class="group relative block w-24 h-24 rounded-lg overflow-hidden border border-[#e6e6e6] bg-[#f6f5f4] hover:opacity-90 transition-opacity">
                  <img src={dispute.evidenceUrl} alt="Debtor Evidence" class="w-full h-full object-cover" />
                  <div class="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center text-white text-[10px] font-medium transition-opacity">View Full</div>
                </a>
                <div class="text-[11px] text-[#615d59]">
                  <p class="font-medium text-[#000000]">Document / Photo Attached</p>
                  <a href={dispute.evidenceUrl} target="_blank" rel="noopener noreferrer" class="text-[#0075de] hover:underline text-xs">Open in New Tab &rarr;</a>
                </div>
              </dd>
            </div>
          {/if}

          <!-- Creditor Counter-Evidence Section -->
          <div class="mt-4 border-t border-[#e6e6e6] pt-3">
            <dt class="text-xs font-bold text-[#000000] mb-2 flex items-center gap-1.5">
              <span>Creditor (Bill Owner) Counter-Evidence</span>
              {#if dispute.creditorRespondedAt}
                <span class="rounded bg-[#e8f8eb] text-[#138029] px-1.5 py-0.5 text-[10px] font-semibold">Submitted</span>
              {:else}
                <span class="rounded bg-[#fef2e8] text-[#dd5b00] px-1.5 py-0.5 text-[10px] font-semibold">Pending Response</span>
              {/if}
            </dt>
            {#if dispute.creditorRespondedAt}
              <dd class="rounded-lg border border-[#e6e6e6] bg-[#fbfbfa] p-3 text-xs text-[#31302e] space-y-2">
                {#if dispute.creditorEvidenceNote}
                  <p class="leading-relaxed font-medium">{dispute.creditorEvidenceNote}</p>
                {/if}
                {#if dispute.creditorEvidenceUrl}
                  <div class="pt-2 flex items-center gap-3">
                    <a href={dispute.creditorEvidenceUrl} target="_blank" rel="noopener noreferrer" class="group relative block w-20 h-20 rounded-lg overflow-hidden border border-[#e6e6e6] bg-white hover:opacity-90">
                      <img src={dispute.creditorEvidenceUrl} alt="Creditor Proof" class="w-full h-full object-cover" />
                      <div class="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center text-white text-[10px] font-medium">View</div>
                    </a>
                    <div class="text-[11px] text-[#615d59]">
                      <p class="font-medium text-[#000000]">Creditor Proof Photo</p>
                      <a href={dispute.creditorEvidenceUrl} target="_blank" rel="noopener noreferrer" class="text-[#0075de] hover:underline text-xs">Open in New Tab &rarr;</a>
                    </div>
                  </div>
                {/if}
                <p class="text-[10px] text-[#a39e98] font-mono pt-1">Responded: {new Date(dispute.creditorRespondedAt).toLocaleString()}</p>
              </dd>
            {:else}
              <dd class="rounded-lg border border-dashed border-[#e6e6e6] p-3 text-xs text-[#a39e98] italic">
                Bill owner has not submitted additional counter-explanation yet.
              </dd>
            {/if}
          </div>

          {#if dispute.resolutionNote}
            <div class="mt-4 border-t border-[#e6e6e6] pt-3">
              <dt class="text-xs font-semibold text-[#138029]">Official Determination Recorded</dt>
              <dd class="mt-1.5 rounded-lg bg-[#e8f8eb] p-3.5 text-xs text-[#138029] border border-[#d2f3d7]">
                <p class="font-bold">{dispute.resolutionNote}</p>
                <p class="mt-2 text-[10px] font-mono opacity-80">Resolved at: {new Date(dispute.resolvedAt).toLocaleString()}</p>
              </dd>
            </div>
          {/if}
        </dl>
      </div>

      <!-- Bill & Debt Context -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
        <h2 class="mb-4 text-sm font-bold text-[#000000]">Bill & Debt Context</h2>
        <dl class="space-y-2.5">
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Bill Title</dt>
            <dd class="text-xs font-medium text-[#000000]">
              {#if dispute.billItem?.bill}
                <a href="/bills/{dispute.billItem.bill.id}" class="text-[#0075de] hover:underline font-bold">
                  {dispute.billItem.bill.title || 'Untitled Bill'} &rarr;
                </a>
              {:else}
                <span>-</span>
              {/if}
            </dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Creditor (Bill Owner)</dt>
            <dd class="text-xs text-[#000000]">
              {#if dispute.billItem?.bill?.owner}
                <a href="/users/{dispute.billItem.bill.owner.id}" class="text-[#0075de] hover:underline">
                  {dispute.billItem.bill.owner.displayName || dispute.billItem.bill.owner.userCode}
                </a>
              {:else}
                <span>-</span>
              {/if}
            </dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Debtor (Payer)</dt>
            <dd class="text-xs text-[#000000]">
              {#if dispute.billItem?.debtor}
                <a href="/users/{dispute.billItem.debtor.id}" class="text-[#0075de] hover:underline">
                  {dispute.billItem.debtor.displayName || dispute.billItem.debtor.userCode}
                </a>
              {:else}
                <span>-</span>
              {/if}
            </dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Debtor Acknowledgement</dt>
            <dd class="text-xs">
              {#if dispute.billItem?.isAcknowledged}
                <span class="font-semibold text-[#138029]">✓ Acknowledged</span>
                {#if dispute.billItem.acknowledgedAt}
                  <span class="text-[10px] text-[#615d59] font-mono">({new Date(dispute.billItem.acknowledgedAt).toLocaleDateString()})</span>
                {/if}
              {:else}
                <span class="font-medium text-[#dd5b00]">Pending Acknowledgement</span>
              {/if}
              {#if dispute.billItem?.isLocked}
                <span class="ml-1 rounded bg-[#f0efed] px-1.5 py-0.5 text-[10px] font-mono text-[#615d59]">Locked</span>
              {/if}
            </dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Original Assigned Amount</dt>
            <dd class="text-xs font-mono font-semibold text-[#000000]">฿{Number(dispute.billItem?.originalAmount || 0).toFixed(2)}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Current Adjusted Amount</dt>
            <dd class="text-xs font-mono font-bold text-[#000000]">฿{Number(dispute.billItem?.currentAmount || 0).toFixed(2)}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Recorded Paid / Written Off</dt>
            <dd class="text-xs font-mono text-[#138029]">
              Paid: ฿{Number(dispute.billItem?.amountPaid || 0).toFixed(2)} | Off: ฿{Number(dispute.billItem?.amountWrittenOff || 0).toFixed(2)}
            </dd>
          </div>
        </dl>
      </div>
    </div>

    <!-- Slips & Payment Evidence -->
    <div class="mt-6 rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h2 class="text-sm font-bold text-[#000000]">Payment Attempts & EasySlip v2 Verification Evidence</h2>
          <p class="text-[11px] text-[#615d59]">Examine uploaded slips, bank OCR verifications, and deduplication hashes</p>
        </div>
        <span class="rounded-full bg-[#f0efed] px-2 py-0.5 font-mono text-[11px] text-[#615d59]">
          {dispute.billItem?.payments?.length || 0} attempt(s)
        </span>
      </div>

      {#if dispute.billItem?.payments?.length > 0}
        <div class="space-y-4">
          {#each dispute.billItem.payments as payment}
            {@const latestVerif = payment.verifications?.[0]}
            <div class="rounded-xl border border-[#e6e6e6] p-4 bg-[#fbfbfa]">
              <div class="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
                <div class="space-y-2 flex-1">
                  <div class="flex items-center gap-2">
                    <StatusBadge status={payment.status} />
                    <span class="text-sm font-bold text-[#000000]">฿{Number(payment.amount || 0).toFixed(2)}</span>
                    <span class="text-xs text-[#615d59] capitalize">via {payment.channel?.replace(/_/g, ' ')}</span>
                  </div>

                  <div class="grid grid-cols-1 gap-2 sm:grid-cols-2 text-xs text-[#615d59] bg-white p-3 rounded-lg border border-[#e6e6e6]">
                    <div>
                      <span class="text-[10px] uppercase text-[#a39e98] block">Submitted At</span>
                      <span class="text-[#000000]">{new Date(payment.createdAt).toLocaleString()}</span>
                    </div>
                    <div>
                      <span class="text-[10px] uppercase text-[#a39e98] block">Provider Ref</span>
                      <span class="font-mono text-[#0075de] break-all">{latestVerif?.providerReference || payment.slipOkReferenceId || '-'}</span>
                    </div>
                    {#if payment.slipHash}
                      <div class="sm:col-span-2">
                        <span class="text-[10px] uppercase text-[#a39e98] block">SHA-256 Slip Hash (Dedup)</span>
                        <span class="font-mono text-[10px] text-[#615d59] break-all">{payment.slipHash}</span>
                      </div>
                    {/if}
                  </div>
                </div>

                {#if payment.slipImageUrl}
                  <div class="flex flex-col items-center gap-1.5 shrink-0">
                    <button
                      onclick={() => previewSlipUrl = payment.slipImageUrl}
                      class="group relative overflow-hidden rounded-lg border border-[#e6e6e6] shadow-sm bg-white p-1"
                    >
                      <img src={payment.slipImageUrl} alt="Transfer Slip" class="h-24 w-24 object-contain group-hover:opacity-80 transition-opacity" />
                      <div class="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 group-hover:opacity-100 text-white text-[11px] font-bold transition-opacity">
                        Zoom
                      </div>
                    </button>
                    <span class="text-[10px] text-[#615d59]">Transfer Slip</span>
                  </div>
                {/if}
              </div>

              <!-- Multi-attempt Verification History -->
              {#if payment.verifications?.length > 0}
                <div class="mt-4 border-t border-[#e6e6e6] pt-3">
                  <h4 class="text-[11px] font-bold uppercase tracking-wider text-[#615d59] mb-2">Automated Verification Records</h4>
                  <div class="space-y-2">
                    {#each payment.verifications as v}
                      <div class="rounded-lg bg-white p-3 border border-[#e6e6e6] text-xs">
                        <div class="flex items-center justify-between mb-1.5">
                          <div class="flex items-center gap-2">
                            <span class="rounded px-1.5 py-0.5 text-[10px] font-mono font-bold {v.status === 'success' ? 'bg-[#e8f8eb] text-[#138029]' : 'bg-[#fde8e8] text-[#c53030]'}">
                              {v.provider?.toUpperCase() || 'EASYSLIP'}: {v.status?.toUpperCase()}
                            </span>
                            <span class="font-bold text-[#000000]">Verified: ฿{Number(v.verifiedAmount ?? payment.amount ?? 0).toFixed(2)}</span>
                          </div>
                          <span class="text-[10px] text-[#615d59] font-mono">{new Date(v.createdAt).toLocaleTimeString()}</span>
                        </div>

                        {#if v.senderInfo || v.receiverInfo}
                          <div class="grid grid-cols-2 gap-2 text-[11px] bg-[#fbfbfa] p-2 rounded border border-[#f0efed] mt-2">
                            <div>
                              <span class="text-[#615d59] font-semibold">Sender:</span>
                              <div class="text-[#000000]">{v.senderInfo?.name || '-'} ({v.senderInfo?.bank || ''})</div>
                            </div>
                            <div>
                              <span class="text-[#615d59] font-semibold">Receiver:</span>
                              <div class="text-[#000000]">{v.receiverInfo?.name || '-'} ({v.receiverInfo?.bank || ''})</div>
                            </div>
                          </div>
                        {/if}

                        {#if v.rawResponse}
                          <div class="mt-2 text-right">
                            <button
                              onclick={() => expandedRawVerifId = expandedRawVerifId === v.id ? null : v.id}
                              class="text-[10px] text-[#0075de] hover:underline"
                            >
                              {expandedRawVerifId === v.id ? 'Hide Raw API JSON' : 'Inspect Raw Verification JSON'}
                            </button>
                            {#if expandedRawVerifId === v.id}
                              <pre class="mt-1.5 max-h-48 overflow-auto rounded bg-[#f6f5f4] p-2 text-left text-[10px] font-mono text-[#31302e] border border-[#e6e6e6]">{JSON.stringify(v.rawResponse, null, 2)}</pre>
                            {/if}
                          </div>
                        {/if}
                      </div>
                    {/each}
                  </div>
                </div>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        <p class="text-xs text-[#615d59] py-4 text-center">No payment submissions found for this bill item.</p>
      {/if}
    </div>

    <!-- Edit History Logs -->
    <div class="mt-6 rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h2 class="text-sm font-bold text-[#000000]">Bill Edit & Audit Trail</h2>
          <p class="text-[11px] text-[#615d59]">Every modification made to this bill's amounts or members</p>
        </div>
      </div>

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
                <p class="mt-2 text-xs text-[#31302e] bg-[#fbfbfa] p-2 rounded-md border border-[#e6e6e6] font-medium">{log.note}</p>
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
        <p class="text-xs text-[#615d59] py-3 text-center">No modifications logged on this bill.</p>
      {/if}
    </div>
  {/if}
</div>

<!-- Resolution Modal -->
{#if resolveForm.show}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-xs p-4">
    <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl border border-[#e6e6e6]">
      <h3 class="mb-1 text-base font-bold text-[#000000]">Dispute Determination</h3>
      <p class="text-xs text-[#615d59] mb-4">Select the resolution outcome. System ledger and debtor balance will be updated automatically.</p>

      <div class="space-y-3.5">
        <div>
          <label for="resolve-decision" class="block text-[11px] font-bold text-[#615d59] uppercase">Determination Decision</label>
          <select id="resolve-decision" bind:value={resolveForm.status} class="mt-1 block w-full rounded-[6px] border border-[#e6e6e6] bg-white px-3 py-2 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none shadow-2xs">
            <option value="resolved_paid">✓ Confirmed Paid (Valid Transfer Slip / Mark Paid)</option>
            <option value="resolved_written_off">✂ Write Off Debt (Forgive / Cancel Remaining Debt)</option>
            <option value="resolved_rejected">✕ Reject Claim (Invalid Slip / Fraud / Keep Debt Unpaid)</option>
          </select>
        </div>
        <div>
          <label for="resolve-note" class="block text-[11px] font-bold text-[#615d59] uppercase">Official Determination Rationale</label>
          <textarea id="resolve-note" bind:value={resolveForm.note} rows={4} class="mt-1 block w-full rounded-[6px] border border-[#e6e6e6] bg-white px-3 py-2 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none shadow-2xs" placeholder="Explain the verification evidence and rationale for this determination..."></textarea>
        </div>
      </div>

      <div class="mt-6 flex justify-end gap-2 border-t border-[#e6e6e6] pt-4">
        <button onclick={() => resolveForm.show = false} class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors">
          Cancel
        </button>
        <button
          onclick={submitResolve}
          disabled={!resolveForm.note.trim()}
          class="rounded-md bg-[#1aae39] px-4 py-1.5 text-xs font-medium text-white hover:bg-[#138029] disabled:opacity-50 shadow-sm transition-colors"
        >
          Confirm Determination
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Image Zoom Modal -->
{#if previewSlipUrl}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" onclick={() => previewSlipUrl = null} role="presentation">
    <div class="relative max-h-screen max-w-2xl overflow-auto rounded-2xl bg-white p-4 shadow-2xl border border-[#e6e6e6]" onclick={(e) => e.stopPropagation()} role="presentation">
      <img src={previewSlipUrl} alt="Transfer Slip Preview" class="max-h-[85vh] w-auto mx-auto rounded-lg" />
      <button
        onclick={() => previewSlipUrl = null}
        class="absolute top-6 right-6 rounded-full bg-black/60 px-3 py-1 text-xs text-white hover:bg-black transition-colors"
      >
        &times; Close
      </button>
    </div>
  </div>
{/if}
