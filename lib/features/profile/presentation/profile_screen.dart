import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thai_promptpay/thai_promptpay.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/app_toast.dart';
import '../../auth/providers/auth_provider.dart';
import '../../friends/providers/friends_provider.dart';
import '../../home/providers/pull_sensitivity_provider.dart';
import 'widgets/setup_payment_channel_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final themeMode = ref.watch(themeModeProvider);
    final pullSensitivity = ref.watch(pullSensitivityProvider);
    final friendsAsync = ref.watch(friendsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final friendCount = friendsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          ref.invalidate(authStateProvider);
          ref.invalidate(friendsListProvider);
        },
        color: const Color(0xFFFF5000),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Container(
            color: isDark ? AppColors.surfaceBlack : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Top Executive Gradient Header ──────────────────────
                _buildExecutiveHeader(context, user, isDark, friendCount),

                const SizedBox(height: 16),

                // ── 2. Settings Group: Financials & Payouts ───────────────
                _buildSectionHeader('การเงินและการรับเงิน', Icons.account_balance_wallet_rounded, const Color(0xFF00B900), isDark),
                const SizedBox(height: 6),

                // PromptPay Setup / View QR
                _buildModernSettingsTile(
                  icon: Icons.qr_code_2_rounded,
                  iconBgColor: const Color(0xFF00B900).withValues(alpha: 0.12),
                  iconColor: const Color(0xFF00B900),
                  title: 'PromptPay QR สำหรับรับเงิน',
                  subtitle: (user?.promptPayId != null && user!.promptPayId!.isNotEmpty)
                      ? 'เบอร์พร้อมเพย์: ${user.promptPayId}'
                      : 'แตะเพื่อผูกบัญชีหรือดู QR รับเงิน',
                  badge: (user?.promptPayId != null && user!.promptPayId!.isNotEmpty)
                      ? _buildStatusBadge('ผูกแล้ว', const Color(0xFF00B900))
                      : _buildStatusBadge('ยังไม่ผูก', Colors.orange),
                  isDark: isDark,
                  onTap: () => _showPromptPayQRModal(context),
                ),
                _buildTileDivider(isDark),

                // Rewards Store Shortcut
                _buildModernSettingsTile(
                  icon: Icons.card_giftcard_rounded,
                  iconBgColor: const Color(0xFFFF9500).withValues(alpha: 0.12),
                  iconColor: const Color(0xFFFF9500),
                  title: 'ร้านค้าแลกของรางวัล (Rewards)',
                  subtitle: 'ใช้เหรียญ PingPay Coins แลกของรางวัลส่งตรงถึงบ้าน',
                  badge: _buildStatusBadge('${user?.rewardPoints ?? 27} แต้ม', const Color(0xFFFF9500)),
                  isDark: isDark,
                  onTap: () => context.go('/rewards'),
                ),
                _buildTileDivider(isDark),

                // Shipping Details
                _buildModernSettingsTile(
                  icon: Icons.local_shipping_rounded,
                  iconBgColor: const Color(0xFF5856D6).withValues(alpha: 0.12),
                  iconColor: const Color(0xFF5856D6),
                  title: 'ที่อยู่จัดส่งของรางวัล',
                  subtitle: (user?.shippingAddress != null && user!.shippingAddress!.isNotEmpty)
                      ? user.shippingAddress!
                      : 'แตะเพื่อบันทึกที่อยู่จัดส่ง',
                  isDark: isDark,
                  onTap: () => _showShippingAddressModal(context, user),
                ),

                const SizedBox(height: 20),

                // ── 3. Settings Group: Security & Active Sessions ──────────
                _buildSectionHeader('ความปลอดภัยและบัญชี', Icons.shield_rounded, const Color(0xFF007AFF), isDark),
                const SizedBox(height: 6),

                // Change PIN
                _buildModernSettingsTile(
                  icon: Icons.lock_outline_rounded,
                  iconBgColor: const Color(0xFF007AFF).withValues(alpha: 0.12),
                  iconColor: const Color(0xFF007AFF),
                  title: 'เปลี่ยนรหัส PIN ความปลอดภัย',
                  subtitle: 'รหัส 6 หลักสำหรับยืนยันการทำธุรกรรมและการเงิน',
                  isDark: isDark,
                  onTap: () => context.push('/pin/change'),
                ),
                _buildTileDivider(isDark),

                // Single Device Active Session Notice
                _buildModernSettingsTile(
                  icon: Icons.devices_rounded,
                  iconBgColor: const Color(0xFF34C759).withValues(alpha: 0.12),
                  iconColor: const Color(0xFF34C759),
                  title: 'อุปกรณ์ที่เข้าใช้งานปัจจุบัน',
                  subtitle: 'เครื่องนี้ (Active Session) • จำกัด 1 เครื่องเพื่อความปลอดภัย',
                  badge: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34C759),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'ออนไลน์',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF34C759),
                        ),
                      ),
                    ],
                  ),
                  isDark: isDark,
                  onTap: () {
                    AppToast.info(context, 'บัญชีของคุณออนไลน์อยู่บนเครื่องนี้ และได้รับการคุ้มครองความปลอดภัย');
                  },
                ),
                _buildTileDivider(isDark),

                // PDPA & Data Privacy
                _buildModernSettingsTile(
                  icon: Icons.policy_outlined,
                  iconBgColor: Colors.teal.withValues(alpha: 0.12),
                  iconColor: Colors.teal,
                  title: 'นโยบายความเป็นส่วนตัว (PDPA)',
                  subtitle: 'เงื่อนไขการคุ้มครองข้อมูลส่วนบุคคลและ Audit Logs',
                  isDark: isDark,
                  onTap: () => _showPdpaPolicyBottomSheet(context),
                ),

                const SizedBox(height: 20),

                // ── 4. Settings Group: Preferences & Appearance ────────────
                _buildSectionHeader('การตั้งค่าและการแสดงผล', Icons.tune_rounded, const Color(0xFFFF5000), isDark),
                const SizedBox(height: 6),

                // Theme Mode Switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: ShapeDecoration(
                              color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                              shape: const SmoothRectangleBorder(
                                borderRadius: SmoothBorderRadius.all(
                                  SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.palette_outlined,
                              color: Color(0xFFFF5000),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ธีมการแสดงผล (Theme)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getThemeLabel(themeMode),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _buildThemeSegment(
                              label: 'สว่าง',
                              icon: Icons.light_mode_rounded,
                              isSelected: themeMode == ThemeMode.light,
                              isDark: isDark,
                              onTap: () {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                                HapticFeedback.selectionClick();
                              },
                            ),
                            _buildThemeSegment(
                              label: 'มืด',
                              icon: Icons.dark_mode_rounded,
                              isSelected: themeMode == ThemeMode.dark,
                              isDark: isDark,
                              onTap: () {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                                HapticFeedback.selectionClick();
                              },
                            ),
                            _buildThemeSegment(
                              label: 'ตามระบบ',
                              icon: Icons.brightness_auto_rounded,
                              isSelected: themeMode == ThemeMode.system,
                              isDark: isDark,
                              onTap: () {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                                HapticFeedback.selectionClick();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                _buildTileDivider(isDark),

                // Pull Sensitivity Setting
                _buildModernSettingsTile(
                  icon: Icons.swipe_down_rounded,
                  iconBgColor: const Color(0xFFFF5000).withValues(alpha: 0.12),
                  iconColor: const Color(0xFFFF5000),
                  title: 'ความไวดึงลงเพื่อสร้างบิล',
                  subtitle: 'ระยะลากนิ้วจากหน้าหลัก: ${pullSensitivity.label}',
                  badge: _buildStatusBadge(pullSensitivity.label.split(' ').first, const Color(0xFFFF5000)),
                  isDark: isDark,
                  onTap: () => _showSensitivitySheet(context),
                ),

                const SizedBox(height: 28),

                // ── 5. Logout Action Button ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: InkWell(
                    onTap: () => _handleLogout(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: ShapeDecoration(
                        color: isDark ? const Color(0xFF261214) : const Color(0xFFFFF1F1),
                        shape: SmoothRectangleBorder(
                          side: BorderSide(
                            color: const Color(0xFFFF3B30).withValues(alpha: isDark ? 0.35 : 0.25),
                            width: 1,
                          ),
                          borderRadius: const SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
                          ),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFFF3B30),
                            size: 19,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ออกจากระบบ (Logout)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF3B30),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── 6. Footer App Version ──────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF5000),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PingPay v1.0.0 (Production Engine)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'เพื่อนหารเงินง่าย อัปเดตยอดหนี้แบบเรียลไทม์',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white30 : AppColors.inkMuted48,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TOP SIGNATURE GRADIENT HEADER & USER PROFILE
  // =========================================================================
  Widget _buildExecutiveHeader(
    BuildContext context,
    dynamic user,
    bool isDark,
    int friendCount,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.surfaceTile1,
                  AppColors.surfaceTile2,
                  AppColors.surfaceTile3,
                ]
              : [
                  const Color(0xFFFF5000),
                  const Color(0xFFFF6A00),
                  const Color(0xFFFF8500),
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Title + My QR Code Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'โปรไฟล์ของฉัน',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),

                  // My QR Code Button
                  if (user?.userCode != null)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showMyQrCodeModal(
                          context,
                          user!.userCode!,
                          user.displayName ?? 'PingPay User',
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: ShapeDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                            ),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'QR ของฉัน',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. User Info (Avatar + Name + Copyable Code)
              Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                              ? Image.network(
                                  user.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildAvatarFallback(user),
                                )
                              : _buildAvatarFallback(user),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF34C759),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Display Name & User Code
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'ผู้ใช้งาน PingPay',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            if (user?.userCode != null) {
                              Clipboard.setData(ClipboardData(text: user!.userCode!));
                              HapticFeedback.lightImpact();
                              AppToast.success(context, 'คัดลอก User Code (${user.userCode}) แล้ว');
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user?.userCode ?? '-',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 3. Frosted 3-Stat Highlights Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // 1. Coins
                    Expanded(
                      child: InkWell(
                        onTap: () => context.go('/rewards'),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.monetization_on_rounded, size: 14, color: Color(0xFFFFD700)),
                                const SizedBox(width: 4),
                                Text(
                                  '${user?.rewardPoints ?? 27}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'PingPay Coins',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 20, color: Colors.white24),

                    // 2. Friends Count
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push('/friends'),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_alt_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '$friendCount',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'เพื่อนทั้งหมด',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 20, color: Colors.white24),

                    // 3. Verified Status
                    Expanded(
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF34C759)),
                              SizedBox(width: 4),
                              Text(
                                'ยืนยันแล้ว',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'สถานะบัญชี',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(dynamic user) {
    return Container(
      color: const Color(0xFF1E1E24),
      alignment: Alignment.center,
      child: Text(
        (user?.displayName != null && user!.displayName!.isNotEmpty)
            ? user.displayName![0].toUpperCase()
            : 'U',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  // =========================================================================
  // SECTION HEADERS & SETTINGS LIST TILES
  // =========================================================================
  Widget _buildSectionHeader(String title, IconData icon, Color iconColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSettingsTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    return Material(
      color: isDark ? AppColors.surfaceTile1 : Colors.white,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: ShapeDecoration(
                  color: iconBgColor,
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                badge,
              ],
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTileDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 68,
      color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildThemeSegment({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.surfaceTile1 : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? const Color(0xFFFF5000)
                    : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.ink)
                      : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'โหมดสว่าง (Light Theme)';
      case ThemeMode.dark:
        return 'โหมดมืด (Dark Theme)';
      case ThemeMode.system:
        return 'ปรับตามระบบอุปกรณ์อัตโนมัติ';
    }
  }

  // =========================================================================
  // DIALOGS & MODALS
  // =========================================================================
  void _showMyQrCodeModal(BuildContext context, String userCode, String displayName) {
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
            Text(
              'QR Code เพิ่มเพื่อน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ให้เพื่อนใช้เมนู "สแกน QR" สแกนเพื่อเพิ่มคุณเป็นเพื่อน',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: 'pingpay://friend/$userCode',
                version: QrVersions.auto,
                size: 200,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1E2024),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1E2024),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceTile1 : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userCode,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: Color(0xFFFF5000),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: userCode));
                      HapticFeedback.lightImpact();
                      AppToast.success(context, 'คัดลอก User Code แล้ว');
                    },
                    child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFFF5000)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPromptPayQRModal(BuildContext context) {
    SetupPaymentChannelSheet.show(context);
  }

  void _showShippingAddressModal(BuildContext context, dynamic user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addressCtrl = TextEditingController(text: user?.shippingAddress ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: ShapeDecoration(
            color: isDark ? AppColors.surfaceTile1 : Colors.white,
            shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.vertical(
                top: SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.8),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ที่อยู่จัดส่งของรางวัล',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ใช้สำหรับจัดส่งของรางวัลที่คุณแลกจากร้านค้า PingPay Coins',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'บ้านเลขที่ ซอย ถนน แขวง/ตำบล เขต/อำเภอ จังหวัด รหัสไปรษณีย์',
                  labelText: 'ที่อยู่จัดส่ง',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  AppToast.success(context, 'บันทึกที่อยู่จัดส่งแล้ว');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5000),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('บันทึกที่อยู่', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPdpaPolicyBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: ShapeDecoration(
            color: isDark ? AppColors.surfaceTile1 : Colors.white,
            shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.vertical(
                top: SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.8),
              ),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'นโยบายความเป็นส่วนตัว (PDPA)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    'แอปพลิเคชัน PingPay ให้ความสำคัญสูงสุดกับความปลอดภัยและการคุ้มครองข้อมูลส่วนบุคคลของคุณ '
                    'ข้อมูลการทำธุรกรรม ยอดหนี้ รายการบิล และประวัติการชำระเงิน จะถูกเข้ารหัสและบันทึกอย่างปลอดภัย '
                    'โดยจะไม่มีการส่งต่อหรือเปิดเผยข้อมูลให้แก่บุคคลภายนอกโดยไม่ได้รับความยินยอมจากคุณ\n\n'
                    'หากมีข้อสงสัยเพิ่มเติม สามารถติดต่อทีมงานฝ่ายสนับสนุนได้ตลอด 24 ชั่วโมง',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSensitivitySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = ref.read(pullSensitivityProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.8),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ความไวดึงลงเพื่อสร้างบิล',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            ...PullSensitivity.values.map((s) {
              final isSelected = s == current;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 14,
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
                  ref.read(pullSensitivityProvider.notifier).setSensitivity(s);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบ PingPay ใช่หรือไม่?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
            ),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }
}
