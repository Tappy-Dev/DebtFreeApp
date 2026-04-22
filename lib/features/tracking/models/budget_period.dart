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
  });

  final String id;
  final int year;
  final int month;
  final BudgetPeriodStatus status;
  final String notes;
  final DateTime? closedAt;

  bool get isOpen => status == BudgetPeriodStatus.open;
  bool get isClosed => status == BudgetPeriodStatus.closed;

  BudgetPeriod copyWith({
    BudgetPeriodStatus? status,
    String? notes,
    DateTime? closedAt,
    bool clearClosedAt = false,
  }) {
    return BudgetPeriod(
      id: id,
      year: year,
      month: month,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      closedAt: clearClosedAt ? null : (closedAt ?? this.closedAt),
    );
  }

  static String buildId(int year, int month) =>
      '${year}-${month.toString().padLeft(2, '0')}';
}
