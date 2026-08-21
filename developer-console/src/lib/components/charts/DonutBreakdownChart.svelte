<script lang="ts">
  interface DonutSlice {
    label: string;
    value: number;
    color?: string;
  }

  let {
    slices = [],
    title = 'Proportion Breakdown',
    subtitle = 'Category distribution',
    height = 220,
    unit = 'items',
  }: {
    slices: DonutSlice[];
    title?: string;
    subtitle?: string;
    height?: number;
    unit?: string;
  } = $props();

  let hoveredIndex = $state<number | null>(null);

  const defaultColors = ['#0075de', '#06c755', '#dd5b00', '#c53030', '#8c52ff', '#00b4d8'];

  const total = $derived(slices.reduce((sum, s) => sum + s.value, 0));

  // Compute SVG arc paths for donut
  const arcs = $derived.by(() => {
    if (total === 0) return [];
    let currentAngle = -Math.PI / 2; // start from top (12 o'clock)
    const cx = 110;
    const cy = 110;
    const outerRadius = 80;
    const innerRadius = 52;

    return slices.map((s, i) => {
      const sliceAngle = (s.value / total) * 2 * Math.PI;
      const startAngle = currentAngle;
      const endAngle = currentAngle + sliceAngle;
      currentAngle = endAngle;

      const x1 = cx + outerRadius * Math.cos(startAngle);
      const y1 = cy + outerRadius * Math.sin(startAngle);
      const x2 = cx + outerRadius * Math.cos(endAngle);
      const y2 = cy + outerRadius * Math.sin(endAngle);

      const x3 = cx + innerRadius * Math.cos(endAngle);
      const y3 = cy + innerRadius * Math.sin(endAngle);
      const x4 = cx + innerRadius * Math.cos(startAngle);
      const y4 = cy + innerRadius * Math.sin(startAngle);

      const largeArc = sliceAngle > Math.PI ? 1 : 0;

      const pathData = `M ${x1} ${y1} A ${outerRadius} ${outerRadius} 0 ${largeArc} 1 ${x2} ${y2} L ${x3} ${y3} A ${innerRadius} ${innerRadius} 0 ${largeArc} 0 ${x4} ${y4} Z`;

      const percent = Math.round((s.value / total) * 100);
      const color = s.color || defaultColors[i % defaultColors.length];

      return {
        pathData,
        slice: s,
        percent,
        color,
        index: i,
      };
    });
  });
</script>

<div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm">
  <div class="mb-3">
    <h3 class="text-sm font-bold text-[#000000]">{title}</h3>
    {#if subtitle}
      <p class="text-[11px] text-[#615d59]">{subtitle}</p>
    {/if}
  </div>

  <div class="flex flex-col items-center gap-4 sm:flex-row sm:justify-around">
    <!-- SVG Donut Chart -->
    <div class="relative flex-shrink-0">
      <svg width="220" height="220" viewBox="0 0 220 220" class="select-none">
        {#each arcs as arc, i}
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <path
            d={arc.pathData}
            fill={arc.color}
            stroke="#ffffff"
            stroke-width="2"
            opacity={hoveredIndex === null || hoveredIndex === i ? 1 : 0.45}
            class="transition-all cursor-pointer"
            onmouseenter={() => hoveredIndex = i}
            onmouseleave={() => hoveredIndex = null}
          />
        {/each}

        <!-- Center Text -->
        <text x="110" y="105" text-anchor="middle" class="text-xl font-bold fill-[#000000] font-mono">
          {hoveredIndex !== null && slices[hoveredIndex] ? slices[hoveredIndex].value : total}
        </text>
        <text x="110" y="122" text-anchor="middle" class="text-[10px] fill-[#615d59] font-medium">
          {hoveredIndex !== null && slices[hoveredIndex] ? slices[hoveredIndex].label : `Total ${unit}`}
        </text>
      </svg>
    </div>

    <!-- Legend List -->
    <div class="flex flex-col gap-2 w-full max-w-xs">
      {#each slices as slice, i}
        {@const color = slice.color || defaultColors[i % defaultColors.length]}
        {@const percent = total > 0 ? Math.round((slice.value / total) * 100) : 0}
        <button
          type="button"
          class="flex items-center justify-between rounded-lg p-2 text-xs transition-colors {hoveredIndex === i ? 'bg-[#f6f5f4]' : 'hover:bg-[#faf9f8]'}"
          onmouseenter={() => hoveredIndex = i}
          onmouseleave={() => hoveredIndex = null}
        >
          <div class="flex items-center gap-2">
            <span class="h-2.5 w-2.5 rounded-full" style="background-color: {color}"></span>
            <span class="text-[#31302e] font-medium">{slice.label}</span>
          </div>
          <div class="flex items-center gap-2">
            <span class="font-mono text-[#615d59] text-[11px]">{percent}%</span>
            <strong class="font-mono text-[#000000]">{slice.value}</strong>
          </div>
        </button>
      {/each}
    </div>
  </div>
</div>
