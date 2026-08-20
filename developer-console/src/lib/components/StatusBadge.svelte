<script lang="ts">
  let { status, size = 'sm' }: { status: string; size?: 'sm' | 'md' } = $props();

  const colorMap: Record<string, string> = {
    active: 'bg-green-100 text-green-800',
    confirmed: 'bg-green-100 text-green-800',
    resolved_paid: 'bg-green-100 text-green-800',
    paid: 'bg-green-100 text-green-800',
    payment: 'bg-green-100 text-green-800',
    user: 'bg-blue-100 text-blue-800',
    developer: 'bg-purple-100 text-purple-800',
    suspended: 'bg-yellow-100 text-yellow-800',
    pending_verification: 'bg-yellow-100 text-yellow-800',
    pending_owner_confirmation: 'bg-yellow-100 text-yellow-800',
    under_review: 'bg-yellow-100 text-yellow-800',
    open: 'bg-yellow-100 text-yellow-800',
    debt_created: 'bg-blue-100 text-blue-800',
    debt_adjusted: 'bg-indigo-100 text-indigo-800',
    banned: 'bg-red-100 text-red-800',
    rejected: 'bg-red-100 text-red-800',
    verification_failed: 'bg-red-100 text-red-800',
    resolved_rejected: 'bg-red-100 text-red-800',
    duplicate_slip: 'bg-red-100 text-red-800',
    multi_account_ip: 'bg-red-100 text-red-800',
    frequent_writeoff: 'bg-orange-100 text-orange-800',
    frequent_bill_edit: 'bg-yellow-100 text-yellow-800',
    fake_slip_manipulation: 'bg-red-100 text-red-800',
    cancelled: 'bg-gray-100 text-gray-800',
    written_off: 'bg-gray-100 text-gray-800',
    write_off: 'bg-gray-100 text-gray-800',
    resolved_written_off: 'bg-gray-100 text-gray-800',
    refund: 'bg-orange-100 text-orange-800',
  };

  let sizeClass = $derived(size === 'md' ? 'px-3 py-1 text-sm' : 'px-2 py-0.5 text-xs');
  let color = $derived(colorMap[status] || 'bg-blue-100 text-blue-800');
</script>

<span class="inline-flex items-center rounded-full font-medium {sizeClass} {color}">
  {status ? status.replace(/_/g, ' ') : '-'}
</span>
