enum BudgetPeriodStatus {
  open,
  closed,
}

class BudgetPeriod {
  const BudgetPeriod({
    required this.id,
    required this.year,
    required this.month,
    this.status = BudgetPeriodStatus.open,
    this.notes = '',
    this.closedAt,
    this.carriedForwardBalance = 0,
  });

  final String id;
  final int year;
  final int month;
  final BudgetPeriodStatus status;
  final String notes;
  final DateTime? closedAt;
  /// Positive surplus carried into the next month.
  final double carriedForwardBalance;

  bool get isOpen => status == BudgetPeriodStatus.open;
  bool get isClosed => status == BudgetPeriodStatus.closed;

  BudgetPeriod copyWith({
    BudgetPeriodStatus? status,
    String? notes,
    DateTime? closedAt,
    bool clearClosedAt = false,
    double? carriedForwardBalance,
  }) {
    return BudgetPeriod(
      id: id,
      year: year,
      month: month,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      closedAt: clearClosedAt ? null : (closedAt ?? this.closedAt),
      carriedForwardBalance: carriedForwardBalance ?? this.carriedForwardBalance,
    );
  }

  static String buildId(int year, int month) =>
      '${year}-${month.toString().padLeft(2, '0')}';
}
