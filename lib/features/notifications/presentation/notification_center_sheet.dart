import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../payments/models/payment_models.dart';
import '../../payments/presentation/widgets/debt_acknowledgement_detail_sheet.dart';
import '../models/app_notification_model.dart';
import '../providers/notification_providers.dart';

class NotificationCenterSheet extends ConsumerWidget {
  const NotificationCenterSheet({super.key});

  static void show(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationCenterSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifState = ref.watch(notificationNotifierProvider);
    final notifications = ref.watch(allNotificationsProvider);
    final unreadCount = ref.watch(totalUnreadNotificationCountProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceBlack : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 2. Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFFFF5000),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'ศูนย์การแจ้งเตือน',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5000),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unreadCount ใหม่',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'รวมทุกการแจ้งเตือนและกิจกรรมในระบบ',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Mark all as read button
                  if (unreadCount > 0)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(notificationNotifierProvider.notifier).markAllAsRead();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'อ่านทั้งหมด',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 3. Category Filter Chips
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryChip(
                    context: context,
                    ref: ref,
                    label: 'ทั้งหมด',
                    category: NotificationCategory.all,
                    isSelected: notifState.selectedCategory == NotificationCategory.all,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    context: context,
                    ref: ref,
                    label: 'คำขอหนี้ & บิล',
                    category: NotificationCategory.debts,
                    isSelected: notifState.selectedCategory == NotificationCategory.debts,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    context: context,
                    ref: ref,
                    label: 'การชำระเงิน',
                    category: NotificationCategory.payments,
                    isSelected: notifState.selectedCategory == NotificationCategory.payments,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    context: context,
                    ref: ref,
                    label: 'เพื่อน & รางวัล',
                    category: NotificationCategory.friendsAndRewards,
                    isSelected: notifState.selectedCategory == NotificationCategory.friendsAndRewards,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    context: context,
                    ref: ref,
                    label: 'ระบบ',
                    category: NotificationCategory.system,
                    isSelected: notifState.selectedCategory == NotificationCategory.system,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            Divider(
              height: 1,
              thickness: 0.8,
              color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
            ),

            // 4. Notifications Feed
            Expanded(
              child: notifications.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 68,
                        color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
                      ),
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        return _buildNotificationTile(context, ref, notif, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required NotificationCategory category,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(notificationNotifierProvider.notifier).setCategory(category);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF5000)
              : (isDark ? AppColors.surfaceTile2 : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.bodyMuted : AppColors.inkMuted80),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    WidgetRef ref,
    AppNotificationItem notif,
    bool isDark,
  ) {
    return Material(
      color: notif.isRead
          ? Colors.transparent
          : (isDark
              ? const Color(0xFFFF5000).withValues(alpha: 0.05)
              : const Color(0xFFFFF7F2)),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(notificationNotifierProvider.notifier).markAsRead(notif.id);

          // Deep link navigation based on notification type
          if (notif.type == NotificationType.debtRequest) {
            final debt = notif.metadata?['debtItem'] as DebtItemModel?;
            if (debt != null) {
              Navigator.pop(context);
              DebtAcknowledgementDetailSheet.show(context, debt);
            } else {
              Navigator.pop(context);
              context.go('/payments');
            }
          } else if (notif.type == NotificationType.paymentReceived ||
              notif.type == NotificationType.paymentConfirmed) {
            Navigator.pop(context);
            context.go('/payments');
          } else if (notif.type == NotificationType.friendRequest ||
              notif.type == NotificationType.friendAdded) {
            Navigator.pop(context);
            context.push('/friends');
          } else if (notif.type == NotificationType.rewardPointsEarned ||
              notif.type == NotificationType.rewardShipped) {
            Navigator.pop(context);
            context.go('/rewards');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon in tinted squircle box
              Container(
                width: 40,
                height: 40,
                decoration: ShapeDecoration(
                  color: notif.iconColor.withValues(alpha: 0.14),
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: Icon(notif.icon, color: notif.iconColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Title, Body, Timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w700,
                              letterSpacing: -0.2,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          _formatRelativeTime(notif.createdAt),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.body,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                      ),
                    ),

                    // Quick Action Button for Debt Acknowledgements
                    if (notif.type == NotificationType.debtRequest) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          ref.read(notificationNotifierProvider.notifier).markAsRead(notif.id);
                          final debt = notif.metadata?['debtItem'] as DebtItemModel?;
                          if (debt != null) {
                            Navigator.pop(context);
                            DebtAcknowledgementDetailSheet.show(context, debt);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5000),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'ตรวจสอบและยอมรับหนี้',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Unread Indicator Dot
              if (!notif.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF5000),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 42,
                color: Color(0xFFFF5000),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'ไม่มีรายการแจ้งเตือนในขณะนี้',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'เมื่อมีคำร้องขอหารบิล การชำระเงิน หรือกิจกรรมใหม่ จะแจ้งเตือนที่นี่',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'เมื่อสักครู่';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} นาทีที่แล้ว';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ชม. ที่แล้ว';
    } else if (diff.inDays == 1) {
      return 'เมื่อวานนี้';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} วันที่แล้ว';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
