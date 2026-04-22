enum PlannerEventType {
  payRise,
  oneOffExpense,
  oneOffIncome,
  recurringExpenseChange,
  extraDebtPayment,
}

class PlannerEvent {
  const PlannerEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.scheduledMonth,
    required this.scheduledYear,
    this.isRecurring = false,
    this.notes = '',
  });

  final String id;
  final String title;
  final PlannerEventType type;
  final double amount;
  final int scheduledMonth;
  final int scheduledYear;
  final bool isRecurring;
  final String notes;

  PlannerEvent copyWith({
    String? id,
    String? title,
    PlannerEventType? type,
    double? amount,
    int? scheduledMonth,
    int? scheduledYear,
    bool? isRecurring,
    String? notes,
  }) {
    return PlannerEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      scheduledMonth: scheduledMonth ?? this.scheduledMonth,
      scheduledYear: scheduledYear ?? this.scheduledYear,
      isRecurring: isRecurring ?? this.isRecurring,
      notes: notes ?? this.notes,
    );
  }

  String get typeLabel {
    switch (type) {
      case PlannerEventType.payRise:
        return 'Pay Rise';
      case PlannerEventType.oneOffExpense:
        return 'One-off Expense';
      case PlannerEventType.oneOffIncome:
        return 'One-off Income';
      case PlannerEventType.recurringExpenseChange:
        return 'Recurring Expense Change';
      case PlannerEventType.extraDebtPayment:
        return 'Extra Debt Payment';
    }
  }

  String get scheduledLabel {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[scheduledMonth]} $scheduledYear';
  }
}
