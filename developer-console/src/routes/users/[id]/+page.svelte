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
  <a href="/users" class="mb-4 inline-block text-sm text-blue-600 hover:underline">&larr; Back to Users</a>

  {#if loading}
    <p class="text-gray-500">Loading...</p>
  {:else if error}
    <div class="rounded-md bg-red-50 p-4 text-red-700">{error}</div>
  {:else if user}
    <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">{user.displayName || user.fullName || user.userCode}</h1>
        <p class="text-sm text-gray-500 font-mono">ID: {user.id}</p>
      </div>

      <div class="flex items-center gap-2">
        {#if user.accountStatus === 'active' && user.role !== 'developer'}
          <button onclick={() => openAction('suspend')} class="rounded bg-yellow-600 px-4 py-2 text-sm font-medium text-white hover:bg-yellow-700">
            Suspend Account
          </button>
          <button onclick={() => openAction('ban')} class="rounded bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700">
            Ban Account
          </button>
        {:else if user.accountStatus === 'suspended' || user.accountStatus === 'banned'}
          <button onclick={() => openAction('unsuspend')} class="rounded bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700">
            Restore Account
          </button>
        {/if}
      </div>
    </div>

    {#if actionMessage}
      <div class="mb-4 rounded-md bg-green-50 p-3 text-sm text-green-700">{actionMessage}</div>
    {/if}

    <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <!-- Profile Card -->
      <div class="rounded-lg bg-white p-6 shadow">
        <h2 class="mb-4 text-lg font-semibold text-gray-800">Profile Details</h2>
        <dl class="space-y-3">
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">User Code</dt>
            <dd class="text-sm font-mono font-medium">{user.userCode}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Display Name</dt>
            <dd class="text-sm">{user.displayName || '-'}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Full Name</dt>
            <dd class="text-sm">{user.fullName || '-'}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Phone</dt>
            <dd class="text-sm">{user.phoneNumber || '-'}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Role</dt>
            <dd><StatusBadge status={user.role} /></dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Account Status</dt>
            <dd><StatusBadge status={user.accountStatus} /></dd>
          </div>
          {#if user.suspendedUntil}
            <div class="flex justify-between">
              <dt class="text-sm text-gray-500">Suspended Until</dt>
              <dd class="text-sm font-semibold text-red-600">{new Date(user.suspendedUntil).toLocaleString()}</dd>
            </div>
          {/if}
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Registered</dt>
            <dd class="text-sm">{new Date(user.createdAt).toLocaleDateString()}</dd>
          </div>
        </dl>
      </div>

      <!-- Financial & Banking Card -->
      <div class="rounded-lg bg-white p-6 shadow">
        <h2 class="mb-4 text-lg font-semibold text-gray-800">Payment & Bank Info</h2>
        <dl class="space-y-3">
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">PromptPay ID</dt>
            <dd class="text-sm font-mono">{user.promptPayId || '-'}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">PromptPay Type</dt>
            <dd class="text-sm">{user.promptPayIdType || '-'}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Bank Name</dt>
            <dd class="text-sm">{user.bankName || '-'}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">Bank Account Number</dt>
            <dd class="text-sm font-mono">{user.bankAccountNumber || '-'}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm text-gray-500">PromptPay Verified</dt>
            <dd class="text-sm">{user.promptPayVerifiedAt ? new Date(user.promptPayVerifiedAt).toLocaleDateString() : 'Not verified'}</dd>
          </div>
        </dl>

        <div class="mt-6 border-t pt-4">
          <h3 class="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">Audit Quick Links</h3>
          <div class="flex flex-wrap gap-2">
            <a href="/transactions?userId={user.id}" class="rounded bg-blue-50 px-3 py-1.5 text-xs font-medium text-blue-700 hover:bg-blue-100">
              Transactions &rarr;
            </a>
            <a href="/activity-logs?userId={user.id}" class="rounded bg-gray-100 px-3 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-200">
              Activity Logs &rarr;
            </a>
            <a href="/suspicious?userId={user.id}" class="rounded bg-red-50 px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-100">
              Suspicious Logs &rarr;
            </a>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>

{#if actionModal.show}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
    <div class="w-full max-w-md rounded-lg bg-white p-6 shadow-xl">
      <h3 class="mb-4 text-lg font-bold capitalize">{actionModal.type} Account</h3>
      <div class="space-y-4">
        <div>
          <label for="user-detail-modal-reason" class="block text-sm font-medium text-gray-700">Reason for audit log</label>
          <textarea id="user-detail-modal-reason" bind:value={actionModal.reason} rows={3} class="mt-1 block w-full rounded border border-gray-300 px-3 py-2 text-sm" placeholder="Provide reason..."></textarea>
        </div>
        {#if actionModal.type === 'suspend'}
          <div>
            <label for="user-detail-modal-duration" class="block text-sm font-medium text-gray-700">Duration in Days (optional)</label>
            <input id="user-detail-modal-duration" type="number" bind:value={actionModal.durationDays} min={1} class="mt-1 block w-full rounded border border-gray-300 px-3 py-2 text-sm" placeholder="e.g. 7" />
            <p class="mt-1 text-xs text-gray-500">Leave empty for indefinite suspension until manually restored</p>
          </div>
        {/if}
      </div>
      <div class="mt-6 flex justify-end gap-3">
        <button onclick={() => actionModal.show = false} class="rounded border border-gray-300 px-4 py-2 text-sm">Cancel</button>
        <button
          onclick={executeAction}
          disabled={!actionModal.reason}
          class="rounded px-4 py-2 text-sm font-medium text-white disabled:opacity-50 {actionModal.type === 'ban' ? 'bg-red-600 hover:bg-red-700' : actionModal.type === 'suspend' ? 'bg-yellow-600 hover:bg-yellow-700' : 'bg-green-600 hover:bg-green-700'}"
        >
          Confirm {actionModal.type}
        </button>
      </div>
    </div>
  </div>
{/if}
