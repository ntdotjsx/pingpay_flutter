import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/animations/animated_list_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../models/payment_models.dart';
import '../providers/payment_providers.dart';
import 'widgets/friend_receivable_detail_bottom_sheet.dart';
import 'widgets/receivable_friend_card.dart';

class ReceivablesScreen extends StatelessWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: ReceivablesContentSection(),
      ),
    );
  }
}

class ReceivablesContentSection extends ConsumerWidget {
  const ReceivablesContentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(userReceivablesProvider);
    final notifier = ref.read(userReceivablesProvider.notifier);
    final filteredFriends = state.filteredFriends;

    if (state.isLoading) {
      return _buildSkeletonLoading(isDark);
    }
    if (state.errorMessage != null) {
      return _buildErrorState(context, state.errorMessage!, notifier, isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),

        // 1. Search & Sort Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildSearchAndSortBar(context, ref, isDark, state),
        ),

        const SizedBox(height: 10),

        // 2. Filter Chips Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildFiltersBar(isDark, state, notifier),
        ),

        const SizedBox(height: 14),

        // 3. Section Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'เพื่อนที่ยังค้างชำระ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              Text(
                '${filteredFriends.length} คน',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 4. Friends List / Empty State
        if (filteredFriends.isEmpty)
          _buildEmptyState(isDark)
        else
          Column(
            children: filteredFriends.asMap().entries.map((entry) {
              return AnimatedListItem(
                index: entry.key,
                child: ReceivableFriendCard(
                  friend: entry.value,
                  onTap: () => FriendReceivableDetailBottomSheet.show(
                    context,
                    entry.value,
                  ),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 36),
      ],
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
        // Search TextField
        Expanded(
          child: Container(
            height: 38,
            decoration: ShapeDecoration(
              color: isDark ? AppColors.surfaceTile1 : const Color(0xFFF3F4F6),
              shape: SmoothRectangleBorder(
                side: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                  width: 0.8,
                ),
                borderRadius: const SmoothBorderRadius.all(
                  SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 17,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    onChanged: (val) => notifier.setSearchQuery(val),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ค้นหาเพื่อนที่ติดเงิน...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (state.searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => notifier.setSearchQuery(''),
                    child: Icon(
                      Icons.cancel_rounded,
                      size: 15,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Sort Button
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showSortOptionsSheet(context, ref, isDark, state);
          },
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: ShapeDecoration(
              color: isDark ? AppColors.surfaceTile1 : const Color(0xFFF3F4F6),
              shape: SmoothRectangleBorder(
                side: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                  width: 0.8,
                ),
                borderRadius: const SmoothBorderRadius.all(
                  SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sort_rounded,
                  size: 16,
                  color: Color(0xFFFF5000),
                ),
                const SizedBox(width: 4),
                Text(
                  _getSortLabel(state.currentSort),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
              ],
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
      {'key': ReceivableFilter.pendingConfirmation, 'label': 'รอยืนยันสลิป'},
      {'key': ReceivableFilter.overdue, 'label': 'เกิน 7 วัน ⚠️'},
      {'key': ReceivableFilter.partiallyPaid, 'label': 'ชำระบางส่วน'},
      {'key': ReceivableFilter.history, 'label': 'ประวัติ'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final filterType = f['key'] as ReceivableFilter;
          final isSelected = state.currentFilter == filterType;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                notifier.setFilter(filterType);
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                decoration: ShapeDecoration(
                  color: isSelected
                      ? const Color(0xFFFF5000)
                      : (isDark ? AppColors.surfaceTile1 : const Color(0xFFF3F4F6)),
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                      width: 0.8,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: Text(
                  f['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.bodyMuted : AppColors.ink),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showSortOptionsSheet(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    UserReceivablesState state,
  ) {
    final notifier = ref.read(userReceivablesProvider.notifier);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceTile1 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : AppColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'จัดเรียงรายชื่อเพื่อน',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                ...ReceivableSortOption.values.map((opt) {
                  final isSelected = state.currentSort == opt;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _getSortFullLabel(opt),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFFFF5000)
                            : (isDark ? AppColors.bodyOnDark : AppColors.ink),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF5000), size: 20)
                        : null,
                    onTap: () {
                      notifier.setSort(opt);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getSortLabel(ReceivableSortOption opt) {
    switch (opt) {
      case ReceivableSortOption.mostOverdue:
        return 'เก่าสุด';
      case ReceivableSortOption.highestAmount:
        return 'ยอดมากสุด';
      case ReceivableSortOption.lowestAmount:
        return 'ยอดน้อยสุด';
      case ReceivableSortOption.name:
        return 'ชื่อ ก-ฮ';
    }
  }

  String _getSortFullLabel(ReceivableSortOption opt) {
    switch (opt) {
      case ReceivableSortOption.mostOverdue:
        return 'หนี้ที่ค้างนานที่สุดก่อน (แนะนำ)';
      case ReceivableSortOption.highestAmount:
        return 'ยอดหนี้คงค้างมากที่สุด';
      case ReceivableSortOption.lowestAmount:
        return 'ยอดหนี้คงค้างน้อยที่สุด';
      case ReceivableSortOption.name:
        return 'ชื่อเพื่อนตามลำดับอักษร (A-Z, ก-ฮ)';
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sentiment_very_satisfied_rounded,
              size: 40,
              color: Color(0xFF34C759),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'ไม่มีเพื่อนคนไหนค้างเงินคุณ 🎉',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'เมื่อคุณสร้างบิลหารเงินและมีเพื่อนติดหนี้ รายการจะปรากฏที่นี่',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          AppSkeleton(width: double.infinity, height: 38, cornerRadius: 10, margin: EdgeInsets.only(bottom: 10)),
          AppSkeleton(width: double.infinity, height: 32, cornerRadius: 10, margin: EdgeInsets.only(bottom: 14)),
          DebtCardSkeleton(),
          DebtCardSkeleton(),
          DebtCardSkeleton(),
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'ไม่สามารถโหลดข้อมูลลูกหนี้ได้',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted48),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => notifier.loadReceivables(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('ลองใหม่อีกครั้ง'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
