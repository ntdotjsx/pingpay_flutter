<script lang="ts">
  let { label, value, color = 'blue' }: { label: string; value: number | string; color?: string } = $props();

  const bgMap: Record<string, string> = {
    blue: 'bg-blue-50 border-blue-200',
    green: 'bg-green-50 border-green-200',
    yellow: 'bg-yellow-50 border-yellow-200',
    red: 'bg-red-50 border-red-200',
    gray: 'bg-gray-50 border-gray-200',
  };
  const textMap: Record<string, string> = {
    blue: 'text-blue-600',
    green: 'text-green-600',
    yellow: 'text-yellow-600',
    red: 'text-red-600',
    gray: 'text-gray-600',
  };
</script>

<div class="rounded-lg border p-6 {bgMap[color] || bgMap.blue}">
  <p class="text-sm font-medium text-gray-600">{label}</p>
  <p class="mt-2 text-3xl font-bold {textMap[color] || textMap.blue}">{value}</p>
</div>
