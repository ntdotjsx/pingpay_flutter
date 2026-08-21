import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bills/models/bill_models.dart';
import '../../../bills/providers/bill_provider.dart';
import '../../../friends/models/friend_models.dart';
import '../../../friends/providers/friends_provider.dart';
import '../../../payments/models/payment_models.dart';
import '../../../payments/providers/payment_providers.dart';
import '../../../payments/presentation/widgets/debt_acknowledgement_detail_sheet.dart';
import '../../../payments/presentation/widgets/payment_detail_bottom_sheet.dart';

class GlobalSearchSheet extends ConsumerStatefulWidget {
  const GlobalSearchSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GlobalSearchSheet(),
    );
  }

  @override
  ConsumerState<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends ConsumerState<GlobalSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  int _selectedFilterTag = 0; // 0: ทั้งหมด, 1: เพื่อน, 2: บิลของฉัน, 3: หนี้สิน

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendsAsync = ref.watch(friendsListProvider);
    final myBillsAsync = ref.watch(myBillsProvider);
    final debtsState = ref.watch(userDebtsProvider);
    final cleanQuery = _query.trim().toLowerCase();

    // 1. Filter Friends
    final allFriends = friendsAsync.valueOrNull ?? [];
    final filteredFriends = cleanQuery.isEmpty
        ? <FriendItemModel>[]
        : allFriends.where((f) {
            final name = f.user.displayName.toLowerCase();
            final code = f.user.userCode.toLowerCase();
            return name.contains(cleanQuery) || code.contains(cleanQuery);
          }).toList();

    // 2. Filter My Bills
    final allBills = myBillsAsync.valueOrNull ?? [];
    final filteredBills = cleanQuery.isEmpty
        ? <BillModel>[]
        : allBills.where((b) {
            final title = (b.title ?? '').toLowerCase();
            final desc = (b.description ?? '').toLowerCase();
            final debtorMatch = b.items.any((i) =>
                (i.debtor?.displayName.toLowerCase().contains(cleanQuery) ?? false) ||
                (i.debtor?.userCode.toLowerCase().contains(cleanQuery) ?? false));
            return title.contains(cleanQuery) || desc.contains(cleanQuery) || debtorMatch;
          }).toList();

    // 3. Filter Debts We Owe (เราติดเพื่อน)
    final allDebts = debtsState.allDebts;
    final filteredDebts = cleanQuery.isEmpty
        ? <DebtItemModel>[]
        : allDebts.where((d) {
            final title = d.billTitle.toLowerCase();
            final creditorName = d.creditor.displayName.toLowerCase();
            final code = d.creditor.userCode.toLowerCase();
            return title.contains(cleanQuery) || creditorName.contains(cleanQuery) || code.contains(cleanQuery);
          }).toList();

    // Total Results Count
    final int totalCount = (_selectedFilterTag == 0
        ? (filteredFriends.length + filteredBills.length + filteredDebts.length)
        : (_selectedFilterTag == 1
            ? filteredFriends.length
            : (_selectedFilterTag == 2 ? filteredBills.length : filteredDebts.length)));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Search Header Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: ShapeDecoration(
                        color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            size: 22,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'ค้นหาชื่อเพื่อน, บิล, หรือยอดเงิน...',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) => setState(() => _query = val),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(
                                Icons.cancel_rounded,
                                size: 18,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Filter Tabs (Chips)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip(0, 'ทั้งหมด ($totalCount)', isDark),
                  _buildFilterChip(1, 'เพื่อน (${filteredFriends.length})', isDark),
                  _buildFilterChip(2, 'บิลของฉัน (${filteredBills.length})', isDark),
                  _buildFilterChip(3, 'เราติดเพื่อน (${filteredDebts.length})', isDark),
                ],
              ),
            ),

            const SizedBox(height: 10),
            Divider(height: 1, color: isDark ? Colors.white10 : AppColors.hairline),

            // Search Results List Body
            Expanded(
              child: cleanQuery.isEmpty
                  ? _buildInitialEmptyState(isDark)
                  : totalCount == 0
                      ? _buildNoResultsState(isDark, cleanQuery)
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            // 1. Friends Section
                            if ((_selectedFilterTag == 0 || _selectedFilterTag == 1) &&
                                filteredFriends.isNotEmpty) ...[
                              _buildSectionTitle('เพื่อน (${filteredFriends.length})', isDark),
                              const SizedBox(height: 8),
                              ...filteredFriends.map((f) => _buildFriendResultTile(f, isDark)),
                              const SizedBox(height: 16),
                            ],

                            // 2. My Bills Section
                            if ((_selectedFilterTag == 0 || _selectedFilterTag == 2) &&
                                filteredBills.isNotEmpty) ...[
                              _buildSectionTitle('บิลของฉัน (${filteredBills.length})', isDark),
                              const SizedBox(height: 8),
                              ...filteredBills.map((b) => _buildBillResultTile(b, isDark)),
                              const SizedBox(height: 16),
                            ],

                            // 3. Debts We Owe Section
                            if ((_selectedFilterTag == 0 || _selectedFilterTag == 3) &&
                                filteredDebts.isNotEmpty) ...[
                              _buildSectionTitle('รายการที่เราติดเพื่อน (${filteredDebts.length})', isDark),
                              const SizedBox(height: 8),
                              ...filteredDebts.map((d) => _buildDebtResultTile(d, isDark)),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, bool isDark) {
    final isSelected = _selectedFilterTag == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _selectedFilterTag = index);
        },
        selectedColor: AppColors.primary,
        backgroundColor: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (isDark ? AppColors.bodyMuted : AppColors.ink),
        ),
        side: BorderSide(
          color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : AppColors.hairline),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
      ),
    );
  }

  Widget _buildFriendResultTile(FriendItemModel f, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
        shape: SmoothRectangleBorder(
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
          ),
          side: BorderSide(color: isDark ? Colors.white10 : AppColors.hairline),
        ),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).pop();
          context.push('/friends/${f.friendshipId}');
        },
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundImage: f.user.avatarUrl != null && f.user.avatarUrl!.isNotEmpty
              ? NetworkImage(f.user.avatarUrl!)
              : null,
          child: f.user.avatarUrl == null || f.user.avatarUrl!.isEmpty
              ? Text(
                  f.user.displayName.isNotEmpty ? f.user.displayName[0].toUpperCase() : 'U',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                )
              : null,
        ),
        title: Text(
          f.user.displayName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
        subtitle: Text(
          'รหัส: ${f.user.userCode}',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
      ),
    );
  }

  Widget _buildBillResultTile(BillModel b, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
        shape: SmoothRectangleBorder(
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
          ),
          side: BorderSide(color: isDark ? Colors.white10 : AppColors.hairline),
        ),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).pop();
          context.push('/bills/detail/${b.id}');
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFF5000).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.receipt_rounded, color: Color(0xFFFF5000), size: 20),
        ),
        title: Text(
          b.title ?? 'บิลค่าใช้จ่าย',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
        subtitle: Text(
          'ผู้ร่วมหาร ${b.items.length} คน',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '฿${b.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.primary,
              ),
            ),
            const Text(
              'ยอดรวมบิล',
              style: TextStyle(fontSize: 10, color: AppColors.inkMuted48),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtResultTile(DebtItemModel d, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
        shape: SmoothRectangleBorder(
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
          ),
          side: BorderSide(color: isDark ? Colors.white10 : AppColors.hairline),
        ),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).pop();
          if (!d.isAcknowledged) {
            DebtAcknowledgementDetailSheet.show(context, d);
          } else {
            PaymentDetailBottomSheet.show(context, d);
          }
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.payment_rounded, color: Color(0xFFFF9500), size: 20),
        ),
        title: Text(
          d.billTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
        subtitle: Text(
          'เจ้าหนี้: ${d.creditor.displayName}',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '฿${d.outstandingAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFFFF9500),
              ),
            ),
            Text(
              !d.isAcknowledged ? 'รอตรวจสอบ' : 'ค้างชำระ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: !d.isAcknowledged ? const Color(0xFFFF9500) : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.manage_search_rounded, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'ค้นหาข้อมูลได้อย่างรวดเร็ว',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'พิมพ์ชื่อเพื่อน, รายการบิล หรือยอดเงิน เพื่อค้นหาทันที',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.inkMuted48),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(bool isDark, String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.inkMuted48),
            const SizedBox(height: 16),
            Text(
              'ไม่พบผลการค้นหาสำหรับ "$query"',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'ลองค้นหาด้วยคำค้นอื่น เช่น ชื่อเพื่อน หรือชื่อรายการบิล',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted48),
            ),
          ],
        ),
      ),
    );
  }
}
