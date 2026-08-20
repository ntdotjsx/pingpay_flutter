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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text(
          'โปรไฟล์ของฉัน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          children: [
            // 1. User Profile Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: ShapeDecoration(
                color: isDark ? AppColors.surfaceTile1 : Colors.white,
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                shape: SmoothRectangleBorder(
                  side: BorderSide(
                    color: isDark ? Colors.white10 : AppColors.hairline,
                    width: 1,
                  ),
                  borderRadius: const SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar with Squircle / Circle Outline
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            backgroundImage: user?.avatarUrl != null
                                ? NetworkImage(user!.avatarUrl!)
                                : null,
                            child: user?.avatarUrl == null
                                ? Text(
                                    (user?.displayName != null && user!.displayName!.isNotEmpty)
                                        ? user.displayName![0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'ผู้ใช้งาน PingPay',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // User Code with Copy Button
                            GestureDetector(
                              onTap: () {
                                if (user?.userCode != null) {
                                  Clipboard.setData(ClipboardData(text: user!.userCode!));
                                  AppToast.success(context, 'คัดลอกรหัส ${user.userCode} เรียบร้อยแล้ว');
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'รหัส: ${user?.userCode ?? "-"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.copy_rounded,
                                      size: 13,
                                      color: AppColors.primary,
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
                  const SizedBox(height: 18),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? Colors.white10 : AppColors.dividerSoft,
                  ),
                  const SizedBox(height: 14),
                  // Coins & Activity Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildProfileMetric(
                        icon: Icons.monetization_on,
                        iconColor: const Color(0xFFFFD700),
                        label: 'PingPay Coins',
                        value: '27 เหรียญ',
                        isDark: isDark,
                      ),
                      Container(
                        height: 28,
                        width: 1,
                        color: isDark ? Colors.white10 : AppColors.dividerSoft,
                      ),
                      _buildProfileMetric(
                        icon: Icons.shield_rounded,
                        iconColor: AppColors.success,
                        label: 'สถานะบัญชี',
                        value: 'ยืนยันตัวตนแล้ว',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Settings Group 1: Appearance & Gesture
            _buildSectionTitle('การตั้งค่าและการแสดงผล', isDark),
            const SizedBox(height: 8),
            _buildSettingsContainer(
              isDark: isDark,
              children: [
                // Theme Mode Selector
                _buildSettingsTile(
                  icon: Icons.dark_mode_outlined,
                  iconColor: Colors.deepPurple,
                  title: 'ธีมการแสดงผล (Theme)',
                  subtitle: _getThemeLabel(themeMode),
                  isDark: isDark,
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<ThemeMode>(
                      value: themeMode,
                      dropdownColor: isDark ? AppColors.surfaceTile2 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('ตามระบบ (System)', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('สว่าง (Light)', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('มืด (Dark)', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode != null) {
                          ref.read(themeModeProvider.notifier).setThemeMode(mode);
                        }
                      },
                    ),
                  ),
                ),
                _buildTileDivider(isDark),
                // Pull Sensitivity Setting
                _buildSettingsTile(
                  icon: Icons.swipe_down_rounded,
                  iconColor: AppColors.primary,
                  title: 'ความไวดึงลงเพื่อสร้างบิล',
                  subtitle: pullSensitivity.label,
                  isDark: isDark,
                  onTap: () => _showSensitivitySheet(context),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted48),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. Settings Group 2: Account & Security
            _buildSectionTitle('ความปลอดภัยและบัญชี', isDark),
            const SizedBox(height: 8),
            _buildSettingsContainer(
              isDark: isDark,
              children: [
                _buildSettingsTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: const Color(0xFF007AFF),
                  title: 'เปลี่ยนรหัส PIN ความปลอดภัย',
                  subtitle: 'ตั้งรหัส PIN 6 หลักใหม่สำหรับยืนยันการเงิน',
                  isDark: isDark,
                  onTap: () => context.push('/pin/setup'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted48),
                ),
                _buildTileDivider(isDark),
                _buildSettingsTile(
                  icon: Icons.qr_code_2_rounded,
                  iconColor: const Color(0xFF00B900),
                  title: 'PromptPay QR สำหรับรับเงิน',
                  subtitle: user?.promptPayId != null && user!.promptPayId!.isNotEmpty
                      ? 'เบอร์พร้อมเพย์: ${user.promptPayId}'
                      : 'แตะเพื่อดู QR Code หรือผูกบัญชีพร้อมเพย์',
                  isDark: isDark,
                  onTap: () => _showPromptPayQRModal(context),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted48),
                ),
                _buildTileDivider(isDark),
                _buildSettingsTile(
                  icon: Icons.card_giftcard_rounded,
                  iconColor: const Color(0xFFFF9500),
                  title: 'ร้านค้าแลกของรางวัล (Rewards Store)',
                  subtitle: 'ใช้แต้มแลกของรางวัลในชีวิตจริง จัดส่งถึงบ้าน',
                  isDark: isDark,
                  onTap: () => context.push('/rewards'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted48),
                ),
                _buildTileDivider(isDark),
                _buildSettingsTile(
                  icon: Icons.policy_outlined,
                  iconColor: Colors.teal,
                  title: 'นโยบายความเป็นส่วนตัว (PDPA)',
                  subtitle: 'เงื่อนไขการเก็บรักษาข้อมูลและ Audit Logs 7 วัน',
                  isDark: isDark,
                  onTap: () => context.push('/pdpa'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted48),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 4. Logout Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                label: const Text(
                  'ออกจากระบบ (Logout)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'PingPay Version 1.0.0 (Build 2026.08)',
              style: TextStyle(fontSize: 11, color: AppColors.inkMuted48),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
          ),
        ),
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
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: ShapeDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 12, cornerSmoothing: 1.0),
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
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
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
      color: isDark ? Colors.white10 : AppColors.dividerSoft,
    );
  }

  Widget _buildProfileMetric({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.inkMuted48),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'สว่าง (Light Mode)';
      case ThemeMode.dark:
        return 'มืด (Dark Mode)';
      case ThemeMode.system:
        return 'ตามการตั้งค่าระบบ (System)';
    }
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
                topLeft: SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
                topRight: SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
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
              const SizedBox(height: 16),
              const Text(
                'ปรับความไวดึงลงสร้างบิล',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'เลือกระยะการลากนิ้วจากบนลงล่างที่หน้าหลักเพื่อเข้าสู่หน้าสร้างบิลทันที',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted48),
              ),
              const SizedBox(height: 16),
              ...PullSensitivity.values.map((s) {
                final isSelected = s == currentSens;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
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
                      const Icon(Icons.qr_code_scanner_rounded, size: 48, color: AppColors.primary),
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
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
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
                          backgroundColor: AppColors.primary,
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
                      backgroundColor: AppColors.primary,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ต้องการออกจากระบบ?'),
        content: const Text('คุณจะต้องเข้าสู่ระบบใหม่เพื่อใช้งาน PingPay อีกครั้ง'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (!mounted) return;
      GoRouter.of(this.context).go('/login');
    }
  }
}
