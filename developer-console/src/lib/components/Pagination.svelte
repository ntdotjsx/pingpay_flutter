<script lang="ts">
  let { page = 1, total = 0, limit = 20, onPageChange }: {
    page: number; total: number; limit: number; onPageChange: (p: number) => void
  } = $props();

  const totalPages = $derived(Math.ceil(total / limit));
  const canPrev = $derived(page > 1);
  const canNext = $derived(page < totalPages);
</script>

{#if totalPages > 1}
<div class="mt-4 flex items-center justify-between px-2 py-3">
  <div class="text-xs text-[#615d59]">
    Showing <span class="font-medium text-[#000000]">{(page - 1) * limit + 1}</span> to
    <span class="font-medium text-[#000000]">{Math.min(page * limit, total)}</span> of
    <span class="font-medium text-[#000000]">{total}</span>
  </div>
  <div class="flex items-center gap-2">
    <button
      class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
      disabled={!canPrev}
      onclick={() => onPageChange(page - 1)}
    >
      Previous
    </button>
    <span class="px-2 text-xs font-mono text-[#615d59]">
      {page} / {totalPages}
    </span>
    <button
      class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
      disabled={!canNext}
      onclick={() => onPageChange(page + 1)}
    >
      Next
    </button>
  </div>
</div>
{/if}
