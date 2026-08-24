<script lang="ts">
  import './layout.css';
  import { page } from '$app/stores';
  import { isAuthenticated, clearToken, getMe } from '$lib/api/client';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import Icon from '$lib/components/Icon.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';

  let { children } = $props();
  let mounted = $state(false);
  let authenticated = $state(false);
  let currentUser = $state<any>(null);
  let mobileMenuOpen = $state(false);

  const navItems: { label: string; href: string; icon: 'dashboard' | 'bills' | 'payments' | 'transactions' | 'activity' | 'suspicious' | 'users' | 'disputes' | 'rewards' | 'notifications' | 'security' | 'audit' | 'maintenance' }[] = [
    { label: 'Dashboard', href: '/', icon: 'dashboard' },
    { label: 'Bills', href: '/bills', icon: 'bills' },
    { label: 'Payments', href: '/payments', icon: 'payments' },
    { label: 'Transactions', href: '/transactions', icon: 'transactions' },
    { label: 'Rewards Store', href: '/rewards', icon: 'rewards' },
    { label: 'Notifications', href: '/notifications', icon: 'notifications' },
    { label: 'Security Events', href: '/security', icon: 'security' },
    { label: 'Activity Logs', href: '/activity-logs', icon: 'activity' },
    { label: 'Suspicious', href: '/suspicious', icon: 'suspicious' },
    { label: 'Users', href: '/users', icon: 'users' },
    { label: 'Disputes', href: '/disputes', icon: 'disputes' },
    { label: 'Audit Log', href: '/audit-logs', icon: 'audit' },
    { label: 'Maintenance', href: '/maintenance', icon: 'maintenance' },
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
    if (mounted && $page.url.pathname) {
      mobileMenuOpen = false;
      checkAuth();
    }
  });

  function logout() {
    clearToken();
    currentUser = null;
    authenticated = false;
    mobileMenuOpen = false;
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
  <div class="flex h-screen items-center justify-center bg-[#f6f5f4]">
    <LoadingLottie text="Loading PingPay Console..." size={180} />
  </div>
{:else if !authenticated && $page.url.pathname !== '/login'}
  <div class="flex h-screen items-center justify-center bg-[#f6f5f4]">
    <LoadingLottie text="Redirecting to login..." size={180} />
  </div>
{:else if $page.url.pathname === '/login'}
  {@render children()}
{:else}
  <div class="flex h-screen flex-col lg:flex-row bg-[#f6f5f4] overflow-hidden">
    <!-- Mobile Top Navigation Bar -->
    <header class="flex h-14 w-full items-center justify-between border-b border-[#e6e6e6] bg-white px-4 lg:hidden shrink-0 z-30">
      <div class="flex items-center gap-3">
        <button
          onclick={() => mobileMenuOpen = !mobileMenuOpen}
          aria-label="Toggle navigation menu"
          class="flex h-9 w-9 items-center justify-center rounded-md border border-[#e6e6e6] text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
        >
          <Icon name={mobileMenuOpen ? 'close' : 'menu'} class="h-5 w-5" />
        </button>
        <div class="flex items-center gap-2">
          <div class="flex h-7 w-7 items-center justify-center rounded-[6px] bg-[#0075de] text-white shadow-sm">
            <Icon name="card" class="h-4 w-4" />
          </div>
          <span class="text-sm font-bold tracking-tight text-[#000000]">PingPay Console</span>
        </div>
      </div>

      {#if currentUser}
        <div class="flex items-center gap-2">
          {#if currentUser.avatarUrl}
            <img src={currentUser.avatarUrl} alt="" class="h-7 w-7 rounded-full object-cover border border-[#e6e6e6]" />
          {:else}
            <div class="flex h-7 w-7 items-center justify-center rounded-full bg-[#0075de] text-xs font-bold text-white">
              {(currentUser.displayName || 'A')[0]}
            </div>
          {/if}
        </div>
      {/if}
    </header>

    <!-- Mobile Drawer Backdrop -->
    {#if mobileMenuOpen}
      <button
        onclick={() => mobileMenuOpen = false}
        aria-label="Close navigation menu"
        class="fixed inset-0 z-40 bg-black/40 backdrop-blur-sm lg:hidden transition-opacity"
      ></button>
    {/if}

    <!-- Mobile Drawer / Sidebar -->
    <aside
      class="fixed inset-y-0 left-0 z-50 flex w-72 flex-col border-r border-[#e6e6e6] bg-[#fbfbfa] text-[#000000] shadow-xl transition-transform duration-200 lg:static lg:w-64 lg:shadow-none lg:translate-x-0 shrink-0 {mobileMenuOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}"
    >
      <!-- Header / Brand -->
      <div class="flex h-14 items-center justify-between border-b border-[#e6e6e6] px-5 bg-white shrink-0">
        <div class="flex items-center gap-3">
          <div class="flex h-7 w-7 items-center justify-center rounded-[6px] bg-[#0075de] text-white shadow-sm">
            <Icon name="card" class="h-4 w-4" />
          </div>
          <div class="min-w-0">
            <h1 class="text-sm font-bold tracking-tight text-[#000000]">PingPay</h1>
            <span class="block text-[10px] font-semibold text-[#0075de] uppercase tracking-wider">Console</span>
          </div>
        </div>

        <button
          onclick={() => mobileMenuOpen = false}
          aria-label="Close navigation drawer"
          class="flex h-7 w-7 items-center justify-center rounded text-[#615d59] hover:bg-[#f6f5f4] lg:hidden"
        >
          <Icon name="close" class="h-4 w-4" />
        </button>
      </div>

      <!-- Navigation Links -->
      <nav class="flex-1 space-y-0.5 px-3 py-3 overflow-y-auto">
        {#each navItems as item}
          <a
            href={item.href}
            onclick={() => mobileMenuOpen = false}
            class="flex items-center gap-2.5 rounded-[5px] px-2.5 py-2 text-xs font-medium transition-colors {isActive(item.href, $page.url.pathname) ? 'bg-[#e8f3fc] text-[#0075de] font-semibold' : 'text-[#31302e] hover:bg-[#eae8e5]'}"
          >
            <Icon name={item.icon} class="h-4 w-4 flex-shrink-0" />
            <span>{item.label}</span>
          </a>
        {/each}
      </nav>

      <!-- Current User Section -->
      {#if currentUser}
        <div class="border-t border-[#e6e6e6] bg-white p-3 shrink-0">
          <div class="flex items-center gap-2.5">
            {#if currentUser.avatarUrl}
              <img src={currentUser.avatarUrl} alt="" class="h-8 w-8 rounded-full object-cover border border-[#e6e6e6]" />
            {:else}
              <div class="flex h-8 w-8 items-center justify-center rounded-full bg-[#0075de] text-xs font-bold text-white">
                {(currentUser.displayName || 'A')[0]}
              </div>
            {/if}
            <div class="flex-1 min-w-0">
              <div class="text-xs font-semibold text-[#000000] truncate">{currentUser.displayName || 'Developer Admin'}</div>
              <div class="flex items-center gap-1 mt-0.5">
                <span class="inline-block h-1.5 w-1.5 rounded-full bg-[#1aae39]"></span>
                <span class="text-[10px] text-[#615d59] uppercase font-mono">{currentUser.role || 'developer'}</span>
              </div>
            </div>
          </div>
        </div>
      {/if}

      <!-- Sign Out -->
      <div class="border-t border-[#e6e6e6] p-2 bg-[#fbfbfa] shrink-0">
        <button
          onclick={logout}
          class="flex w-full items-center gap-2 rounded-[5px] px-2.5 py-1.5 text-left text-xs font-medium text-[#c53030] hover:bg-[#fde8e8] transition-colors"
        >
          <Icon name="logout" class="h-3.5 w-3.5" />
          <span>Sign Out</span>
        </button>
      </div>
    </aside>

    <!-- Main Content Area -->
    <main class="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8">
      {@render children()}
    </main>
  </div>
{/if}
