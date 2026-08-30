import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme.dart';
import '../../../friends/models/friend_models.dart';
import '../../models/nli_bill_result_model.dart';
import '../../services/nli_bill_parser.dart';

class NliBillInputBottomSheet extends StatefulWidget {
  final List<FriendUserModel> userFriends;
  final Map<String, String> friendNicknames;
  final ValueChanged<NliParsedBill> onApplyParsedBill;

  const NliBillInputBottomSheet({
    super.key,
    required this.userFriends,
    this.friendNicknames = const {},
    required this.onApplyParsedBill,
  });

  static Future<void> show({
    required BuildContext context,
    required List<FriendUserModel> userFriends,
    Map<String, String> friendNicknames = const {},
    required ValueChanged<NliParsedBill> onApplyParsedBill,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NliBillInputBottomSheet(
        userFriends: userFriends,
        friendNicknames: friendNicknames,
        onApplyParsedBill: onApplyParsedBill,
      ),
    );
  }

  @override
  State<NliBillInputBottomSheet> createState() => _NliBillInputBottomSheetState();
}

class _NliBillInputBottomSheetState extends State<NliBillInputBottomSheet> {
  final TextEditingController _promptController = TextEditingController();
  NliParsedBill? _parsedResult;

  // Pre-defined quick prompt examples based on real user scenarios
  final List<String> _samplePrompts = [
    'กินชาบู 1200 มีเนื้อ 500 ผัก 200 น้ำ 100 หาร 3 คนกับ บาส เอ็ม',
    'ค่ากาแฟ 240: ลาเต้ 80 มอคค่า 160 หารกับ บาส',
    'ค่าห้องพักทริปหัวหิน 4500 บาท หาร 3 คน รวมฉัน',
    'ค่าน้ำมัน 800 บาท หารกับ สมชาย ไม่รวมฉัน',
  ];

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
  }

  void _onPromptChanged() {
    final text = _promptController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedResult = null;
      });
      return;
    }

    final result = NliBillParser.parse(
      text,
      widget.userFriends,
      friendNicknames: widget.friendNicknames,
    );
    setState(() {
      _parsedResult = result;
    });
  }

  @override
  void dispose() {
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    super.dispose();
  }

  void _applyPrompt(String prompt) {
    HapticFeedback.lightImpact();
    _promptController.text = prompt;
    _promptController.selection = TextSelection.fromPosition(
      TextPosition(offset: prompt.length),
    );
  }

  void _submit() {
    if (_parsedResult == null || !_parsedResult!.hasValidData) return;
    HapticFeedback.mediumImpact();
    widget.onApplyParsedBill(_parsedResult!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currencyFormatter = NumberFormat('#,##0.00', 'th');

    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 20 + bottomInset),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceBlack : Colors.white,
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
            top: SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grabber Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Title with Glowing AI Icon
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const ShapeDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF5000), Color(0xFF8B5CF6)],
                      ),
                      shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'พิมพ์สั่งสร้างบิลด้วย AI (NLI)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'พิมพ์ชื่อบิล สินค้า ยอดเงิน และชื่อเล่นเพื่อน',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Prompt Input Field (Mult-line Squircle Card)
              Container(
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : const Color(0xFFF9FAFB),
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: const Color(0xFFFF5000).withValues(alpha: isDark ? 0.45 : 0.3),
                      width: 1.2,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _promptController,
                      maxLines: 3,
                      minLines: 2,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'เช่น กินชาบู 1200 มีเนื้อ 500 ผัก 200 น้ำ 100 หาร 3 คนกับ บาส เอ็ม...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                    if (_promptController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _promptController.clear();
                          setState(() {
                            _parsedResult = null;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'ล้างข้อความ',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Quick Suggestion Chips Carousel
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _samplePrompts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final sample = _samplePrompts[index];
                    return GestureDetector(
                      onTap: () => _applyPrompt(sample),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: ShapeDecoration(
                          color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF3F4F6),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                            ),
                          ),
                        ),
                        child: Text(
                          sample,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Live Parsed Preview Card
              if (_parsedResult != null && _parsedResult!.hasValidData) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: ShapeDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF1E293B),
                              const Color(0xFF0F172A),
                            ]
                          : [
                              const Color(0xFFFFF7ED),
                              const Color(0xFFFDF2F8),
                            ],
                    ),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.bolt_rounded,
                                  color: Color(0xFFFF5000),
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'ผลการวิเคราะห์ (Live Preview)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFF5000),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _parsedResult!.includeOwner ? 'รวมส่วนฉัน' : 'ไม่คิดส่วนฉัน',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Title & Amount Extracted
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ชื่อบิล:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                  ),
                                ),
                                Text(
                                  _parsedResult!.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'ยอดรวม:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                              Text(
                                '฿${currencyFormatter.format(_parsedResult!.totalAmount)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFF5000),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Extracted Items Section if any
                      if (_parsedResult!.items.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 10),
                        Text(
                          'รายการสินค้าที่ตรวจพบ (${_parsedResult!.items.length} รายการ):',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _parsedResult!.items.map((it) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: ShapeDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.25 : 0.12),
                                shape: const SmoothRectangleBorder(
                                  borderRadius: SmoothBorderRadius.all(
                                    SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 13,
                                    color: Color(0xFF3B82F6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    it.name,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '฿${it.amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 10),
                      const Divider(height: 1, thickness: 0.5),
                      const SizedBox(height: 10),

                      // Matched Friends Chips
                      Text(
                        'เพื่อนที่ร่วมหาร (${_parsedResult!.matchedParticipants.length} คน):',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                      const SizedBox(height: 6),

                      if (_parsedResult!.matchedParticipants.isEmpty)
                        Text(
                          'ยังไม่พบชื่อเพื่อนที่ตรงกับระบบ (ระบบจะใช้ยอดรวมให้คุณเลือกเพื่อนต่อ)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _parsedResult!.matchedParticipants.map((p) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: ShapeDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.12),
                                shape: const SmoothRectangleBorder(
                                  borderRadius: SmoothBorderRadius.all(
                                    SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0x2810B981),
                                    ),
                                    child: ClipOval(
                                      child: (p.friend.avatarUrl != null && p.friend.avatarUrl!.trim().isNotEmpty)
                                          ? Image.network(
                                              p.friend.avatarUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Text(
                                                  p.effectiveDisplayName.isNotEmpty
                                                      ? p.effectiveDisplayName[0].toUpperCase()
                                                      : 'U',
                                                  style: const TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                p.effectiveDisplayName.isNotEmpty
                                                    ? p.effectiveDisplayName[0].toUpperCase()
                                                    : 'U',
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.effectiveDisplayName,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  if (p.isCustomAmountSpecified && p.customAmount != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(฿${p.customAmount!.toStringAsFixed(0)})',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                      // Unmatched Names warning if any
                      if (_parsedResult!.unmatchedNames.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 13,
                              color: Color(0xFFFF9500),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'ไม่พบเพื่อน: ${_parsedResult!.unmatchedNames.join(", ")} (เพิ่มเพื่อนก่อนเพื่อให้แท็กอัตโนมัติ)',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFFFF9500),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit / Apply Button
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _parsedResult != null && _parsedResult!.hasValidData
                      ? _submit
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5000),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? Colors.white12 : Colors.black12,
                    disabledForegroundColor: isDark ? Colors.white30 : Colors.black26,
                    elevation: 0,
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 16, cornerSmoothing: 0.8),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text(
                    'นำข้อมูลไปใส่ในบิล',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
