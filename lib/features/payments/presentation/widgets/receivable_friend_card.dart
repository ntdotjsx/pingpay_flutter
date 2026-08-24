import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../friends/providers/friend_nickname_provider.dart';
import '../../models/payment_models.dart';
import '../../services/debt_age_calculator.dart';

class ReceivableFriendCard extends ConsumerWidget {
  final ReceivableFriendModel friend;
  final VoidCallback? onTap;

  const ReceivableFriendCard({super.key, required this.friend, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final oldestAgeText = DebtAgeCalculator.formatDebtAgeThai(
      friend.oldestDebtStartDate,
    );

    final nicknamesMap = ref.watch(friendNicknameProvider);
    final nickname = nicknamesMap[friend.debtor.id] ?? nicknamesMap[friend.debtor.userCode];
    final hasNickname = nickname != null && nickname.trim().isNotEmpty;
    final effectiveName = hasNickname ? nickname : friend.debtor.displayName;

    return Material(
      color: isDark ? AppColors.surfaceTile1 : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Debtor Avatar
                  _buildAvatar(isDark, effectiveName),

                  const SizedBox(width: 12),

                  // 2. Center: Name, Outstanding Bills Count, Age
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                effectiveName,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: isDark
                                      ? AppColors.bodyOnDark
                                      : AppColors.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasNickname) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${friend.debtor.displayName})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                            ],
                            if (friend.latestPaymentStatus ==
                                'pending_owner_confirmation') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'รอยืนยันสลิป',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF007AFF),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${friend.outstandingBillCount} รายการค้างชำระ',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? AppColors.bodyMuted
                                : AppColors.inkMuted80,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          oldestAgeText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFFF5000),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 3. Right: Amount & Arrow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'ติดเรา',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inkMuted48,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '฿${friend.totalOutstandingAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: Color(0xFFFF5000),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.bodyMuted
                                : const Color(0xFFFF5000),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Inset Divider
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 68,
              color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isDark, String effectiveName) {
    return Container(
      width: 40,
      height: 40,
      decoration: ShapeDecoration(
        color: isDark ? const Color(0xFF2C2D32) : const Color(0xFFFFECE5),
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: ClipSmoothRect(
        radius: const SmoothBorderRadius.all(
          SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.8),
        ),
        child: friend.debtor.avatarUrl != null &&
                friend.debtor.avatarUrl!.isNotEmpty
            ? Image.network(
                friend.debtor.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAvatarInitial(isDark, effectiveName),
              )
            : _buildAvatarInitial(isDark, effectiveName),
      ),
    );
  }

  Widget _buildAvatarInitial(bool isDark, String effectiveName) {
    return Center(
      child: Text(
        effectiveName.isNotEmpty
            ? effectiveName[0].toUpperCase()
            : 'U',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFFF6A00) : const Color(0xFFFF5000),
        ),
      ),
    );
  }
}
