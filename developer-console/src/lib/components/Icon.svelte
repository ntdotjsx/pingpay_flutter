<script lang="ts">
  let {
    name,
    class: className = 'h-4 w-4',
    strokeWidth = 2
  }: {
    name:
      | 'dashboard'
      | 'bills'
      | 'payments'
      | 'transactions'
      | 'activity'
      | 'suspicious'
      | 'users'
      | 'disputes'
      | 'audit'
      | 'maintenance'
      | 'rewards'
      | 'notifications'
      | 'security'
      | 'card'
      | 'logout'
      | 'zap'
      | 'brush'
      | 'trash'
      | 'info'
      | 'check'
      | 'close'
      | 'plus'
      | 'edit'
      | 'menu'
      | 'apple'
      | 'android'
      | 'windows'
      | 'mac'
      | 'smartphone';
    class?: string;
    strokeWidth?: number;
  } = $props();
</script>

<svg
  xmlns="http://www.w3.org/2000/svg"
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width={strokeWidth}
  stroke-linecap="round"
  stroke-linejoin="round"
  class={className}
>
  {#if name === 'dashboard'}
    <rect width="7" height="9" x="3" y="3" rx="1" />
    <rect width="7" height="5" x="14" y="3" rx="1" />
    <rect width="7" height="9" x="14" y="12" rx="1" />
    <rect width="7" height="5" x="3" y="16" rx="1" />
  {:else if name === 'bills'}
    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
    <polyline points="14 2 14 8 20 8" />
    <line x1="16" y1="13" x2="8" y2="13" />
    <line x1="16" y1="17" x2="8" y2="17" />
    <polyline points="10 9 9 9 8 9" />
  {:else if name === 'payments'}
    <rect width="20" height="14" x="2" y="5" rx="2" />
    <line x1="2" y1="10" x2="22" y2="10" />
    <circle cx="7" cy="15" r="1" />
  {:else if name === 'transactions'}
    <path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z" />
    <path d="M16 8h-6a2 2 0 1 0 0 4h4a2 2 0 1 1 0 4H8" />
    <path d="M12 17.5v-11" />
  {:else if name === 'activity'}
    <path d="M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.48 12H2" />
  {:else if name === 'suspicious'}
    <path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z" />
    <path d="M12 8v4" />
    <path d="M12 16h.01" />
  {:else if name === 'users'}
    <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
    <circle cx="9" cy="7" r="4" />
    <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
    <path d="M16 3.13a4 4 0 0 1 0 7.75" />
  {:else if name === 'disputes'}
    <path d="m16 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z" />
    <path d="m2 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z" />
    <path d="M7 21h10" />
    <path d="M12 3v18" />
    <path d="M3 7h2c2 0 5-1 7-2 2 1 5 2 7 2h2" />
  {:else if name === 'audit'}
    <path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z" />
    <path d="M14 2v4a2 2 0 0 0 2 2h4" />
    <circle cx="11.5" cy="14.5" r="2.5" />
    <path d="m13.5 16.5 2 2" />
  {:else if name === 'maintenance'}
    <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" />
  {:else if name === 'card'}
    <rect width="20" height="14" x="2" y="5" rx="2" />
    <line x1="2" x2="22" y1="10" y2="10" />
  {:else if name === 'logout'}
    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
    <polyline points="16 17 21 12 16 7" />
    <line x1="21" x2="9" y1="12" y2="12" />
  {:else if name === 'zap'}
    <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
  {:else if name === 'brush'}
    <path d="m9.06 11.9 8.07-8.06a2.85 2.85 0 1 1 4.03 4.03l-8.06 8.08" />
    <path d="M7.07 14.94c-1.66 0-3 1.35-3 3.02 0 1.33-2.5 1.52-2 2.04 1.5 1.5 6 1 8-1 .52-.5.33-3-1-2" />
  {:else if name === 'trash'}
    <path d="M3 6h18" />
    <path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" />
    <path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" />
    <line x1="10" x2="10" y1="11" y2="17" />
    <line x1="14" x2="14" y1="11" y2="17" />
  {:else if name === 'info'}
    <circle cx="12" cy="12" r="10" />
    <path d="M12 16v-4" />
    <path d="M12 8h.01" />
  {:else if name === 'check'}
    <polyline points="20 6 9 17 4 12" />
  {:else if name === 'close'}
    <line x1="18" x2="6" y1="6" y2="18" />
    <line x1="6" x2="18" y1="6" y2="18" />
  {:else if name === 'rewards'}
    <rect x="3" y="8" width="18" height="14" rx="2" />
    <path d="M12 8v14" />
    <path d="M19 12H5" />
    <path d="M7.5 8a2.5 2.5 0 0 1 0-5A4.8 8 0 0 1 12 8a4.8 8 0 0 1 4.5-5 2.5 2.5 0 0 1 0 5" />
  {:else if name === 'notifications'}
    <path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9" />
    <path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" />
  {:else if name === 'security'}
    <rect width="18" height="11" x="3" y="11" rx="2" ry="2" />
    <path d="M7 11V7a5 5 0 0 1 10 0v4" />
  {:else if name === 'plus'}
    <path d="M5 12h14" />
    <path d="M12 5v14" />
  {:else if name === 'edit'}
    <path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
    <path d="m15 5 4 4" />
  {:else if name === 'menu'}
    <line x1="4" x2="20" y1="12" y2="12" />
    <line x1="4" x2="20" y1="6" y2="6" />
    <line x1="4" x2="20" y1="18" y2="18" />
  {:else if name === 'apple'}
    <path d="M12 20.94c1.88 0 2.9-.66 4.36-.66 1.43 0 2.3.66 4.14.66 2.3 0 4.14-2.14 5.5-4.14-2.88-1.66-3.32-5.74-.48-7.58-1.54-2.14-3.9-2.38-4.72-2.38-2.02 0-3.5 1.18-4.52 1.18-.98 0-2.52-1.14-4.22-1.14C8.7 6.88 5.76 8.9 4.34 11.4c-2.18 3.78-.56 9.38 1.56 12.44 1.04 1.5 2.28 3.16 3.9 3.1 1.56-.06 2.16-1 4.02-1M15.42 4.42c.86-1.04 1.44-2.48 1.28-3.92-1.24.06-2.72.82-3.6 1.86-.78.9-1.46 2.36-1.28 3.76 1.38.12 2.76-.66 3.6-1.7" />
  {:else if name === 'android'}
    <path d="M4 10a8 8 0 0 1 16 0v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V10Z" />
    <path d="M7 2l2.5 3" />
    <path d="M17 2l-2.5 3" />
    <circle cx="8.5" cy="12.5" r="1" fill="currentColor" />
    <circle cx="15.5" cy="12.5" r="1" fill="currentColor" />
  {:else if name === 'windows'}
    <path d="M3 5.5 10 4.5v6.75H3V5.5zm8-1.15L21 3v8.25h-10V4.35zM3 12.75h7V19.5l-7-1v-5.75zm8 0h10V21l-10-1.4v-6.85z" />
  {:else if name === 'mac'}
    <rect width="20" height="14" x="2" y="3" rx="2" />
    <line x1="8" x2="16" y1="21" y2="21" />
    <line x1="12" x2="12" y1="17" y2="21" />
  {:else if name === 'smartphone'}
    <rect width="14" height="20" x="5" y="2" rx="2" ry="2" />
    <line x1="12" x2="12.01" y1="18" y2="18" />
  {/if}
</svg>
