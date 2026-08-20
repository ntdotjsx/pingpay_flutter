<script lang="ts">
  import './layout.css';
  import { page } from '$app/stores';
  import { isAuthenticated, clearToken, getMe } from '$lib/api/client';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  let { children } = $props();
  let mounted = $state(false);
  let authenticated = $state(false);
  let currentUser = $state<any>(null);

  const navItems = [
    { label: 'Dashboard', href: '/', icon: '📊' },
    { label: 'Transactions', href: '/transactions', icon: '💰' },
    { label: 'Activity Logs', href: '/activity-logs', icon: '📋' },
    { label: 'Suspicious', href: '/suspicious', icon: '🚨' },
    { label: 'Users', href: '/users', icon: '👥' },
    { label: 'Disputes', href: '/disputes', icon: '⚖️' },
    { label: 'Audit Log', href: '/audit-logs', icon: '🔍' },
    { label: 'Maintenance', href: '/maintenance', icon: '🧹' },
  ];

  function checkAuth() {
    if (typeof window === 'undefined') return;
    authenticated = isAuthenticated();
    if (!authenticated && $page.url.pathname !== '/login') {
      goto('/login');
    } else if (authenticated && !currentUser) {
      getMe().then((res) => {
        currentUser = res;
      }).catch(() => {});
    }
  }

  onMount(() => {
    mounted = true;
    checkAuth();
  });

  $effect(() => {
    // Reactively check auth on route changes
    if (mounted && $page.url.pathname) {
      checkAuth();
    }
  });

  function logout() {
    clearToken();
    currentUser = null;
    authenticated = false;
    goto('/login');
  }

  function isActive(href: string, currentPath: string): boolean {
    if (href === '/') return currentPath === '/';
    return currentPath.startsWith(href);
  }
</script>

<svelte:head>
  <title>PingPay Developer Console</title>
</svelte:head>

{#if !mounted}
  <div class="flex h-screen items-center justify-center bg-gray-100">
    <p class="text-gray-500">Loading...</p>
  </div>
{:else if !authenticated && $page.url.pathname !== '/login'}
  <div class="flex h-screen items-center justify-center bg-gray-100">
    <p class="text-gray-500">Redirecting to login...</p>
  </div>
{:else if $page.url.pathname === '/login'}
  {@render children()}
{:else}
  <div class="flex h-screen bg-gray-100">
    <aside class="flex w-64 flex-col bg-gray-900 text-white">
      <div class="flex h-16 items-center gap-3 px-6 border-b border-gray-800">
        <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-emerald-600 text-base font-bold">
          💳
        </div>
        <div>
          <h1 class="text-sm font-bold tracking-wide">PingPay Console</h1>
          <span class="text-[10px] text-emerald-400 font-mono">DEVELOPER PORTAL</span>
        </div>
      </div>

      <nav class="flex-1 space-y-1 px-3 py-4">
        {#each navItems as item}
          <a
            href={item.href}
            class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors {isActive(item.href, $page.url.pathname) ? 'bg-gray-800 text-emerald-400 font-semibold' : 'text-gray-400 hover:bg-gray-800 hover:text-white'}"
          >
            <span class="text-base">{item.icon}</span>
            <span>{item.label}</span>
          </a>
        {/each}
      </nav>

      <!-- Current Admin User Section -->
      {#if currentUser}
        <div class="border-t border-gray-800 p-4 bg-gray-950/40">
          <div class="flex items-center gap-3">
            {#if currentUser.avatarUrl}
              <img src={currentUser.avatarUrl} alt="" class="h-9 w-9 rounded-full object-cover border border-emerald-500" />
            {:else}
              <div class="flex h-9 w-9 items-center justify-center rounded-full bg-emerald-700 text-sm font-bold text-white">
                {(currentUser.displayName || 'A')[0]}
              </div>
            {/if}
            <div class="flex-1 min-w-0">
              <div class="text-xs font-semibold text-white truncate">{currentUser.displayName || 'Developer Admin'}</div>
              <div class="flex items-center gap-1.5 mt-0.5">
                <span class="inline-block h-1.5 w-1.5 rounded-full bg-emerald-400"></span>
                <span class="text-[10px] text-gray-400 uppercase font-mono">{currentUser.role || 'developer'}</span>
              </div>
            </div>
          </div>
        </div>
      {/if}

      <div class="border-t border-gray-800 p-3">
        <button
          onclick={logout}
          class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-xs font-medium text-red-400 hover:bg-gray-800 hover:text-red-300 transition-colors"
        >
          <span>🚪</span>
          <span>Sign Out</span>
        </button>
      </div>
    </aside>

    <main class="flex-1 overflow-auto p-8">
      {@render children()}
    </main>
  </div>
{/if}
