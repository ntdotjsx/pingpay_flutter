import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/payment_providers.dart';
import 'widgets/friend_receivable_detail_bottom_sheet.dart';
import 'widgets/receivable_friend_card.dart';
import 'widgets/receivable_summary_card.dart';

class ReceivablesScreen extends StatelessWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: ReceivablesScreenBody());
  }
}

class ReceivablesScreenBody extends ConsumerWidget {
  const ReceivablesScreenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(userReceivablesProvider);
    final notifier = ref.read(userReceivablesProvider.notifier);
    final filteredFriends = state.filteredFriends;

    return RefreshIndicator(
      onRefresh: () => notifier.loadReceivables(showLoading: false),
      color: AppColors.primary,
      child: state.isLoading
          ? _buildSkeletonLoading(isDark)
          : state.errorMessage != null
          ? _buildErrorState(context, state.errorMessage!, notifier, isDark)
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // 1. Summary Header Card
                ReceivableSummaryCard(
                  debtorCount: state.summary.debtorCount,
                  totalOutstandingAmount: state.summary.totalOutstandingAmount,
                  currency: state.summary.currency,
                  onRefresh: () => notifier.loadReceivables(),
                ),

                const SizedBox(height: 16),

                // 2. Search & Sort Row
                _buildSearchAndSortBar(context, ref, isDark, state),

                const SizedBox(height: 12),

                // 3. Filter Chips Bar
                _buildFiltersBar(isDark, state, notifier),

                const SizedBox(height: 16),

                // 4. Section Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'เพื่อนที่ยังค้างชำระ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      ),
                    ),
                    Text(
                      '${filteredFriends.length} คน',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted48,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 5. Friends List / Empty State
                if (filteredFriends.isEmpty)
                  _buildEmptyState(isDark)
                else
                  ...filteredFriends.map(
                    (friend) => ReceivableFriendCard(
                      friend: friend,
                      onTap: () => FriendReceivableDetailBottomSheet.show(
                        context,
                        friend,
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSearchAndSortBar(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    UserReceivablesState state,
  ) {
    final notifier = ref.read(userReceivablesProvider.notifier);

    return Row(
      children: [
        // Search Bar
        Expanded(
          child: Container(
            height: 44,
            decoration: ShapeDecoration(
              color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
              shape: SmoothRectangleBorder(
                side: BorderSide(
                  color: isDark ? Colors.white10 : AppColors.hairline,
                ),
                borderRadius: const SmoothBorderRadius.all(
                  SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.inkMuted48,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (val) => notifier.setSearchQuery(val),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'ค้นหาชื่อเพื่อน หรือรหัส...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMuted48,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (state.searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => notifier.setSearchQuery(''),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.inkMuted48,
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Sort Button Popup
        PopupMenuButton<ReceivableSortOption>(
          initialValue: state.currentSort,
          onSelected: (sort) => notifier.setSort(sort),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: ReceivableSortOption.mostOverdue,
              child: Text('ค้างนานที่สุด (Default)'),
            ),
            const PopupMenuItem(
              value: ReceivableSortOption.highestAmount,
              child: Text('ยอดค้างสูงสุด'),
            ),
            const PopupMenuItem(
              value: ReceivableSortOption.lowestAmount,
              child: Text('ยอดค้างต่ำสุด'),
            ),
            const PopupMenuItem(
              value: ReceivableSortOption.name,
              child: Text('เรียงตามชื่อ'),
            ),
          ],
          child: Container(
            height: 44,
            width: 44,
            decoration: ShapeDecoration(
              color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
              shape: SmoothRectangleBorder(
                side: BorderSide(
                  color: isDark ? Colors.white10 : AppColors.hairline,
                ),
                borderRadius: const SmoothBorderRadius.all(
                  SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
                ),
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.sort_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersBar(
    bool isDark,
    UserReceivablesState state,
    UserReceivablesNotifier notifier,
  ) {
    final filters = [
      {'key': ReceivableFilter.all, 'label': 'ทั้งหมด'},
      {'key': ReceivableFilter.overdue, 'label': 'ค้างเกิน 7 วัน'},
      {'key': ReceivableFilter.partiallyPaid, 'label': 'ชำระบางส่วน'},
      {'key': ReceivableFilter.pendingConfirmation, 'label': 'รอยืนยันสลิป'},
      {'key': ReceivableFilter.history, 'label': 'ชำระครบแล้ว'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final filterType = f['key'] as ReceivableFilter;
          final isSelected = state.currentFilter == filterType;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label'] as String),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) notifier.setFilter(filterType);
              },
              selectedColor: AppColors.primary,
              backgroundColor: isDark
                  ? AppColors.surfaceTile1
                  : AppColors.canvas,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.bodyMuted : AppColors.ink),
              ),
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white10 : AppColors.hairline),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ไม่มีเพื่อนค้างชำระ',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ตอนนี้ยังไม่มีรายการที่เพื่อนต้องชำระให้คุณ',
            style: TextStyle(fontSize: 13, color: AppColors.inkMuted48),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String error,
    UserReceivablesNotifier notifier,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'ไม่สามารถโหลดข้อมูลได้',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted48),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => notifier.loadReceivables(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceTile1 : Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceTile1 : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (i) => Container(
            height: 110,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceTile1 : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }
}
