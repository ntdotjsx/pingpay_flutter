import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/widgets/pingpay_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/friend_models.dart';
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
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 22, color: Color(0xFFFF5000)),
            tooltip: 'เพิ่มเพื่อน',
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                    ),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7A00), Color(0xFFFF5000)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.badge_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
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
                          const SizedBox(height: 2),
                          Text(
                            currentUser!.userCode!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quick Copy Button
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: currentUser.userCode!));
                        HapticFeedback.lightImpact();
                        AppToast.success(context, 'คัดลอกรหัส ${currentUser.userCode} แล้ว');
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 14, color: Color(0xFFFF5000)),
                            SizedBox(width: 4),
                            Text(
                              'คัดลอก',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF5000),
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
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceTile2 : const Color(0xFFE9ECF0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: const Color(0xFFFF5000),
                unselectedLabelColor: isDark ? Colors.white60 : AppColors.inkMuted48,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$incomingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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

          const SizedBox(height: 8),

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              height: 44,
              decoration: ShapeDecoration(
                color: isDark ? AppColors.surfaceTile1 : Colors.white,
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาด้วยชื่อเพื่อน หรือรหัส User ID...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: Icon(
                        Icons.cancel_rounded,
                        size: 18,
                        color: isDark ? AppColors.bodyMuted : Colors.grey,
                      ),
                    ),
                ],
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
                final filtered = friends.where((f) {
                  if (_searchQuery.isEmpty) return true;
                  final name = f.user.displayName.toLowerCase();
                  final code = f.user.userCode.toLowerCase();
                  return name.contains(_searchQuery) || code.contains(_searchQuery);
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
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
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

  Widget _buildFriendCard(
    BuildContext context,
    FriendItemModel friend,
    bool isDark,
  ) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/friends/${friend.friendshipId}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.6),
                      ),
                    ),
                  ),
                  child: ClipSmoothRect(
                    radius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.6),
                    ),
                    child: friend.user.avatarUrl != null && friend.user.avatarUrl!.isNotEmpty
                        ? Image.network(
                            friend.user.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                friend.user.displayName.isNotEmpty
                                    ? friend.user.displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFFFF5000),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              friend.user.displayName.isNotEmpty
                                  ? friend.user.displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFFFF5000),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.user.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFEFF1F5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'รหัส: ${friend.user.userCode}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : AppColors.hairline,
                  size: 20,
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
