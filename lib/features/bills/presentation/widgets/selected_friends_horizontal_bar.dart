import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/theme.dart';
import '../../../friends/models/friend_models.dart';
import '../../services/bill_split_calculator.dart';
import 'friend_selection_bottom_sheet.dart';

class SelectedFriendsHorizontalBar extends StatefulWidget {
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
  State<SelectedFriendsHorizontalBar> createState() =>
      _SelectedFriendsHorizontalBarState();
}

class _SelectedFriendsHorizontalBarState
    extends State<SelectedFriendsHorizontalBar>
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

    _wiggleAnimation = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _wiggleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    HapticFeedback.heavyImpact();
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
        initiallySelectedUserIds: widget.selectedParticipants
            .map((p) => p.userId)
            .toList(),
        onConfirm: widget.onFriendsSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ผู้ร่วมหารบิล (Participants)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (widget.selectedParticipants.isNotEmpty)
              Row(
                children: [
                  if (_isEditMode)
                    GestureDetector(
                      onTap: _exitEditMode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'เสร็จสิ้น',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
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
              // Circular '+' Button with label container structure to align exactly with Avatar items
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

              // Selected Horizontal Avatar List with Long Press & Wiggle Animation
              ...widget.selectedParticipants.map((p) {
                return Semantics(
                  label: '${p.displayName} selected',
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
                      height: 80,
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
                                            p.displayName.isNotEmpty
                                                ? p.displayName[0].toUpperCase()
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
                                          p.displayName.isNotEmpty
                                              ? p.displayName[0].toUpperCase()
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
                              p.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          // Absolute Badge 'X' Button: Only visible when in Long Press Edit Mode
                          if (_isEditMode)
                            Positioned(
                              top: -2,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  widget.onRemoveParticipant(p.userId);
                                  if (widget.selectedParticipants.length <= 1) {
                                    _exitEditMode();
                                  }
                                },
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.surfaceTile1
                                          : AppColors.canvas,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: Colors.white,
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
