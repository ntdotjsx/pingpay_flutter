import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/animations/animation_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../payments/providers/payment_providers.dart';

class MainShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ถ้า outstandingDebtsCountProvider เป็น Provider<int> ธรรมดา
    // ให้เปลี่ยนบรรทัดนี้กลับเป็น:
    // final debtsCount = ref.watch(outstandingDebtsCountProvider);
    final debtsCount = ref.watch(outstandingDebtsCountProvider);

    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : AppColors.dividerSoft,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context,
                  index: 0,
                  currentIndex: currentIndex,
                  icon: Icons.home_rounded,
                  label: 'หน้าหลัก',
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  index: 1,
                  currentIndex: currentIndex,
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'การเงิน',
                  badgeCount: debtsCount,
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  index: 2,
                  currentIndex: currentIndex,
                  icon: Icons.receipt_long_outlined,
                  label: 'รายการ',
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  index: 3,
                  currentIndex: currentIndex,
                  icon: Icons.card_giftcard_outlined,
                  label: 'แลกคอยน์',
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  index: 4,
                  currentIndex: currentIndex,
                  icon: Icons.person_outline_rounded,
                  label: 'ฉัน',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required int currentIndex,
    required IconData icon,
    required String label,
    required bool isDark,
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;
    final color = isSelected
        ? (isDark ? AppColors.primaryOnDark : AppColors.primary)
        : AppColors.inkMuted48;

    return GestureDetector(
      onTap: () {
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.1 : 1.0,
            duration: AppAnimation.normal,
            curve: AppAnimation.standard,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: AppAnimation.normal,
                  curve: AppAnimation.standard,
                  child: Icon(icon, size: 24, color: color),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: const ShapeDecoration(
                        color: AppColors.error,
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 6, cornerSmoothing: 1.0),
                          ),
                        ),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
