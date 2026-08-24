<script lang="ts">
  let { status, size = 'sm' }: { status: string; size?: 'sm' | 'md' } = $props();

  const colorMap: Record<string, string> = {
    active: 'bg-[#e8f8eb] text-[#138029]',
    confirmed: 'bg-[#e8f8eb] text-[#138029]',
    resolved_paid: 'bg-[#e8f8eb] text-[#138029]',
    paid: 'bg-[#e8f8eb] text-[#138029]',
    fully_paid: 'bg-[#e8f8eb] text-[#138029]',
    partially_paid: 'bg-[#e8f3fc] text-[#005bab]',
    unpaid: 'bg-[#fef2e8] text-[#b34900]',
    payment: 'bg-[#e8f8eb] text-[#138029]',
    user: 'bg-[#e8f3fc] text-[#005bab]',
    developer: 'bg-[#f5eefc] text-[#6e2fb5]',
    suspended: 'bg-[#fef2e8] text-[#b34900]',
    pending_verification: 'bg-[#fef2e8] text-[#b34900]',
    pending_owner_confirmation: 'bg-[#fef2e8] text-[#b34900]',
    under_review: 'bg-[#fef2e8] text-[#b34900]',
    open: 'bg-[#fef2e8] text-[#b34900]',
    bill_created: 'bg-[#e8f3fc] text-[#005bab]',
    bill_updated: 'bg-[#e8f3fc] text-[#005bab]',
    debt_created: 'bg-[#e8f3fc] text-[#005bab]',
    debt_adjusted: 'bg-[#e8f3fc] text-[#005bab]',
    debt_written_off: 'bg-[#f0efed] text-[#45423f]',
    bill_cancelled: 'bg-[#fde8e8] text-[#c53030]',
    banned: 'bg-[#fde8e8] text-[#c53030]',
    rejected: 'bg-[#fde8e8] text-[#c53030]',
    verification_failed: 'bg-[#fde8e8] text-[#c53030]',
    resolved_rejected: 'bg-[#fde8e8] text-[#c53030]',
    duplicate_slip: 'bg-[#fde8e8] text-[#c53030]',
    multi_account_ip: 'bg-[#fde8e8] text-[#c53030]',
    fake_slip_manipulation: 'bg-[#fde8e8] text-[#c53030]',
    frequent_writeoff: 'bg-[#faeee3] text-[#793400]',
    frequent_bill_edit: 'bg-[#fef2e8] text-[#b34900]',
    cancelled: 'bg-[#fde8e8] text-[#c53030]',
    written_off: 'bg-[#f0efed] text-[#45423f]',
    fully_written_off: 'bg-[#f0efed] text-[#45423f]',
    partially_written_off: 'bg-[#faeee3] text-[#793400]',
    write_off: 'bg-[#f0efed] text-[#45423f]',
    resolved_written_off: 'bg-[#f0efed] text-[#45423f]',
    refund: 'bg-[#faeee3] text-[#793400]',
    // Activity actions
    user_login: 'bg-[#e8f3fc] text-[#005bab]',
    user_registered: 'bg-[#f5eefc] text-[#6e2fb5]',
    pin_setup: 'bg-[#e8f3fc] text-[#005bab]',
    pin_verified: 'bg-[#e8f8eb] text-[#138029]',
    profile_updated: 'bg-[#e8f3fc] text-[#005bab]',
    debt_acknowledged: 'bg-[#e8f8eb] text-[#138029]',
    slip_uploaded: 'bg-[#fef2e8] text-[#b34900]',
    payment_confirmed: 'bg-[#e8f8eb] text-[#138029]',
    payment_rejected: 'bg-[#fde8e8] text-[#c53030]',
    friend_request_sent: 'bg-[#e8f3fc] text-[#005bab]',
    friend_request_accepted: 'bg-[#e8f8eb] text-[#138029]',
    friend_removed: 'bg-[#f0efed] text-[#45423f]',
    reward_redeemed: 'bg-[#fdf0f9] text-[#b82d8c]',
    // Rewards redemptions
    pending_delivery: 'bg-[#fef2e8] text-[#b34900]',
    shipped: 'bg-[#e8f3fc] text-[#005bab]',
    delivered: 'bg-[#e8f8eb] text-[#138029]',
    // Notifications outbox
    PENDING: 'bg-[#fef2e8] text-[#b34900]',
    PROCESSING: 'bg-[#e8f3fc] text-[#005bab]',
    SENT: 'bg-[#e8f8eb] text-[#138029]',
    FAILED: 'bg-[#fde8e8] text-[#c53030]',
    SKIPPED: 'bg-[#f0efed] text-[#45423f]',
    // Security events
    pin_brute_force: 'bg-[#fde8e8] text-[#c53030]',
    pin_brute_force_locked: 'bg-[#fde8e8] text-[#c53030]',
    pin_lockout: 'bg-[#fde8e8] text-[#c53030]',
    unauthorized_access: 'bg-[#fde8e8] text-[#c53030]',
    suspicious_login: 'bg-[#faeee3] text-[#793400]',
    pin_changed: 'bg-[#e8f3fc] text-[#005bab]',
  };

  let sizeClass = $derived(size === 'md' ? 'px-3 py-1 text-xs font-semibold' : 'px-2.5 py-0.5 text-[11px] font-medium');
  let color = $derived(colorMap[status] || 'bg-[#e8f3fc] text-[#005bab]');
</script>

<span class="inline-flex items-center rounded-full {sizeClass} {color}">
  {status ? status.replace(/_/g, ' ') : '-'}
</span>
