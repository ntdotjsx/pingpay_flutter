import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme.dart';

class LineCalendarWidget extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final Set<String> activeEventDates; // Format: yyyy-MM-dd (Bills created / Receivables)
  final Set<String> debtEventDates; // Format: yyyy-MM-dd (Debts owed to friends / เราติดเพื่อน)

  const LineCalendarWidget({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.activeEventDates = const {},
    this.debtEventDates = const {},
  });

  @override
  State<LineCalendarWidget> createState() => _LineCalendarWidgetState();
}

class _LineCalendarWidgetState extends State<LineCalendarWidget> {
  late final ScrollController _scrollController;
  final int _pastDays = 30;
  final int _futureDays = 30;
  final double _itemWidth = 54.0;
  final double _itemSpacing = 8.0;

  late final DateTime _baseDate;
  late final List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final now = DateTime.now();
    _baseDate = DateTime(now.year, now.month, now.day);

    _dates = List.generate(
      _pastDays + _futureDays + 1,
      (index) => _baseDate.add(Duration(days: index - _pastDays)),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(widget.selectedDate, animated: false);
    });
  }

  @override
  void didUpdateWidget(covariant LineCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      // If the new selected date is outside the current date range, rebuild
      final inRange = _dates.any((d) => _isSameDay(d, widget.selectedDate));
      if (!inRange) {
        final now = DateTime.now();
        _baseDate = DateTime(now.year, now.month, now.day);
        _dates = List.generate(
          _pastDays + _futureDays + 1,
          (index) => _baseDate.add(Duration(days: index - _pastDays)),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToDate(widget.selectedDate, animated: true);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _scrollToDate(DateTime targetDate, {bool animated = true}) {
    final index = _dates.indexWhere((d) => _isSameDay(d, targetDate));
    if (index != -1 && _scrollController.hasClients) {
      final screenWidth = MediaQuery.of(context).size.width;
      final targetOffset =
          index * (_itemWidth + _itemSpacing) -
          (screenWidth / 2) +
          (_itemWidth / 2) +
          16; // left padding

      final clampedOffset = targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );

      if (animated) {
        _scrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(clampedOffset);
      }
    }
  }

  void _jumpToToday() {
    HapticFeedback.selectionClick();
    final today = DateTime.now();
    final normalized = DateTime(today.year, today.month, today.day);
    widget.onDateSelected(normalized);
    _scrollToDate(normalized, animated: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isViewingToday = _isSameDay(widget.selectedDate, now);

    const thaiFullMonths = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final formattedMonth =
        '${thaiFullMonths[widget.selectedDate.month - 1]} ${widget.selectedDate.year + 543}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Month & Year + "วันนี้ (Today)" Quick Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedMonth,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    ),
                  ),
                ],
              ),
              if (!isViewingToday)
                GestureDetector(
                  onTap: _jumpToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: ShapeDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 12, cornerSmoothing: 1.0),
                        ),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.today_rounded, size: 13, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'วันนี้',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Horizontal Line Calendar List
        SizedBox(
          height: 70,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _dates.length,
            separatorBuilder: (_, __) => SizedBox(width: _itemSpacing),
            itemBuilder: (context, index) {
              final date = _dates[index];
              final isSelected = _isSameDay(date, widget.selectedDate);
              final isToday = _isSameDay(date, now);
              final dateKey = DateFormat('yyyy-MM-dd').format(date);
              final hasEvent = widget.activeEventDates.contains(dateKey);
              final hasDebt = widget.debtEventDates.contains(dateKey);

              return _buildDayTile(
                date: date,
                isSelected: isSelected,
                isToday: isToday,
                hasEvent: hasEvent,
                hasDebt: hasDebt,
                isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayTile({
    required DateTime date,
    required bool isSelected,
    required bool isToday,
    required bool hasEvent,
    required bool hasDebt,
    required bool isDark,
  }) {
    final weekdayFormat = DateFormat('E'); // Sat, Sun, Mon, etc.
    final weekdayName = weekdayFormat.format(date);
    final dayNumber = date.day.toString();

    Color bgColor;
    Color dayTextColor;
    Color weekdayTextColor;
    BorderSide borderSide = BorderSide.none;

    if (isSelected) {
      // Selected Active State (White or Primary Highlight pill as in image)
      bgColor = isDark ? const Color(0xFFE5E5EA) : AppColors.primary;
      dayTextColor = isDark ? Colors.black : Colors.white;
      weekdayTextColor = isDark ? Colors.black87 : Colors.white70;
    } else {
      // Normal Tile
      bgColor = isDark ? const Color(0xFF1E1E20) : AppColors.canvas;
      dayTextColor = isDark ? AppColors.bodyOnDark : AppColors.ink;
      weekdayTextColor = isDark ? AppColors.bodyMuted : AppColors.inkMuted48;
      borderSide = BorderSide(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.5)
            : (isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.hairline),
        width: isToday ? 1.5 : 1.0,
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onDateSelected(date);
        _scrollToDate(date, animated: true);
      },
      child: Container(
        width: _itemWidth,
        decoration: ShapeDecoration(
          color: bgColor,
          shape: SmoothRectangleBorder(
            side: borderSide,
            borderRadius: const SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 18, cornerSmoothing: 1.0),
            ),
          ),
          shadows: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? Colors.white : AppColors.primary)
                        .withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: weekdayTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: dayTextColor,
                  ),
                ),
              ],
            ),

            // Event Indicator Dots (Top row: Orange for Bill created, Blue/Cyan for Debt owed to friend)
            if (hasEvent || hasDebt)
              Positioned(
                top: 7,
                right: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasEvent)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(left: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (hasDebt)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(left: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0xFF007AFF) : const Color(0xFF00C2FF))
                              : const Color(0xFF007AFF), // Blue dot for debt we owe to friends
                          shape: BoxShape.circle,
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
}
