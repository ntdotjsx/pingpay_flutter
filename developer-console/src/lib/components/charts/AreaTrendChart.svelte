<script lang="ts">
  interface DataPoint {
    label: string;
    value: number;
    secondaryValue?: number;
  }

  let {
    data = [],
    title = 'Financial Volume Trend',
    subtitle = 'Daily transaction volume across PingPay',
    height = 220,
    unit = 'THB',
  }: {
    data: DataPoint[];
    title?: string;
    subtitle?: string;
    height?: number;
    unit?: string;
  } = $props();

  let hoveredIndex = $state<number | null>(null);

  const padding = { top: 20, right: 20, bottom: 30, left: 45 };
  const width = 600; // SVG viewBox coordinate width

  const maxVal = $derived(Math.max(...data.map((d) => d.value), 100));
  const minVal = 0;

  const points = $derived.by(() => {
    if (data.length <= 1) return [];
    const step = (width - padding.left - padding.right) / (data.length - 1);
    return data.map((d, i) => {
      const x = padding.left + i * step;
      const yRatio = (d.value - minVal) / (maxVal - minVal || 1);
      const y = height - padding.bottom - yRatio * (height - padding.top - padding.bottom);
      return { x, y, data: d, index: i };
    });
  });

  const linePath = $derived.by(() => {
    if (points.length === 0) return '';
    return points.reduce((acc, p, i) => (i === 0 ? `M ${p.x},${p.y}` : `${acc} L ${p.x},${p.y}`), '');
  });

  const areaPath = $derived.by(() => {
    if (points.length === 0) return '';
    const bottomY = height - padding.bottom;
    const firstX = points[0].x;
    const lastX = points[points.length - 1].x;
    return `${linePath} L ${lastX},${bottomY} L ${firstX},${bottomY} Z`;
  });

  const yTicks = $derived([
    0,
    Math.round(maxVal * 0.5),
    Math.round(maxVal),
  ]);
</script>

<div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm">
  <div class="mb-3 flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h3 class="text-sm font-bold text-[#000000]">{title}</h3>
      {#if subtitle}
        <p class="text-[11px] text-[#615d59]">{subtitle}</p>
      {/if}
    </div>
    {#if hoveredIndex !== null && points[hoveredIndex]}
      <div class="flex items-center gap-2 text-xs">
        <span class="text-[#615d59]">{points[hoveredIndex].data.label}:</span>
        <strong class="font-mono text-[#0075de] font-bold">
          {points[hoveredIndex].data.value.toLocaleString()} {unit}
        </strong>
      </div>
    {/if}
  </div>

  <div class="relative w-full overflow-hidden">
    <svg viewBox="0 0 {width} {height}" class="w-full h-auto overflow-visible select-none">
      <defs>
        <linearGradient id="areaGradient" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#0075de" stop-opacity="0.25" />
          <stop offset="100%" stop-color="#0075de" stop-opacity="0.0" />
        </linearGradient>
      </defs>

      <!-- Y Grid Lines & Labels -->
      {#each yTicks as tick}
        {@const yRatio = (tick - minVal) / (maxVal - minVal || 1)}
        {@const y = height - padding.bottom - yRatio * (height - padding.top - padding.bottom)}
        <line
          x1={padding.left}
          y1={y}
          x2={width - padding.right}
          y2={y}
          stroke="#f0efed"
          stroke-width="1"
          stroke-dasharray="4 4"
        />
        <text
          x={padding.left - 8}
          y={y + 3}
          text-anchor="end"
          class="text-[9px] fill-[#a39e98] font-mono"
        >
          {tick >= 1000 ? `${(tick / 1000).toFixed(0)}k` : tick}
        </text>
      {/each}

      <!-- Area fill -->
      {#if areaPath}
        <path d={areaPath} fill="url(#areaGradient)" />
      {/if}

      <!-- Line stroke -->
      {#if linePath}
        <path d={linePath} fill="none" stroke="#0075de" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" />
      {/if}

      <!-- Points & Hover targets -->
      {#each points as pt, i}
        <!-- X Axis Label -->
        <text
          x={pt.x}
          y={height - 8}
          text-anchor="middle"
          class="text-[9px] fill-[#615d59] font-mono"
        >
          {pt.data.label}
        </text>

        <!-- Point dot -->
        <circle
          cx={pt.x}
          cy={pt.y}
          r={hoveredIndex === i ? 5 : 3}
          fill={hoveredIndex === i ? '#0075de' : '#ffffff'}
          stroke="#0075de"
          stroke-width="2"
          class="transition-all"
        />

        <!-- Hover vertical crosshair -->
        {#if hoveredIndex === i}
          <line
            x1={pt.x}
            y1={padding.top}
            x2={pt.x}
            y2={height - padding.bottom}
            stroke="#0075de"
            stroke-width="1"
            stroke-dasharray="2 2"
            opacity="0.6"
          />
        {/if}

        <!-- Invisible Hit Target -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <rect
          x={pt.x - 15}
          y={padding.top}
          width="30"
          height={height - padding.top - padding.bottom}
          fill="transparent"
          class="cursor-pointer"
          onmouseenter={() => hoveredIndex = i}
          onmouseleave={() => hoveredIndex = null}
        />
      {/each}
    </svg>
  </div>
</div>
