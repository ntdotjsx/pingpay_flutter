import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../auth/providers/auth_provider.dart';
import '../../friends/providers/friends_provider.dart';
import '../../payments/services/debt_age_calculator.dart';
import '../models/bill_models.dart';
import '../providers/bill_provider.dart';

enum MyBillsFilter {
  all,
  unpaid,
  partiallyPaid,
  paid,
}

final myBillsFilterProvider = StateProvider<MyBillsFilter>((ref) => MyBillsFilter.all);

class MyBillsScreen extends ConsumerWidget {
  const MyBillsScreen({super.key});

  Future<void> _handleCreateBill(BuildContext context, WidgetRef ref) async {
    final friendsAsync = ref.read(friendsListProvider);
    final friends = friendsAsync.valueOrNull ?? await ref.read(friendsRepositoryProvider).getFriends();
    if (friends.isEmpty && context.mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: ShapeDecoration(
            color: isDark ? AppColors.surfaceBlack : Colors.white,
            shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.vertical(
                top: SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.7),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_off_rounded,
                  color: Color(0xFFFF5000),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ยังไม่มีเพื่อนในระบบ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'คุณต้องมีเพื่อนในระบบอย่างน้อย 1 คนก่อน จึงจะสามารถสร้างบิลหรือสแกนบิล OCR ได้',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push('/friends/scan');
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text(
                    'สแกน QR Code เพิ่มเพื่อน',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (context.mounted) {
      context.push('/bills/create');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(myBillsProvider);
    final selectedFilter = ref.watch(myBillsFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text(
          'บิลของฉัน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'รีเฟรช',
            onPressed: () => ref.invalidate(myBillsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleCreateBill(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'สร้างบิลใหม่',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      body: billsAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            AppSkeleton(width: double.infinity, height: 110, cornerRadius: 22, margin: EdgeInsets.only(bottom: 16)),
            AppSkeleton(width: double.infinity, height: 44, cornerRadius: 14, margin: EdgeInsets.only(bottom: 16)),
            DebtCardSkeleton(),
            DebtCardSkeleton(),
            DebtCardSkeleton(),
          ],
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded, size: 42, color: AppColors.error),
                ),
                const SizedBox(height: 16),
                Text(
                  'โหลดรายการบิลไม่สำเร็จ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.inkMuted48),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(myBillsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('ลองใหม่อีกครั้ง'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (allBills) {
          final currentUserId = ref.read(authStateProvider).user?.id;
          final bills = allBills.where((b) => b.ownerId == currentUserId).toList();
          final totalBillAmount = bills.fold(0.0, (acc, b) => acc + b.totalAmount);
          final uniqueDebtorIds = <String>{};
          for (final b in bills) {
            for (final item in b.items) {
              if (item.debtorId.isNotEmpty) {
                uniqueDebtorIds.add(item.debtorId);
              }
            }
          }
          final totalDebtors = uniqueDebtorIds.length;
          final unpaidBillsCount = bills.where((b) => b.status != 'paid' && b.status != 'cancelled').length;

          // Filter bills
          final filteredBills = bills.where((b) {
            switch (selectedFilter) {
              case MyBillsFilter.unpaid:
                return b.status == 'unpaid';
              case MyBillsFilter.partiallyPaid:
                return b.status == 'partially_paid';
              case MyBillsFilter.paid:
                return b.status == 'paid';
              case MyBillsFilter.all:
                return true;
            }
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(myBillsProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // Top Summary Metrics Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: ShapeDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [AppColors.surfaceTile1, AppColors.surfaceTile2]
                              : [const Color(0xFFFF5000), const Color(0xFFFF6A00)],
                        ),
                        shadows: [
                          BoxShadow(
                            color: const Color(0xFFFF5000).withValues(alpha: isDark ? 0.05 : 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 22, cornerSmoothing: 1.0),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'ยอดรวมบิลทั้งหมดที่สร้าง',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${bills.length} บิล',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '฿${totalBillAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMetricItem(
                                  label: 'รอดำเนินการ',
                                  value: '$unpaidBillsCount บิล',
                                  icon: Icons.pending_actions_rounded,
                                ),
                                Container(
                                  width: 1,
                                  height: 20,
                                  color: Colors.white24,
                                ),
                                _buildMetricItem(
                                  label: 'ผู้ร่วมจ่ายทั้งหมด',
                                  value: '$totalDebtors คน',
                                  icon: Icons.people_alt_rounded,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Filter Chips Bar
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          ref: ref,
                          label: 'ทั้งหมด (${bills.length})',
                          filter: MyBillsFilter.all,
                          current: selectedFilter,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          ref: ref,
                          label: 'ยังไม่ชำระ (${bills.where((b) => b.status == 'unpaid').length})',
                          filter: MyBillsFilter.unpaid,
                          current: selectedFilter,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          ref: ref,
                          label: 'ชำระบางส่วน (${bills.where((b) => b.status == 'partially_paid').length})',
                          filter: MyBillsFilter.partiallyPaid,
                          current: selectedFilter,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          ref: ref,
                          label: 'ครบแล้ว (${bills.where((b) => b.status == 'paid').length})',
                          filter: MyBillsFilter.paid,
                          current: selectedFilter,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bills List
                if (filteredBills.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_off_rounded,
                              size: 44,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'ไม่พบบิลในหมวดหมู่นี้',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final bill = filteredBills[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildBillCard(context, bill, isDark),
                          );
                        },
                        childCount: filteredBills.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required WidgetRef ref,
    required String label,
    required MyBillsFilter filter,
    required MyBillsFilter current,
    required bool isDark,
  }) {
    final isSelected = filter == current;
    return GestureDetector(
      onTap: () => ref.read(myBillsFilterProvider.notifier).state = filter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.surfaceTile2 : AppColors.canvas),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white10 : AppColors.hairline),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.bodyMuted : AppColors.inkMuted80),
          ),
        ),
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, BillModel bill, bool isDark) {
    final dateStr = bill.createdAt != null
        ? DebtAgeCalculator.formatThaiDate(bill.createdAt!)
        : 'วันนี้';

    return Container(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : AppColors.hairline,
            width: 1,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 20, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/bills/${bill.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Bill Icon & Title + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: ShapeDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 12, cornerSmoothing: 1.0),
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (bill.title != null && bill.title!.trim().isNotEmpty)
                                ? bill.title!
                                : 'บิลค่าใช้จ่าย',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (bill.items.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '•  ${bill.items.length} ผู้ร่วมหาร',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(bill.status),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.white10 : AppColors.dividerSoft,
                ),
                const SizedBox(height: 12),

                // Bottom Row: Debtor Avatars Stack + Amount & Arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Debtor avatars preview
                    if (bill.items.isNotEmpty)
                      _buildDebtorsPreview(bill.items, isDark)
                    else
                      Text(
                        'ไม่มีผู้หารเพิ่มเติม',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),

                    // Amount display
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              bill.totalOutstandingAmount > 0
                                  ? 'คงค้างรอเก็บ (บิล ฿${bill.totalAmount.toStringAsFixed(0)})'
                                  : 'ยอดรวมบิล',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                            Text(
                              bill.totalOutstandingAmount > 0
                                  ? '฿${bill.totalOutstandingAmount.toStringAsFixed(2)}'
                                  : '฿${bill.totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: bill.totalOutstandingAmount > 0
                                    ? AppColors.primary
                                    : AppColors.success,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebtorsPreview(List<BillItemParticipantModel> items, bool isDark) {
    const maxVisible = 4;
    final visibleItems = items.take(maxVisible).toList();
    final remaining = items.length - maxVisible;

    return Row(
      children: [
        SizedBox(
          height: 28,
          width: (visibleItems.length * 20.0) + 12,
          child: Stack(
            children: List.generate(visibleItems.length, (idx) {
              final participant = visibleItems[idx];
              final debtor = participant.debtor;
              final name = debtor?.displayName ?? 'เพื่อน';
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

              return Positioned(
                left: idx * 18.0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.15),
                    border: Border.all(
                      color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: debtor?.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            debtor!.avatarUrl!,
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              );
            }),
          ),
        ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '+$remaining',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'paid':
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        label = 'ชำระครบแล้ว';
        icon = Icons.check_circle_rounded;
        break;
      case 'partially_paid':
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
        label = 'ชำระบางส่วน';
        icon = Icons.hourglass_top_rounded;
        break;
      case 'cancelled':
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        label = 'ยกเลิกแล้ว';
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = AppColors.primary.withValues(alpha: 0.12);
        fg = AppColors.primary;
        label = 'รอชำระ';
        icon = Icons.schedule_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
