<script lang="ts">
  import {
    getRewardItems,
    createRewardItem,
    updateRewardItem,
    deleteRewardItem,
    getRewardRedemptions,
    updateRedemptionStatus,
  } from '$lib/api/client';
  import { onMount } from 'svelte';
  import { TableHandler } from '$lib/components/datatable';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import ThSort from '$lib/components/datatable/ThSort.svelte';
  import SearchInput from '$lib/components/datatable/SearchInput.svelte';
  import DataTablePagination from '$lib/components/datatable/DataTablePagination.svelte';
  import ExportCsvButton from '$lib/components/datatable/ExportCsvButton.svelte';
  import LoadingLottie from '$lib/components/LoadingLottie.svelte';
  import Icon from '$lib/components/Icon.svelte';

  let activeTab = $state<'catalog' | 'redemptions'>('catalog');

  // ── Catalog State ──
  let items = $state<any[]>([]);
  let loadingItems = $state(true);
  let catalogError = $state('');
  let itemModal = $state<{
    show: boolean;
    isEdit: boolean;
    id?: string;
    title: string;
    description: string;
    pointsCost: number;
    category: string;
    imageUrl: string;
    inStock: number;
    isActive: boolean;
  }>({
    show: false,
    isEdit: false,
    title: '',
    description: '',
    pointsCost: 50,
    category: 'physical',
    imageUrl: '',
    inStock: 100,
    isActive: true,
  });

  // ── Redemptions State ──
  let rawRedemptions = $state<any[]>([]);
  let redemptionsTotal = $state(0);
  let loadingRedemptions = $state(false);
  let redemptionsError = $state('');
  let redemptionsFilter = $state({
    status: '',
    limit: 100,
  });
  const redemptionsTable = new TableHandler<any>([], { rowsPerPage: 20 });

  let deliveryModal = $state<{
    show: boolean;
    redemptionId: string;
    currentStatus: string;
    status: 'pending_delivery' | 'shipped' | 'delivered' | 'cancelled';
    trackingNumber: string;
    recipientName: string;
  }>({
    show: false,
    redemptionId: '',
    currentStatus: '',
    status: 'pending_delivery',
    trackingNumber: '',
    recipientName: '',
  });

  async function loadCatalog() {
    loadingItems = true;
    catalogError = '';
    try {
      const res = await getRewardItems();
      items = res.data.items;
    } catch (e: any) {
      catalogError = e.message;
    } finally {
      loadingItems = false;
    }
  }

  async function loadRedemptions() {
    loadingRedemptions = true;
    redemptionsError = '';
    try {
      const res = await getRewardRedemptions(redemptionsFilter);
      rawRedemptions = res.data.rows;
      redemptionsTotal = res.data.total;
      redemptionsTable.setRows(rawRedemptions);
    } catch (e: any) {
      redemptionsError = e.message;
    } finally {
      loadingRedemptions = false;
    }
  }

  onMount(() => {
    loadCatalog();
    loadRedemptions();
  });

  function openCreateItemModal() {
    itemModal = {
      show: true,
      isEdit: false,
      title: '',
      description: '',
      pointsCost: 50,
      category: 'physical',
      imageUrl: '',
      inStock: 100,
      isActive: true,
    };
  }

  function openEditItemModal(item: any) {
    itemModal = {
      show: true,
      isEdit: true,
      id: item.id,
      title: item.title,
      description: item.description || '',
      pointsCost: item.pointsCost,
      category: item.category || 'physical',
      imageUrl: item.imageUrl || '',
      inStock: item.inStock,
      isActive: item.isActive,
    };
  }

  async function saveItem() {
    try {
      if (itemModal.isEdit && itemModal.id) {
        await updateRewardItem(itemModal.id, {
          title: itemModal.title,
          description: itemModal.description,
          pointsCost: itemModal.pointsCost,
          category: itemModal.category,
          imageUrl: itemModal.imageUrl,
          inStock: itemModal.inStock,
          isActive: itemModal.isActive,
        });
      } else {
        await createRewardItem({
          title: itemModal.title,
          description: itemModal.description,
          pointsCost: itemModal.pointsCost,
          category: itemModal.category,
          imageUrl: itemModal.imageUrl,
          inStock: itemModal.inStock,
          isActive: itemModal.isActive,
        });
      }
      itemModal.show = false;
      loadCatalog();
    } catch (e: any) {
      catalogError = e.message;
    }
  }

  async function removeItem(id: string) {
    if (!confirm('Are you sure you want to delete this reward item?')) return;
    try {
      await deleteRewardItem(id);
      loadCatalog();
    } catch (e: any) {
      catalogError = e.message;
    }
  }

  function openDeliveryModal(redemption: any) {
    deliveryModal = {
      show: true,
      redemptionId: redemption.id,
      currentStatus: redemption.status,
      status: redemption.status,
      trackingNumber: redemption.trackingNumber || '',
      recipientName: redemption.recipientName,
    };
  }

  async function saveDeliveryStatus() {
    try {
      await updateRedemptionStatus(
        deliveryModal.redemptionId,
        deliveryModal.status,
        deliveryModal.trackingNumber
      );
      deliveryModal.show = false;
      loadRedemptions();
    } catch (e: any) {
      redemptionsError = e.message;
    }
  }
</script>

<div>
  <div class="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-[#000000]">Rewards Store Management</h1>
      <p class="mt-0.5 text-xs text-[#615d59]">Manage redeemable rewards catalog, stock inventory, and user redemption fulfillment orders.</p>
    </div>
    {#if activeTab === 'catalog'}
      <button
        onclick={openCreateItemModal}
        class="inline-flex items-center gap-1.5 rounded-md bg-[#0075de] px-3.5 py-2 text-xs font-semibold text-white shadow-sm hover:bg-[#005bab] transition-colors"
      >
        <Icon name="plus" class="h-3.5 w-3.5" />
        <span>Add Reward Item</span>
      </button>
    {:else}
      <ExportCsvButton table={redemptionsTable} filename="rewards-redemptions-export.csv" />
    {/if}
  </div>

  <!-- Tab Switcher -->
  <div class="mb-6 flex gap-2 border-b border-[#e6e6e6] pb-2">
    <button
      onclick={() => activeTab = 'catalog'}
      class="rounded-md px-3.5 py-1.5 text-xs font-semibold transition-colors {activeTab === 'catalog' ? 'bg-[#e8f3fc] text-[#0075de]' : 'text-[#615d59] hover:bg-[#f6f5f4]'}"
    >
      Catalog Items ({items.length})
    </button>
    <button
      onclick={() => activeTab = 'redemptions'}
      class="rounded-md px-3.5 py-1.5 text-xs font-semibold transition-colors {activeTab === 'redemptions' ? 'bg-[#e8f3fc] text-[#0075de]' : 'text-[#615d59] hover:bg-[#f6f5f4]'}"
    >
      Redemptions Orders ({redemptionsTotal})
    </button>
  </div>

  <!-- Tab 1: Catalog Items -->
  {#if activeTab === 'catalog'}
    {#if loadingItems}
      <div class="rounded-xl border border-[#e6e6e6] bg-white p-6 shadow-sm">
        <LoadingLottie text="Loading reward catalog..." size={160} />
      </div>
    {:else if catalogError}
      <div class="rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030]">{catalogError}</div>
    {:else}
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {#each items as item}
          <div class="rounded-xl border border-[#e6e6e6] bg-white p-5 shadow-sm hover:border-[#0075de] transition-colors flex flex-col justify-between">
            <div>
              <div class="flex items-start justify-between gap-3 mb-3">
                <div class="flex items-center gap-3">
                  {#if item.imageUrl}
                    <img src={item.imageUrl} alt="" class="h-12 w-12 rounded-lg object-cover border border-[#e6e6e6]" />
                  {:else}
                    <div class="flex h-12 w-12 items-center justify-center rounded-lg bg-[#e8f3fc] text-[#0075de]">
                      <Icon name="rewards" class="h-6 w-6" />
                    </div>
                  {/if}
                  <div>
                    <h3 class="font-bold text-sm text-[#000000]">{item.title}</h3>
                    <span class="inline-block rounded-full bg-[#f6f5f4] px-2 py-0.5 text-[10px] font-mono text-[#615d59] uppercase">{item.category || 'physical'}</span>
                  </div>
                </div>
                <StatusBadge status={item.isActive ? 'active' : 'cancelled'} />
              </div>

              {#if item.description}
                <p class="text-xs text-[#615d59] line-clamp-2 mb-3">{item.description}</p>
              {/if}

              <div class="grid grid-cols-2 gap-2 rounded-lg bg-[#fbfbfa] p-2.5 border border-[#f6f5f4] text-xs">
                <div>
                  <span class="text-[10px] text-[#615d59] uppercase tracking-wider block">Points Cost</span>
                  <span class="font-bold text-[#0075de]">{item.pointsCost} pts</span>
                </div>
                <div>
                  <span class="text-[10px] text-[#615d59] uppercase tracking-wider block">In Stock</span>
                  <span class="font-semibold {item.inStock > 0 ? 'text-[#1aae39]' : 'text-[#c53030]'}">{item.inStock} units</span>
                </div>
              </div>
            </div>

            <div class="mt-4 flex items-center justify-end gap-2 border-t border-[#e6e6e6] pt-3">
              <button
                onclick={() => openEditItemModal(item)}
                class="rounded-md border border-[#e6e6e6] bg-white px-2.5 py-1 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
              >
                Edit
              </button>
              <button
                onclick={() => removeItem(item.id)}
                class="rounded-md border border-[#fde8e8] bg-white px-2.5 py-1 text-xs font-medium text-[#c53030] hover:bg-[#fde8e8] transition-colors"
              >
                Delete
              </button>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  {/if}

  <!-- Tab 2: Redemptions Orders -->
  {#if activeTab === 'redemptions'}
    {#if redemptionsError}
      <div class="mb-4 rounded-md bg-[#fde8e8] border border-[#fde8e8] p-3 text-xs text-[#c53030] flex items-center justify-between">
        <span>{redemptionsError}</span>
        <button onclick={() => redemptionsError = ''} class="text-[#c53030] font-bold">&times;</button>
      </div>
    {/if}

    <!-- Unified DataTable Card -->
    <div class="overflow-hidden rounded-xl border border-[#e6e6e6] bg-white shadow-sm">
      <!-- Integrated Header & Filter Toolbar -->
      <div class="flex flex-col gap-3 border-b border-[#e6e6e6] bg-[#fbfbfa] p-4 lg:flex-row lg:items-center lg:justify-between">
        <SearchInput table={redemptionsTable} placeholder="Search recipient, item, phone..." class="w-full lg:w-72" />

        <!-- Integrated Filters -->
        <div class="flex flex-wrap items-center gap-2.5">
          <div class="flex items-center gap-1.5">
            <span class="text-[11px] font-medium text-[#615d59]">Status:</span>
            <select
              bind:value={redemptionsFilter.status}
              onchange={loadRedemptions}
              class="rounded-[4px] border border-[#e6e6e6] bg-white px-2 py-1 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none"
            >
              <option value="">All Statuses</option>
              <option value="pending_delivery">Pending Delivery</option>
              <option value="shipped">Shipped</option>
              <option value="delivered">Delivered</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>

          <button
            onclick={loadRedemptions}
            class="inline-flex h-7 items-center justify-center rounded border border-[#e6e6e6] bg-white px-2.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4] transition-colors"
          >
            Refresh
          </button>

          <ExportCsvButton table={redemptionsTable} filename="rewards-redemptions-export.csv" />
        </div>
      </div>

      {#if loadingRedemptions}
        <div class="p-8">
          <LoadingLottie text="Loading redemptions..." size={160} />
        </div>
      {:else if redemptionsError}
        <div class="p-4 text-xs text-[#c53030]">{redemptionsError}</div>
      {:else}
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y border-[#e6e6e6] text-left text-xs">
            <thead class="bg-[#fbfbfa] text-[#615d59]">
              <tr>
                <ThSort table={redemptionsTable} field="createdAt">Date</ThSort>
                <ThSort table={redemptionsTable} field="recipientName">Recipient</ThSort>
                <ThSort table={redemptionsTable} field="phoneNumber">Phone</ThSort>
                <ThSort table={redemptionsTable} field="rewardItem.title">Reward Item</ThSort>
                <ThSort table={redemptionsTable} field="pointsSpent">Points</ThSort>
                <th class="px-4 py-3 font-semibold">Shipping Address</th>
                <ThSort table={redemptionsTable} field="trackingNumber">Tracking No.</ThSort>
                <ThSort table={redemptionsTable} field="status">Status</ThSort>
                <th class="px-4 py-3 font-semibold text-right">Action</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-[#f6f5f4]">
              {#each redemptionsTable.rows as row}
                <tr class="hover:bg-[#fbfbfa] transition-colors">
                  <td class="px-4 py-3 font-mono text-[11px] text-[#615d59]">{new Date(row.createdAt).toLocaleDateString()}</td>
                  <td class="px-4 py-3 font-medium text-[#000000]">{row.recipientName}</td>
                  <td class="px-4 py-3 font-mono text-[11px] text-[#31302e]">{row.phoneNumber}</td>
                  <td class="px-4 py-3 font-semibold text-[#0075de]">{row.rewardItem?.title || '-'}</td>
                  <td class="px-4 py-3 font-bold text-[#000000]">{row.pointsSpent} pts</td>
                  <td class="px-4 py-3 text-[#615d59] max-w-[180px] truncate" title={row.shippingAddress}>{row.shippingAddress}</td>
                  <td class="px-4 py-3 font-mono text-[11px] text-[#31302e]">{row.trackingNumber || '-'}</td>
                  <td class="px-4 py-3"><StatusBadge status={row.status} /></td>
                  <td class="px-4 py-3 text-right">
                    <button
                      onclick={() => openDeliveryModal(row)}
                      class="rounded-md bg-[#e8f3fc] px-2.5 py-1 text-xs font-semibold text-[#0075de] hover:bg-[#d0e7fa] transition-colors"
                    >
                      Update
                    </button>
                  </td>
                </tr>
              {:else}
                <tr>
                  <td colspan="9" class="p-8 text-center text-xs text-[#615d59]">No redemptions found.</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
        <DataTablePagination table={redemptionsTable} />
      {/if}
    </div>
  {/if}
</div>

<!-- Item Modal (Create/Edit) -->
{#if itemModal.show}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
    <div class="w-full max-w-lg rounded-xl bg-white p-6 shadow-xl border border-[#e6e6e6]">
      <h3 class="mb-4 text-base font-bold text-[#000000]">{itemModal.isEdit ? 'Edit Reward Item' : 'Add Reward Item'}</h3>
      <div class="space-y-3">
        <div>
          <label for="item-title" class="block text-[11px] font-medium text-[#615d59]">Item Title</label>
          <input id="item-title" type="text" bind:value={itemModal.title} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none" placeholder="e.g. PingPay Premium T-Shirt" />
        </div>
        <div>
          <label for="item-desc" class="block text-[11px] font-medium text-[#615d59]">Description</label>
          <textarea id="item-desc" bind:value={itemModal.description} rows={2} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none" placeholder="Item details..."></textarea>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label for="item-cost" class="block text-[11px] font-medium text-[#615d59]">Points Cost</label>
            <input id="item-cost" type="number" bind:value={itemModal.pointsCost} min={1} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none" />
          </div>
          <div>
            <label for="item-stock" class="block text-[11px] font-medium text-[#615d59]">In Stock</label>
            <input id="item-stock" type="number" bind:value={itemModal.inStock} min={0} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label for="item-category" class="block text-[11px] font-medium text-[#615d59]">Category</label>
            <select id="item-category" bind:value={itemModal.category} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none">
              <option value="physical">Physical Gift</option>
              <option value="voucher">Digital Voucher</option>
              <option value="gadget">Tech Gadget</option>
            </select>
          </div>
          <div class="flex items-center gap-2 pt-5">
            <input id="item-active" type="checkbox" bind:checked={itemModal.isActive} class="rounded border-[#e6e6e6] text-[#0075de]" />
            <label for="item-active" class="text-xs font-medium text-[#000000]">Active for Redemption</label>
          </div>
        </div>
        <div>
          <label for="item-image" class="block text-[11px] font-medium text-[#615d59]">Image URL (optional)</label>
          <input id="item-image" type="text" bind:value={itemModal.imageUrl} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none" placeholder="https://..." />
        </div>
      </div>
      <div class="mt-6 flex justify-end gap-2 border-t border-[#e6e6e6] pt-3">
        <button onclick={() => itemModal.show = false} class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4]">Cancel</button>
        <button onclick={saveItem} disabled={!itemModal.title || itemModal.pointsCost <= 0} class="rounded-md bg-[#0075de] px-4 py-1.5 text-xs font-semibold text-white hover:bg-[#005bab] disabled:opacity-50">Save Item</button>
      </div>
    </div>
  </div>
{/if}

<!-- Delivery Status Modal -->
{#if deliveryModal.show}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
    <div class="w-full max-w-md rounded-xl bg-white p-6 shadow-xl border border-[#e6e6e6]">
      <h3 class="mb-2 text-base font-bold text-[#000000]">Update Delivery Status</h3>
      <p class="text-xs text-[#615d59] mb-4">Recipient: <strong class="text-[#000000]">{deliveryModal.recipientName}</strong></p>
      <div class="space-y-3">
        <div>
          <label for="delivery-status" class="block text-[11px] font-medium text-[#615d59]">Fulfillment Status</label>
          <select id="delivery-status" bind:value={deliveryModal.status} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] px-2.5 py-1.5 text-xs text-[#000000] focus:border-[#0075de] focus:outline-none">
            <option value="pending_delivery">Pending Delivery</option>
            <option value="shipped">Shipped</option>
            <option value="delivered">Delivered</option>
            <option value="cancelled">Cancelled</option>
          </select>
        </div>
        <div>
          <label for="delivery-tracking" class="block text-[11px] font-medium text-[#615d59]">Tracking Number (e.g. Flash, Kerry, EMS)</label>
          <input id="delivery-tracking" type="text" bind:value={deliveryModal.trackingNumber} class="mt-1 block w-full rounded-[4px] border border-[#e6e6e6] px-2.5 py-1.5 text-xs font-mono text-[#000000] focus:border-[#0075de] focus:outline-none" placeholder="e.g. TH0123456789" />
        </div>
      </div>
      <div class="mt-6 flex justify-end gap-2 border-t border-[#e6e6e6] pt-3">
        <button onclick={() => deliveryModal.show = false} class="rounded-md border border-[#e6e6e6] bg-white px-3 py-1.5 text-xs font-medium text-[#31302e] hover:bg-[#f6f5f4]">Cancel</button>
        <button onclick={saveDeliveryStatus} class="rounded-md bg-[#0075de] px-4 py-1.5 text-xs font-semibold text-white hover:bg-[#005bab]">Update Status</button>
      </div>
    </div>
  </div>
{/if}
