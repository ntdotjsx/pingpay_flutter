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
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'โปรไฟล์ของฉัน',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            letterSpacing: -0.4,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (user?.userCode != null)
            IconButton(
              icon: const Icon(Icons.qr_code_rounded, size: 22),
              tooltip: 'QR Code ของฉัน',
              onPressed: () => _showMyQrCodeModal(
                context,
                user!.userCode!,
                user.displayName ?? 'PingPay User',
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Hero VIP Profile Executive Card ───────────────────────
            _buildHeroProfileCard(context, user, isDark, friendCount),

            const SizedBox(height: 24),

            // ── 2. Settings Group: Financials & Payouts ─────────────────
            _buildSectionHeader('การเงินและการรับเงิน', Icons.account_balance_wallet_rounded, const Color(0xFF00B900), isDark),
            const SizedBox(height: 10),
            _buildSettingsContainer(
              isDark: isDark,
              children: [
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
                  onTap: () => context.push('/rewards'),
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
              ],
            ),

            const SizedBox(height: 24),

            // ── 3. Settings Group: Security & Active Sessions ────────────
            _buildSectionHeader('ความปลอดภัยและบัญชี', Icons.shield_rounded, const Color(0xFF007AFF), isDark),
            const SizedBox(height: 10),
            _buildSettingsContainer(
              isDark: isDark,
              children: [
                // Change PIN
                _buildModernSettingsTile(
                  icon: Icons.lock_outline_rounded,
                  iconBgColor: const Color(0xFF007AFF).withValues(alpha: 0.12),
                  iconColor: const Color(0xFF007AFF),
                  title: 'เปลี่ยนรหัส PIN ความปลอดภัย',
                  subtitle: 'รหัส 6 หลักสำหรับยืนยันการทำธุรกรรมและการเงิน',
                  isDark: isDark,
                  onTap: () => context.push('/pin/setup'),
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
                  onTap: () => context.push('/pdpa'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── 4. Settings Group: Preferences & Appearance ──────────────
            _buildSectionHeader('การตั้งค่าและการแสดงผล', Icons.tune_rounded, const Color(0xFFFF5000), isDark),
            const SizedBox(height: 10),
            _buildSettingsContainer(
              isDark: isDark,
              children: [
                // Theme Mode Segmented Switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
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
                      const SizedBox(height: 14),
                      // Segmented Button Bar
                      Container(
                        height: 40,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceTile2 : const Color(0xFFE9ECF0),
                          borderRadius: BorderRadius.circular(12),
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
              ],
            ),

            const SizedBox(height: 28),

            // ── 5. Logout Action Button ──────────────────────────────────
            InkWell(
              onTap: () => _handleLogout(context),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: ShapeDecoration(
                  color: isDark ? const Color(0xFF261214) : const Color(0xFFFFF1F1),
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: const Color(0xFFFF3B30).withValues(alpha: isDark ? 0.35 : 0.25),
                      width: 1,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFFF3B30),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'ออกจากระบบ (Logout)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF3B30),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── 6. Footer App Version & Shorebird Info ───────────────────
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
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HERO PROFILE CARD WIDGET
  // ==========================================
  Widget _buildHeroProfileCard(
    BuildContext context,
    dynamic user,
    bool isDark,
    int friendCount,
  ) {
    return Container(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFEBEFF5),
            width: 1,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Column(
        children: [
          // Top Section: Avatar + Name + User Code
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with Glowing Ring
                Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: ShapeDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7A00), Color(0xFFFF4500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 22, cornerSmoothing: 0.7),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: ClipSmoothRect(
                        radius: const SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.7),
                        ),
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
                      bottom: -1,
                      right: -1,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceTile1 : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF34C759),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Name & Code Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'ผู้ใช้งาน PingPay',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (user?.email != null)
                        Text(
                          user!.email!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),

                      // User Code Capsule with Copy & QR Action
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              if (user?.userCode != null) {
                                Clipboard.setData(ClipboardData(text: user!.userCode!));
                                HapticFeedback.lightImpact();
                                AppToast.success(context, 'คัดลอกรหัส ${user.userCode} เรียบร้อยแล้ว');
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFF5000).withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    user?.userCode ?? '-',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: Color(0xFFFF5000),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.copy_rounded,
                                    size: 13,
                                    color: Color(0xFFFF5000),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
          ),

          // Bottom Stats Grid (Revolut/Apple Style 3-Column Highlights)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Row(
              children: [
                // 1. Coins
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/rewards'),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 14),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${user?.rewardPoints ?? 27}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PingPay Coins',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Container(
                  height: 28,
                  width: 1,
                  color: isDark ? Colors.white10 : const Color(0xFFEBEFF5),
                ),

                // 2. Friends Count
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/friends'),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.people_alt_rounded,
                                color: Color(0xFFFF5000),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$friendCount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'เพื่อนทั้งหมด',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Container(
                  height: 28,
                  width: 1,
                  color: isDark ? Colors.white10 : const Color(0xFFEBEFF5),
                ),

                // 3. Verified Status
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              color: Color(0xFF34C759),
                              size: 18,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'ยืนยันแล้ว',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF34C759),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'สถานะบัญชี',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
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
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  // ==========================================
  // SECTION HEADERS & SETTING CONTAINERS
  // ==========================================
  Widget _buildSectionHeader(String title, IconData icon, Color iconColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContainer({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFEBEFF5),
            width: 1,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 22, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildModernSettingsTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    Widget? badge,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Modern Squircle Icon Container
              Container(
                width: 40,
                height: 40,
                decoration: ShapeDecoration(
                  color: iconBgColor,
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
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
              const SizedBox(width: 8),
              if (badge != null) ...[
                badge,
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white30 : AppColors.inkMuted48,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.surfaceTile1 : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
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
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

  Widget _buildTileDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 16,
      color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'โหมดสว่าง (Light)';
      case ThemeMode.dark:
        return 'โหมดมืด (Dark)';
      case ThemeMode.system:
        return 'ตามการตั้งค่าระบบ (System)';
    }
  }

  // ==========================================
  // MODALS & DIALOGS
  // ==========================================
  void _showMyQrCodeModal(BuildContext context, String userCode, String displayName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceBlack : Colors.white,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 32, cornerSmoothing: 0.7),
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
              'ให้เพื่อนสแกนรหัสนี้เพื่อเพิ่มคุณเป็นเพื่อนได้ทันที',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: userCode,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFFFF5000),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'รหัสผู้ใช้: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    ),
                  ),
                  Text(
                    userCode,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Color(0xFFFF5000),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSensitivitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final currentSens = ref.watch(pullSensitivityProvider);
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Container(
          decoration: ShapeDecoration(
            color: isDark ? AppColors.surfaceTile1 : Colors.white,
            shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.only(
                topLeft: SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.8),
                topRight: SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.8),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'ความไวดึงลงเพื่อสร้างบิล',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'เลือกระยะการลากนิ้วจากบนลงล่างที่หน้าหลักเพื่อเปิดหน้าสร้างบิลอัตโนมัติ',
                style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted48),
              ),
              const SizedBox(height: 18),
              ...PullSensitivity.values.map((s) {
                final isSelected = s == currentSens;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF5000))
                      : const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.inkMuted48),
                  onTap: () {
                    ref.read(pullSensitivityProvider.notifier).setSensitivity(s);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showShippingAddressModal(BuildContext context, dynamic user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: user?.shippingRecipientName ?? user?.displayName ?? '');
    final phoneCtrl = TextEditingController(text: user?.shippingPhone ?? user?.phoneNumber ?? '');
    final addrCtrl = TextEditingController(text: user?.shippingAddress ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: ShapeDecoration(
            color: isDark ? AppColors.surfaceTile1 : Colors.white,
            shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.vertical(
                top: SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.8),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'ที่อยู่จัดส่งของรางวัล 📦',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ใช้สำหรับจัดส่งของรางวัลจาก Rewards Store ถึงมือคุณ',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'ชื่อ-นามสกุลผู้รับ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'เบอร์โทรศัพท์ติดต่อ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addrCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'ที่อยู่จัดส่งโดยละเอียด',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    AppToast.success(context, 'บันทึกที่อยู่จัดส่งเรียบร้อยแล้ว');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('บันทึกข้อมูล', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPromptPayQRModal(BuildContext context) {
    final user = ref.read(authStateProvider).user;
    final promptPayId = user?.promptPayId ?? user?.phoneNumber ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? qrPayload;
    if (promptPayId.isNotEmpty) {
      try {
        final cleanId = promptPayId.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanId.length == 13) {
          qrPayload = encodePromptPay(
            target: PromptPayTarget(PromptPayType.nationalId, cleanId),
          );
        } else if (cleanId.length == 15) {
          qrPayload = encodePromptPay(
            target: PromptPayTarget(PromptPayType.eWallet, cleanId),
          );
        } else {
          qrPayload = promptPayMobile(cleanId);
        }
      } catch (e) {
        debugPrint('Error generating personal PromptPay QR: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: ShapeDecoration(
            color: isDark ? AppColors.surfaceTile1 : Colors.white,
            shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.only(
                topLeft: SmoothRadius(cornerRadius: 28, cornerSmoothing: 1.0),
                topRight: SmoothRadius(cornerRadius: 28, cornerSmoothing: 1.0),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'PromptPay QR สำหรับรับเงิน',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ให้เพื่อนสแกน QR Code นี้เพื่อโอนเงินคืนคุณผ่านแอปธนาคาร',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                ),
              ),
              const SizedBox(height: 20),

              if (qrPayload != null) ...[
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
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF003D6B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'PromptPay พร้อมเพย์',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.displayName ?? 'ผู้ใช้งาน PingPay',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'พร้อมเพย์: $promptPayId',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMuted80,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, size: 48, color: Color(0xFFFF5000)),
                      const SizedBox(height: 12),
                      const Text(
                        'ยังไม่ได้ตั้งค่าเบอร์พร้อมเพย์',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'กรุณาระบุเบอร์โทรศัพท์หรือพร้อมเพย์เพื่อสร้าง QR Code รับเงิน',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (qrPayload != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          SetupPaymentChannelSheet.show(context);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('แก้ไขข้อมูล'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF5000),
                          side: const BorderSide(color: Color(0xFFFF5000)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5000),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('ปิดหน้าต่าง', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      SetupPaymentChannelSheet.show(context);
                    },
                    icon: const Icon(Icons.add_card_rounded, size: 20),
                    label: const Text('ตั้งค่าพร้อมเพย์ตอนนี้', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 28,
              offset: const Offset(0, -4),
            ),
          ],
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 32, cornerSmoothing: 0.8),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Grab Handle
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),

            // Red Warning Icon Badge
            Container(
              width: 68,
              height: 68,
              decoration: ShapeDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 22, cornerSmoothing: 0.8),
                  ),
                ),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFFF3B30),
                size: 32,
              ),
            ),
            const SizedBox(height: 18),

            // Title & Subtitle
            Text(
              'ต้องการออกจากระบบ?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'เซสชันการใช้งานบนอุปกรณ์นี้จะสิ้นสุดลงทันที คุณสามารถกลับเข้าสู่ระบบได้ทุกเมื่อด้วยบัญชี Google ของคุณ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),

            // Cloud Security Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_done_rounded,
                    color: Color(0xFF34C759),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ข้อมูลบัญชีและประวัติการเงินของคุณได้รับการสำรองไว้อย่างปลอดภัย',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // Destructive Action: Confirm Logout Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'ยืนยันออกจากระบบ (Logout)',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: const Color(0xFFFF3B30).withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Safe Action: Cancel Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'ยกเลิก (อยู่ในระบบต่อ)',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (!mounted) return;
      GoRouter.of(this.context).go('/login');
    }
  }
}
