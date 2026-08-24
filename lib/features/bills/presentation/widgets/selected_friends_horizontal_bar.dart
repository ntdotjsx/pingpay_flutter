import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../friends/models/friend_models.dart';
import '../../../friends/providers/friend_nickname_provider.dart';
import '../../services/bill_split_calculator.dart';
import 'friend_selection_bottom_sheet.dart';

class SelectedFriendsHorizontalBar extends ConsumerStatefulWidget {
  final List<FriendItemModel> allFriends;
  final List<BillSplitParticipant> selectedParticipants;
  final ValueChanged<List<FriendItemModel>> onFriendsSelected;
  final ValueChanged<String> onRemoveParticipant;

  const SelectedFriendsHorizontalBar({
    super.key,
    required this.allFriends,
    required this.selectedParticipants,
    required this.onFriendsSelected,
    required this.onRemoveParticipant,
  });

  @override
  ConsumerState<SelectedFriendsHorizontalBar> createState() =>
      _SelectedFriendsHorizontalBarState();
}

class _SelectedFriendsHorizontalBarState
    extends ConsumerState<SelectedFriendsHorizontalBar>
    with SingleTickerProviderStateMixin {
  bool _isEditMode = false;
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _wiggleAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _wiggleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isEditMode = true;
    });
    _wiggleController.repeat(reverse: true);
  }

  void _exitEditMode() {
    if (_isEditMode) {
      setState(() {
        _isEditMode = false;
      });
      _wiggleController.stop();
      _wiggleController.reset();
    }
  }

  void _openFriendSelection(BuildContext context) {
    _exitEditMode();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FriendSelectionBottomSheet(
        allFriends: widget.allFriends,
        initiallySelectedUserIds:
            widget.selectedParticipants.map((p) => p.userId).toList(),
        onConfirm: widget.onFriendsSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nicknamesMap = ref.watch(friendNicknameProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'เพื่อนที่หารบิลนี้',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                if (_isEditMode) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _exitEditMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'เสร็จสิ้น',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (!_isEditMode)
              Row(
                children: [
                  if (widget.selectedParticipants.isNotEmpty)
                    Text(
                      'กดค้างเพื่อลบเพื่อน  •  ',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                      ),
                    ),
                  Text(
                    'เลือกแล้ว ${widget.selectedParticipants.length} คน',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              // Circular '+' Button
              Semantics(
                label: 'Add friend to bill',
                button: true,
                child: GestureDetector(
                  onTap: () => _openFriendSelection(context),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 54,
                    height: 82,
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? AppColors.surfaceTile2
                            : AppColors.canvasParchment,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.5,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),

              // Selected Horizontal Avatar List
              ...widget.selectedParticipants.map((p) {
                final nick = (nicknamesMap[p.userId] ?? (p.userCode != null ? nicknamesMap[p.userCode] : null));
                final effectiveDisplayName = (nick != null && nick.trim().isNotEmpty) ? nick : p.displayName;

                return Semantics(
                  label: '$effectiveDisplayName selected',
                  child: GestureDetector(
                    onLongPress: _enterEditMode,
                    onTap: () {
                      if (_isEditMode) {
                        _exitEditMode();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 56,
                      height: 82,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          // Animated Jiggle Avatar
                          AnimatedBuilder(
                            animation: _wiggleAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _isEditMode
                                    ? _wiggleAnimation.value
                                    : 0.0,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: (p.avatarUrl != null && p.avatarUrl!.trim().isNotEmpty)
                                    ? Image.network(
                                        p.avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            effectiveDisplayName.isNotEmpty
                                                ? effectiveDisplayName[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          effectiveDisplayName.isNotEmpty
                                              ? effectiveDisplayName[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          // Absolute Display Name below Avatar
                          Positioned(
                            top: 56,
                            left: 0,
                            right: 0,
                            child: Text(
                              effectiveDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          // Absolute Badge 'X' Button
                          if (_isEditMode)
                            Positioned(
                              top: -2,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  widget.onRemoveParticipant(p.userId);
                                },
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? AppColors.surfaceTile1 : Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
