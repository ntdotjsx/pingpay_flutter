import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/animations/animated_list_item.dart';
import '../../../../core/animations/animated_pressable.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/widgets/pingpay_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/friend_models.dart';
import '../providers/friend_nickname_provider.dart';
import '../providers/friends_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: userCode));
                      HapticFeedback.lightImpact();
                      AppToast.success(context, 'คัดลอกรหัสผู้ใช้แล้ว');
                    },
                    child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFFF5000)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.surfaceTile2 : const Color(0xFFEAECEF),
                  foregroundColor: isDark ? Colors.white : AppColors.ink,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('ปิด', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(authStateProvider).user;
    final incomingRequests = ref.watch(incomingFriendRequestsProvider);
    final outgoingRequests = ref.watch(outgoingFriendRequestsProvider);
    final friendsAsync = ref.watch(friendsListProvider);

    final incomingCount = incomingRequests.maybeWhen(data: (d) => d.length, orElse: () => 0);
    final outgoingCount = outgoingRequests.maybeWhen(data: (d) => d.length, orElse: () => 0);
    final friendsCount = friendsAsync.maybeWhen(data: (d) => d.length, orElse: () => 0);

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'เพื่อน (Friends)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF7F8FA),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_rounded, size: 22, color: Color(0xFFFFD700)),
            tooltip: 'ทำเนียบจัดอันดับเพื่อน 🏆',
            onPressed: () => context.push('/friends/leaderboard'),
          ),
          if (currentUser?.userCode != null)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 22, color: Color(0xFFFF5000)),
              tooltip: 'สแกน QR เพิ่มเพื่อน',
              onPressed: () => context.push('/friends/scan'),
            ),
          if (currentUser?.userCode != null)
            IconButton(
              icon: const Icon(Icons.qr_code_rounded, size: 22),
              tooltip: 'QR Code ของฉัน',
              onPressed: () => _showMyQrCodeModal(
                context,
                currentUser!.userCode!,
                currentUser.displayName ?? '',
              ),
            ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
            tooltip: 'เพิ่มเพื่อนด้วยรหัส',
            onPressed: () => context.push('/friends/add'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // ── 1. My Friend Code Card (Hero Banner) ────────────────────────
          if (currentUser?.userCode != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                      width: 0.8,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 16, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const ShapeDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF7A00), Color(0xFFFF5000)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.6),
                          ),
                        ),
                      ),
                      child: const Icon(Icons.badge_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'รหัสเพื่อนของคุณ (My ID)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            currentUser!.userCode!,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Scan QR Button
                    InkWell(
                      onTap: () => context.push('/friends/scan'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, size: 13, color: Color(0xFFFF5000)),
                            SizedBox(width: 3),
                            Text(
                              'สแกน',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF5000),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Quick Copy Button
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: currentUser.userCode!));
                        HapticFeedback.lightImpact();
                        AppToast.success(context, 'คัดลอกรหัส ${currentUser.userCode} แล้ว');
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 13, color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                            const SizedBox(width: 3),
                            Text(
                              'คัดลอก',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
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
            ),

          // ── 2. Pill Segmented Tab Navigation ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceTile2 : const Color(0xFFE9ECF0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                labelColor: const Color(0xFFFF5000),
                unselectedLabelColor: isDark ? Colors.white60 : AppColors.inkMuted48,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                tabs: [
                  const Tab(text: 'เพื่อนของฉัน'),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('คำขอเข้า'),
                        if (incomingCount > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$incomingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'คำขอที่ส่ง'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ── 3. Tab Views ────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsListTab(context, isDark, friendsCount),
                _buildIncomingRequestsTab(context, isDark),
                _buildOutgoingRequestsTab(context, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsListTab(BuildContext context, bool isDark, int count) {
    final friendsAsync = ref.watch(friendsListProvider);

    return RefreshIndicator(
      color: const Color(0xFFFF5000),
      onRefresh: () async => ref.invalidate(friendsListProvider),
      child: Column(
        children: [
          // Search input field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceTile1 : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'ค้นหาด้วยชื่อเพื่อน หรือรหัส User ID...',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.inkMuted48,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 16, color: AppColors.inkMuted48),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),

          // Friends List View
          Expanded(
            child: friendsAsync.when(
              loading: () => const PingPayLoadingWidget(
                message: 'กำลังโหลดรายชื่อเพื่อน...',
                size: 130,
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('เกิดข้อผิดพลาดในการโหลดรายชื่อเพื่อน: $err'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(friendsListProvider),
                      child: const Text('ลองใหม่'),
                    ),
                  ],
                ),
              ),
              data: (friends) {
                final nicknamesMap = ref.watch(friendNicknameProvider);
                final filtered = friends.where((f) {
                  if (_searchQuery.isEmpty) return true;
                  final friendKey = (f.user.id != null && f.user.id!.isNotEmpty)
                      ? f.user.id!
                      : f.user.userCode;
                  final nickname = (nicknamesMap[friendKey] ?? '').toLowerCase();
                  final name = f.user.displayName.toLowerCase();
                  final code = f.user.userCode.toLowerCase();
                  return name.contains(_searchQuery) ||
                      code.contains(_searchQuery) ||
                      nickname.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.people_alt_rounded,
                    title: _searchQuery.isEmpty
                        ? 'ยังไม่มีเพื่อนในระบบ'
                        : 'ไม่พบเพื่อนที่ค้นหา',
                    subtitle: _searchQuery.isEmpty
                        ? 'เพิ่มเพื่อนด้วยรหัส User ID หรือแชร์ QR Code เพื่อเริ่มหารบิลร่วมกัน'
                        : 'ลองค้นหาด้วยคำอื่น หรือกดค้นหาและเพิ่มเพื่อนใหม่',
                    primaryActionLabel: '+ เพิ่มเพื่อนทันที',
                    onPrimaryAction: () => context.push('/friends/add'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final friend = filtered[index];
                    return _buildFriendCard(context, friend, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNicknameDialog(BuildContext context, FriendItemModel friend) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendKey = (friend.user.id != null && friend.user.id!.isNotEmpty)
        ? friend.user.id!
        : friend.user.userCode;
    final currentNickname = ref.read(friendNicknameProvider)[friendKey] ?? '';
    final controller = TextEditingController(text: currentNickname);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'ตั้งชื่อเล่นให้เพื่อน',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ชื่อในระบบ: ${friend.user.displayName} (${friend.user.userCode})',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'เช่น บาส, เอ็ม, นัท...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: isDark ? AppColors.surfaceTile2 : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'ชื่อเล่นนี้จะแสดงในเครื่องของคุณและใช้สั่งสร้างบิลด้วย AI ได้',
              style: TextStyle(fontSize: 11, color: Color(0xFFFF5000)),
            ),
          ],
        ),
        actions: [
          if (currentNickname.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(friendNicknameProvider.notifier).removeNickname(
                      userId: friend.user.id,
                      userCode: friend.user.userCode,
                    );
                if (context.mounted) {
                  AppToast.success(context, 'ล้างชื่อเล่นเรียบร้อยแล้ว');
                }
              },
              child: const Text(
                'ล้างชื่อเล่น',
                style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w600),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newNick = controller.text.trim();
              Navigator.pop(ctx);
              await ref.read(friendNicknameProvider.notifier).setNickname(
                    userId: friend.user.id,
                    userCode: friend.user.userCode,
                    nickname: newNick,
                  );
              if (context.mounted) {
                AppToast.success(
                  context,
                  newNick.isEmpty
                      ? 'ล้างชื่อเล่นเรียบร้อยแล้ว'
                      : 'ตั้งชื่อเล่นเป็น "$newNick" แล้ว',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('บันทึก', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(
    BuildContext context,
    FriendItemModel friend,
    bool isDark,
  ) {
    final friendKey = (friend.user.id != null && friend.user.id!.isNotEmpty)
        ? friend.user.id!
        : friend.user.userCode;
    final nicknamesMap = ref.watch(friendNicknameProvider);
    final nickname = nicknamesMap[friendKey];
    final hasNickname = nickname != null && nickname.trim().isNotEmpty;
    final effectiveName = hasNickname ? nickname.trim() : friend.user.displayName;

    final colorPalette = [
      const Color(0xFFFF5000),
      const Color(0xFF8B5CF6),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
    ];
    final colorIndex = (friend.user.userCode.hashCode.abs()) % colorPalette.length;
    final avatarAccent = colorPalette[colorIndex];

    return Container(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            width: 0.9,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
          ),
        ),
        shadows: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/friends/${friend.friendshipId}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // 1. Avatar with subtle gradient/badge
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: ShapeDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            avatarAccent.withValues(alpha: isDark ? 0.35 : 0.18),
                            avatarAccent.withValues(alpha: isDark ? 0.20 : 0.08),
                          ],
                        ),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 15, cornerSmoothing: 0.7),
                          ),
                        ),
                      ),
                      child: ClipSmoothRect(
                        radius: const SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 15, cornerSmoothing: 0.7),
                        ),
                        child: (friend.user.avatarUrl != null && friend.user.avatarUrl!.trim().isNotEmpty)
                            ? Image.network(
                                friend.user.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    effectiveName.isNotEmpty
                                        ? effectiveName[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: avatarAccent,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  effectiveName.isNotEmpty
                                      ? effectiveName[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: avatarAccent,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.surfaceTile1 : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 14),

                // 2. Info details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name Line
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              effectiveName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                                letterSpacing: -0.3,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasNickname) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: ShapeDecoration(
                                color: const Color(0xFFFF5000).withValues(alpha: isDark ? 0.25 : 0.12),
                                shape: const SmoothRectangleBorder(
                                  borderRadius: SmoothBorderRadius.all(
                                    SmoothRadius(cornerRadius: 6, cornerSmoothing: 0.6),
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.label_rounded, size: 10, color: Color(0xFFFF5000)),
                                  SizedBox(width: 2),
                                  Text(
                                    'ชื่อเล่น',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF5000),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 3),

                      // Subtitle Line (Real Name / Display Name & ID)
                      if (hasNickname)
                        Text(
                          'ชื่อในระบบ: ${friend.user.displayName}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showEditNicknameDialog(context, friend),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                                    width: 0.6,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit_note_rounded,
                                      size: 12,
                                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'ตั้งชื่อเล่น',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 4),

                      // User Code Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F3F6),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'รหัส: ${friend.user.userCode}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 3. Quick Actions: Edit Nickname Button
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  color: isDark ? Colors.white38 : AppColors.inkMuted48,
                  tooltip: 'แก้ไขชื่อเล่น',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showEditNicknameDialog(context, friend),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white24 : AppColors.hairline,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingRequestsTab(BuildContext context, bool isDark) {
    final requestsAsync = ref.watch(incomingFriendRequestsProvider);
    final actionState = ref.watch(friendActionsProvider);

    return RefreshIndicator(
      color: const Color(0xFFFF5000),
      onRefresh: () async => ref.invalidate(incomingFriendRequestsProvider),
      child: requestsAsync.when(
        loading: () => const PingPayLoadingWidget(
          message: 'กำลังโหลดคำขอเป็นเพื่อน...',
          size: 130,
        ),
        error: (err, _) => Center(child: Text('เกิดข้อผิดพลาด: $err')),
        data: (requests) {
          if (requests.isEmpty) {
            return _buildEmptyState(
              icon: Icons.mark_email_read_outlined,
              title: 'ไม่มีคำขอเป็นเพื่อนใหม่',
              subtitle: 'เมื่อมีเพื่อนส่งคำขอมา จะแสดงรายการให้คุณตอบรับได้ทันทีที่นี่',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final req = requests[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                    ),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: ShapeDecoration(
                            color: const Color(0xFFFFF0E6),
                            shape: const SmoothRectangleBorder(
                              borderRadius: SmoothBorderRadius.all(
                                SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.6),
                              ),
                            ),
                          ),
                          child: ClipSmoothRect(
                            radius: const SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.6),
                            ),
                            child: req.user.avatarUrl != null && req.user.avatarUrl!.isNotEmpty
                                ? Image.network(
                                    req.user.avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        req.user.displayName.isNotEmpty
                                            ? req.user.displayName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF5000),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      req.user.displayName.isNotEmpty
                                          ? req.user.displayName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF5000),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.user.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'รหัส: ${req.user.userCode}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'ขอเป็นเพื่อน',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: actionState.isLoading
                                ? null
                                : () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('ปฏิเสธคำขอ'),
                                        content: Text('คุณต้องการปฏิเสธคำขอเป็นเพื่อนจาก ${req.user.displayName} ใช่หรือไม่?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('ยกเลิก'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                            child: const Text('ปฏิเสธ', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (ok == true) {
                                      final success = await ref
                                          .read(friendActionsProvider.notifier)
                                          .rejectRequest(req.requestId);
                                      if (success && context.mounted) {
                                        AppToast.info(context, 'ปฏิเสธคำขอเรียบร้อยแล้ว');
                                      }
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('ปฏิเสธ', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: actionState.isLoading
                                ? null
                                : () async {
                                    final success = await ref
                                        .read(friendActionsProvider.notifier)
                                        .acceptRequest(req.requestId);
                                    if (success && context.mounted) {
                                      HapticFeedback.mediumImpact();
                                      AppToast.success(context, 'ตอบรับเป็นเพื่อนกับ ${req.user.displayName} แล้ว 🎉');
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5000),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('ยอมรับ', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOutgoingRequestsTab(BuildContext context, bool isDark) {
    final requestsAsync = ref.watch(outgoingFriendRequestsProvider);
    final actionState = ref.watch(friendActionsProvider);

    return RefreshIndicator(
      color: const Color(0xFFFF5000),
      onRefresh: () async => ref.invalidate(outgoingFriendRequestsProvider),
      child: requestsAsync.when(
        loading: () => const PingPayLoadingWidget(
          message: 'กำลังโหลดคำขอที่ส่ง...',
          size: 130,
        ),
        error: (err, _) => Center(child: Text('เกิดข้อผิดพลาด: $err')),
        data: (requests) {
          if (requests.isEmpty) {
            return _buildEmptyState(
              icon: Icons.send_rounded,
              title: 'ไม่มีคำขอที่รอการตอบรับ',
              subtitle: 'คำขอเป็นเพื่อนที่คุณส่งไปหาผู้อื่นจะแสดงที่นี่',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final req = requests[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                    ),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: ShapeDecoration(
                        color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.6),
                          ),
                        ),
                      ),
                      child: ClipSmoothRect(
                        radius: const SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.6),
                        ),
                        child: req.user.avatarUrl != null && req.user.avatarUrl!.isNotEmpty
                            ? Image.network(
                                req.user.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    req.user.displayName.isNotEmpty
                                        ? req.user.displayName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF5000),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  req.user.displayName.isNotEmpty
                                      ? req.user.displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF5000),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.user.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'รอการตอบรับ...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF9500),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: actionState.isLoading
                          ? null
                          : () async {
                              final success = await ref
                                  .read(friendActionsProvider.notifier)
                                  .cancelRequest(req.requestId);
                              if (success && context.mounted) {
                                AppToast.info(context, 'ยกเลิกคำขอเป็นเพื่อนแล้ว');
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text('ยกเลิก', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? primaryActionLabel,
    VoidCallback? onPrimaryAction,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Layered Icon Glow
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF5000).withValues(alpha: isDark ? 0.08 : 0.06),
              ),
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF5000).withValues(alpha: isDark ? 0.16 : 0.12),
                  ),
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF7A00), Color(0xFFFF5000)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(icon, size: 26, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (primaryActionLabel != null && onPrimaryAction != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                height: 46,
                child: ElevatedButton(
                  onPressed: onPrimaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5000),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    primaryActionLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
