<script lang="ts">
  import { getUsers, suspendUser, banUser, unsuspendUser } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import ThSort from '$lib/components/datatable/ThSort.svelte';
  import SearchInput from '$lib/components/datatable/SearchInput.svelte';
  import DataTablePagination from '$lib/components/datatable/DataTablePagination.svelte';
  import ExportCsvButton from '$lib/components/datatable/ExportCsvButton.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let rawUsers = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');

  const table = new TableHandler<any>([], { rowsPerPage: 20 });

  let filters = $state({
    search: '',
    accountStatus: '',
    role: '',
    limit: 100,
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
      rawUsers = res.data.rows;
      total = res.data.total;
      table.setRows(rawUsers);
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  onMount(load);

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
  <div class="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">User Management</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Inspect user credentials, verify roles, and manage account suspensions with interactive DataTables.</p>
    </div>
  </div>

  {#if actionMessage}
    <div class="mb-4 rounded-md bg-[#e8f8eb] border border-[#e8f8eb] p-3 text-xs text-[#138029] flex justify-between items-center">
      <span>{actionMessage}</span>
      <button onclick={() => actionMessage = ''} class="text-[#138029] font-bold">&times;</button>
    </div>
  {/if}

  {#if error}
    <div class="mb-4 rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030] flex justify-between items-center">
      <span>{error}</span>
      <button onclick={() => error = ''} class="text-[#c53030] font-bold">&times;</button>
    </div>
  {/if}

  <!-- Unified DataTable Card with Integrated Controls -->
  <div class="overflow-hidden rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
    <!-- Integrated Header & Filter Toolbar -->
    <div class="flex flex-col gap-3 border-b border-[#e6e6e6] bg-[#fbfbfa] p-4 lg:flex-row lg:items-center lg:justify-between">
      <SearchInput {table} placeholder="Search by name, user code, phone..." class="w-full lg:w-72" />

      <!-- Integrated Filters -->
      <div class="flex flex-wrap items-center gap-2.5">
        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">Status:</span>
          <select
            bind:value={filters.accountStatus}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          >
            <option value="">All Statuses</option>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
            <option value="banned">Banned</option>
          </select>
        </div>

        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">Role:</span>
          <select
            bind:value={filters.role}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          >
            <option value="">All Roles</option>
            <option value="user">User</option>
            <option value="developer">Developer</option>
          </select>
        </div>

        <button
          onclick={load}
          class="inline-flex h-7 items-center justify-center rounded border border-[#e6e6e6] bg-white px-2.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
        >
          Refresh
        </button>

        <ExportCsvButton {table} filename="users-export.csv" />
      </div>
    </div>

    {#if loading}
      <div class="p-8">
        <LoadingLottie text="Loading users..." size={150} />
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-[#e6e6e6]">
          <thead class="bg-[#f6f5f4]">
            <tr>
              <ThSort {table} field={(row) => row.displayName || row.fullName || ''}>User</ThSort>
              <ThSort {table} field="userCode">Code</ThSort>
              <ThSort {table} field="role">Role</ThSort>
              <ThSort {table} field="accountStatus">Status</ThSort>
              <ThSort {table} field="createdAt">Joined</ThSort>
              <th class="px-4 py-2.5 text-right text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e6e6e6] bg-white">
            {#each table.rows as user}
              <tr class="hover:bg-[#faf9f8] transition-colors">
                <td class="px-4 py-3">
                  <div class="flex items-center gap-2.5">
                    {#if user.avatarUrl}
                      <img src={user.avatarUrl} alt="" class="h-7 w-7 rounded-full object-cover border border-[#e6e6e6]" />
                    {:else}
                      <div class="flex h-7 w-7 items-center justify-center rounded-full bg-[#f0efed] text-xs font-semibold text-[#615d59]">
                        {(user.displayName || user.fullName || '?')[0]}
                      </div>
                    {/if}
                    <div>
                      <div class="text-xs font-semibold text-[#000000]">{user.displayName || user.fullName || '-'}</div>
                      <div class="text-[11px] text-[#615d59]">{user.phoneNumber || ''}</div>
                    </div>
                  </div>
                </td>
                <td class="px-4 py-3 text-xs font-mono text-[#615d59]">{user.userCode}</td>
                <td class="px-4 py-3"><StatusBadge status={user.role} /></td>
                <td class="px-4 py-3"><StatusBadge status={user.accountStatus} /></td>
                <td class="px-4 py-3 text-xs text-[#615d59]">{new Date(user.createdAt).toLocaleDateString()}</td>
                <td class="px-4 py-3 text-right">
                  <div class="inline-flex gap-1.5">
                    {#if user.accountStatus === 'active' && user.role !== 'developer'}
                      <button onclick={() => openAction('suspend', user)} class="rounded-md border border-[#e6e6e6] bg-white px-2 py-1 text-[11px] font-medium text-[#dd5b00] hover:bg-[#fef2e8] transition-colors">Suspend</button>
                      <button onclick={() => openAction('ban', user)} class="rounded-md border border-[#e6e6e6] bg-white px-2 py-1 text-[11px] font-medium text-[#c53030] hover:bg-[#fde8e8] transition-colors">Ban</button>
                    {:else if user.accountStatus === 'suspended' || user.accountStatus === 'banned'}
                      <button onclick={() => openAction('unsuspend', user)} class="rounded-md border border-[#e6e6e6] bg-white px-2 py-1 text-[11px] font-medium text-[#138029] hover:bg-[#e8f8eb] transition-colors">Restore</button>
                    {/if}
                    <a href="/users/{user.id}" class="rounded-md border border-[#e6e6e6] bg-white px-2.5 py-1 text-[11px] font-medium text-[#0075de] hover:bg-[#e8f3fc] transition-colors">Detail</a>
                  </div>
                </td>
              </tr>
            {:else}
              <tr><td colspan="6" class="px-4 py-8 text-center text-xs text-[#615d59]">No matching users found</td></tr>
            {/each}
          </tbody>
        </table>
      </div>
      <DataTablePagination {table} />
    {/if}
  </div>
</div>

{#if actionModal.show}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
    <div class="w-full max-w-md rounded-xl bg-white p-6 shadow-xl border border-[#e6e6e6]">
      <h3 class="mb-3 text-base font-bold text-[#000000] capitalize">{actionModal.type} Account</h3>
      <p class="mb-4 text-xs text-[#615d59]">Target: <strong class="text-[#000000]">{actionModal.userName}</strong></p>
      <div class="space-y-3">
        <div>
          <label for="modal-reason-input" class="block text-[11px] font-medium text-[#615d59]">Reason for audit log</label>
          <textarea id="modal-reason-input" bind:value={actionModal.reason} rows={3} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" placeholder="Provide reason..."></textarea>
        </div>
        {#if actionModal.type === 'suspend'}
          <div>
            <label for="modal-duration-input" class="block text-[11px] font-medium text-[#615d59]">Duration in Days (optional)</label>
            <input id="modal-duration-input" type="number" bind:value={actionModal.durationDays} min={1} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none" placeholder="e.g. 7" />
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
