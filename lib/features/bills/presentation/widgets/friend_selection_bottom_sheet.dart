import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../friends/models/friend_models.dart';

class FriendSelectionBottomSheet extends StatefulWidget {
  final List<FriendItemModel> allFriends;
  final List<String> initiallySelectedUserIds;
  final ValueChanged<List<FriendItemModel>> onConfirm;

  const FriendSelectionBottomSheet({
    super.key,
    required this.allFriends,
    required this.initiallySelectedUserIds,
    required this.onConfirm,
  });

  @override
  State<FriendSelectionBottomSheet> createState() =>
      _FriendSelectionBottomSheetState();
}

class _FriendSelectionBottomSheetState
    extends State<FriendSelectionBottomSheet> {
  late final Set<String> _selectedUserIds;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedUserIds = Set<String>.from(widget.initiallySelectedUserIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FriendItemModel> get _filteredFriends {
    if (_searchQuery.trim().isEmpty) {
      return widget.allFriends;
    }
    final q = _searchQuery.toLowerCase().trim();
    return widget.allFriends.where((f) {
      final name = f.user.displayName.toLowerCase();
      final code = f.user.userCode.toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  void _toggleSelection(FriendItemModel friend) {
    final userId = friend.user.id ?? friend.friendshipId;
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredFriends;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'เลือกเพื่อน (Select Friends)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'เลือกแล้ว ${_selectedUserIds.length} คน',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: '🔍 ค้นหาเพื่อนด้วยชื่อ หรือ User ID...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkMuted48,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.surfaceTile2
                      : AppColors.canvasParchment,
                  isDense: true,
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.inkMuted48,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Friend List
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'ไม่พบรายชื่อเพื่อนที่ค้นหา',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.bodyMuted
                                : AppColors.inkMuted48,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, idx) {
                        final friend = filtered[idx];
                        final userId = friend.user.id ?? friend.friendshipId;
                        final isSelected = _selectedUserIds.contains(userId);

                        return Material(
                          color: isSelected
                              ? AppColors.primary.withValues(
                                  alpha: isDark ? 0.2 : 0.08,
                                )
                              : Colors.transparent,
                          shape: SmoothRectangleBorder(
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                        ? Colors.white10
                                        : AppColors.dividerSoft),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                            borderRadius: const SmoothBorderRadius.all(
                              SmoothRadius(
                                cornerRadius: 14,
                                cornerSmoothing: 1.0,
                              ),
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _toggleSelection(friend),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    child: Text(
                                      friend.user.displayName.isNotEmpty
                                          ? friend.user.displayName[0]
                                                .toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.user.displayName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark
                                                ? AppColors.bodyOnDark
                                                : AppColors.ink,
                                          ),
                                        ),
                                        Text(
                                          'User ID: ${friend.user.userCode}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.inkMuted48,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (_) => _toggleSelection(friend),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            // Confirm Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  final selectedList = widget.allFriends.where((f) {
                    final uid = f.user.id ?? f.friendshipId;
                    return _selectedUserIds.contains(uid);
                  }).toList();
                  widget.onConfirm(selectedList);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'ยืนยัน (${_selectedUserIds.length} คน)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
