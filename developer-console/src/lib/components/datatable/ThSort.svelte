<script lang="ts">
  import type { TableHandler } from './TableHandler.svelte';
  import type { Snippet } from 'svelte';

  let {
    table,
    field,
    children,
    class: className = '',
  }: {
    table: TableHandler<any>;
    field: string | ((row: any) => any);
    children?: Snippet;
    class?: string;
  } = $props();

  const sort = $derived.by(() => table.createSort(field as any));
</script>

<th
  onclick={() => sort.set()}
  class="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[#615d59] hover:text-[#000000] hover:bg-[#eae8e5] cursor-pointer select-none transition-colors {className}"
>
  <div class="flex items-center gap-1.5">
    <span>
      {#if children}
        {@render children()}
      {/if}
    </span>
    <span class="inline-flex flex-col text-[8px] leading-[8px] {sort.isActive ? 'text-[#0075de]' : 'text-[#a39e98]'}">
      {#if sort.direction === 'asc'}
        <span class="font-bold text-[#0075de]">▲</span>
      {:else if sort.direction === 'desc'}
        <span class="font-bold text-[#0075de]">▼</span>
      {:else}
        <span class="opacity-50">▲</span>
        <span class="opacity-50">▼</span>
      {/if}
    </span>
  </div>
</th>
