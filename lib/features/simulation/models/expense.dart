class Expense {
  const Expense({
    this.id = '',
    this.name = '',
    required this.amount,
    this.monthKey = '',
    this.trackable = false,
    this.isSubscription = false,
    this.paymentDay,
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

  Expense copyWith({
    String? id,
    String? name,
    double? amount,
    String? monthKey,
    bool? trackable,
    bool? isSubscription,
    int? paymentDay,
  }) {
    return Expense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      monthKey: monthKey ?? this.monthKey,
      trackable: trackable ?? this.trackable,
      isSubscription: isSubscription ?? this.isSubscription,
      paymentDay: paymentDay ?? this.paymentDay,
    );
  }
}
