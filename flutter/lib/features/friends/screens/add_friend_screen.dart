import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../models/friend_models.dart';
import '../providers/friends_provider.dart';

class AddFriendScreen extends ConsumerStatefulWidget {
  const AddFriendScreen({super.key});

  @override
  ConsumerState<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends ConsumerState<AddFriendScreen> {
  final TextEditingController _codeController = TextEditingController();
  UserSearchModel? _searchResult;
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _codeController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResult = null;
    });

    try {
      final repo = ref.read(friendsRepositoryProvider);
      final result = await repo.searchUser(query);
      if (result == null) {
        setState(() {
          _isSearching = false;
          _searchError = 'ไม่พบผู้ใช้งานด้วยรหัส "$query"';
        });
      } else {
        setState(() {
          _isSearching = false;
          _searchResult = result;
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchError = 'เกิดข้อผิดพลาดในการค้นหา: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionState = ref.watch(friendActionsProvider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.surfaceBlack
          : const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text(
          'เพิ่มเพื่อนใหม่',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Input Box
              Container(
                padding: const EdgeInsets.all(18),
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 20, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ค้นหาด้วยรหัสประจำตัว (User Code / ID)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'กรอกรหัสประจำตัวของผู้ใช้เพื่อส่งคำขอเป็นเพื่อน (ต้องให้ทั้งสองฝ่ายตอบรับก่อน)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'เช่น USR-ABCD123',
                              prefixIcon: const Icon(Icons.tag_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _isSearching ? null : _performSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          child: _isSearching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'ค้นหา',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Search Error Box
              if (_searchError != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _searchError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Search Result Card
              if (_searchResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: ShapeDecoration(
                    color: isDark ? AppColors.surfaceTile1 : Colors.white,
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 20, cornerSmoothing: 1.0),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: const Color(0xFFFFF0E6),
                            child: Text(
                              _searchResult!.displayName.isNotEmpty
                                  ? _searchResult!.displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFFFF5000),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _searchResult!.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'รหัส: ${_searchResult!.userCode}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildRelationshipBadge(_searchResult!.relationship),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Action Button based on Relationship State
                      _buildActionButtonForRelationship(
                        _searchResult!,
                        actionState,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRelationshipBadge(RelationshipState rel) {
    String text;
    Color bg;
    Color fg;

    switch (rel) {
      case RelationshipState.self:
        text = 'ตัวเอง';
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        break;
      case RelationshipState.friend:
        text = 'เพื่อนแล้ว';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case RelationshipState.outgoingRequest:
        text = 'ส่งคำขอแล้ว';
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case RelationshipState.incomingRequest:
        text = 'ส่งคำขอถึงคุณ';
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      case RelationshipState.blocked:
        text = 'ถูกระงับ';
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      case RelationshipState.none:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildActionButtonForRelationship(
    UserSearchModel user,
    FriendActionState actionState,
  ) {
    if (user.relationship == RelationshipState.self) {
      return const OutlinedButton(
        onPressed: null,
        child: Text('ไม่สามารถส่งคำขอให้ตัวเองได้'),
      );
    }

    if (user.relationship == RelationshipState.friend) {
      return const OutlinedButton(
        onPressed: null,
        child: Text('คุณและผู้ใช้นี้เป็นเพื่อนกันอยู่แล้ว'),
      );
    }

    if (user.relationship == RelationshipState.outgoingRequest) {
      return const OutlinedButton(
        onPressed: null,
        child: Text('ส่งคำขอไปแล้ว (รอการตอบรับ)'),
      );
    }

    if (user.relationship == RelationshipState.incomingRequest) {
      return ElevatedButton(
        onPressed: () {
          context.pop();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5000),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text(
          'ตรวจสอบในกล่องคำขอเข้า',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    return ElevatedButton(
      onPressed: actionState.isLoading
          ? null
          : () async {
              final router = GoRouter.of(context);
              final ok = await ref
                  .read(friendActionsProvider.notifier)
                  .sendRequest(user.userCode);
              if (ok) {
                if (mounted) {
                  AppToast.success(context, 'ส่งคำขอเป็นเพื่อนเรียบร้อยแล้ว รอการตอบรับ');
                  router.pop();
                }
              } else {
                if (mounted) {
                  final err = ref.read(friendActionsProvider).errorMessage;
                  AppToast.error(context, err ?? 'ส่งคำขอไม่สำเร็จ');
                }
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF5000),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: actionState.isLoading
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Text('กำลังส่งคำขอ...'),
              ],
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  'ส่งคำขอเป็นเพื่อน (Send Friend Request)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
    );
  }
}
