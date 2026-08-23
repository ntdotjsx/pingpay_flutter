<script lang="ts">
  import { setToken, verifyGoogleToken, AUTH_BASE } from '$lib/api/client';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import Icon from '$lib/components/Icon.svelte';

  let token = $state('');
  let error = $state('');
  let loading = $state(false);
  let showAdvanced = $state(false);

  let mockDevUser = $state({
    mockGoogleId: 'google_admin_dev_001',
    mockDisplayName: 'Admin Developer',
    mockEmail: 'admin.dev@pingpay.app',
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

  async function handleMockGoogleLogin() {
    loading = true;
    error = '';
    try {
      const res = await verifyGoogleToken({
        mockGoogleId: mockDevUser.mockGoogleId,
        mockDisplayName: mockDevUser.mockDisplayName,
        mockEmail: mockDevUser.mockEmail,
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
      <!-- Dev Google Login Button -->
      <button
        onclick={handleMockGoogleLogin}
        disabled={loading}
        class="flex w-full items-center justify-center gap-2.5 rounded-full bg-[#0075de] px-5 py-3 text-sm font-bold text-white shadow-sm transition-all hover:bg-[#005bab] active:scale-[0.99] disabled:opacity-50"
      >
        <Icon name="zap" class="h-4 w-4 text-white" />
        <span>Developer Quick Sign-In</span>
      </button>

      <!-- Mock Google Dev Config -->
      <div class="rounded-lg bg-[#fbfbfa] p-3 border border-[#e6e6e6] space-y-2 text-left">
        <div>
          <label for="mock-user-id" class="block text-[10px] font-medium text-[#615d59] uppercase tracking-wider">Mock Developer Google ID</label>
          <input
            id="mock-user-id"
            type="text"
            bind:value={mockDevUser.mockGoogleId}
            class="mt-0.5 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs font-mono text-[#000000] focus:border-[#0075de] focus:outline-none"
          />
        </div>
        <div>
          <label for="mock-user-name" class="block text-[10px] font-medium text-[#615d59] uppercase tracking-wider">Display Name</label>
          <input
            id="mock-user-name"
            type="text"
            bind:value={mockDevUser.mockDisplayName}
            class="mt-0.5 block w-full rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
          />
        </div>
      </div>

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
