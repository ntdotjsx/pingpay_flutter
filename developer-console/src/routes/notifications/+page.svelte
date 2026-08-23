<script lang="ts">
  import { getNotificationOutbox, retryNotification } from '$lib/api/client';
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

  onMount(load);

  async function handleRetry(id: string) {
    try {
      await retryNotification(id);
      actionMessage = 'Notification queued for retry.';
      load();
    } catch (e: any) {
      error = e.message;
    }
  }
</script>

<div>
  <div class="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Notification Outbox</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Monitor FCM push notification queue, delivery attempts, error logs, and retry failed messages.</p>
    </div>
    <div class="flex items-center gap-2">
      <ExportCsvButton {table} filename="notification-outbox-export.csv" />
    </div>
  </div>

  {#if actionMessage}
    <div class="mb-4 rounded-md bg-[#e8f8eb] border border-[#e8f8eb] p-3 text-xs text-[#138029] flex items-center justify-between">
      <span>{actionMessage}</span>
      <button onclick={() => actionMessage = ''} class="text-[#138029] font-bold">&times;</button>
    </div>
  {/if}

  <!-- Filters Bar -->
  <div class="mb-6 rounded-xl border border-[#e6e6e6] bg-white p-4 shadow-sm">
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
      <div>
        <label for="filter-status" class="block text-[11px] font-medium text-[#615d59]">Status</label>
        <select id="filter-status" bind:value={filters.status} onchange={load} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none">
          <option value="">All Statuses</option>
          <option value="PENDING">PENDING</option>
          <option value="PROCESSING">PROCESSING</option>
          <option value="SENT">SENT</option>
          <option value="FAILED">FAILED</option>
          <option value="SKIPPED">SKIPPED</option>
        </select>
      </div>
      <div>
        <label for="filter-event-type" class="block text-[11px] font-medium text-[#615d59]">Event Type</label>
        <select id="filter-event-type" bind:value={filters.eventType} onchange={load} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none">
          <option value="">All Events</option>
          <option value="BILL_CREATED">BILL_CREATED</option>
          <option value="BILL_UPDATED">BILL_UPDATED</option>
          <option value="BILL_WRITTEN_OFF">BILL_WRITTEN_OFF</option>
          <option value="PAYMENT_PENDING_CONFIRMATION">PAYMENT_PENDING_CONFIRMATION</option>
          <option value="PAYMENT_CONFIRMED">PAYMENT_CONFIRMED</option>
          <option value="PAYMENT_REJECTED">PAYMENT_REJECTED</option>
          <option value="DEBT_WEEKLY_REMINDER">DEBT_WEEKLY_REMINDER</option>
        </select>
      </div>
      <div class="flex items-end">
        <button onclick={load} class="w-full rounded-md bg-[#0075de] px-4 py-2 text-xs font-semibold text-white hover:bg-[#005bab] transition-colors">
          Refresh Outbox
        </button>
      </div>
    </div>
  </div>

  <!-- Search & Table -->
  <div class="mb-4 flex items-center justify-between">
    <SearchInput {table} placeholder="Search by recipient name, event type, status..." />
    <span class="text-xs text-[#615d59] font-mono">Total: {total} notifications</span>
  </div>

  {#if loading}
    <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
      <LoadingLottie text="Loading notification outbox..." size={160} />
    </div>
  {:else if error}
    <div class="rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030]">{error}</div>
  {:else}
    <div class="overflow-hidden rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
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
    </div>
  {/if}
</div>

<!-- Payload Detail Modal -->
{#if selectedNotification}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
    <div class="w-full max-w-lg rounded-xl bg-white p-6 shadow-xl border border-[#e6e6e6]">
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
