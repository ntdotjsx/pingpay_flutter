<script lang="ts">
  import { setToken, verifyGoogleToken } from '$lib/api/client';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import Icon from '$lib/components/Icon.svelte';

  const GOOGLE_CLIENT_ID =
    import.meta.env.VITE_GOOGLE_CLIENT_ID ||
    '628880255448-qvtgouniidlkanp37l0nfh2pts26fth5.apps.googleusercontent.com';

  let token = $state('');
  let error = $state('');
  let loading = $state(false);
  let showAdvanced = $state(false);
  let gClientLoaded = $state(false);

  async function handleCredentialResponse(response: any) {
    if (!response?.credential) {
      error = 'Google authentication response missing credential';
      return;
    }

    loading = true;
    error = '';
    try {
      const res = await verifyGoogleToken({
        idToken: response.credential,
      });

      if (res.accessToken) {
        goto('/');
      }
    } catch (e: any) {
      error = e.message || 'Google authentication failed';
    } finally {
      loading = false;
    }
  }

  function initGoogleBtn() {
    if (typeof window === 'undefined') return;
    const g = (window as any).google;
    if (g?.accounts?.id) {
      try {
        g.accounts.id.initialize({
          client_id: GOOGLE_CLIENT_ID,
          callback: handleCredentialResponse,
          auto_select: false,
          cancel_on_tap_outside: true,
        });

        const container = document.getElementById('google-signin-btn-container');
        if (container) {
          container.innerHTML = '';
          g.accounts.id.renderButton(container, {
            type: 'standard',
            theme: 'outline',
            size: 'large',
            text: 'signin_with',
            shape: 'pill',
            logo_alignment: 'left',
            width: 320,
          });
          gClientLoaded = true;
        }
      } catch (err) {
        console.error('Google Sign-In render error:', err);
      }
    }
  }

  onMount(() => {
    const queryToken = $page.url.searchParams.get('token');
    const queryError = $page.url.searchParams.get('error');

    if (queryError) {
      error = decodeURIComponent(queryError);
    } else if (queryToken) {
      setToken(queryToken);
      window.location.replace('/');
      return;
    }

    // Check if Google script is already loaded, otherwise poll until available
    if ((window as any).google?.accounts?.id) {
      initGoogleBtn();
    } else {
      const interval = setInterval(() => {
        if ((window as any).google?.accounts?.id) {
          clearInterval(interval);
          initGoogleBtn();
        }
      }, 200);

      setTimeout(() => clearInterval(interval), 10000);
    }
  });

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

    <div class="space-y-4">
      <!-- Real Google Sign-In Container -->
      <div class="flex flex-col items-center justify-center min-h-[48px] py-2">
        <div id="google-signin-btn-container" class="flex justify-center w-full"></div>
        {#if !gClientLoaded && !loading}
          <div class="flex items-center gap-2 text-xs text-[#615d59] py-2">
            <span class="inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-[#0075de] border-r-transparent"></span>
            <span>Loading Google Sign-In SDK...</span>
          </div>
        {/if}
        {#if loading}
          <div class="flex items-center gap-2 text-xs text-[#0075de] font-semibold py-2">
            <span class="inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-[#0075de] border-r-transparent"></span>
            <span>Verifying Google account credentials...</span>
          </div>
        {/if}
      </div>

      <div class="rounded-lg bg-[#fbfbfa] p-3 border border-[#e6e6e6] text-center">
        <p class="text-[11px] text-[#615d59]">
          Sign in with your authorized Google Account. Developer role (<code class="font-mono text-[#000000]">role = 'developer'</code>) is required to access back-office tools.
        </p>
      </div>

      <!-- Advanced JWT Token Input Toggle -->
      <div class="pt-2 text-center">
        <button
          onclick={() => showAdvanced = !showAdvanced}
          class="text-[11px] text-[#615d59] hover:text-[#000000] underline"
        >
          {showAdvanced ? 'Hide direct token input' : 'Advanced: Paste developer JWT access token directly'}
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
