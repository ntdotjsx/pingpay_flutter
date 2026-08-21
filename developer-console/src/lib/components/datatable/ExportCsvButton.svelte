<script lang="ts">
  import type { TableHandler } from './TableHandler.svelte';

  let {
    table,
    filename = 'export.csv',
    class: className = '',
  }: {
    table: TableHandler<any>;
    filename?: string;
    class?: string;
  } = $props();

  function handleExport() {
    const csv = table.createCSV();
    csv.download(filename);
  }
</script>

<button
  type="button"
  onclick={handleExport}
  class="inline-flex items-center gap-1.5 rounded-md border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs font-medium text-[#31302e] shadow-sm hover:bg-[#f6f5f4] transition-colors {className}"
>
  <svg class="h-3.5 w-3.5 text-[#615d59]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
  </svg>
  <span>Export CSV</span>
</button>
