<script lang="ts">
  import { getUserDetail, suspendUser, banUser, unsuspendUser } from '$lib/api/client';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import Icon from '$lib/components/Icon.svelte';

  let userId = $derived($page.params.id || '');
  let user = $state<any>(null);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');
  let copiedTokenId = $state<string | null>(null);

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

  function getPlatformIcon(platform: string = '', brand: string = '', model: string = ''): 'apple' | 'android' | 'windows' | 'mac' | 'smartphone' {
    const p = (platform || '').toLowerCase();
    const b = (brand || '').toLowerCase();
    const m = (model || '').toLowerCase();
    if (p.includes('ios') || b.includes('apple') || m.includes('iphone') || m.includes('ipad')) return 'apple';
    if (p.includes('mac') || p.includes('darwin')) return 'mac';
    if (p.includes('win') || b.includes('microsoft')) return 'windows';
    if (p.includes('android') || b.includes('samsung') || b.includes('google') || b.includes('xiaomi') || b.includes('oppo') || b.includes('vivo') || b.includes('realme') || b.includes('huawei')) return 'android';
    return 'smartphone';
  }

  function copyToClipboard(text: string, id: string) {
    if (typeof navigator !== 'undefined') {
      navigator.clipboard.writeText(text);
      copiedTokenId = id;
      setTimeout(() => {
        if (copiedTokenId === id) copiedTokenId = null;
      }, 2000);
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
            <dt class="text-xs text-[#615d59]">Email</dt>
            <dd class="text-xs text-[#000000]">{user.email || '-'}</dd>
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
      </div>
    </div>

    <!-- Registered Devices & Client Hardware Card -->
    <div class="mt-6 rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center gap-2">
          <div class="flex h-7 w-7 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de]">
            <Icon name="smartphone" class="h-4 w-4" />
          </div>
          <div>
            <h2 class="text-sm font-bold text-[#000000]">Registered Devices & Hardware</h2>
            <p class="text-[11px] text-[#615d59]">Client device specifications, operating system, and FCM push tokens</p>
          </div>
        </div>
        <span class="text-xs font-mono text-[#615d59]">{user.deviceTokens?.length || 0} device(s)</span>
      </div>

      {#if user.deviceTokens && user.deviceTokens.length > 0}
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {#each user.deviceTokens as dt}
            {@const iconName = getPlatformIcon(dt.platform, dt.deviceBrand, dt.deviceModel)}
            <div class="rounded-xl border border-[#e6e6e6] bg-[#fbfbfa] p-4 flex flex-col justify-between hover:border-[#0075de] transition-colors">
              <div>
                <!-- Header: Platform Icon + Device Name -->
                <div class="flex items-start justify-between gap-2 mb-3">
                  <div class="flex items-center gap-2.5">
                    <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-white border border-[#e6e6e6] text-[#000000] shadow-2xs">
                      <Icon name={iconName} class="h-5 w-5 {iconName === 'android' ? 'text-[#1aae39]' : iconName === 'windows' ? 'text-[#0075de]' : 'text-[#000000]'}" />
                    </div>
                    <div>
                      <h4 class="font-bold text-xs text-[#000000] leading-snug">
                        {dt.deviceName && dt.deviceName !== 'Unknown Device' ? dt.deviceName : (dt.deviceModel || 'Mobile Device')}
                      </h4>
                      <span class="inline-block text-[10px] font-mono uppercase text-[#615d59]">
                        {dt.deviceBrand && dt.deviceBrand !== 'Unknown Brand' ? dt.deviceBrand : dt.platform}
                      </span>
                    </div>
                  </div>
                  <span class="rounded-full bg-[#e8f8eb] px-2 py-0.5 text-[10px] font-semibold text-[#138029]">Active</span>
                </div>

                <!-- Specs Breakdown -->
                <dl class="space-y-1.5 text-[11px] border-t border-[#f0efed] pt-2.5">
                  <div class="flex justify-between">
                    <dt class="text-[#615d59]">Model:</dt>
                    <dd class="font-medium text-[#000000] font-mono">{dt.deviceModel || '-'}</dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-[#615d59]">OS Version:</dt>
                    <dd class="font-medium text-[#000000]">{dt.osVersion || '-'}</dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-[#615d59]">App Version:</dt>
                    <dd class="font-medium text-[#000000] font-mono">{dt.appVersion || '1.0.0'}</dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-[#615d59]">Last Sync:</dt>
                    <dd class="text-[#615d59] font-mono">{new Date(dt.updatedAt || dt.createdAt).toLocaleDateString()}</dd>
                  </div>
                </dl>
              </div>

              <!-- Token copy footer -->
              <div class="mt-3 pt-2.5 border-t border-[#e6e6e6] flex items-center justify-between text-[10px]">
                <span class="text-[#615d59] font-mono truncate max-w-[170px]" title={dt.token}>
                  {dt.token.slice(0, 16)}...{dt.token.slice(-8)}
                </span>
                <button
                  type="button"
                  onclick={() => copyToClipboard(dt.token, dt.id)}
                  class="font-semibold transition-colors {copiedTokenId === dt.id ? 'text-[#1aae39]' : 'text-[#0075de] hover:underline'}"
                >
                  {copiedTokenId === dt.id ? 'Copied!' : 'Copy Token'}
                </button>
              </div>
            </div>
          {/each}
        </div>
      {:else}
        <div class="rounded-lg border border-dashed border-[#e6e6e6] bg-[#fbfbfa] p-6 text-center text-xs text-[#615d59]">
          <Icon name="smartphone" class="h-6 w-6 mx-auto mb-2 text-[#a39e98]" />
          <p class="font-semibold text-[#000000]">No registered devices</p>
          <p class="text-[11px] text-[#615d59] mt-0.5">This user has not yet signed in on a client device to register an FCM push token.</p>
        </div>
      {/if}
    </div>

    <!-- Quick Navigation Hub -->
    <div class="mt-6 rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm">
      <h3 class="text-[11px] font-semibold uppercase tracking-wider text-[#615d59] mb-3">Audit Quick Links</h3>
      <div class="flex flex-wrap gap-2.5">
        <a href="/transactions?userId={user.id}" class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#0075de] hover:bg-[#e8f3fc] transition-colors">
          Transactions Explorer &rarr;
        </a>
        <a href="/activity-logs?userId={user.id}" class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors">
          Activity Logs &rarr;
        </a>
        <a href="/suspicious?userId={user.id}" class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#c53030] hover:bg-[#fde8e8] transition-colors">
          Suspicious Logs &rarr;
        </a>
        <a href="/security?userId={user.id}" class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#dd5b00] hover:bg-[#fef2e8] transition-colors">
          Security Events &rarr;
        </a>
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
