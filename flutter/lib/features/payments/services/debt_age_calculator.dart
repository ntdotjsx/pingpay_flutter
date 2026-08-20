class DebtAgeCalculator {
  DebtAgeCalculator._();

  /// Calculates the integer number of calendar days between [debtStartDate] and [targetDate].
  /// Uses calendar date only (ignoring time-of-day) to prevent timezone & 23:59 vs 00:01 boundary bugs.
  static int calculateDaysOutstanding(
    DateTime debtStartDate, {
    DateTime? targetDate,
  }) {
    final now = targetDate ?? DateTime.now();

    final startCalendarDate = DateTime(
      debtStartDate.year,
      debtStartDate.month,
      debtStartDate.day,
    );
    final currentCalendarDate = DateTime(now.year, now.month, now.day);

    final difference = currentCalendarDate.difference(startCalendarDate).inDays;
    return difference >= 0 ? difference : 0;
  }

  /// Formats the debt age into natural, Thai localized copy:
  /// - 0 days: "ค้างวันนี้"
  /// - 1 day: "ค้างมาแล้ว 1 วัน"
  /// - X days: "ค้างมาแล้ว X วัน"
  static String formatDebtAgeThai(
    DateTime debtStartDate, {
    DateTime? targetDate,
  }) {
    final days = calculateDaysOutstanding(
      debtStartDate,
      targetDate: targetDate,
    );

    if (days == 0) {
      return 'ค้างวันนี้';
    } else if (days == 1) {
      return 'ค้างมาแล้ว 1 วัน';
    } else {
      return 'ค้างมาแล้ว $days วัน';
    }
  }

  /// Formats date to Thai calendar date e.g. "20 ส.ค. 2569" or "8 ส.ค. 2569"
  static String formatThaiDate(DateTime date) {
    const thaiMonths = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];

    final day = date.day;
    final month = thaiMonths[date.month - 1];
    final year = date.year + 543; // Buddhist Era

    return '$day $month $year';
  }
}
