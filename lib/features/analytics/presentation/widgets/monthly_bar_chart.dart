import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme.dart';
import '../../models/monthly_summary_model.dart';

class MonthlyBarChart extends StatelessWidget {
  final List<MonthlyDataPoint> dataPoints;
  final int selectedMonth;
  final ValueChanged<int> onMonthSelected;

  const MonthlyBarChart({
    super.key,
    required this.dataPoints,
    required this.selectedMonth,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxAmount = dataPoints.fold<double>(
      1000.0,
      (max, p) => p.outflow > max ? p.outflow : max,
    );

    final currencyFormatter = NumberFormat('#,##0', 'th');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.9),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Legend & Peak Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFF5000).withValues(alpha: isDark ? 0.2 : 0.1),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      color: Color(0xFFFF5000),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'แนวโน้มค่าใช้จ่ายทั้งปี',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'สูงสุด: ฿${currencyFormatter.format(maxAmount)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Scrollable or Fitted Bar Chart Canvas
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(dataPoints.length, (index) {
                final point = dataPoints[index];
                final isSelected = point.month == selectedMonth;
                final heightRatio = maxAmount > 0 ? (point.outflow / maxAmount).clamp(0.06, 1.0) : 0.06;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onMonthSelected(point.month);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Amount Tooltip for Selected Bar
                        if (isSelected && point.outflow > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5000),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              point.outflow >= 1000
                                  ? '${(point.outflow / 1000).toStringAsFixed(1)}k'
                                  : point.outflow.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 18),

                        // Animated Bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          width: isSelected ? 16 : 10,
                          height: (140 - 45) * heightRatio,
                          decoration: ShapeDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFFF5000),
                                      Color(0xFFFF8500),
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isDark
                                        ? [
                                            Colors.white.withValues(alpha: 0.25),
                                            Colors.white.withValues(alpha: 0.08),
                                          ]
                                        : [
                                            const Color(0xFFE5E7EB),
                                            const Color(0xFFD1D5DB),
                                          ],
                                  ),
                            shadows: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF5000).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                            shape: const SmoothRectangleBorder(
                              borderRadius: SmoothBorderRadius.vertical(
                                top: SmoothRadius(cornerRadius: 6, cornerSmoothing: 0.7),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Month Name Label
                        Text(
                          point.monthName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFFFF5000)
                                : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
