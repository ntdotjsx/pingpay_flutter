import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
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
          'จัดการเพื่อน (Friends)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'เพิ่มเพื่อน',
            onPressed: () => context.push('/friends/add'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          labelColor: const Color(0xFFFF5000),
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: const Color(0xFFFF5000),
          indicatorWeight: 3,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/friends/add'),
        backgroundColor: const Color(0xFFFF5000),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'เพิ่มเพื่อน',
          style: TextStyle(fontWeight: FontWeight.bold),
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
              height: 44,
              decoration: ShapeDecoration(
                color: isDark ? AppColors.surfaceTile1 : Colors.white,
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'ค้นหาเพื่อนด้วยชื่อหรือรหัส...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: const Icon(
                        Icons.cancel_rounded,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Friends List View
          Expanded(
            child: friendsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    return Material(
      color: isDark ? AppColors.surfaceTile1 : Colors.white,
      shape: const SmoothRectangleBorder(
        borderRadius: SmoothBorderRadius.all(
          SmoothRadius(cornerRadius: 18, cornerSmoothing: 1.0),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFF0E6),
          child: Text(
            friend.user.displayName.isNotEmpty
                ? friend.user.displayName[0].toUpperCase()
                : 'U',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF5000),
            ),
          ),
        ),
        title: Text(
          friend.user.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          'รหัส: ${friend.user.userCode}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () => context.push('/friends/${friend.friendshipId}'),
      ),
    );
  }

  Widget _buildIncomingRequestsTab(BuildContext context, bool isDark) {
    final requestsAsync = ref.watch(incomingFriendRequestsProvider);
    final actionState = ref.watch(friendActionsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(incomingFriendRequestsProvider),
      child: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                        CircleAvatar(
                          backgroundColor: const Color(0xFFFFF0E6),
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
                    CircleAvatar(
                      backgroundColor: const Color(0xFFFFF0E6),
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
