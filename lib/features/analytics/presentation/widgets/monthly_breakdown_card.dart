import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme.dart';
import '../../models/monthly_summary_model.dart';
import '../../models/yearly_summary_model.dart';

class MonthlyBreakdownCard extends StatelessWidget {
  final MonthlyExpenseSummary? summary;
  final YearlyExpenseSummary? yearlySummary;

  const MonthlyBreakdownCard({
    super.key,
    required this.summary,
  }) : yearlySummary = null;

  const MonthlyBreakdownCard.yearly({
    super.key,
    required this.yearlySummary,
  }) : summary = null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormatter = NumberFormat('#,##0.00', 'th');

    final isYearly = yearlySummary != null;
    final settlementRate = isYearly ? yearlySummary!.settlementRate : (summary?.settlementRate ?? 100.0);
    final totalOutflow = isYearly ? yearlySummary!.totalOutflow : (summary?.totalOutflow ?? 0.0);
    final categoryBreakdown = isYearly ? yearlySummary!.categoryBreakdown : (summary?.categoryBreakdown ?? const []);
    final totalCreatedBillsAmount = isYearly ? yearlySummary!.totalCreatedBillsAmount : (summary?.totalCreatedBillsAmount ?? 0.0);
    final totalDebtsPaidAmount = isYearly ? yearlySummary!.totalDebtsPaidAmount : (summary?.totalDebtsPaidAmount ?? 0.0);
    final totalReceivablesCollected = isYearly ? yearlySummary!.totalReceivablesCollected : (summary?.totalReceivablesCollected ?? 0.0);
    final pendingReceivablesAmount = isYearly ? yearlySummary!.pendingReceivablesAmount : (summary?.pendingReceivablesAmount ?? 0.0);
    final totalBillsCount = isYearly ? yearlySummary!.totalBillsCount : (summary?.totalBillsCount ?? 0);

    return Container(
      padding: const EdgeInsets.all(18),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isYearly ? 'จำแนกสัดส่วนการเงินทั้งปี' : 'จำแนกสัดส่วนการเงิน',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'สำเร็จ ${settlementRate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Multi-color Segmented Progress Bar
          if (totalOutflow > 0 && categoryBreakdown.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: categoryBreakdown.map((cat) {
                    return Expanded(
                      flex: (cat.percentage * 10).toInt().clamp(1, 1000),
                      child: Container(
                        color: Color(cat.colorValue),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Breakdown Items List
          _buildBreakdownItem(
            context,
            color: const Color(0xFFFF5000),
            icon: Icons.receipt_long_rounded,
            title: isYearly ? 'บิลที่ออกเงินไปก่อนทั้งปี' : 'บิลที่ออกเงินไปก่อน',
            amount: totalCreatedBillsAmount,
            subtitle: '$totalBillsCount รายการบิล',
            isDark: isDark,
            formatter: currencyFormatter,
          ),
          const SizedBox(height: 12),
          _buildBreakdownItem(
            context,
            color: const Color(0xFF2563EB),
            icon: Icons.payments_rounded,
            title: isYearly ? 'จ่ายหนี้คืนเพื่อนทั้งปี' : 'จ่ายหนี้คืนเพื่อน',
            amount: totalDebtsPaidAmount,
            subtitle: 'ยอดโอนชำระสำเร็จ',
            isDark: isDark,
            formatter: currencyFormatter,
          ),
          const SizedBox(height: 12),
          _buildBreakdownItem(
            context,
            color: const Color(0xFF10B981),
            icon: Icons.call_received_rounded,
            title: isYearly ? 'ได้รับเงินคืนแล้วทั้งปี' : 'ได้รับเงินคืนจากเพื่อน',
            amount: totalReceivablesCollected,
            subtitle: 'รับชำระผ่าน PromptPay/สลิป',
            isDark: isDark,
            formatter: currencyFormatter,
          ),

          if (pendingReceivablesAmount > 0) ...[
            const SizedBox(height: 12),
            _buildBreakdownItem(
              context,
              color: const Color(0xFFFF9500),
              icon: Icons.hourglass_top_rounded,
              title: isYearly ? 'ยอดรอเพื่อนคืนเงินทั้งปี' : 'ยอดรอเพื่อนคืนเงิน',
              amount: pendingReceivablesAmount,
              subtitle: isYearly ? 'ยอดหนี้คงค้างในรอบปีนี้' : 'ยอดหนี้คงค้างในเดือนนี้',
              isDark: isDark,
              formatter: currencyFormatter,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required double amount,
    required String subtitle,
    required bool isDark,
    required NumberFormat formatter,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: ShapeDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.1),
            shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.all(
                SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
              ),
            ),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                ),
              ),
            ],
          ),
        ),
        Text(
          '฿${formatter.format(amount)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
      ],
    );
  }
}
