<script lang="ts">
  import { getPaymentDetail } from '$lib/api/client';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let paymentId = $derived($page.params.id || '');
  let payment = $state<any>(null);
  let loading = $state(true);
  let error = $state('');
  let showRawResponse = $state(false);
  let showQrPayload = $state(false);

  async function load() {
    if (!paymentId) return;
    loading = true;
    error = '';
    try {
      const res = await getPaymentDetail(paymentId);
      payment = res.data;
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  onMount(load);
</script>

<div>
  <a href="/payments" class="mb-4 inline-flex items-center gap-1 text-xs font-medium text-[#0075de] hover:underline">&larr; Back to Payments</a>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-8 text-center shadow-sm">
      <LoadingLottie text="Loading payment details..." size={160} />
    </div>
  {:else if error}
    <div class="rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030]">{error}</div>
  {:else if payment}
    <!-- Header -->
    <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Payment Transaction Detail</h1>
          <StatusBadge status={payment.status} size="md" />
        </div>
        <p class="mt-0.5 text-xs text-[#615d59] font-mono">Payment ID: {payment.id}</p>
      </div>

      <div class="text-right">
        <span class="text-xs text-[#615d59]">Transfer Amount</span>
        <div class="text-2xl font-bold text-[#000000]">
          ฿{Number(payment.amount || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
      <!-- Left 2 Cols: Verification & Audit Details -->
      <div class="space-y-6 lg:col-span-2">
        <!-- EasySlip / SlipOK Verification Results Card -->
        <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h2 class="text-sm font-bold text-[#000000]">Slip Verification Intelligence</h2>
              <p class="text-[11px] text-[#615d59]">Bank slip verification through EasySlip v2 / SlipOK engine</p>
            </div>
            {#if payment.verifications && payment.verifications.length > 0}
              <span class="rounded px-2 py-0.5 text-[10px] font-mono font-semibold {payment.verifications[0].status === 'success' ? 'bg-[#e8f8eb] text-[#138029]' : 'bg-[#fde8e8] text-[#c53030]'}">
                {payment.verifications[0].provider?.toUpperCase() || 'EASYSLIP'}: {payment.verifications[0].status?.toUpperCase()}
              </span>
            {/if}
          </div>

          {#if payment.verifications && payment.verifications.length > 0}
            {@const verif = payment.verifications[0]}
            <div class="space-y-4 text-xs">
              <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 bg-[#fbfbfa] p-3.5 rounded-lg border border-[#e6e6e6]">
                <div>
                  <span class="text-[#615d59] text-[11px]">Provider:</span>
                  <div class="font-semibold text-[#000000] font-mono">{verif.provider || 'easyslip'}</div>
                </div>
                <div>
                  <span class="text-[#615d59] text-[11px]">Transaction Reference:</span>
                  <div class="font-mono text-[#000000] break-all">{verif.providerReference || payment.slipOkReferenceId || '-'}</div>
                </div>
                <div>
                  <span class="text-[#615d59] text-[11px]">Verified Amount:</span>
                  <div class="font-bold text-[#000000] font-mono">฿{Number(verif.verifiedAmount || payment.amount || 0).toFixed(2)}</div>
                </div>
                <div>
                  <span class="text-[#615d59] text-[11px]">Verified Date:</span>
                  <div class="text-[#000000]">{new Date(verif.createdAt || payment.slipOkVerifiedAt).toLocaleString()}</div>
                </div>
              </div>

              <!-- Sender & Receiver details if available -->
              {#if verif.senderInfo || verif.receiverInfo}
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 pt-2">
                  <div class="rounded-lg border border-[#f0efed] p-3">
                    <h4 class="font-bold text-[11px] text-[#615d59] uppercase mb-1">Sender (Bank)</h4>
                    <p class="font-medium text-[#000000]">{verif.senderInfo?.name || verif.senderInfo?.displayName || '-'}</p>
                    <p class="font-mono text-[11px] text-[#615d59]">{verif.senderInfo?.bank || verif.senderInfo?.bankCode || ''} {verif.senderInfo?.accountNumber || ''}</p>
                  </div>
                  <div class="rounded-lg border border-[#f0efed] p-3">
                    <h4 class="font-bold text-[11px] text-[#615d59] uppercase mb-1">Receiver (Creditor)</h4>
                    <p class="font-medium text-[#000000]">{verif.receiverInfo?.name || verif.receiverInfo?.displayName || '-'}</p>
                    <p class="font-mono text-[11px] text-[#615d59]">{verif.receiverInfo?.bank || verif.receiverInfo?.bankCode || ''} {verif.receiverInfo?.accountNumber || ''}</p>
                  </div>
                </div>
              {/if}

              <!-- Raw API Response Toggle -->
              <div class="border-t border-[#e6e6e6] pt-3">
                <button
                  onclick={() => showRawResponse = !showRawResponse}
                  class="flex w-full items-center justify-between font-semibold text-[#31302e] hover:text-[#0075de]"
                >
                  <span>Raw Verification Response Payload</span>
                  <span>{showRawResponse ? '▲' : '▼'}</span>
                </button>
                {#if showRawResponse}
                  <pre class="mt-2 max-h-56 overflow-auto rounded bg-[#f6f5f4] p-3 text-[10px] font-mono text-[#31302e] border border-[#e6e6e6]">{JSON.stringify(verif.rawResponse || payment.slipOkRawResponse || {}, null, 2)}</pre>
                {/if}
              </div>
            </div>
          {:else}
            <p class="text-xs text-[#615d59] py-4 text-center">No automated slip verification record found for this transaction.</p>
          {/if}
        </div>

        <!-- Bill & Debtor Context Card -->
        <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
          <h2 class="text-sm font-bold text-[#000000] mb-3">Associated Bill & Debtor</h2>
          <div class="space-y-3 text-xs">
            {#if payment.billItem?.bill}
              <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
                <span class="text-[#615d59]">Bill:</span>
                <a href="/bills/{payment.billItem.bill.id}" class="font-medium text-[#0075de] hover:underline">
                  {payment.billItem.bill.title || 'Untitled Bill'} &rarr;
                </a>
              </div>
            {/if}
            {#if payment.billItem?.debtor}
              <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
                <span class="text-[#615d59]">Debtor:</span>
                <a href="/users/{payment.billItem.debtor.id}" class="font-medium text-[#0075de] hover:underline">
                  {payment.billItem.debtor.displayName || payment.billItem.debtor.fullName || payment.billItem.debtor.userCode}
                </a>
              </div>
            {/if}
            {#if payment.billItem}
              <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
                <span class="text-[#615d59]">Debtor Total Share:</span>
                <span class="font-mono text-[#000000]">฿{Number(payment.billItem.currentAmount || 0).toFixed(2)}</span>
              </div>
            {/if}
            <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
              <span class="text-[#615d59]">Payment Method:</span>
              <span class="capitalize text-[#000000]">{payment.method} ({payment.channel?.replace(/_/g, ' ')})</span>
            </div>
            {#if payment.confirmedByOwnerAt}
              <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
                <span class="text-[#615d59]">Owner Confirmed At:</span>
                <span class="text-[#138029] font-medium">{new Date(payment.confirmedByOwnerAt).toLocaleString()}</span>
              </div>
            {/if}
            {#if payment.rejectedAt}
              <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
                <span class="text-[#615d59]">Rejected At:</span>
                <span class="text-[#c53030] font-medium">{new Date(payment.rejectedAt).toLocaleString()} ({payment.rejectedReason || 'No reason specified'})</span>
              </div>
            {/if}
          </div>
        </div>
      </div>

      <!-- Right 1 Col: Slip Image & PromptPay QR -->
      <div class="space-y-6">
        <!-- Payer Card -->
        <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
          <h2 class="mb-4 text-sm font-bold text-[#000000]">Payer Information</h2>
          {#if payment.payer}
            <div class="flex items-center gap-3 mb-4">
              {#if payment.payer.avatarUrl}
                <img src={payment.payer.avatarUrl} alt="" class="h-10 w-10 rounded-full object-cover border border-[#e6e6e6]" />
              {:else}
                <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[#0075de] text-sm font-bold text-white">
                  {(payment.payer.displayName || payment.payer.fullName || 'U')[0]}
                </div>
              {/if}
              <div>
                <a href="/users/{payment.payer.id}" class="text-xs font-bold text-[#000000] hover:text-[#0075de] hover:underline">
                  {payment.payer.displayName || payment.payer.fullName || payment.payer.userCode}
                </a>
                <p class="text-[10px] font-mono text-[#615d59]">{payment.payer.userCode}</p>
              </div>
            </div>
          {/if}
        </div>

        <!-- Transfer Slip Image -->
        <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-sm font-bold text-[#000000]">Transfer Slip Photo</h2>
            {#if payment.slipImageUrl}
              <a href={payment.slipImageUrl} target="_blank" rel="noreferrer" class="text-[11px] text-[#0075de] hover:underline">
                Open Full &rarr;
              </a>
            {/if}
          </div>

          {#if payment.slipImageUrl}
            <div class="overflow-hidden rounded-lg border border-[#e6e6e6] bg-[#fbfbfa]">
              <img src={payment.slipImageUrl} alt="Transfer Slip" class="max-h-72 w-full object-contain" />
            </div>
            {#if payment.slipHash}
              <p class="mt-2 text-[10px] font-mono text-[#615d59] truncate" title="SHA-256 slip hash for duplicate prevention">
                Hash: {payment.slipHash}
              </p>
            {/if}
          {:else}
            <div class="flex h-36 items-center justify-center rounded-lg border border-dashed border-[#e6e6e6] bg-[#fbfbfa] text-xs text-[#615d59]">
              No slip photo uploaded
            </div>
          {/if}
        </div>

        <!-- EMVCo PromptPay QR Snapshot -->
        {#if payment.promptPayQrImageUrl || payment.promptPayQrPayload}
          <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
            <h2 class="text-sm font-bold text-[#000000] mb-3">Generated PromptPay QR</h2>
            {#if payment.promptPayQrImageUrl}
              <div class="flex justify-center p-3 bg-[#fbfbfa] rounded-lg border border-[#e6e6e6] mb-3">
                <img src={payment.promptPayQrImageUrl} alt="PromptPay QR" class="h-36 w-36 object-contain" />
              </div>
            {/if}
            {#if payment.promptPayQrPayload}
              <button
                onclick={() => showQrPayload = !showQrPayload}
                class="text-[11px] font-medium text-[#0075de] hover:underline"
              >
                {showQrPayload ? 'Hide EMVCo Payload' : 'Show EMVCo QR String'}
              </button>
              {#if showQrPayload}
                <p class="mt-1.5 break-all rounded bg-[#f6f5f4] p-2 text-[10px] font-mono text-[#31302e] border border-[#e6e6e6]">{payment.promptPayQrPayload}</p>
              {/if}
            {/if}
          </div>
        {/if}
      </div>
    </div>
  {/if}
</div>
