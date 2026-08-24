<script lang="ts">
  import { getSuspiciousLogs, flagSuspicious, clearAllSuspiciousLogs, deleteSuspiciousLog, getUsers } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler, ThSort, SearchInput, DataTablePagination, ExportCsvButton } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let rawLogs = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');
  let showForm = $state(false);
  let selectedLog = $state<any>(null);

  // ── User Search in Flag Modal ──
  let userSearchQuery = $state('');
  let userSearchResults = $state<any[]>([]);
  let loadingUsers = $state(false);
  let selectedUser = $state<any>(null);

  const table = new TableHandler<any>([], { rowsPerPage: 20 });

  let filters = $state({
    userId: '',
    type: '',
    dateFrom: '',
    dateTo: '',
    limit: 100,
  });

  let newFlag = $state({
    userId: '',
    type: 'duplicate_slip',
    description: '',
  });

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getSuspiciousLogs(filters);
      rawLogs = res.data.rows;
      total = res.data.total;
      table.setRows(rawLogs);
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  async function searchUsers(query = '') {
    loadingUsers = true;
    try {
      const res = await getUsers({ search: query, limit: 10 });
      userSearchResults = res.data.rows || [];
    } catch (err) {
      console.warn('Failed to search users:', err);
    } finally {
      loadingUsers = false;
    }
  }

  function handleOpenFlagModal() {
    showForm = true;
    newFlag = { userId: '', type: 'duplicate_slip', description: '' };
    selectedUser = null;
    userSearchQuery = '';
    searchUsers('');
  }

  function handleSelectUser(u: any) {
    selectedUser = u;
    newFlag.userId = u.id;
  }

  function handleClearSelectedUser() {
    selectedUser = null;
    newFlag.userId = '';
  }

  onMount(load);

  async function submitFlag() {
    if (!newFlag.description.trim()) {
      alert('Please enter a description or observation evidence');
      return;
    }
    try {
      await flagSuspicious({
        userId: newFlag.userId || undefined,
        type: newFlag.type,
        description: newFlag.description.trim(),
      });
      actionMessage = 'Suspicious threat activity successfully logged.';
      showForm = false;
      newFlag = { userId: '', type: 'duplicate_slip', description: '' };
      selectedUser = null;
      load();
    } catch (e: any) {
      error = e.message;
    }
  }

  async function handleClearAll() {
    if (!confirm('WARNING: Are you sure you want to delete ALL suspicious activity logs?\n\nThis will permanently delete all recorded threat and fraud logs.')) return;
    try {
      await clearAllSuspiciousLogs();
      actionMessage = 'All suspicious activity logs have been cleared.';
      load();
    } catch (e: any) {
      error = `Clear failed: ${e.message}`;
    }
  }

  async function handleDeleteSingle(id: string) {
    if (!confirm('Delete this suspicious log entry?')) return;
    try {
      await deleteSuspiciousLog(id);
      actionMessage = 'Suspicious log entry deleted.';
      if (selectedLog?.id === id) selectedLog = null;
      load();
    } catch (e: any) {
      error = `Delete failed: ${e.message}`;
    }
  }
</script>

<div>
  <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Suspicious Activity Logs</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Security audit trail retained permanently for dispute investigations, duplicate slips, and fraud analysis.</p>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <button onclick={handleOpenFlagModal} class="rounded-md bg-[#0075de] px-3.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-[#005bab] transition-colors flex items-center gap-1.5">
        <span>+</span>
        <span>Manually Flag Activity</span>
      </button>
      <button onclick={handleClearAll} class="rounded-md bg-[#c53030] px-3.5 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-[#a82525] transition-colors">
        Clear All Threat Logs
      </button>
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
      <SearchInput {table} placeholder="Search threat logs by type, user, description..." class="w-full lg:w-72" />

      <!-- Integrated Filters -->
      <div class="flex flex-wrap items-center gap-2.5">
        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">Threat Type:</span>
          <select
            bind:value={filters.type}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          >
            <option value="">All Types</option>
            <option value="duplicate_slip">Duplicate Slip</option>
            <option value="multi_account_ip">Multi-Account IP</option>
            <option value="frequent_writeoff">Frequent Write-offs</option>
            <option value="frequent_bill_edit">Frequent Bill Edits</option>
            <option value="fake_slip_manipulation">Slip Manipulation</option>
            <option value="other">Other</option>
          </select>
        </div>

        <button
          onclick={load}
          class="inline-flex h-7 items-center justify-center rounded border border-[#e6e6e6] bg-white px-2.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
        >
          Refresh
        </button>

        <ExportCsvButton {table} filename="suspicious-logs.csv" />
      </div>
    </div>

    {#if loading}
      <div class="p-8">
        <LoadingLottie text="Loading suspicious activity logs..." size={150} />
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-[#e6e6e6]">
          <thead class="bg-[#f6f5f4]">
            <tr>
              <ThSort {table} field="type">Threat Type</ThSort>
              <ThSort {table} field={(row) => row.userName || row.userCode || row.userId || ''}>User</ThSort>
              <ThSort {table} field="description">Description</ThSort>
              <ThSort {table} field="createdAt">Recorded Date</ThSort>
              <th class="px-4 py-2.5 text-right text-[11px] font-semibold uppercase tracking-wider text-[#615d59]">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e6e6e6] bg-white">
            {#each table.rows as row}
              <tr class="hover:bg-[#faf9f8] transition-colors">
                <td class="px-4 py-3"><StatusBadge status={row.type} /></td>
                <td class="px-4 py-3 text-xs">
                  {#if row.userId}
                    <a href="/users/{row.userId}" class="font-bold text-[#0075de] hover:underline">
                      {row.userName || row.userCode || row.userId.slice(0, 8) + '...'}
                    </a>
                  {:else}
                    <span class="text-[#a39e98]">Unknown / Unregistered</span>
                  {/if}
                </td>
                <td class="px-4 py-3 text-xs text-[#31302e] max-w-sm">{row.description}</td>
                <td class="px-4 py-3 text-xs text-[#615d59] font-mono">{new Date(row.createdAt).toLocaleString()}</td>
                <td class="px-4 py-3 text-right space-x-1 whitespace-nowrap">
                  <button
                    onclick={() => selectedLog = row}
                    class="rounded border border-[#e6e6e6] bg-white px-2.5 py-1 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
                  >
                    Inspect
                  </button>
                  <button
                    onclick={() => handleDeleteSingle(row.id)}
                    class="rounded bg-[#fde8e8] px-2 py-1 text-xs font-medium text-[#c53030] hover:bg-[#fbd5d5] transition-colors"
                    title="Delete this log"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            {:else}
              <tr><td colspan="5" class="px-4 py-8 text-center text-xs text-[#615d59]">No matching suspicious threat logs found</td></tr>
            {/each}
          </tbody>
        </table>
      </div>
      <DataTablePagination {table} />
    {/if}
  </div>
</div>

<!-- Manually Flag Modal with Live User Search -->
{#if showForm}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-xs p-4">
    <div class="w-full max-w-lg rounded-2xl bg-white p-6 shadow-2xl border border-[#e6e6e6]">
      <div class="flex items-center justify-between border-b border-[#e6e6e6] pb-3 mb-4">
        <div>
          <h3 class="text-base font-bold text-[#c53030]">Manually Flag Suspicious Activity</h3>
          <p class="text-xs text-[#615d59]">Select target user and specify threat classification</p>
        </div>
        <button onclick={() => showForm = false} class="text-[#615d59] hover:text-[#000000] text-lg font-bold">&times;</button>
      </div>

      <div class="space-y-4">
        <!-- Target User Picker Section -->
        <div>
          <label for="flag-user-search-input" class="block text-[11px] font-bold text-[#615d59] uppercase mb-1">
            Target User (Search & Select)
          </label>

          {#if selectedUser}
            <!-- Selected User Banner -->
            <div class="flex items-center justify-between rounded-lg border border-[#0075de] bg-[#e8f3fc] p-3">
              <div class="flex items-center gap-3">
                {#if selectedUser.avatarUrl}
                  <img src={selectedUser.avatarUrl} alt="" class="h-9 w-9 rounded-full object-cover border border-[#0075de]/30" />
                {:else}
                  <div class="flex h-9 w-9 items-center justify-center rounded-full bg-[#0075de] text-xs font-bold text-white">
                    {(selectedUser.displayName || selectedUser.fullName || 'U')[0]}
                  </div>
                {/if}
                <div>
                  <div class="text-xs font-bold text-[#000000]">{selectedUser.displayName || selectedUser.fullName || selectedUser.userCode}</div>
                  <div class="text-[10px] text-[#005bab] font-mono">
                    {selectedUser.userCode} {selectedUser.phoneNumber ? `&bull; ${selectedUser.phoneNumber}` : ''}
                  </div>
                </div>
              </div>
              <button
                type="button"
                onclick={handleClearSelectedUser}
                class="text-xs font-semibold text-[#c53030] hover:underline px-2 py-1"
              >
                Change User
              </button>
            </div>
          {:else}
            <!-- Search Input and Results Dropdown -->
            <div class="space-y-2">
              <input
                id="flag-user-search-input"
                type="text"
                bind:value={userSearchQuery}
                oninput={(e) => searchUsers((e.target as HTMLInputElement).value)}
                placeholder="Search user by name, user code, phone..."
                class="block w-full rounded-[6px] border border-[#e6e6e6] bg-white px-3 py-2 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
              />

              {#if loadingUsers}
                <div class="py-3 text-center text-xs text-[#615d59]">
                  <span class="inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-[#0075de] border-r-transparent mr-1.5"></span>
                  Searching users...
                </div>
              {:else if userSearchResults.length === 0}
                <div class="py-3 text-center text-xs text-[#a39e98] bg-[#fbfbfa] rounded-lg border border-[#f0efed]">
                  No matching users found. (You can leave blank for unregistered threats)
                </div>
              {:else}
                <div class="max-h-40 overflow-y-auto divide-y divide-[#f6f5f4] rounded-lg border border-[#e6e6e6] bg-white shadow-2xs">
                  {#each userSearchResults as u}
                    <button
                      type="button"
                      onclick={() => handleSelectUser(u)}
                      class="flex w-full items-center justify-between p-2 text-left hover:bg-[#e8f3fc] transition-colors group"
                    >
                      <div class="flex items-center gap-2">
                        {#if u.avatarUrl}
                          <img src={u.avatarUrl} alt="" class="h-6 w-6 rounded-full object-cover border border-[#e6e6e6]" />
                        {:else}
                          <div class="flex h-6 w-6 items-center justify-center rounded-full bg-[#f0efed] text-[10px] font-bold text-[#615d59]">
                            {(u.displayName || u.fullName || 'U')[0]}
                          </div>
                        {/if}
                        <div>
                          <div class="text-xs font-medium text-[#000000] group-hover:text-[#0075de]">{u.displayName || u.fullName || u.userCode}</div>
                          <div class="text-[10px] text-[#615d59] font-mono">{u.userCode}</div>
                        </div>
                      </div>
                      <span class="text-[11px] font-semibold text-[#0075de] opacity-0 group-hover:opacity-100 transition-opacity">Select &rarr;</span>
                    </button>
                  {/each}
                </div>
              {/if}
            </div>
          {/if}
        </div>

        <!-- Threat Type Selector -->
        <div>
          <label for="flag-threat-type" class="block text-[11px] font-bold text-[#615d59] uppercase mb-1">Threat Type</label>
          <select id="flag-threat-type" bind:value={newFlag.type} class="block w-full rounded-[6px] border border-[#e6e6e6] bg-white px-3 py-2 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none">
            <option value="duplicate_slip">Duplicate Slip Submission</option>
            <option value="multi_account_ip">Multi-Account Access from Same IP</option>
            <option value="frequent_writeoff">Frequent / Unusual Debt Write-offs</option>
            <option value="frequent_bill_edit">Frequent Bill Edits after Debt Creation</option>
            <option value="fake_slip_manipulation">Slip Image Manipulation / Amount Mismatch</option>
            <option value="other">Other Suspicious Activity</option>
          </select>
        </div>

        <!-- Description / Evidence Details -->
        <div>
          <label for="flag-description" class="block text-[11px] font-bold text-[#615d59] uppercase mb-1">Description & Evidence Observations</label>
          <textarea
            id="flag-description"
            bind:value={newFlag.description}
            rows={3}
            class="block w-full rounded-[6px] border border-[#e6e6e6] bg-white px-3 py-2 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
            placeholder="Explain why this activity is flagged and describe evidence..."
          ></textarea>
        </div>
      </div>

      <div class="mt-6 flex justify-end gap-2 border-t border-[#e6e6e6] pt-4">
        <button onclick={() => showForm = false} class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors">
          Cancel
        </button>
        <button
          onclick={submitFlag}
          disabled={!newFlag.description.trim()}
          class="rounded-md bg-[#c53030] px-4 py-1.5 text-xs font-semibold text-white hover:bg-[#a82525] disabled:opacity-50 shadow-sm transition-colors"
        >
          Submit Security Flag
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Inspect Modal -->
{#if selectedLog}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-xs p-4">
    <div class="w-full max-w-lg rounded-2xl bg-white p-6 shadow-2xl border border-[#e6e6e6]">
      <div class="flex items-center justify-between border-b border-[#e6e6e6] pb-3">
        <div class="flex items-center gap-2">
          <h3 class="text-base font-bold text-[#c53030]">Suspicious Activity Record</h3>
          <StatusBadge status={selectedLog.type} />
        </div>
        <button onclick={() => selectedLog = null} class="text-[#615d59] hover:text-[#000000] text-lg font-bold">&times;</button>
      </div>
      <div class="mt-4 space-y-3 text-xs">
        <div class="flex justify-between items-center border-b border-[#f6f5f4] pb-2">
          <span class="text-[#615d59]">Type:</span>
          <StatusBadge status={selectedLog.type} />
        </div>
        <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
          <span class="text-[#615d59]">Target User:</span>
          <span class="text-[#000000] font-medium">{selectedLog.userName || selectedLog.userCode || selectedLog.userId || 'N/A'}</span>
        </div>
        <div>
          <span class="text-[#615d59] font-bold block mb-1">Description & Evidence:</span>
          <p class="rounded-lg bg-[#fbfbfa] p-3 text-xs text-[#31302e] border border-[#e6e6e6] font-medium leading-relaxed">{selectedLog.description}</p>
        </div>
        <div class="flex justify-between border-b border-[#f6f5f4] pb-2">
          <span class="text-[#615d59]">Recorded At:</span>
          <span class="text-[#000000] font-mono">{new Date(selectedLog.createdAt).toLocaleString()}</span>
        </div>
        <div>
          <span class="text-[#615d59] font-bold block mb-1">Metadata Snapshot:</span>
          <pre class="max-h-56 overflow-y-auto rounded-lg bg-[#fbfbfa] p-3 font-mono text-xs text-[#31302e] border border-[#e6e6e6]">{JSON.stringify(selectedLog.metadata, null, 2)}</pre>
        </div>
      </div>
      <div class="mt-6 flex justify-between items-center border-t border-[#e6e6e6] pt-4">
        <div>
          {#if selectedLog.userId}
            <a href="/users/{selectedLog.userId}" class="rounded-md bg-[#fef2e8] px-3.5 py-1.5 text-xs font-semibold text-[#b34900] hover:bg-[#faeee3] transition-colors">
              View / Suspend User &rarr;
            </a>
          {/if}
        </div>
        <div class="flex gap-2">
          <button
            onclick={() => { const id = selectedLog.id; selectedLog = null; handleDeleteSingle(id); }}
            class="rounded-md bg-[#c53030] px-3.5 py-1.5 text-xs font-medium text-white hover:bg-[#a82525] transition-colors"
          >
            Delete Log
          </button>
          <button onclick={() => selectedLog = null} class="rounded-md border border-[#e6e6e6] bg-white px-3.5 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors">
            Close
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
