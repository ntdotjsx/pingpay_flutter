<script lang="ts">
  import type { TableHandler } from './TableHandler.svelte';

  let {
    table,
    class: className = '',
  }: {
    table: TableHandler<any>;
    class?: string;
  } = $props();

  const options = [10, 20, 50, 100];
</script>

<div class="flex flex-col gap-3 py-3 sm:flex-row sm:items-center sm:justify-between px-4 {className}">
  <!-- Row count info & rows per page selector -->
  <div class="flex flex-wrap items-center justify-between sm:justify-start gap-3 text-xs text-[#615d59] w-full sm:w-auto">
    <span class="text-[11px] sm:text-xs">
      Showing <strong class="font-medium text-[#000000]">{table.rowCount.start}</strong> to
      <strong class="font-medium text-[#000000]">{table.rowCount.end}</strong> of
      <strong class="font-medium text-[#000000]">{table.rowCount.total}</strong>
    </span>

    <div class="flex items-center gap-1.5 border-l border-[#e6e6e6] pl-3">
      <label for="dt-rows-per-page" class="text-[11px] text-[#615d59]">Show</label>
      <select
        id="dt-rows-per-page"
        value={table.rowsPerPage}
        onchange={(e) => table.setRowsPerPage(Number((e.target as HTMLSelectElement).value))}
        class="rounded border border-[#e6e6e6] bg-white px-2 py-0.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
      >
        {#each options as opt}
          <option value={opt}>{opt}</option>
        {/each}
      </select>
      <span class="text-[11px] text-[#615d59]">rows</span>
    </div>
  </div>

  <!-- Pagination Buttons -->
  {#if table.pageCount > 1}
    <div class="flex items-center justify-center sm:justify-end gap-1 flex-wrap w-full sm:w-auto">
      <button
        type="button"
        onclick={() => table.setPage('previous')}
        disabled={table.currentPage === 1}
        class="inline-flex h-7 items-center justify-center rounded border border-[#e6e6e6] bg-white px-2 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] disabled:opacity-40 disabled:hover:bg-white transition-colors"
      >
        Prev
      </button>

      {#each table.pagesWithEllipsis as p}
        {#if p === null}
          <span class="px-1 text-xs text-[#a39e98]">...</span>
        {:else}
          <button
            type="button"
            onclick={() => table.setPage(p)}
            class="inline-flex h-7 min-w-7 items-center justify-center rounded px-2 text-xs font-medium transition-colors {table.currentPage === p
              ? 'bg-[#0075de] text-white font-semibold'
              : 'border border-[#e6e6e6] bg-white text-[#31302e] hover:bg-[#f6f5f4]'}"
          >
            {p}
          </button>
        {/if}
      {/each}

      <button
        type="button"
        onclick={() => table.setPage('next')}
        disabled={table.currentPage === table.pageCount}
        class="inline-flex h-7 items-center justify-center rounded border border-[#e6e6e6] bg-white px-2 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] disabled:opacity-40 disabled:hover:bg-white transition-colors"
      >
        Next
      </button>
    </div>
  {/if}
</div>
