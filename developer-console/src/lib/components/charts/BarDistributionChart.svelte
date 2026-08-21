<script lang="ts">
  interface BarItem {
    label: string;
    value: number;
    color?: string;
  }

  let {
    items = [],
    title = 'Distribution Breakdown',
    subtitle = 'Status and volume distribution',
    height = 220,
    unit = 'items',
  }: {
    items: BarItem[];
    title?: string;
    subtitle?: string;
    height?: number;
    unit?: string;
  } = $props();

  let hoveredIndex = $state<number | null>(null);

  const padding = { top: 20, right: 25, bottom: 35, left: 35 };
  const width = 500;

  const maxVal = $derived(Math.max(...items.map((it) => it.value), 10));

  const defaultColors = ['#0075de', '#06c755', '#dd5b00', '#c53030', '#8c52ff', '#00b4d8'];
</script>

<div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm">
  <div class="mb-3 flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h3 class="text-sm font-bold text-[#000000]">{title}</h3>
      {#if subtitle}
        <p class="text-[11px] text-[#615d59]">{subtitle}</p>
      {/if}
    </div>
    {#if hoveredIndex !== null && items[hoveredIndex]}
      <div class="flex items-center gap-2 text-xs">
        <span class="text-[#615d59]">{items[hoveredIndex].label}:</span>
        <strong class="font-mono text-[#000000] font-bold">
          {items[hoveredIndex].value.toLocaleString()} {unit}
        </strong>
      </div>
    {/if}
  </div>

  <div class="relative w-full overflow-hidden">
    <svg viewBox="0 0 {width} {height}" class="w-full h-auto overflow-visible select-none">
      <!-- Bars -->
      {#if items.length > 0}
        {@const chartWidth = width - padding.left - padding.right}
        {@const chartHeight = height - padding.top - padding.bottom}
        {@const barWidth = Math.min(48, (chartWidth / items.length) * 0.65)}
        {@const step = chartWidth / items.length}

        <!-- Baseline -->
        <line
          x1={padding.left}
          y1={height - padding.bottom}
          x2={width - padding.right}
          y2={height - padding.bottom}
          stroke="#e6e6e6"
          stroke-width="1"
        />

        {#each items as item, i}
          {@const barHeight = (item.value / maxVal) * chartHeight}
          {@const x = padding.left + i * step + (step - barWidth) / 2}
          {@const y = height - padding.bottom - barHeight}
          {@const color = item.color || defaultColors[i % defaultColors.length]}

          <!-- Bar Rect with rounded top corners -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <rect
            {x}
            {y}
            width={barWidth}
            height={Math.max(barHeight, 2)}
            rx="4"
            fill={color}
            opacity={hoveredIndex === null || hoveredIndex === i ? 1 : 0.45}
            class="transition-all cursor-pointer"
            onmouseenter={() => hoveredIndex = i}
            onmouseleave={() => hoveredIndex = null}
          />

          <!-- Value on top of bar -->
          <text
            x={x + barWidth / 2}
            y={y - 5}
            text-anchor="middle"
            class="text-[10px] font-bold font-mono transition-opacity {hoveredIndex === i ? 'fill-[#000000]' : 'fill-[#615d59]'}"
          >
            {item.value}
          </text>

          <!-- Label below bar -->
          <text
            x={x + barWidth / 2}
            y={height - padding.bottom + 16}
            text-anchor="middle"
            class="text-[9px] fill-[#615d59] font-medium"
          >
            {item.label}
          </text>
        {/each}
      {/if}
    </svg>
  </div>
</div>
