import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/pingpay_loading.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final incomingRequests = ref.watch(incomingFriendRequestsProvider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.surfaceBlack
          : const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text(
          'เพื่อน (Friends)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF6F7F9),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
            tooltip: 'เพิ่มเพื่อน',
            onPressed: () => context.push('/friends/add'),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          labelColor: const Color(0xFFFF5000),
          unselectedLabelColor: isDark ? Colors.white60 : AppColors.inkMuted48,
          indicatorColor: const Color(0xFFFF5000),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: [
            const Tab(text: 'เพื่อนของฉัน'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('คำขอเข้า'),
                  incomingRequests.maybeWhen(
                    data: (reqs) => reqs.isNotEmpty
                        ? Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3B30),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${reqs.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const Tab(text: 'คำขอที่ส่ง'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsListTab(context, isDark),
          _buildIncomingRequestsTab(context, isDark),
          _buildOutgoingRequestsTab(context, isDark),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5000).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/friends/add'),
          backgroundColor: const Color(0xFFFF5000),
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 2,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 16, cornerSmoothing: 0.6),
            ),
          ),
          icon: const Icon(Icons.person_add_rounded, size: 20),
          label: const Text(
            'เพิ่มเพื่อน',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsListTab(BuildContext context, bool isDark) {
    final friendsAsync = ref.watch(friendsListProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(friendsListProvider);
      },
      child: Column(
        children: [
          // Search input field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 46,
              decoration: ShapeDecoration(
                color: isDark ? AppColors.surfaceTile1 : Colors.white,
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
                  ),
                ),
                shadows: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
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
                        hintText: 'ค้นหาเพื่อนด้วยชื่อหรือรหัส User ID...',
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
                  return name.contains(_searchQuery) ||
                      code.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: _searchQuery.isEmpty
                        ? 'ยังไม่มีเพื่อนในระบบ'
                        : 'ไม่พบเพื่อนที่ค้นหา',
                    subtitle: _searchQuery.isEmpty
                        ? 'เพิ่มเพื่อนด้วยรหัส User ID เพื่อเริ่มหารบิลร่วมกัน'
                        : 'ลองค้นหาด้วยคำอื่น หรือกดเพิ่มเพื่อนใหม่',
                    actionLabel: '+ เพิ่มเพื่อนทันที',
                    onAction: () => context.push('/friends/add'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
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
            SmoothRadius(cornerRadius: 18, cornerSmoothing: 1.0),
          ),
        ),
        shadows: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
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
                Container(
                  width: 44,
                  height: 44,
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
                                  fontSize: 16,
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
                                fontSize: 16,
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
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'รหัส: ${friend.user.userCode}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          letterSpacing: 0.2,
                        ),
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
              title: 'ไม่มีคำขอเป็นเพื่อน',
              subtitle: 'เมื่อมีเพื่อนส่งคำขอมา จะแสดงรายการให้คุณตอบรับที่นี่',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final req = requests[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 18, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'รหัส: ${req.user.userCode}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
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
                                        title: const Text(
                                          'ปฏิเสธคำขอเป็นเพื่อน?',
                                        ),
                                        content: Text(
                                          'คุณต้องการปฏิเสธคำขอจาก ${req.user.displayName} หรือไม่?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('ยกเลิก'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text(
                                              'ปฏิเสธ',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await ref
                                          .read(friendActionsProvider.notifier)
                                          .rejectRequest(req.requestId);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('ปฏิเสธ'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: actionState.isLoading
                                ? null
                                : () async {
                                    await ref
                                        .read(friendActionsProvider.notifier)
                                        .acceptRequest(req.requestId);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5000),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'ยอมรับ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
              icon: Icons.outbox_rounded,
              title: 'ไม่มีคำขอที่กำลังรอการตอบรับ',
              subtitle: 'คำขอเป็นเพื่อนที่คุณส่งให้ผู้อื่นจะแสดงที่นี่',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final req = requests[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 18, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'รหัส: ${req.user.userCode}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: actionState.isLoading
                          ? null
                          : () async {
                              await ref
                                  .read(friendActionsProvider.notifier)
                                  .cancelRequest(req.requestId);
                            },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(fontSize: 12),
                      ),
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
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
