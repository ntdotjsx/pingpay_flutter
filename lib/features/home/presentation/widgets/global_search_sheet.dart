import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bills/models/bill_models.dart';
import '../../../bills/providers/bill_provider.dart';
import '../../../friends/models/friend_models.dart';
import '../../../friends/providers/friend_nickname_provider.dart';
import '../../../friends/providers/friends_provider.dart';
import '../../../payments/models/payment_models.dart';
import '../../../payments/presentation/widgets/debt_acknowledgement_detail_sheet.dart';
import '../../../payments/presentation/widgets/friend_receivable_detail_bottom_sheet.dart';
import '../../../payments/presentation/widgets/payment_detail_bottom_sheet.dart';
import '../../../payments/providers/payment_providers.dart';
import '../../../payments/services/debt_age_calculator.dart';

enum SearchFilterCategory {
  all, // ทั้งหมด
  friends, // เพื่อน
  bills, // บิลของฉัน
  receivables, // เพื่อนติดเรา
  debts, // เราติดเพื่อน
}

class GlobalSearchSheet extends ConsumerStatefulWidget {
  const GlobalSearchSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GlobalSearchSheet(),
    );
  }

  @override
  ConsumerState<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends ConsumerState<GlobalSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  SearchFilterCategory _selectedCategory = SearchFilterCategory.all;

  @override
  void initState() {
    super.initState();
    // Auto focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applyQuickTag(String keyword) {
    HapticFeedback.selectionClick();
    _searchController.text = keyword;
    setState(() {
      _query = keyword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch providers
    final friendsAsync = ref.watch(friendsListProvider);
    final myBillsAsync = ref.watch(myBillsProvider);
    final receivablesState = ref.watch(userReceivablesProvider);
    final debtsState = ref.watch(userDebtsProvider);
    final nicknamesMap = ref.watch(friendNicknameProvider);

    final cleanQuery = _query.trim().toLowerCase();
    final queryNumber = double.tryParse(cleanQuery.replaceAll(RegExp(r'[^0-9.]'), ''));

    // ── 1. Comprehensive Search: Friends ──────────────────────────────────
    final allFriends = friendsAsync.valueOrNull ?? [];
    final filteredFriends = cleanQuery.isEmpty
        ? <FriendItemModel>[]
        : allFriends.where((f) {
            final nick = (nicknamesMap[f.user.id] ?? nicknamesMap[f.user.userCode] ?? '').toLowerCase();
            final name = f.user.displayName.toLowerCase();
            final code = f.user.userCode.toLowerCase();
            return name.contains(cleanQuery) || nick.contains(cleanQuery) || code.contains(cleanQuery);
          }).toList();

    // ── 2. Comprehensive Search: Bills ────────────────────────────────────
    final allBills = myBillsAsync.valueOrNull ?? [];
    final filteredBills = cleanQuery.isEmpty
        ? <BillModel>[]
        : allBills.where((b) {
            final title = (b.title ?? '').toLowerCase();
            final desc = (b.description ?? '').toLowerCase();

            // Match by participants (names, nicknames, codes)
            final participantMatch = b.items.any((item) {
              final dName = item.debtor?.displayName.toLowerCase() ?? '';
              final dCode = item.debtor?.userCode.toLowerCase() ?? '';
              final dNick = (item.debtor != null
                      ? (nicknamesMap[item.debtor!.id] ?? nicknamesMap[item.debtor!.userCode] ?? '')
                      : '')
                  .toLowerCase();
              return dName.contains(cleanQuery) || dNick.contains(cleanQuery) || dCode.contains(cleanQuery);
            });

            // Match by total amount or item amounts
            final amountMatch = queryNumber != null &&
                (b.totalAmount.toString().contains(cleanQuery) ||
                    (b.totalAmount - queryNumber).abs() < 1.0 ||
                    b.items.any((i) => (i.currentAmount - queryNumber).abs() < 1.0));

            return title.contains(cleanQuery) || desc.contains(cleanQuery) || participantMatch || amountMatch;
          }).toList();

    // ── 3. Comprehensive Search: Receivables (เพื่อนติดเรา) ─────────────────
    final allReceivables = receivablesState.allFriends;
    final filteredReceivables = cleanQuery.isEmpty
        ? <ReceivableFriendModel>[]
        : allReceivables.where((rf) {
            final nick = (nicknamesMap[rf.debtor.id] ?? nicknamesMap[rf.debtor.userCode] ?? '').toLowerCase();
            final name = rf.debtor.displayName.toLowerCase();
            final code = rf.debtor.userCode.toLowerCase();
            final billTitleMatch = rf.bills.any((b) => b.billTitle.toLowerCase().contains(cleanQuery));

            final amountMatch = queryNumber != null &&
                (rf.totalOutstandingAmount.toString().contains(cleanQuery) ||
                    (rf.totalOutstandingAmount - queryNumber).abs() < 1.0);

            return name.contains(cleanQuery) ||
                nick.contains(cleanQuery) ||
                code.contains(cleanQuery) ||
                billTitleMatch ||
                amountMatch;
          }).toList();

    // ── 4. Comprehensive Search: Debts (เราติดเพื่อน) ───────────────────────
    final allDebts = debtsState.allDebts;
    final filteredDebts = cleanQuery.isEmpty
        ? <DebtItemModel>[]
        : allDebts.where((d) {
            final nick = (nicknamesMap[d.creditor.id] ?? nicknamesMap[d.creditor.userCode] ?? '').toLowerCase();
            final creditorName = d.creditor.displayName.toLowerCase();
            final code = d.creditor.userCode.toLowerCase();
            final title = d.billTitle.toLowerCase();

            final amountMatch = queryNumber != null &&
                (d.outstandingAmount.toString().contains(cleanQuery) ||
                    (d.outstandingAmount - queryNumber).abs() < 1.0);

            return title.contains(cleanQuery) ||
                creditorName.contains(cleanQuery) ||
                nick.contains(cleanQuery) ||
                code.contains(cleanQuery) ||
                amountMatch;
          }).toList();

    // Total results count based on selected category
    final int totalCount = switch (_selectedCategory) {
      SearchFilterCategory.all =>
        filteredFriends.length + filteredBills.length + filteredReceivables.length + filteredDebts.length,
      SearchFilterCategory.friends => filteredFriends.length,
      SearchFilterCategory.bills => filteredBills.length,
      SearchFilterCategory.receivables => filteredReceivables.length,
      SearchFilterCategory.debts => filteredDebts.length,
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceBlack : const Color(0xFFFAFBFD),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Search Input Header Bar ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: ShapeDecoration(
                      color: isDark ? AppColors.surfaceTile1 : Colors.white,
                      shape: SmoothRectangleBorder(
                        side: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                          width: 0.9,
                        ),
                        borderRadius: const SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
                        ),
                      ),
                      shadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 22,
                          color: Color(0xFFFF5000),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ค้นหาชื่อเพื่อน, บิล, หรือยอดเงิน...',
                              hintStyle: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
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
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.cancel_rounded,
                                size: 18,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    foregroundColor: const Color(0xFFFF5000),
                    textStyle: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('ยกเลิก'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Category Filter Pills Bar ────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildCategoryPill(
                  category: SearchFilterCategory.all,
                  label: 'ทั้งหมด',
                  count: filteredFriends.length +
                      filteredBills.length +
                      filteredReceivables.length +
                      filteredDebts.length,
                  isDark: isDark,
                ),
                _buildCategoryPill(
                  category: SearchFilterCategory.friends,
                  label: 'เพื่อน',
                  count: filteredFriends.length,
                  isDark: isDark,
                ),
                _buildCategoryPill(
                  category: SearchFilterCategory.bills,
                  label: 'บิลของฉัน',
                  count: filteredBills.length,
                  isDark: isDark,
                ),
                _buildCategoryPill(
                  category: SearchFilterCategory.receivables,
                  label: 'เพื่อนติดเรา',
                  count: filteredReceivables.length,
                  isDark: isDark,
                ),
                _buildCategoryPill(
                  category: SearchFilterCategory.debts,
                  label: 'เราติดเพื่อน',
                  count: filteredDebts.length,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 0.6,
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
          ),

          // ── Search Content Body ─────────────────────────────────────────
          Expanded(
            child: cleanQuery.isEmpty
                ? _buildInitialDiscoveryView(
                    isDark,
                    allFriends.length,
                    allBills.length,
                    allReceivables.length,
                    allDebts.length,
                  )
                : totalCount == 0
                    ? _buildNoResultsView(isDark, cleanQuery)
                    : _buildSearchResultsListView(
                        context,
                        filteredFriends,
                        filteredBills,
                        filteredReceivables,
                        filteredDebts,
                        nicknamesMap,
                        isDark,
                      ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CATEGORY PILL WIDGET
  // =========================================================================
  Widget _buildCategoryPill({
    required SearchFilterCategory category,
    required String label,
    required int count,
    required bool isDark,
  }) {
    final isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedCategory = category;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          decoration: ShapeDecoration(
            color: isSelected
                ? const Color(0xFFFF5000)
                : (isDark ? AppColors.surfaceTile1 : Colors.white),
            shape: SmoothRectangleBorder(
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFFFF5000)
                    : (isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                width: 0.8,
              ),
              borderRadius: const SmoothBorderRadius.all(
                SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.8),
              ),
            ),
            shadows: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF5000).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.bodyMuted : AppColors.ink),
                ),
              ),
              if (_query.isNotEmpty) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : (isDark ? Colors.white12 : const Color(0xFFF0F2F5)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // INITIAL DISCOVERY & QUICK SUGGESTIONS VIEW
  // =========================================================================
  Widget _buildInitialDiscoveryView(
    bool isDark,
    int friendCount,
    int billCount,
    int receivableCount,
    int debtCount,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      children: [
        // Quick Keywords Header
        Text(
          'คำค้นหายอดนิยม',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
          ),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickTagChip('🍲 ค่าอาหาร', isDark),
            _buildQuickTagChip('⚡ ค้างชำระ', isDark),
            _buildQuickTagChip('☕ ค่ากาแฟ', isDark),
            _buildQuickTagChip('🏠 ค่าห้อง / ค่าน้ำไฟ', isDark),
            _buildQuickTagChip('🚗 ค่าเดินทาง', isDark),
            _buildQuickTagChip('🛒 ช้อปปิ้ง', isDark),
          ],
        ),

        const SizedBox(height: 24),

        // Quick Category Summary Cards
        Text(
          'ภาพรวมข้อมูลในระบบของคุณ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildSummaryMiniCard(
                icon: Icons.people_alt_rounded,
                iconColor: const Color(0xFF007AFF),
                title: 'เพื่อนทั้งหมด',
                value: '$friendCount คน',
                onTap: () => setState(() => _selectedCategory = SearchFilterCategory.friends),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryMiniCard(
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFFFF9500),
                title: 'บิลของคุณ',
                value: '$billCount บิล',
                onTap: () => setState(() => _selectedCategory = SearchFilterCategory.bills),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSummaryMiniCard(
                icon: Icons.arrow_downward_rounded,
                iconColor: const Color(0xFFFF5000),
                title: 'เพื่อนติดเรา',
                value: '$receivableCount คน',
                onTap: () => setState(() => _selectedCategory = SearchFilterCategory.receivables),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryMiniCard(
                icon: Icons.arrow_upward_rounded,
                iconColor: const Color(0xFFFF3B30),
                title: 'เราติดเพื่อน',
                value: '$debtCount รายการ',
                onTap: () => setState(() => _selectedCategory = SearchFilterCategory.debts),
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Search Info Tip Card
        Container(
          padding: const EdgeInsets.all(14),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFF5000), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'พิมพ์ชื่อเล่นเฉพาะบุคคล, รหัสผู้ใช้, ชื่อบิล หรือพิมพ์จำนวนเงิน เช่น "500" เพื่อค้นหายอดเงินได้ทันที',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTagChip(String label, bool isDark) {
    return InkWell(
      onTap: () => _applyQuickTag(label.replaceAll(RegExp(r'^[^\s]+\s+'), '')),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          shape: SmoothRectangleBorder(
            side: BorderSide(
              color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
              width: 0.8,
            ),
            borderRadius: const SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.6),
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMiniCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          shape: SmoothRectangleBorder(
            side: BorderSide(
              color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
              width: 0.8,
            ),
            borderRadius: const SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SEARCH RESULTS LIST VIEW
  // =========================================================================
  Widget _buildSearchResultsListView(
    BuildContext context,
    List<FriendItemModel> friends,
    List<BillModel> bills,
    List<ReceivableFriendModel> receivables,
    List<DebtItemModel> debts,
    Map<String, String> nicknamesMap,
    bool isDark,
  ) {
    final showFriends = (_selectedCategory == SearchFilterCategory.all ||
            _selectedCategory == SearchFilterCategory.friends) &&
        friends.isNotEmpty;

    final showBills = (_selectedCategory == SearchFilterCategory.all ||
            _selectedCategory == SearchFilterCategory.bills) &&
        bills.isNotEmpty;

    final showReceivables = (_selectedCategory == SearchFilterCategory.all ||
            _selectedCategory == SearchFilterCategory.receivables) &&
        receivables.isNotEmpty;

    final showDebts = (_selectedCategory == SearchFilterCategory.all ||
            _selectedCategory == SearchFilterCategory.debts) &&
        debts.isNotEmpty;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        // ── 1. Friends Section ──────────────────────────────────────────
        if (showFriends) ...[
          _buildSectionHeader('เพื่อน', friends.length, isDark),
          const SizedBox(height: 6),
          ...friends.map((f) => _buildFriendCard(context, f, nicknamesMap, isDark)),
          const SizedBox(height: 14),
        ],

        // ── 2. Bills Section ────────────────────────────────────────────
        if (showBills) ...[
          _buildSectionHeader('บิลของฉัน', bills.length, isDark),
          const SizedBox(height: 6),
          ...bills.map((b) => _buildBillCard(context, b, isDark)),
          const SizedBox(height: 14),
        ],

        // ── 3. Receivables Section (เพื่อนติดเรา) ────────────────────────
        if (showReceivables) ...[
          _buildSectionHeader('เพื่อนติดเรา', receivables.length, isDark),
          const SizedBox(height: 6),
          ...receivables.map((rf) => _buildReceivableCard(context, rf, nicknamesMap, isDark)),
          const SizedBox(height: 14),
        ],

        // ── 4. Debts Section (เราติดเพื่อน) ─────────────────────────────
        if (showDebts) ...[
          _buildSectionHeader('เราติดเพื่อน', debts.length, isDark),
          const SizedBox(height: 6),
          ...debts.map((d) => _buildDebtCard(context, d, nicknamesMap, isDark)),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, bool isDark) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5000).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF5000),
            ),
          ),
        ),
      ],
    );
  }

  // ── 1. Friend Result Card ────────────────────────────────────────────────
  Widget _buildFriendCard(
    BuildContext context,
    FriendItemModel friend,
    Map<String, String> nicknamesMap,
    bool isDark,
  ) {
    final nickname = nicknamesMap[friend.user.id] ?? nicknamesMap[friend.user.userCode];
    final hasNickname = nickname != null && nickname.trim().isNotEmpty;
    final effectiveName = hasNickname ? nickname : friend.user.displayName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/friends/${friend.friendshipId}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Avatar Squircle
                Container(
                  width: 38,
                  height: 38,
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.6),
                      ),
                    ),
                  ),
                  child: ClipSmoothRect(
                    radius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.6),
                    ),
                    child: (friend.user.avatarUrl != null && friend.user.avatarUrl!.isNotEmpty)
                        ? Image.network(
                            friend.user.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildAvatarInitial(effectiveName),
                          )
                        : _buildAvatarInitial(effectiveName),
                  ),
                ),
                const SizedBox(width: 10),

                // Name & ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              effectiveName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasNickname) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${friend.user.displayName})',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'รหัส: ${friend.user.userCode}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFFFF5000),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 2. Bill Result Card ──────────────────────────────────────────────────
  Widget _buildBillCard(BuildContext context, BillModel bill, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/bills/${bill.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Bill Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.6),
                      ),
                    ),
                  ),
                  child: const Icon(Icons.receipt_rounded, color: Color(0xFFFF5000), size: 20),
                ),
                const SizedBox(width: 10),

                // Title & Participant info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.title ?? 'บิลค่าใช้จ่าย',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'หาร ${bill.items.length} คน • ${bill.status == "settled" ? "ชำระครบแล้ว" : "ยังมียอดค้าง"}',
                        style: TextStyle(
                          fontSize: 11,
                          color: bill.status == "settled"
                              ? const Color(0xFF34C759)
                              : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '฿${bill.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF5000),
                      ),
                    ),
                    const Text(
                      'ยอดรวมบิล',
                      style: TextStyle(fontSize: 10, color: AppColors.inkMuted48),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 3. Receivable Result Card (เพื่อนติดเรา) ──────────────────────────────
  Widget _buildReceivableCard(
    BuildContext context,
    ReceivableFriendModel friend,
    Map<String, String> nicknamesMap,
    bool isDark,
  ) {
    final nickname = nicknamesMap[friend.debtor.id] ?? nicknamesMap[friend.debtor.userCode];
    final hasNickname = nickname != null && nickname.trim().isNotEmpty;
    final effectiveName = hasNickname ? nickname : friend.debtor.displayName;
    final ageText = DebtAgeCalculator.formatDebtAgeThai(friend.oldestDebtStartDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => FriendReceivableDetailBottomSheet.show(context, friend),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.6),
                      ),
                    ),
                  ),
                  child: ClipSmoothRect(
                    radius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.6),
                    ),
                    child: (friend.debtor.avatarUrl != null && friend.debtor.avatarUrl!.isNotEmpty)
                        ? Image.network(
                            friend.debtor.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildAvatarInitial(effectiveName),
                          )
                        : _buildAvatarInitial(effectiveName),
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              effectiveName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasNickname) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${friend.debtor.displayName})',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'ติดเรา ${friend.outstandingBillCount} บิล • $ageText',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFFFF5000),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '฿${friend.totalOutstandingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF5000),
                      ),
                    ),
                    const Text(
                      'เพื่อนติดเรา',
                      style: TextStyle(fontSize: 10, color: AppColors.inkMuted48),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 4. Debt Result Card (เราติดเพื่อน) ───────────────────────────────────
  Widget _buildDebtCard(
    BuildContext context,
    DebtItemModel debt,
    Map<String, String> nicknamesMap,
    bool isDark,
  ) {
    final nickname = nicknamesMap[debt.creditor.id] ?? nicknamesMap[debt.creditor.userCode];
    final hasNickname = nickname != null && nickname.trim().isNotEmpty;
    final effectiveName = hasNickname ? nickname : debt.creditor.displayName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (!debt.isAcknowledged) {
              DebtAcknowledgementDetailSheet.show(context, debt);
            } else {
              PaymentDetailBottomSheet.show(context, debt);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.6),
                      ),
                    ),
                  ),
                  child: const Icon(Icons.payment_rounded, color: Color(0xFFFF3B30), size: 18),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.billTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'เจ้าหนี้: $effectiveName',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '฿${debt.outstandingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF3B30),
                      ),
                    ),
                    Text(
                      !debt.isAcknowledged ? 'รอตรวจสอบ' : 'ค้างชำระ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: !debt.isAcknowledged ? const Color(0xFFFF9500) : const Color(0xFFFF3B30),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // NO RESULTS VIEW
  // =========================================================================
  Widget _buildNoResultsView(bool isDark, String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white10 : const Color(0xFFF0F2F5)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 36,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่พบข้อมูลสำหรับ "$query"',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ลองค้นหาด้วยคำอื่น เช่น ชื่อเพื่อน, ชื่อเล่น, รหัสผู้ใช้, หรือยอดเงิน',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarInitial(String name) {
    return Container(
      color: const Color(0xFFFFF0E6),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          color: Color(0xFFFF5000),
        ),
      ),
    );
  }
}
