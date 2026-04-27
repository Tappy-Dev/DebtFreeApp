enum ExpenseCategory {
  // ── Bill / subscription categories ──────────────────────────────────────
  utilities,
  media,
  housing,
  insurance,

  // ── Expense categories ───────────────────────────────────────────────────
  entertainment,
  dining,
  grocery,
  pet,
  healthcare,
  education,
  gifts,
  transport,
  oneOff,
  childMaintenance,

  // ── Savings ─────────────────────────────────────────────────────────────
  savings,

  // ── Fallback (used for legacy DB rows) ───────────────────────────────────
  other;

  String get displayName {
    switch (this) {
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.media:
        return 'Media';
      case ExpenseCategory.housing:
        return 'Housing';
      case ExpenseCategory.insurance:
        return 'Insurance';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.dining:
        return 'Dining / Takeaway';
      case ExpenseCategory.grocery:
        return 'Grocery / Shopping';
      case ExpenseCategory.pet:
        return 'Pet';
      case ExpenseCategory.healthcare:
        return 'Healthcare';
      case ExpenseCategory.education:
        return 'Education';
      case ExpenseCategory.gifts:
        return 'Gifts';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.oneOff:
        return 'One-off / Unexpected';
      case ExpenseCategory.childMaintenance:
        return 'Child Maintenance';
      case ExpenseCategory.savings:
        return 'Savings';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  /// Categories appropriate for bills and subscriptions.
  bool get isBillCategory =>
      this == ExpenseCategory.utilities ||
      this == ExpenseCategory.media ||
      this == ExpenseCategory.housing ||
      this == ExpenseCategory.insurance ||
      this == ExpenseCategory.other;

  /// Categories appropriate for regular expenses.
  bool get isExpenseCategory =>
      this == ExpenseCategory.entertainment ||
      this == ExpenseCategory.dining ||
      this == ExpenseCategory.grocery ||
      this == ExpenseCategory.pet ||
      this == ExpenseCategory.healthcare ||
      this == ExpenseCategory.education ||
      this == ExpenseCategory.gifts ||
      this == ExpenseCategory.transport ||
      this == ExpenseCategory.oneOff ||
      this == ExpenseCategory.childMaintenance ||
      this == ExpenseCategory.savings ||
      this == ExpenseCategory.other;

  static ExpenseCategory fromName(String name) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ExpenseCategory.other,
    );
  }
}

class Expense {
  const Expense({
    this.id = '',
    this.name = '',
    required this.amount,
    this.monthKey = '',
    this.trackable = false,
    this.isSubscription = false,
    this.paymentDay,
    this.category = ExpenseCategory.other,
  });

  final String id;
  final String name;
  final double amount;
  final String monthKey;
  final bool trackable;

  /// True when this bill entry is a recurring subscription (e.g. Netflix, Gym).
  final bool isSubscription;

  /// Day of month this bill or subscription is usually paid.
  final int? paymentDay;

  /// Spending category for breakdown charts.
  final ExpenseCategory category;

  Expense copyWith({
    String? id,
    String? name,
    double? amount,
    String? monthKey,
    bool? trackable,
    bool? isSubscription,
    int? paymentDay,
    ExpenseCategory? category,
  }) {
    return Expense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      monthKey: monthKey ?? this.monthKey,
      trackable: trackable ?? this.trackable,
      isSubscription: isSubscription ?? this.isSubscription,
      paymentDay: paymentDay ?? this.paymentDay,
      category: category ?? this.category,
    );
  }
}
