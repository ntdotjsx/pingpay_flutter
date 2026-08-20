<script lang="ts">
  import { setToken, verifyLineToken } from '$lib/api/client';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';

  let token = $state('');
  let error = $state('');
  let loading = $state(false);
  let showAdvanced = $state(false);

  let mockDevUser = $state({
    mockLineUserId: 'line_admin_dev_001',
    mockDisplayName: 'Admin Developer',
  });

  onMount(async () => {
    // Check if redirect callback provided a token in query param
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
    // Direct browser to Elysia LINE OAuth redirect endpoint
    window.location.href = 'http://localhost:3000/api/v1/auth/line';
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

<div class="flex min-h-screen items-center justify-center bg-gray-100 p-4">
  <div class="w-full max-w-md rounded-2xl bg-white p-8 shadow-xl border border-gray-100">
    <div class="text-center mb-6">
      <div class="mx-auto mb-3 flex h-14 w-14 items-center justify-center rounded-2xl bg-emerald-600 text-2xl text-white shadow-md">
        💳
      </div>
      <h1 class="text-2xl font-black text-gray-900 tracking-tight">PingPay Developer Console</h1>
      <p class="mt-1 text-sm text-gray-500">Back-office administration & developer portal</p>
    </div>

    {#if error}
      <div class="mb-5 rounded-lg border border-red-200 bg-red-50 p-3.5 text-sm text-red-700">
        <div class="flex items-center gap-2">
          <svg class="h-4 w-4 flex-shrink-0" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
          <span>{error}</span>
        </div>
      </div>
    {/if}

    <div class="space-y-4">
      <!-- Primary LINE Login Button -->
      <button
        onclick={handleLineOAuthRedirect}
        disabled={loading}
        class="flex w-full items-center justify-center gap-3 rounded-xl bg-[#06C755] px-5 py-3.5 text-base font-bold text-white shadow transition-all hover:bg-[#05B34C] active:scale-[0.98] disabled:opacity-50"
      >
        <svg class="h-6 w-6 fill-current" viewBox="0 0 24 24">
          <path d="M24 10.304c0-5.369-5.383-9.738-12-9.738-6.616 0-12 4.369-12 9.738 0 4.814 4.269 8.846 10.019 9.587.39.084.922.258 1.057.592.121.303.079.778.039 1.085l-.171 1.027c-.053.303-.242 1.186 1.039.647 1.281-.54 6.911-4.069 9.428-6.967 1.739-1.907 2.589-3.844 2.589-5.971z"/>
        </svg>
        <span>Log in with LINE</span>
      </button>

      <!-- Mock LINE Dev Login (Local Development) -->
      <div class="relative my-4">
        <div class="absolute inset-0 flex items-center"><div class="w-full border-t border-gray-200"></div></div>
        <div class="relative flex justify-center text-xs uppercase"><span class="bg-white px-2 text-gray-400 font-medium">Local Dev Mode</span></div>
      </div>

      <button
        onclick={handleMockLineLogin}
        disabled={loading}
        class="flex w-full items-center justify-center gap-2 rounded-xl border border-gray-300 bg-white px-4 py-2.5 text-sm font-semibold text-gray-700 shadow-sm hover:bg-gray-50 active:scale-[0.99] disabled:opacity-50"
      >
        <span>⚡ Mock LINE Developer Login</span>
      </button>

      <!-- Advanced JWT Token Input Toggle -->
      <div class="pt-2">
        <button
          onclick={() => showAdvanced = !showAdvanced}
          class="text-xs text-gray-500 hover:text-gray-700 underline"
        >
          {showAdvanced ? 'Hide manual JWT token login' : 'Advanced: Paste JWT access token directly'}
        </button>

        {#if showAdvanced}
          <div class="mt-3 space-y-3 rounded-lg bg-gray-50 p-4 border border-gray-200">
            <div>
              <label for="token-input" class="block text-xs font-medium text-gray-700">Access Token (JWT)</label>
              <textarea
                id="token-input"
                bind:value={token}
                rows={3}
                class="mt-1 block w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-xs font-mono shadow-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-none"
                placeholder="eyJhbGciOiJIUzI1NiIs..."
              ></textarea>
            </div>
            <button
              onclick={handleManualTokenLogin}
              class="w-full rounded-md bg-gray-800 px-3 py-1.5 text-xs font-medium text-white hover:bg-gray-900"
            >
              Sign In with Token
            </button>
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>
