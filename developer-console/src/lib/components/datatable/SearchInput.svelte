<script lang="ts">
  import type { TableHandler } from './TableHandler.svelte';

  let {
    table,
    placeholder = 'Search table records...',
    class: className = '',
  }: {
    table: TableHandler<any>;
    placeholder?: string;
    class?: string;
  } = $props();

  const search = $derived.by(() => table.createSearch());
</script>

<div class="relative {className}">
  <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-2.5">
    <svg class="h-3.5 w-3.5 text-[#a39e98]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
    </svg>
  </div>
  <input
    type="text"
    bind:value={search.value}
    oninput={() => search.set()}
    {placeholder}
    class="block w-full rounded-[4px] border border-[#e6e6e6] bg-white py-1.5 pl-8 pr-7 text-xs text-[#000000] placeholder-[#a39e98] focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none"
  />
  {#if search.value}
    <button
      type="button"
      aria-label="Clear search"
      onclick={() => { search.value = ''; search.set(); }}
      class="absolute inset-y-0 right-0 flex items-center pr-2 text-[#a39e98] hover:text-[#000000]"
    >
      <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
      </svg>
    </button>
  {/if}
</div>
