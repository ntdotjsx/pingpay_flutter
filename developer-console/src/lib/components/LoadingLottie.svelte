<script lang="ts">
  import { onMount } from 'svelte';
  import { browser } from '$app/environment';
  import animationData from '$lib/assets/Olympics_Table.json';

  let { text = 'Loading data...', size = 140 }: { text?: string; size?: number } = $props();
  let container = $state<HTMLDivElement | null>(null);
  let anim: any = null;

  onMount(() => {
    if (!container || !browser) return;

    import('lottie-web')
      .then((lottieModule) => {
        const lottie = lottieModule.default || lottieModule;
        if (!container) return;
        anim = lottie.loadAnimation({
          container,
          renderer: 'svg',
          loop: true,
          autoplay: true,
          animationData,
        });
      })
      .catch((err) => {
        console.error('Failed to load Lottie animation:', err);
      });

    return () => {
      anim?.destroy();
    };
  });
</script>

<div class="flex flex-col items-center justify-center py-6 px-4 text-center">
  <div bind:this={container} style="width: {size}px; height: {size}px;" class="mx-auto flex items-center justify-center"></div>
  {#if text}
    <p class="mt-1 text-xs font-medium text-[#615d59]">{text}</p>
  {/if}
</div>
