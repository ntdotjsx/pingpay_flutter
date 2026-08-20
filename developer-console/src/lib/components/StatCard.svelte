<script lang="ts">
  let { label, value, color = 'blue' }: { label: string; value: number | string; color?: string } = $props();

  const stickerMap: Record<string, { dot: string; bg: string }> = {
    blue: { dot: 'bg-[#0075de]', bg: 'bg-[#e8f3fc]' },
    green: { dot: 'bg-[#1aae39]', bg: 'bg-[#e8f8eb]' },
    yellow: { dot: 'bg-[#dd5b00]', bg: 'bg-[#fef2e8]' },
    red: { dot: 'bg-[#e03e3e]', bg: 'bg-[#fde8e8]' },
    purple: { dot: 'bg-[#d6b6f6]', bg: 'bg-[#f5eefc]' },
    gray: { dot: 'bg-[#615d59]', bg: 'bg-[#f0efed]' },
  };

  let sticker = $derived(stickerMap[color] || stickerMap.blue);
</script>

<div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm transition-all hover:border-[#d0d0d0]">
  <div class="flex items-center justify-between">
    <p class="text-xs font-semibold uppercase tracking-wider text-[#615d59]">{label}</p>
    <div class="h-2 w-2 rounded-full {sticker.dot}"></div>
  </div>
  <p class="mt-3 text-3xl font-bold tracking-tight text-[#000000]">{value}</p>
</div>
