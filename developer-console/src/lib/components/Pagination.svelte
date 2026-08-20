<script lang="ts">
  let { page = 1, total = 0, limit = 20, onPageChange }: {
    page: number; total: number; limit: number; onPageChange: (p: number) => void
  } = $props();

  const totalPages = $derived(Math.ceil(total / limit));
  const canPrev = $derived(page > 1);
  const canNext = $derived(page < totalPages);
</script>

{#if totalPages > 1}
<div class="mt-4 flex items-center justify-between px-4 py-3">
  <div class="text-sm text-gray-700">
    Showing <span class="font-medium">{(page - 1) * limit + 1}</span> to
    <span class="font-medium">{Math.min(page * limit, total)}</span> of
    <span class="font-medium">{total}</span>
  </div>
  <div class="flex gap-2">
    <button
      class="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
      disabled={!canPrev}
      onclick={() => onPageChange(page - 1)}
    >
      Previous
    </button>
    <span class="flex items-center px-2 text-sm text-gray-500">
      {page} / {totalPages}
    </span>
    <button
      class="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
      disabled={!canNext}
      onclick={() => onPageChange(page + 1)}
    >
      Next
    </button>
  </div>
</div>
{/if}
