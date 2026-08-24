<script lang="ts">
  import { getNotificationOutbox, retryNotification, sendFcmNotification, getFcmUsers } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import ThSort from '$lib/components/datatable/ThSort.svelte';
  import SearchInput from '$lib/components/datatable/SearchInput.svelte';
  import DataTablePagination from '$lib/components/datatable/DataTablePagination.svelte';
  import ExportCsvButton from '$lib/components/datatable/ExportCsvButton.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';
  import Icon from '$lib/components/Icon.svelte';

  let rawRows = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');
  let actionMessage = $state('');

  const table = new TableHandler<any>([], { rowsPerPage: 20 });

  let filters = $state({
    status: '',
    eventType: '',
    limit: 100,
  });

  let selectedNotification = $state<any>(null);

  // ── Send FCM Modal State ──
  let sendModal = $state<{
    show: boolean;
    target: 'all' | 'user' | 'token';
    userId: string;
    deviceToken: string;
    title: string;
    body: string;
    imageUrl: string;
    customData: string;
    sending: boolean;
  }>({
    show: false,
    target: 'all',
    userId: '',
    deviceToken: '',
    title: 'PingPay Announcement',
    body: '',
    imageUrl: '',
    customData: '{\n  "route": "/home"\n}',
    sending: false,
  });

  // ── FCM User Selector State ──
  let fcmUsers = $state<any[]>([]);
  let fcmUserSearch = $state('');
  let loadingFcmUsers = $state(false);
  let selectedFcmUser = $state<any>(null);

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getNotificationOutbox(filters);
      rawRows = res.data.rows;
      total = res.data.total;
      table.setRows(rawRows);
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  async function fetchFcmUsers(search = '') {
    loadingFcmUsers = true;
    try {
      const res = await getFcmUsers(search);
      fcmUsers = res.data.users || [];
    } catch (e: any) {
      console.warn('Could not load FCM users:', e);
    } finally {
      loadingFcmUsers = false;
    }
  }

  onMount(() => {
    load();
  });

  async function handleRetry(id: string) {
    try {
      await retryNotification(id);
      actionMessage = 'Notification queued for retry.';
      load();
    } catch (e: any) {
      error = e.message;
    }
  }

  function openSendModal() {
    sendModal = {
      show: true,
      target: 'all',
      userId: '',
      deviceToken: '',
      title: 'PingPay Announcement',
      body: '',
      imageUrl: '',
      customData: '{\n  "route": "/home"\n}',
      sending: false,
    };
    selectedFcmUser = null;
    fcmUserSearch = '';
    fetchFcmUsers();
  }

  function handleSelectFcmUser(user: any) {
    selectedFcmUser = user;
    sendModal.userId = user.id;
  }

  function handleClearSelectedFcmUser() {
    selectedFcmUser = null;
    sendModal.userId = '';
  }

  async function handleSendFcm() {
    if (sendModal.target === 'user' && !sendModal.userId) {
      error = 'Please select a user with an active FCM device token';
      return;
    }

    if (!sendModal.title.trim() || !sendModal.body.trim()) {
      error = 'Please provide both notification title and message body';
      return;
    }

    let parsedData = {};
    if (sendModal.customData.trim()) {
      try {
        parsedData = JSON.parse(sendModal.customData);
      } catch (err) {
        error = 'Invalid JSON in custom data payload';
        return;
      }
    }

    sendModal.sending = true;
    error = '';
    try {
      const res = await sendFcmNotification({
        target: sendModal.target,
        userId: sendModal.target === 'user' ? sendModal.userId : undefined,
        deviceToken: sendModal.target === 'token' ? sendModal.deviceToken : undefined,
        title: sendModal.title,
        body: sendModal.body,
        imageUrl: sendModal.imageUrl.trim() || undefined,
        dataPayload: parsedData,
      });

      actionMessage = res.message || 'FCM push message successfully dispatched!';
      sendModal.show = false;
      load();
    } catch (e: any) {
      error = e.message;
    } finally {
      sendModal.sending = false;
    }
  }
</script>

<div>
  <div class="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Notification Outbox</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Monitor FCM push notification queue, delivery attempts, error logs, and dispatch push messages.</p>
    </div>
    <div class="flex items-center gap-2">
      <button
        onclick={openSendModal}
        class="inline-flex items-center gap-1.5 rounded-md bg-[#0075de] px-3.5 py-2 text-xs font-semibold text-white shadow-sm hover:bg-[#005bab] transition-colors"
      >
        <Icon name="notifications" class="h-3.5 w-3.5" />
        <span>Send Firebase Push</span>
      </button>
    </div>
  </div>

  {#if actionMessage}
    <div class="mb-4 rounded-md bg-[#e8f8eb] border border-[#e8f8eb] p-3 text-xs text-[#138029] flex items-center justify-between">
      <span>{actionMessage}</span>
      <button onclick={() => actionMessage = ''} class="text-[#138029] font-bold">&times;</button>
    </div>
  {/if}

  {#if error}
    <div class="mb-4 rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030] flex items-center justify-between">
      <span>{error}</span>
      <button onclick={() => error = ''} class="text-[#c53030] font-bold">&times;</button>
    </div>
  {/if}

  <!-- Unified DataTable Card with Integrated Toolbar -->
  <div class="overflow-hidden rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
    <!-- Integrated Header & Filter Toolbar -->
    <div class="flex flex-col gap-3 border-b border-[#e6e6e6] bg-[#fbfbfa] p-4 lg:flex-row lg:items-center lg:justify-between">
      <SearchInput {table} placeholder="Search recipient, event type, status..." class="w-full lg:w-72" />

      <!-- Integrated Filters & Actions -->
      <div class="flex flex-wrap items-center gap-2.5">
        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">Status:</span>
          <select
            bind:value={filters.status}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          >
            <option value="">All Statuses</option>
            <option value="PENDING">PENDING</option>
            <option value="PROCESSING">PROCESSING</option>
            <option value="SENT">SENT</option>
            <option value="FAILED">FAILED</option>
            <option value="SKIPPED">SKIPPED</option>
          </select>
        </div>

        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">Event:</span>
          <select
            bind:value={filters.eventType}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          >
            <option value="">All Events</option>
            <option value="BILL_CREATED">BILL_CREATED</option>
            <option value="BILL_UPDATED">BILL_UPDATED</option>
            <option value="BILL_WRITTEN_OFF">BILL_WRITTEN_OFF</option>
            <option value="PAYMENT_PENDING_CONFIRMATION">PAYMENT_PENDING</option>
            <option value="PAYMENT_CONFIRMED">PAYMENT_CONFIRMED</option>
            <option value="PAYMENT_REJECTED">PAYMENT_REJECTED</option>
            <option value="DEBT_WEEKLY_REMINDER">DEBT_REMINDER</option>
            <option value="ADMIN_BROADCAST">ADMIN_BROADCAST</option>
          </select>
        </div>

        <button
          onclick={load}
          title="Refresh Outbox"
          class="inline-flex h-7 items-center justify-center rounded border border-[#e6e6e6] bg-white px-2.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
        >
          Refresh
        </button>

        <ExportCsvButton {table} filename="notification-outbox-export.csv" />
      </div>
    </div>

    {#if loading}
      <div class="p-8">
        <LoadingLottie text="Loading notification outbox..." size={160} />
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y border-[#e6e6e6] text-left text-xs">
          <thead class="bg-[#fbfbfa] text-[#615d59]">
            <tr>
              <ThSort {table} field="createdAt">Created At</ThSort>
              <ThSort {table} field="eventType">Event Type</ThSort>
              <ThSort {table} field="recipient.displayName">Recipient</ThSort>
              <th class="px-4 py-3 font-semibold">Channel</th>
              <ThSort {table} field="status">Status</ThSort>
              <ThSort {table} field="attempts">Attempts</ThSort>
              <th class="px-4 py-3 font-semibold">Error / Info</th>
              <th class="px-4 py-3 font-semibold text-right">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#f6f5f4]">
            {#each table.rows as row}
              <tr class="hover:bg-[#fbfbfa] transition-colors">
                <td class="px-4 py-3 font-mono text-[11px] text-[#615d59]">{new Date(row.createdAt).toLocaleString()}</td>
                <td class="px-4 py-3 font-mono font-semibold text-[#0075de]">{row.eventType}</td>
                <td class="px-4 py-3 font-medium text-[#000000]">
                  {row.recipient?.displayName || row.recipient?.fullName || row.recipient?.userCode || row.recipientUserId}
                </td>
                <td class="px-4 py-3 font-mono text-[10px] uppercase text-[#615d59]">{row.channel}</td>
                <td class="px-4 py-3"><StatusBadge status={row.status} /></td>
                <td class="px-4 py-3 font-mono text-[11px]">{row.attempts} / {row.maxAttempts}</td>
                <td class="px-4 py-3 max-w-[200px] truncate text-[11px] text-[#c53030]" title={row.lastError || ''}>
                  {row.lastError || '-'}
                </td>
                <td class="px-4 py-3 text-right">
                  <div class="flex items-center justify-end gap-1.5">
                    <button
                      onclick={() => selectedNotification = row}
                      class="rounded-md border border-[#e6e6e6] bg-white px-2 py-1 text-[11px] font-medium text-[#31302e] hover:bg-[#f6f5f4]"
                    >
                      Payload
                    </button>
                    {#if row.status === 'FAILED' || row.status === 'SKIPPED'}
                      <button
                        onclick={() => handleRetry(row.id)}
                        class="rounded-md bg-[#e8f3fc] px-2 py-1 text-[11px] font-semibold text-[#0075de] hover:bg-[#d0e7fa]"
                      >
                        Retry
                      </button>
                    {/if}
                  </div>
                </td>
              </tr>
            {:else}
              <tr>
                <td colspan="8" class="p-8 text-center text-xs text-[#615d59]">No notification records found.</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      <DataTablePagination {table} />
    {/if}
  </div>
</div>

<!-- Send FCM Modal (with Searchable FCM User Picker) -->
{#if sendModal.show}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
    <div class="w-full max-w-lg rounded-xl bg-white p-6 shadow-xl border border-[#e6e6e6] max-h-[90vh] overflow-y-auto">
      <div class="flex items-center gap-2.5 mb-3">
        <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de]">
          <Icon name="notifications" class="h-4 w-4" />
        </div>
        <div>
          <h3 class="text-base font-bold text-[#000000]">Send Firebase Cloud Message (FCM)</h3>
          <p class="text-xs text-[#615d59]">Dispatch live push notifications to registered mobile devices</p>
        </div>
      </div>

      <div class="space-y-3.5 text-xs">
        <div>
          <label for="fcm-target-type" class="block text-[11px] font-semibold text-[#615d59]">Target Audience</label>
          <select
            id="fcm-target-type"
            bind:value={sendModal.target}
            onchange={() => {
              if (sendModal.target === 'user' && fcmUsers.length === 0) {
                fetchFcmUsers();
              }
            }}
            class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          >
            <option value="all">Broadcast to All Registered Devices</option>
            <option value="user">Select Specific User (with Registered FCM)</option>
            <option value="token">Direct Device FCM Token</option>
          </select>
        </div>

        <!-- Searchable User Picker for FCM Users -->
        {#if sendModal.target === 'user'}
          <div class="rounded-lg bg-[#fbfbfa] p-3 border border-[#e6e6e6] space-y-2">
            <div class="flex items-center justify-between">
              <label for="fcm-user-search-input" class="text-[11px] font-semibold text-[#000000]">Select User with FCM Device</label>
              <span class="text-[10px] text-[#615d59] font-mono">{fcmUsers.length} available</span>
            </div>

            {#if selectedFcmUser}
              <!-- Selected User Chip -->
              <div class="flex items-center justify-between rounded-md border border-[#0075de] bg-[#e8f3fc] p-2.5">
                <div class="flex items-center gap-2.5">
                  {#if selectedFcmUser.avatarUrl}
                    <img src={selectedFcmUser.avatarUrl} alt="" class="h-8 w-8 rounded-full object-cover border border-[#0075de]/30" />
                  {:else}
                    <div class="flex h-8 w-8 items-center justify-center rounded-full bg-[#0075de] text-xs font-bold text-white">
                      {(selectedFcmUser.displayName || selectedFcmUser.fullName || 'U')[0]}
                    </div>
                  {/if}
                  <div>
                    <div class="text-xs font-bold text-[#000000]">{selectedFcmUser.displayName || selectedFcmUser.fullName || selectedFcmUser.userCode}</div>
                    <div class="text-[10px] text-[#005bab] font-mono">
                      {selectedFcmUser.userCode} &bull; {selectedFcmUser.tokenCount} device{selectedFcmUser.tokenCount > 1 ? 's' : ''} ({selectedFcmUser.platforms?.join(', ') || 'android'})
                    </div>
                  </div>
                </div>

                <button
                  type="button"
                  onclick={handleClearSelectedFcmUser}
                  class="text-xs font-semibold text-[#c53030] hover:underline px-2 py-1"
                >
                  Change
                </button>
              </div>
            {:else}
              <!-- Search and List -->
              <div>
                <input
                  id="fcm-user-search-input"
                  type="text"
                  bind:value={fcmUserSearch}
                  oninput={(e) => fetchFcmUsers((e.target as HTMLInputElement).value)}
                  placeholder="Search user by name, user code, phone..."
                  class="block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
                />
              </div>

              {#if loadingFcmUsers}
                <div class="py-4 text-center text-xs text-[#615d59]">
                  <span class="inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-[#0075de] border-r-transparent mr-1.5"></span>
                  Searching active FCM users...
                </div>
              {:else if fcmUsers.length === 0}
                <div class="py-4 text-center text-xs text-[#a39e98] bg-white rounded border border-[#f6f5f4]">
                  No users with active device tokens found.
                </div>
              {:else}
                <div class="max-h-44 overflow-y-auto divide-y divide-[#f6f5f4] rounded border border-[#e6e6e6] bg-white">
                  {#each fcmUsers as u}
                    <button
                      type="button"
                      onclick={() => handleSelectFcmUser(u)}
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
                          <div class="text-[10px] text-[#615d59] font-mono">{u.userCode} {u.phoneNumber ? `&bull; ${u.phoneNumber}` : ''}</div>
                        </div>
                      </div>

                      <div class="text-right">
                        <span class="inline-block rounded bg-[#e8f8eb] px-1.5 py-0.5 text-[10px] font-semibold text-[#138029]">
                          {u.tokenCount} device{u.tokenCount > 1 ? 's' : ''}
                        </span>
                      </div>
                    </button>
                  {/each}
                </div>
              {/if}
            {/if}
          </div>
        {/if}

        {#if sendModal.target === 'token'}
          <div>
            <label for="fcm-token" class="block text-[11px] font-semibold text-[#615d59]">Device FCM Token</label>
            <textarea
              id="fcm-token"
              bind:value={sendModal.deviceToken}
              rows={2}
              placeholder="Paste raw device token..."
              class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs font-mono text-[#000000] focus:border-[#0075de] focus:outline-none"
            ></textarea>
          </div>
        {/if}

        <div>
          <label for="fcm-title" class="block text-[11px] font-semibold text-[#615d59]">Notification Title</label>
          <input
            id="fcm-title"
            type="text"
            bind:value={sendModal.title}
            placeholder="e.g. PingPay Announcement"
            class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          />
        </div>

        <div>
          <label for="fcm-body" class="block text-[11px] font-semibold text-[#615d59]">Notification Message</label>
          <textarea
            id="fcm-body"
            bind:value={sendModal.body}
            rows={3}
            placeholder="Write your push notification message..."
            class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          ></textarea>
        </div>

        <div>
          <label for="fcm-image-url" class="block text-[11px] font-semibold text-[#615d59]">Banner Image URL (Optional)</label>
          <input
            id="fcm-image-url"
            type="url"
            bind:value={sendModal.imageUrl}
            placeholder="https://example.com/banner.png"
            class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none font-mono"
          />
          {#if sendModal.imageUrl}
            <div class="mt-2 flex items-center gap-3 rounded-lg border border-[#e6e6e6] bg-[#fbfbfa] p-2">
              <img
                src={sendModal.imageUrl}
                alt="Push Banner Preview"
                class="h-14 w-24 rounded object-cover border border-[#e6e6e6]"
                onerror={(e) => ((e.target as HTMLElement).style.display = 'none')}
              />
              <div class="text-[11px] text-[#615d59]">
                <span class="font-semibold text-[#000000] block">Image Preview</span>
                <span class="text-[10px] text-[#a39e98] truncate max-w-xs block font-mono">{sendModal.imageUrl}</span>
              </div>
            </div>
          {/if}
        </div>

        <div>
          <label for="fcm-custom-data" class="block text-[11px] font-semibold text-[#615d59]">Data Payload (JSON, optional)</label>
          <textarea
            id="fcm-custom-data"
            bind:value={sendModal.customData}
            rows={3}
            class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-[#fbfbfa] px-2.5 py-1.5 text-xs font-mono text-[#000000] focus:border-[#0075de] focus:outline-none"
          ></textarea>
        </div>
      </div>

      <div class="mt-6 flex justify-end gap-2 border-t border-[#e6e6e6] pt-3">
        <button
          onclick={() => sendModal.show = false}
          disabled={sendModal.sending}
          class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4]"
        >
          Cancel
        </button>
        <button
          onclick={handleSendFcm}
          disabled={sendModal.sending || !sendModal.title || !sendModal.body || (sendModal.target === 'user' && !sendModal.userId)}
          class="inline-flex items-center gap-1.5 rounded-md bg-[#0075de] px-4 py-1.5 text-xs font-semibold text-white hover:bg-[#005bab] disabled:opacity-50 transition-colors"
        >
          {#if sendModal.sending}
            <span class="inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-white border-r-transparent"></span>
            <span>Sending Push...</span>
          {:else}
            <Icon name="notifications" class="h-3.5 w-3.5" />
            <span>Send Push Message</span>
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Payload Detail Modal -->
{#if selectedNotification}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
    <div class="w-full max-w-lg rounded-xl bg-white p-6 shadow-xl border border-[#e6e6e6] max-h-[90vh] overflow-y-auto">
      <h3 class="mb-2 text-base font-bold text-[#000000]">Notification Detail</h3>
      <p class="text-xs text-[#615d59] font-mono mb-3">ID: {selectedNotification.id}</p>

      <div class="space-y-3 text-xs">
        <div>
          <span class="text-[10px] uppercase tracking-wider font-semibold text-[#615d59] block">Deduplication Key</span>
          <code class="font-mono text-[#000000] bg-[#f6f5f4] p-1 rounded block mt-0.5">{selectedNotification.deduplicationKey}</code>
        </div>
        <div>
          <span class="text-[10px] uppercase tracking-wider font-semibold text-[#615d59] block">Payload JSON</span>
          <pre class="font-mono text-[11px] bg-[#fbfbfa] p-3 rounded-lg border border-[#e6e6e6] overflow-x-auto max-h-60 mt-1">{JSON.stringify(selectedNotification.payload, null, 2)}</pre>
        </div>
        {#if selectedNotification.lastError}
          <div>
            <span class="text-[10px] uppercase tracking-wider font-semibold text-[#c53030] block">Last Error</span>
            <p class="text-xs text-[#c53030] bg-[#fde8e8] p-2 rounded mt-0.5">{selectedNotification.lastError}</p>
          </div>
        {/if}
      </div>

      <div class="mt-6 flex justify-end border-t border-[#e6e6e6] pt-3">
        <button onclick={() => selectedNotification = null} class="rounded-md bg-[#0075de] px-4 py-1.5 text-xs font-semibold text-white hover:bg-[#005bab]">Close</button>
      </div>
    </div>
  </div>
{/if}
