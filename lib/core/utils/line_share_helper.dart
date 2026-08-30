import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/bills/models/bill_models.dart';
import '../../features/payments/models/payment_models.dart';
import 'app_toast.dart';

/// Helper utility to format and dispatch bills, reminders, and monthly reports directly to LINE OA ป้านวล (@508zvpuj)
class LineShareHelper {
  LineShareHelper._();

  /// Official LINE OA of ป้านวล (Parnuan Bot)
  static const String paNualLineOaId = '@508zvpuj';
  static const String paNualLineIdClean = '508zvpuj';
  static const String paNualLinePageUrl = 'https://page.line.me/508zvpuj';

  /// Formats date and time into natural Thai format for Parnuan Bot
  /// e.g. "วันที่ 30 ส.ค. 2569 เวลา 20:12 น."
  static String formatThaiDateTime(DateTime dt) {
    final day = dt.day;
    const thaiMonths = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    final monthStr = thaiMonths[dt.month];
    final yearThai = dt.year > 2400 ? dt.year : dt.year + 543;
    final hourStr = dt.hour.toString().padLeft(2, '0');
    final minStr = dt.minute.toString().padLeft(2, '0');
    return 'วันที่ $day $monthStr $yearThai เวลา $hourStr:$minStr น.';
  }

  /// Helper to clean title so "ค่า" is not repeated (e.g. avoid "ค่าค่าแท็กซี่")
  static String cleanItemTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return 'ใช้จ่าย';
    if (trimmed.startsWith('ค่า')) {
      final stripped = trimmed.substring(3).trim();
      return stripped.isNotEmpty ? stripped : trimmed;
    }
    return trimmed;
  }

  /// Formats natural language expense text for a single bill for Parnuan LINE Bot
  static String formatParnuanBillMessage({required BillModel bill}) {
    final cleanAmount = bill.totalAmount % 1 == 0
        ? bill.totalAmount.toInt().toString()
        : bill.totalAmount.toStringAsFixed(2);
    final rawTitle = bill.title;
    final title = (rawTitle != null && rawTitle.trim().isNotEmpty) ? rawTitle.trim() : 'ค่าใช้จ่าย';
    final dateStr = formatThaiDateTime(bill.createdAt ?? DateTime.now());
    return '$title $cleanAmount $dateStr';
  }

  /// Formats reminder / debt text for Parnuan Bot with date & time
  static String formatParnuanDebtMessage({
    required String title,
    required double amount,
    bool isIncome = false,
    DateTime? date,
    int? installmentRound,
    int? totalInstallments,
  }) {
    final cleanAmount = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
    final clean = cleanItemTitle(title);
    final dateStr = formatThaiDateTime(date ?? DateTime.now());

    String installmentSuffix = '';
    if (installmentRound != null && installmentRound > 0) {
      if (totalInstallments != null && totalInstallments > 0) {
        installmentSuffix = ' (ผ่อนงวด $installmentRound/$totalInstallments)';
      } else {
        installmentSuffix = ' (ผ่อนงวดที่ $installmentRound)';
      }
    }

    if (isIncome) {
      return 'ได้รับเงินคืนค่า$clean$installmentSuffix $cleanAmount $dateStr';
    }
    return 'จ่ายค่า$clean$installmentSuffix $cleanAmount $dateStr';
  }

  /// Formats all itemized paid transactions of the month for Parnuan LINE Bot
  /// Rules:
  /// 1. An outflow (รายจ่าย) is counted ONLY when it has actually been paid / settled
  /// 2. If it is an installment payment (ผ่อนชำระ), state the installment round e.g. "(ผ่อนงวดที่ 1)"
  /// 3. Inflow (รายรับ) for receivables collected from real friends (NOT creator's own share)
  /// 4. Resolves friend's nickname if set in nicknamesMap
  /// 5. Every line contains "[ชื่อรายการ] [ยอดเงิน] วันที่ ... เวลา ... น."
  static String formatMonthlyReportForParnuanBot({
    required String periodTitle,
    required List<BillModel> bills,
    required List<DebtItemModel> paidDebts,
    String? currentUserId,
    Map<String, String>? nicknamesMap,
  }) {
    final lines = <String>[];

    // 1. Paid / Settled Bills created by user (Outflow - บิลที่เราจ่ายไป)
    for (final bill in bills) {
      final myShare = bill.myShare > 0
          ? bill.myShare
          : (bill.isFullySettled ? bill.totalAmount : 0.0);

      if (myShare > 0) {
        final cleanAmount = myShare % 1 == 0 ? myShare.toInt().toString() : myShare.toStringAsFixed(2);
        final rawTitle = bill.title;
        final title = (rawTitle != null && rawTitle.trim().isNotEmpty) ? rawTitle.trim() : 'ค่าใช้จ่าย';
        final dateStr = formatThaiDateTime(bill.createdAt ?? DateTime.now());
        lines.add('$title $cleanAmount $dateStr');
      }
    }

    // 2. Debts user paid to friends (Outflow - ยอดหนี้ที่เราชำระให้เพื่อนแล้วจริง)
    for (final debt in paidDebts) {
      if (debt.amountPaid > 0) {
        final cleanAmount = debt.amountPaid % 1 == 0 ? debt.amountPaid.toInt().toString() : debt.amountPaid.toStringAsFixed(2);
        final clean = cleanItemTitle(debt.billTitle);

        // Resolve creditor nickname
        final creditorNick = nicknamesMap?[debt.creditor.id] ?? nicknamesMap?[debt.creditor.userCode];
        final creditorName = (creditorNick != null && creditorNick.trim().isNotEmpty)
            ? creditorNick.trim()
            : (debt.creditor.displayName.trim().isNotEmpty ? debt.creditor.displayName.trim() : 'เพื่อน');

        String installmentSuffix = '';
        if (debt.paymentsCount > 1 || debt.isPartiallyPaid) {
          installmentSuffix = ' (ผ่อนงวดที่ ${debt.paymentsCount})';
        }

        final dateStr = formatThaiDateTime(debt.debtStartDate);
        lines.add('จ่ายค่า$clean$installmentSuffix ให้ $creditorName $cleanAmount $dateStr');
      }
    }

    // 3. Receivables collected from friends who paid us (Inflow / รายรับ)
    for (final bill in bills) {
      for (final item in bill.items) {
        // Skip creator's own record (Cannot collect from myself)
        final isMe = (currentUserId != null && currentUserId.isNotEmpty && item.debtorId == currentUserId) ||
            item.debtorId == bill.ownerId;
        if (isMe) continue;

        if (item.amountPaid > 0) {
          final cleanAmount = item.amountPaid % 1 == 0 ? item.amountPaid.toInt().toString() : item.amountPaid.toStringAsFixed(2);

          // Resolve debtor nickname
          final debtorNick = (item.debtor != null)
              ? (nicknamesMap?[item.debtor!.id] ?? nicknamesMap?[item.debtor!.userCode])
              : null;
          final friendName = (debtorNick != null && debtorNick.trim().isNotEmpty)
              ? debtorNick.trim()
              : (item.debtor?.displayName.trim().isNotEmpty == true ? item.debtor!.displayName.trim() : 'เพื่อน');

          final rawTitle = bill.title ?? 'บิล';
          final clean = cleanItemTitle(rawTitle);

          String installmentSuffix = '';
          if (item.amountPaid > 0 && !item.isFullyPaid) {
            installmentSuffix = ' (ผ่อนชำระ)';
          }

          final dateStr = formatThaiDateTime(item.updatedAt ?? item.createdAt ?? bill.createdAt ?? DateTime.now());
          lines.add('ได้รับเงินคืนค่า$clean$installmentSuffix จาก $friendName $cleanAmount $dateStr');
        }
      }
    }

    // Fallback if no individual transactions exist
    if (lines.isEmpty) {
      final nowStr = formatThaiDateTime(DateTime.now());
      return 'รายจ่าย$periodTitle 0 $nowStr';
    }

    return lines.join('\n');
  }

  /// Opens LINE Official Account of ป้านวล (@508zvpuj) directly with message copied to clipboard
  static Future<bool> openPaNualLinePage({String? messageText, BuildContext? context}) async {
    if (messageText != null && messageText.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: messageText));
    }

    final candidateUris = [
      Uri.parse('line://ti/p/$paNualLineOaId'),
      Uri.parse('https://line.me/R/ti/p/$paNualLineOaId'),
      Uri.parse(paNualLinePageUrl),
    ];

    for (final uri in candidateUris) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) {
            if (context != null && context.mounted) {
              final toastMsg = messageText != null
                  ? 'เปิด LINE ป้านวล และคัดลอกรายการให้แล้ว (แตะวางได้เลย)'
                  : 'เปิด LINE ป้านวล เรียบร้อยแล้ว';
              AppToast.success(context, toastMsg);
            }
            return true;
          }
        }
      } catch (_) {}
    }

    try {
      await launchUrl(Uri.parse(paNualLinePageUrl), mode: LaunchMode.externalApplication);
      if (context != null && context.mounted) {
        AppToast.success(context, 'เปิด LINE ป้านวล เรียบร้อยแล้ว');
      }
      return true;
    } catch (_) {}

    return false;
  }

  /// Formats and opens LINE sharing flow for a single bill directly into Pa Nual bot
  static Future<void> shareBill({
    BuildContext? context,
    required BillModel bill,
    String? creditorName,
    String? promptPayId,
    Map<String, String>? nicknamesMap,
  }) async {
    final parnuanMsg = formatParnuanBillMessage(bill: bill);
    await openPaNualLinePage(messageText: parnuanMsg, context: context);
  }

  /// Formats and opens debt reminder flow directly into Pa Nual bot
  static Future<void> shareDebtReminder({
    BuildContext? context,
    required String debtorName,
    required double amount,
    required String billTitle,
    String? promptPayId,
    int? installmentRound,
    int? totalInstallments,
  }) async {
    final parnuanMsg = formatParnuanDebtMessage(
      title: billTitle,
      amount: amount,
      isIncome: true,
      installmentRound: installmentRound,
      totalInstallments: totalInstallments,
    );
    await openPaNualLinePage(messageText: parnuanMsg, context: context);
  }

  /// Formats and opens monthly summary sharing flow directly into Pa Nual bot
  static Future<void> shareSummary({
    BuildContext? context,
    required String periodTitle,
    required double totalOutflow,
    required double totalInflow,
    required int totalBillsCount,
    List<BillModel> bills = const [],
    List<DebtItemModel> paidDebts = const [],
    String? currentUserId,
    Map<String, String>? nicknamesMap,
    double? averageMonthlyExpense,
    String? peakSpendingMonth,
  }) async {
    final parnuanMsg = formatMonthlyReportForParnuanBot(
      periodTitle: periodTitle,
      bills: bills,
      paidDebts: paidDebts,
      currentUserId: currentUserId,
      nicknamesMap: nicknamesMap,
    );

    await openPaNualLinePage(messageText: parnuanMsg, context: context);
  }
}
