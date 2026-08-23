<script lang="ts">
  import { getSecurityEvents } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import ThSort from '$lib/components/datatable/ThSort.svelte';
  import SearchInput from '$lib/components/datatable/SearchInput.svelte';
  import DataTablePagination from '$lib/components/datatable/DataTablePagination.svelte';
  import ExportCsvButton from '$lib/components/datatable/ExportCsvButton.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';
  import { page } from '$app/stores';

  let rawRows = $state<any[]>([]);
  let total = $state(0);
  let loading = $state(true);
  let error = $state('');

  const table = new TableHandler<any>([], { rowsPerPage: 20 });

  let filters = $state({
    userId: $page.url.searchParams.get('userId') || '',
    event: '',
    limit: 100,
  });

  let selectedEvent = $state<any>(null);

  async function load() {
    loading = true;
    error = '';
    try {
      const res = await getSecurityEvents(filters);
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
</script>

<div>
  <div class="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Security Events Monitor</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Track PIN brute-force attempts, suspicious authentication anomalies, and IP access patterns.</p>
    </div>
  </div>

  {#if error}
    <div class="mb-4 rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030] flex items-center justify-between">
      <span>{error}</span>
      <button onclick={() => error = ''} class="text-[#c53030] font-bold">&times;</button>
    </div>
  {/if}

  <!-- Unified DataTable Card with Integrated Controls -->
  <div class="overflow-hidden rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
    <!-- Integrated Header & Filter Toolbar -->
    <div class="flex flex-col gap-3 border-b border-[#e6e6e6] bg-[#fbfbfa] p-4 lg:flex-row lg:items-center lg:justify-between">
      <SearchInput {table} placeholder="Search event type, IP, user name..." class="w-full lg:w-72" />

      <!-- Integrated Filters -->
      <div class="flex flex-wrap items-center gap-2.5">
        <div class="flex items-center gap-1.5">
          <span class="text-[11px] font-medium text-[#615d59]">Event:</span>
          <select
            bind:value={filters.event}
            onchange={load}
            class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          >
            <option value="">All Events</option>
            <option value="pin_brute_force">PIN Brute Force</option>
            <option value="pin_lockout">PIN Lockout</option>
            <option value="suspicious_login">Suspicious Login</option>
            <option value="unauthorized_access">Unauthorized Access</option>
          </select>
        </div>

        <button
          onclick={load}
          class="inline-flex h-7 items-center justify-center rounded border border-[#e6e6e6] bg-white px-2.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
        >
          Refresh
        </button>

        <ExportCsvButton {table} filename="security-events-export.csv" />
      </div>
    </div>

    {#if loading}
      <div class="p-8">
        <LoadingLottie text="Loading security events..." size={160} />
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y border-[#e6e6e6] text-left text-xs">
          <thead class="bg-[#fbfbfa] text-[#615d59]">
            <tr>
              <ThSort {table} field="createdAt">Timestamp</ThSort>
              <ThSort {table} field="event">Event</ThSort>
              <ThSort {table} field="userName">User</ThSort>
              <ThSort {table} field="ipAddress">IP Address</ThSort>
              <th class="px-4 py-3 font-semibold">Metadata Summary</th>
              <th class="px-4 py-3 font-semibold text-right">Action</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#f6f5f4]">
            {#each table.rows as row}
              <tr class="hover:bg-[#fbfbfa] transition-colors">
                <td class="px-4 py-3 font-mono text-[11px] text-[#615d59]">{new Date(row.createdAt).toLocaleString()}</td>
                <td class="px-4 py-3"><StatusBadge status={row.event} /></td>
                <td class="px-4 py-3 font-medium text-[#000000]">
                  {#if row.userId}
                    <a href="/users/{row.userId}" class="text-[#0075de] hover:underline">
                      {row.userName || row.userCode || row.userId}
                    </a>
                  {:else}
                    <span class="text-[#615d59]">Anonymous</span>
                  {/if}
                </td>
                <td class="px-4 py-3 font-mono text-[11px] text-[#31302e]">{row.ipAddress || '-'}</td>
                <td class="px-4 py-3 max-w-[240px] truncate text-[11px] text-[#615d59]" title={JSON.stringify(row.metadata)}>
                  {JSON.stringify(row.metadata) || '-'}
                </td>
                <td class="px-4 py-3 text-right">
                  <button
                    onclick={() => selectedEvent = row}
                    class="rounded-md border border-[#e6e6e6] bg-white px-2.5 py-1 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4]"
                  >
                    View Details
                  </button>
                </td>
              </tr>
            {:else}
              <tr>
                <td colspan="6" class="p-8 text-center text-xs text-[#615d59]">No security events logged.</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      <DataTablePagination {table} />
    {/if}
  </div>
</div>

<!-- Event Detail Modal -->
{#if selectedEvent}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
    <div class="w-full max-w-md rounded-xl bg-white p-6 shadow-xl border border-[#e6e6e6]">
      <h3 class="mb-2 text-base font-bold text-[#000000]">Security Event Details</h3>
      <p class="text-xs text-[#615d59] font-mono mb-3">Event: <StatusBadge status={selectedEvent.event} /></p>

      <div class="space-y-2.5 text-xs">
        <div>
          <span class="text-[10px] uppercase font-semibold text-[#615d59] block">User ID</span>
          <span class="font-mono text-[#000000]">{selectedEvent.userId || 'Anonymous'}</span>
        </div>
        <div>
          <span class="text-[10px] uppercase font-semibold text-[#615d59] block">IP Address</span>
          <span class="font-mono text-[#000000]">{selectedEvent.ipAddress || '-'}</span>
        </div>
        <div>
          <span class="text-[10px] uppercase font-semibold text-[#615d59] block">Timestamp</span>
          <span class="text-[#000000]">{new Date(selectedEvent.createdAt).toLocaleString()}</span>
        </div>
        <div>
          <span class="text-[10px] uppercase font-semibold text-[#615d59] block">Event Metadata</span>
          <pre class="font-mono text-[11px] bg-[#fbfbfa] p-3 rounded-lg border border-[#e6e6e6] overflow-x-auto max-h-48 mt-1">{JSON.stringify(selectedEvent.metadata, null, 2)}</pre>
        </div>
      </div>

      <div class="mt-6 flex justify-end border-t border-[#e6e6e6] pt-3">
        <button onclick={() => selectedEvent = null} class="rounded-md bg-[#0075de] px-4 py-1.5 text-xs font-semibold text-white hover:bg-[#005bab]">Close</button>
      </div>
    </div>
  </div>
{/if}
