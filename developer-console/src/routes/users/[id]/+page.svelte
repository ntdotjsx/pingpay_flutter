<script lang="ts">
  import { getUserDetail, suspendUser, banUser, unsuspendUser } from '$lib/api/client';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';

  let userId = $derived($page.params.id || '');
  let user = $state<any>(null);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');

  let actionModal = $state<{
    show: boolean;
    type: 'suspend' | 'ban' | 'unsuspend';
    reason: string;
    durationDays: number | undefined;
  }>({
    show: false,
    type: 'suspend',
    reason: '',
    durationDays: undefined,
  });

  async function load() {
    if (!userId) return;
    loading = true;
    error = '';
    try {
      const res = await getUserDetail(userId);
      user = res.data;
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  onMount(load);

  function openAction(type: 'suspend' | 'ban' | 'unsuspend') {
    actionModal = {
      show: true,
      type,
      reason: '',
      durationDays: type === 'suspend' ? 7 : undefined,
    };
  }

  async function executeAction() {
    if (!userId) return;
    try {
      if (actionModal.type === 'suspend') {
        await suspendUser(userId, actionModal.reason, actionModal.durationDays);
      } else if (actionModal.type === 'ban') {
        await banUser(userId, actionModal.reason);
      } else {
        await unsuspendUser(userId, actionModal.reason);
      }
      actionMessage = `User successfully ${actionModal.type === 'unsuspend' ? 'restored' : actionModal.type + 'ed'}.`;
      actionModal.show = false;
      load();
    } catch (e: any) {
      error = e.message;
    }
  }
</script>

<div>
  <a href="/users" class="mb-4 inline-flex items-center gap-1 text-xs font-medium text-[#0075de] hover:underline">&larr; Back to Users</a>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-8 text-center shadow-sm">
      <p class="text-xs text-[#615d59]">Loading user details...</p>
    </div>
  {:else if error}
    <div class="rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030]">{error}</div>
  {:else if user}
    <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-bold tracking-tight text-[#000000]">{user.displayName || user.fullName || user.userCode}</h1>
        <p class="text-xs text-[#615d59] font-mono mt-0.5">ID: {user.id}</p>
      </div>

      <div class="flex items-center gap-2">
        {#if user.accountStatus === 'active' && user.role !== 'developer'}
          <button onclick={() => openAction('suspend')} class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#dd5b00] hover:bg-[#fef2e8] transition-colors">
            Suspend Account
          </button>
          <button onclick={() => openAction('ban')} class="rounded-md bg-[#c53030] px-3.5 py-1.5 text-xs font-medium text-white hover:bg-[#a82525] transition-colors">
            Ban Account
          </button>
        {:else if user.accountStatus === 'suspended' || user.accountStatus === 'banned'}
          <button onclick={() => openAction('unsuspend')} class="rounded-md bg-[#1aae39] px-3.5 py-1.5 text-xs font-medium text-white hover:bg-[#138029] transition-colors">
            Restore Account
          </button>
        {/if}
      </div>
    </div>

    {#if actionMessage}
      <div class="mb-4 rounded-md bg-[#e8f8eb] border border-[#e8f8eb] p-3 text-xs text-[#138029]">{actionMessage}</div>
    {/if}

    <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <!-- Profile Card -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
        <div class="flex items-center gap-3 mb-4">
          {#if user.avatarUrl}
            <img src={user.avatarUrl} alt="" class="h-10 w-10 rounded-full object-cover border border-[#e6e6e6]" />
          {:else}
            <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[#0075de] text-sm font-bold text-white">
              {(user.displayName || user.fullName || 'U')[0]}
            </div>
          {/if}
          <div>
            <h2 class="text-sm font-bold text-[#000000]">Profile Details</h2>
            <p class="text-[11px] text-[#615d59]">{user.profileCompletedAt ? 'Completed Profile' : 'Onboarding Pending'}</p>
          </div>
        </div>

        <dl class="space-y-3">
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">User Code</dt>
            <dd class="text-xs font-mono font-medium text-[#000000]">{user.userCode}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Display Name</dt>
            <dd class="text-xs text-[#000000]">{user.displayName || '-'}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Full Name</dt>
            <dd class="text-xs text-[#000000]">{user.fullName || '-'}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Phone</dt>
            <dd class="text-xs text-[#000000]">{user.phoneNumber || '-'}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Role</dt>
            <dd><StatusBadge status={user.role} /></dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Account Status</dt>
            <dd><StatusBadge status={user.accountStatus} /></dd>
          </div>
          {#if user.suspendedUntil}
            <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
              <dt class="text-xs text-[#615d59]">Suspended Until</dt>
              <dd class="text-xs font-semibold text-[#c53030]">{new Date(user.suspendedUntil).toLocaleString()}</dd>
            </div>
          {/if}
          <div class="flex justify-between pt-1">
            <dt class="text-xs text-[#615d59]">Registered</dt>
            <dd class="text-xs text-[#000000]">{new Date(user.createdAt).toLocaleDateString()}</dd>
          </div>
        </dl>
      </div>

      <!-- Financial & Banking Card -->
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
        <h2 class="mb-4 text-sm font-bold text-[#000000]">Payment & Bank Info</h2>
        <dl class="space-y-3">
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">PromptPay ID</dt>
            <dd class="text-xs font-mono text-[#000000]">{user.promptPayId || '-'}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">PromptPay Type</dt>
            <dd class="text-xs text-[#000000]">{user.promptPayIdType || '-'}</dd>
          </div>
          <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
            <dt class="text-xs text-[#615d59]">Bank Account Number</dt>
            <dd class="text-xs font-mono text-[#000000]">{user.bankAccountNumber || '-'}</dd>
          </div>
          <div class="flex justify-between pt-1">
            <dt class="text-xs text-[#615d59]">PromptPay Verified</dt>
            <dd class="text-xs text-[#000000]">{user.promptPayVerifiedAt ? new Date(user.promptPayVerifiedAt).toLocaleDateString() : 'Not verified'}</dd>
          </div>
        </dl>

        <div class="mt-6 border-t border-[#e6e6e6] pt-4">
          <h2 class="mb-3 text-sm font-bold text-[#000000]">Rewards & Shipping Info</h2>
          <dl class="space-y-2.5">
            <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
              <dt class="text-xs text-[#615d59]">Reward Points</dt>
              <dd class="text-xs font-bold text-[#0075de]">{user.rewardPoints ?? 0} pts</dd>
            </div>
            <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
              <dt class="text-xs text-[#615d59]">Shipping Recipient</dt>
              <dd class="text-xs text-[#000000]">{user.shippingRecipientName || '-'}</dd>
            </div>
            <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
              <dt class="text-xs text-[#615d59]">Shipping Phone</dt>
              <dd class="text-xs text-[#000000]">{user.shippingPhone || '-'}</dd>
            </div>
            <div class="flex justify-between pt-1">
              <dt class="text-xs text-[#615d59]">Shipping Address</dt>
              <dd class="text-xs text-[#000000] max-w-[200px] text-right truncate">{user.shippingAddress || '-'}</dd>
            </div>
          </dl>
        </div>

        <div class="mt-6 border-t border-[#e6e6e6] pt-4">
          <h3 class="text-[11px] font-semibold uppercase tracking-wider text-[#615d59] mb-2.5">Audit Quick Links</h3>
          <div class="flex flex-wrap gap-2">
            <a href="/transactions?userId={user.id}" class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#0075de] hover:bg-[#e8f3fc] transition-colors">
              Transactions &rarr;
            </a>
            <a href="/activity-logs?userId={user.id}" class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors">
              Activity Logs &rarr;
            </a>
            <a href="/suspicious?userId={user.id}" class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#c53030] hover:bg-[#fde8e8] transition-colors">
              Suspicious Logs &rarr;
            </a>
            <a href="/security?userId={user.id}" class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#dd5b00] hover:bg-[#fef2e8] transition-colors">
              Security Events &rarr;
            </a>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>

{#if actionModal.show}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
    <div class="w-full max-w-md rounded-xl bg-white p-6 shadow-xl border border-[#e6e6e6]">
      <h3 class="mb-3 text-base font-bold text-[#000000] capitalize">{actionModal.type} Account</h3>
      <div class="space-y-3">
        <div>
          <label for="user-detail-modal-reason" class="block text-[11px] font-medium text-[#615d59]">Reason for audit log</label>
          <textarea id="user-detail-modal-reason" bind:value={actionModal.reason} rows={3} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" placeholder="Provide reason..."></textarea>
        </div>
        {#if actionModal.type === 'suspend'}
          <div>
            <label for="user-detail-modal-duration" class="block text-[11px] font-medium text-[#615d59]">Duration in Days (optional)</label>
            <input id="user-detail-modal-duration" type="number" bind:value={actionModal.durationDays} min={1} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" placeholder="e.g. 7" />
            <p class="mt-1 text-[11px] text-[#a39e98]">Leave empty for indefinite suspension until manually restored</p>
          </div>
        {/if}
      </div>
      <div class="mt-6 flex justify-end gap-2 border-t border-[#e6e6e6] pt-3">
        <button onclick={() => actionModal.show = false} class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors">Cancel</button>
        <button
          onclick={executeAction}
          disabled={!actionModal.reason}
          class="rounded-md px-3.5 py-1.5 text-xs font-medium text-white disabled:opacity-50 transition-colors {actionModal.type === 'ban' ? 'bg-[#c53030] hover:bg-[#a82525]' : actionModal.type === 'suspend' ? 'bg-[#dd5b00] hover:bg-[#b34900]' : 'bg-[#1aae39] hover:bg-[#138029]'}"
        >
          Confirm {actionModal.type}
        </button>
      </div>
    </div>
  </div>
{/if}
