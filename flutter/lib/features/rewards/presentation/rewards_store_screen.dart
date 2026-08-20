import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_toast.dart';
import '../models/reward_models.dart';
import '../providers/reward_providers.dart';

class RewardsStoreScreen extends ConsumerStatefulWidget {
  const RewardsStoreScreen({super.key});

  @override
  ConsumerState<RewardsStoreScreen> createState() => _RewardsStoreScreenState();
}

class _RewardsStoreScreenState extends ConsumerState<RewardsStoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storeState = ref.watch(rewardStoreProvider);
    final catalogAsync = ref.watch(rewardCatalogProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'แลกของรางวัล',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // 1. Points Balance Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(20),
            decoration: ShapeDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shadows: [
                BoxShadow(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              shape: const SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius.all(
                  SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.monetization_on_rounded,
                    size: 32,
                    color: Color(0xFFFFD700),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'แต้มสะสมของคุณ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${storeState.points}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'แต้ม',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'ใช้ได้ทันที',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Custom Tabs (Catalog vs History)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceTile1 : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'ของรางวัลทั้งหมด'),
                Tab(text: 'ประวัติการแลก'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Reward Catalog Grid
                catalogAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text('เกิดข้อผิดพลาด: $err'),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(child: Text('ไม่มีของรางวัลในขณะนี้'));
                    }

                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final canAfford = storeState.points >= item.pointsCost;

                        return _buildRewardItemCard(
                          context: context,
                          item: item,
                          canAfford: canAfford,
                          isDark: isDark,
                        );
                      },
                    );
                  },
                ),

                // Tab 2: Redemption History
                _buildRedemptionHistoryTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardItemCard({
    required BuildContext context,
    required RewardItemModel item,
    required bool canAfford,
    required bool isDark,
  }) {
    return Container(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image / Placeholder
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackImage(),
                    )
                  : _buildFallbackImage(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      size: 16,
                      color: Color(0xFFFFD700),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.pointsCost} แต้ม',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: item.inStock > 0
                        ? () => _showRedeemBottomSheet(context, item)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford ? AppColors.primary : const Color(0xFFB0B0B0),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      item.inStock <= 0
                          ? 'สินค้าหมด'
                          : (canAfford ? 'แลกรับของรางวัล' : 'แต้มไม่พอ'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

  Widget _buildFallbackImage() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(
          Icons.card_giftcard_rounded,
          size: 40,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildRedemptionHistoryTab(bool isDark) {
    final historyAsync = ref.watch(redemptionHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('เกิดข้อผิดพลาด: $err')),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history_rounded, size: 50, color: AppColors.inkMuted48),
                const SizedBox(height: 12),
                Text(
                  'ยังไม่มีประวัติการแลกของรางวัล',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final redemption = items[index];

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: ShapeDecoration(
                color: isDark ? AppColors.surfaceTile1 : Colors.white,
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                shape: SmoothRectangleBorder(
                  side: BorderSide(
                    color: isDark ? Colors.white10 : AppColors.hairline,
                    width: 1,
                  ),
                  borderRadius: const SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 18, cornerSmoothing: 1.0),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: AppColors.success,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              redemption.rewardItem.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                            ),
                            Text(
                              'ใช้ไป ${redemption.pointsSpent} แต้ม',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'เตรียมจัดส่ง',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    'ผู้รับ: ${redemption.recipientName} (${redemption.phoneNumber})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ที่อยู่จัดส่ง: ${redemption.shippingAddress}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRedeemBottomSheet(BuildContext context, RewardItemModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storeState = ref.read(rewardStoreProvider);

    final nameController = TextEditingController(
      text: storeState.shippingRecipientName ?? '',
    );
    final phoneController = TextEditingController(
      text: storeState.shippingPhone ?? '',
    );
    final addressController = TextEditingController(
      text: storeState.shippingAddress ?? '',
    );

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isRedeeming = ref.watch(rewardStoreProvider).isRedeeming;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceTile1 : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 16,
                left: 20,
                right: 20,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : AppColors.hairline,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ยืนยันการแลกรับของรางวัล',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'ใช้ ${item.pointsCost} แต้ม เพื่อแลกรับสิ่งนี้',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Item preview card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: item.imageUrl != null
                                      ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                                      : _buildFallbackImage(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (item.description != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        item.description!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.inkMuted48,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'ที่อยู่จัดส่งของรางวัล (บันทึกลงระบบทันที)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Recipient Name
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'ชื่อ-นามสกุล ผู้รับ',
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                            filled: true,
                            fillColor: isDark ? AppColors.surfaceTile2 : const Color(0xFFF6F7F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'กรุณาระบุชื่อผู้รับ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        // Phone Number
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'เบอร์โทรศัพท์ติดต่อ',
                            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                            filled: true,
                            fillColor: isDark ? AppColors.surfaceTile2 : const Color(0xFFF6F7F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().length < 9) {
                              return 'กรุณาระบุเบอร์โทรศัพท์ที่ถูกต้อง';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        // Full Address
                        TextFormField(
                          controller: addressController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'ที่อยู่จัดส่ง (บ้านเลขที่, ถนน, ตำบล, อำเภอ, จังหวัด, รหัสไปรษณีย์)',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 40),
                              child: Icon(Icons.location_on_outlined, size: 20),
                            ),
                            filled: true,
                            fillColor: isDark ? AppColors.surfaceTile2 : const Color(0xFFF6F7F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().length < 5) {
                              return 'กรุณาระบุที่อยู่จัดส่งให้ครบถ้วน';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Submit Button
                        ElevatedButton(
                          onPressed: isRedeeming
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  final success = await ref
                                      .read(rewardStoreProvider.notifier)
                                      .redeemReward(
                                        rewardItemId: item.id,
                                        recipientName: nameController.text.trim(),
                                        phoneNumber: phoneController.text.trim(),
                                        shippingAddress: addressController.text.trim(),
                                      );

                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    if (success) {
                                      AppToast.success(
                                        context,
                                        'แลกรับ "${item.title}" สำเร็จ! ทางเราจะจัดส่งให้เร็วที่สุด',
                                      );
                                    } else {
                                      final err = ref.read(rewardStoreProvider).errorMessage;
                                      AppToast.error(
                                        context,
                                        err ?? 'ไม่สามารถแลกของรางวัลได้',
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isRedeeming
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'ยืนยันแลกรับของรางวัล',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
