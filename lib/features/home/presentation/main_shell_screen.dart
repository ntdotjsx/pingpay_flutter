import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final debtsCount = ref.watch(outstandingDebtsCountProvider);
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
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
                  selectedIcon: Icons.home_rounded,
                  unselectedIcon: Icons.home_outlined,
                  label: 'หน้าหลัก',
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  index: 1,
                  currentIndex: currentIndex,
                  selectedIcon: Icons.account_balance_wallet_rounded,
                  unselectedIcon: Icons.account_balance_wallet_outlined,
                  label: 'การเงิน',
                  badgeCount: debtsCount,
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  index: 2,
                  currentIndex: currentIndex,
                  selectedIcon: Icons.receipt_long_rounded,
                  unselectedIcon: Icons.receipt_long_outlined,
                  label: 'รายการ',
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  index: 3,
                  currentIndex: currentIndex,
                  selectedIcon: Icons.card_giftcard_rounded,
                  unselectedIcon: Icons.card_giftcard_outlined,
                  label: 'แลกคอยน์',
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  index: 4,
                  currentIndex: currentIndex,
                  selectedIcon: Icons.person_rounded,
                  unselectedIcon: Icons.person_outline_rounded,
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
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required String label,
    required bool isDark,
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = isDark ? const Color(0xFFFF6A00) : const Color(0xFFFF5000);
    final inactiveColor = isDark ? AppColors.bodyMuted : AppColors.inkMuted48;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: AppAnimation.normal,
              curve: AppAnimation.standard,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      isSelected ? selectedIcon : unselectedIcon,
                      key: ValueKey<bool>(isSelected),
                      size: 24,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
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
                          color: Color(0xFFFF3B30),
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
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: -0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
