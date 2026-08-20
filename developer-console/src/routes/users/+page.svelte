<script lang="ts">
  import { getUsers, suspendUser, banUser, unsuspendUser } from '$lib/api/client';
  import { onMount } from 'svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import Pagination from '$lib/components/Pagination.svelte';

  let rows = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');

  let filters = $state({
    search: '',
    accountStatus: '',
    role: '',
    page: 1,
    limit: 20,
  });

  let actionModal = $state<{
    show: boolean;
    type: 'suspend' | 'ban' | 'unsuspend';
    userId: string;
    userName: string;
    reason: string;
    durationDays: number | undefined;
  }>({
    show: false,
    type: 'suspend',
    userId: '',
    userName: '',
    reason: '',
    durationDays: undefined,
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getUsers(filters);
      rows = res.data.rows;
      total = res.data.total;
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  onMount(load);

  function applyFilters() {
    filters.page = 1;
    load();
  }

  function changePage(p: number) {
    filters.page = p;
    load();
  }

  function openAction(type: 'suspend' | 'ban' | 'unsuspend', user: any) {
    actionModal = {
      show: true,
      type,
      userId: user.id,
      userName: user.displayName || user.fullName || user.userCode,
      reason: '',
      durationDays: type === 'suspend' ? 7 : undefined,
    };
  }

  async function executeAction() {
    try {
      if (actionModal.type === 'suspend') {
        await suspendUser(actionModal.userId, actionModal.reason, actionModal.durationDays);
      } else if (actionModal.type === 'ban') {
        await banUser(actionModal.userId, actionModal.reason);
      } else {
        await unsuspendUser(actionModal.userId, actionModal.reason);
      }
      actionMessage = `${actionModal.type} action on ${actionModal.userName} completed`;
      actionModal.show = false;
      load();
    } catch (e: any) {
      error = e.message;
    }
  }
</script>

<div>
  <h1 class="mb-6 text-2xl font-bold text-gray-900">User Management</h1>

  {#if actionMessage}
    <div class="mb-4 rounded-md bg-green-50 p-3 text-sm text-green-700">{actionMessage}</div>
  {/if}

  <div class="mb-6 rounded-lg bg-white p-4 shadow">
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <div>
        <label for="filter-user-search" class="block text-xs font-medium text-gray-600">Search User</label>
        <input id="filter-user-search" type="text" bind:value={filters.search} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm" placeholder="Name, code, phone..." />
      </div>
      <div>
        <label for="filter-user-status" class="block text-xs font-medium text-gray-600">Account Status</label>
        <select id="filter-user-status" bind:value={filters.accountStatus} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm">
          <option value="">All Statuses</option>
          <option value="active">Active</option>
          <option value="suspended">Suspended</option>
          <option value="banned">Banned</option>
        </select>
      </div>
      <div>
        <label for="filter-user-role" class="block text-xs font-medium text-gray-600">Role</label>
        <select id="filter-user-role" bind:value={filters.role} class="mt-1 block w-full rounded border border-gray-300 px-3 py-1.5 text-sm">
          <option value="">All Roles</option>
          <option value="user">User</option>
          <option value="developer">Developer</option>
        </select>
      </div>
    </div>
    <div class="mt-4 flex justify-between items-center">
      <button onclick={applyFilters} class="rounded bg-blue-600 px-4 py-1.5 text-sm font-medium text-white hover:bg-blue-700">Filter</button>
      <span class="text-xs text-gray-500">Total: {total} users</span>
    </div>
  </div>

  {#if loading}
    <p class="text-gray-500">Loading...</p>
  {:else if error}
    <div class="rounded-md bg-red-50 p-4 text-red-700">{error}</div>
  {:else}
    <div class="overflow-x-auto rounded-lg bg-white shadow">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">User</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Code</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Role</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Status</th>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Joined</th>
            <th class="px-4 py-3 text-right text-xs font-medium uppercase text-gray-500">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          {#each rows as user}
            <tr class="hover:bg-gray-50">
              <td class="px-4 py-3">
                <div class="flex items-center gap-2">
                  {#if user.avatarUrl}
                    <img src={user.avatarUrl} alt="" class="h-8 w-8 rounded-full object-cover" />
                  {:else}
                    <div class="flex h-8 w-8 items-center justify-center rounded-full bg-gray-200 text-xs font-medium text-gray-600">
                      {(user.displayName || user.fullName || '?')[0]}
                    </div>
                  {/if}
                  <div>
                    <div class="text-sm font-medium">{user.displayName || user.fullName || '-'}</div>
                    <div class="text-xs text-gray-500">{user.phoneNumber || ''}</div>
                  </div>
                </div>
              </td>
              <td class="px-4 py-3 text-sm font-mono text-gray-600">{user.userCode}</td>
              <td class="px-4 py-3"><StatusBadge status={user.role} /></td>
              <td class="px-4 py-3"><StatusBadge status={user.accountStatus} /></td>
              <td class="px-4 py-3 text-sm text-gray-500">{new Date(user.createdAt).toLocaleDateString()}</td>
              <td class="px-4 py-3 text-right">
                <div class="inline-flex gap-1">
                  {#if user.accountStatus === 'active' && user.role !== 'developer'}
                    <button onclick={() => openAction('suspend', user)} class="rounded bg-yellow-100 px-2 py-1 text-xs font-medium text-yellow-800 hover:bg-yellow-200">Suspend</button>
                    <button onclick={() => openAction('ban', user)} class="rounded bg-red-100 px-2 py-1 text-xs font-medium text-red-800 hover:bg-red-200">Ban</button>
                  {:else if user.accountStatus === 'suspended' || user.accountStatus === 'banned'}
                    <button onclick={() => openAction('unsuspend', user)} class="rounded bg-green-100 px-2 py-1 text-xs font-medium text-green-800 hover:bg-green-200">Restore</button>
                  {/if}
                  <a href="/users/{user.id}" class="rounded bg-blue-100 px-2 py-1 text-xs font-medium text-blue-800 hover:bg-blue-200">Detail</a>
                </div>
              </td>
            </tr>
          {:else}
            <tr><td colspan="6" class="px-4 py-8 text-center text-gray-500">No users found</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    <Pagination page={filters.page} {total} limit={filters.limit} onPageChange={changePage} />
  {/if}
</div>

{#if actionModal.show}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
    <div class="w-full max-w-md rounded-lg bg-white p-6 shadow-xl">
      <h3 class="mb-4 text-lg font-bold capitalize">{actionModal.type} Account</h3>
      <p class="mb-4 text-sm text-gray-600">Target: <strong>{actionModal.userName}</strong></p>
      <div class="space-y-4">
        <div>
          <label for="modal-action-reason" class="block text-sm font-medium text-gray-700">Reason</label>
          <textarea id="modal-action-reason" bind:value={actionModal.reason} rows={3} class="mt-1 block w-full rounded border border-gray-300 px-3 py-2 text-sm" placeholder="Provide audit reason..."></textarea>
        </div>
        {#if actionModal.type === 'suspend'}
          <div>
            <label for="modal-action-duration" class="block text-sm font-medium text-gray-700">Duration (days)</label>
            <input id="modal-action-duration" type="number" bind:value={actionModal.durationDays} min={1} class="mt-1 block w-full rounded border border-gray-300 px-3 py-2 text-sm" />
            <p class="mt-1 text-xs text-gray-500">Leave empty for indefinite suspension</p>
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
