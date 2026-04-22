/// Utility for computing financial-month boundaries based on a configurable
/// start day (e.g. 21 = "21st to 20th" cycles).
///
/// When [startDay] is 1 the behaviour matches plain calendar months.
class FinancialMonth {
  const FinancialMonth._();

  /// Returns the month-key (`YYYY-MM`) that [date] falls within given
  /// [startDay].
  ///
  /// If the day-of-month is **before** [startDay] the key belongs to the
  /// previous calendar month (because that period hasn't ended yet).
  static String monthKeyFor(DateTime date, int startDay) {
    DateTime anchor;
    if (startDay <= 1 || date.day >= startDay) {
      anchor = date;
    } else {
      // Roll back to the previous calendar month.
      anchor = DateTime(date.year, date.month - 1);
    }
    return '${anchor.year}-${anchor.month.toString().padLeft(2, '0')}';
  }

  /// The current financial month key.
  static String currentMonthKey(int startDay) {
    return monthKeyFor(DateTime.now(), startDay);
  }

  /// The start date of the financial month identified by [year]/[month].
  static DateTime startDate(int year, int month, int startDay) {
    return DateTime(year, month, startDay.clamp(1, 28));
  }

  /// The inclusive end date of the financial month identified by
  /// [year]/[month].
  static DateTime endDate(int year, int month, int startDay) {
    if (startDay <= 1) {
      // Calendar month: 1st to last day of that month.
      return DateTime(year, month + 1, 0);
    }
    // Custom cycle: ends the day before the start day of the next month.
    return DateTime(year, month + 1, startDay - 1);
  }

  /// A human-friendly label for the period, e.g. "21 Mar – 20 Apr" or
  /// "April 2026" when [startDay] is 1.
  static String periodLabel(int year, int month, int startDay) {
    final start = startDate(year, month, startDay);
    final end = endDate(year, month, startDay);
    if (startDay <= 1) {
      return _monthYearFormat(start);
    }
    return '${start.day} ${_shortMonth(start.month)} – '
        '${end.day} ${_shortMonth(end.month)}';
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _fullMonths = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _shortMonth(int m) => _months[m];

  static String _monthYearFormat(DateTime d) =>
      '${_fullMonths[d.month]} ${d.year}';

  /// Parse a `YYYY-MM` key into (year, month).
  static (int year, int month) parseKey(String key) {
    final parts = key.split('-');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }
}
