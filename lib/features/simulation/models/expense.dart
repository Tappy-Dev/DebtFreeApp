class Expense {
  const Expense({
    this.id = '',
    this.name = '',
    required this.amount,
    this.monthKey = '',
    this.trackable = false,
  });

  final String id;
  final String name;
  final double amount;
  final String monthKey;
  final bool trackable;

  Expense copyWith({
    String? id,
    String? name,
    double? amount,
    String? monthKey,
    bool? trackable,
  }) {
    return Expense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      monthKey: monthKey ?? this.monthKey,
      trackable: trackable ?? this.trackable,
    );
  }
}
