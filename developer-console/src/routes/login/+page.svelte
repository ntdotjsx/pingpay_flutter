<script lang="ts">
  import { setToken, verifyLineToken, AUTH_BASE } from '$lib/api/client';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import Icon from '$lib/components/Icon.svelte';

  let token = $state('');
  let error = $state('');
  let loading = $state(false);
  let showAdvanced = $state(false);

  let mockDevUser = $state({
    mockLineUserId: 'line_admin_dev_001',
    mockDisplayName: 'Admin Developer',
  });

  onMount(async () => {
    const queryToken = $page.url.searchParams.get('token');
    const queryError = $page.url.searchParams.get('error');

    if (queryError) {
      error = decodeURIComponent(queryError);
    } else if (queryToken) {
      setToken(queryToken);
      window.location.replace('/');
    }
  });

  function handleLineOAuthRedirect() {
    const origin = typeof window !== 'undefined' ? window.location.origin : '';
    const redirectParam = origin ? `?redirect_to=${encodeURIComponent(origin)}` : '';
    window.location.href = `${AUTH_BASE}/line${redirectParam}`;
  }

  async function handleMockLineLogin() {
    loading = true;
    error = '';
    try {
      const res = await verifyLineToken({
        mockLineUserId: mockDevUser.mockLineUserId,
        mockDisplayName: mockDevUser.mockDisplayName,
      });
      if (res.accessToken) {
        goto('/');
      }
    } catch (e: any) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  function handleManualTokenLogin() {
    if (!token.trim()) {
      error = 'Please enter an access token';
      return;
    }
    setToken(token.trim());
    goto('/');
  }
</script>

<div class="flex min-h-screen items-center justify-center bg-[#f6f5f4] p-4">
  <div class="w-full max-w-md rounded-2xl bg-white p-8 shadow-sm border border-[#e6e6e6]">
    <div class="text-center mb-6">
      <div class="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-xl bg-[#0075de] text-white shadow-sm">
        <Icon name="card" class="h-6 w-6" />
      </div>
      <h1 class="text-xl font-bold text-[#000000] tracking-tight">PingPay Developer Console</h1>
      <p class="mt-1 text-xs text-[#615d59]">Administration & developer portal</p>
    </div>

    {#if error}
      <div class="mb-5 rounded-md border border-[#fde8e8] bg-[#fde8e8] p-3 text-xs text-[#c53030] flex items-center gap-2">
        <svg class="h-4 w-4 flex-shrink-0" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
        <span>{error}</span>
      </div>
    {/if}

    <div class="space-y-3.5">
      <!-- Primary LINE Login Button -->
      <button
        onclick={handleLineOAuthRedirect}
        disabled={loading}
        class="flex w-full items-center justify-center gap-2.5 rounded-full bg-[#06C755] px-5 py-3 text-sm font-bold text-white shadow-sm transition-all hover:bg-[#05B34C] active:scale-[0.99] disabled:opacity-50"
      >
        <svg class="h-5 w-5 fill-current" viewBox="0 0 24 24">
          <path d="M24 10.304c0-5.369-5.383-9.738-12-9.738-6.616 0-12 4.369-12 9.738 0 4.814 4.269 8.846 10.019 9.587.39.084.922.258 1.057.592.121.303.079.778.039 1.085l-.171 1.027c-.053.303-.242 1.186 1.039.647 1.281-.54 6.911-4.069 9.428-6.967 1.739-1.907 2.589-3.844 2.589-5.971z"/>
        </svg>
        <span>Log in with LINE</span>
      </button>

      <!-- Mock LINE Dev Login -->
      <div class="relative my-3">
        <div class="absolute inset-0 flex items-center"><div class="w-full border-t border-[#e6e6e6]"></div></div>
        <div class="relative flex justify-center text-[10px] uppercase"><span class="bg-white px-2 text-[#a39e98] font-mono">Dev Mode</span></div>
      </div>

      <button
        onclick={handleMockLineLogin}
        disabled={loading}
        class="flex w-full items-center justify-center gap-2 rounded-md border border-[#e6e6e6] bg-white px-4 py-2.5 text-xs font-semibold text-[#31302e] shadow-sm hover:bg-[#f6f5f4] active:scale-[0.99] disabled:opacity-50 transition-colors"
      >
        <Icon name="zap" class="h-3.5 w-3.5 text-[#dd5b00]" />
        <span>Mock LINE Developer Login</span>
      </button>

      <!-- Advanced JWT Token Input Toggle -->
      <div class="pt-2 text-center">
        <button
          onclick={() => showAdvanced = !showAdvanced}
          class="text-[11px] text-[#615d59] hover:text-[#000000] underline"
        >
          {showAdvanced ? 'Hide manual JWT token login' : 'Advanced: Paste JWT access token directly'}
        </button>

        {#if showAdvanced}
          <div class="mt-3 space-y-3 rounded-lg bg-[#fbfbfa] p-3.5 border border-[#e6e6e6] text-left">
            <div>
              <label for="token-input" class="block text-[11px] font-medium text-[#615d59]">Access Token (JWT)</label>
              <textarea
                id="token-input"
                bind:value={token}
                rows={3}
                class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2.5 py-1.5 text-xs font-mono shadow-sm focus:border-[#0075de] focus:ring-1 focus:ring-[#0075de] focus:outline-none"
                placeholder="eyJhbGciOiJIUzI1NiIs..."
              ></textarea>
            </div>
            <button
              onclick={handleManualTokenLogin}
              class="w-full rounded-md bg-[#0075de] px-3 py-1.5 text-xs font-medium text-white hover:bg-[#005bab] transition-colors"
            >
              Sign In with Token
            </button>
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>
