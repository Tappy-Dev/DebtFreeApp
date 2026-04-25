class Mortgage {
  const Mortgage({
    this.id = 'mortgage',
    this.name = 'Mortgage',
    required this.balance,
    required this.annualRate,
    required this.monthlyPayment,
    required this.remainingTermMonths,
    this.overpayment = 0,
    this.paymentDay = 1,
    this.dealEndDate,
  });

  final String id;
  final String name;
  final double balance;
  final double annualRate;
  final double monthlyPayment;
  final int remainingTermMonths;

  /// Extra monthly amount the user pays on top of the standard payment.
  final double overpayment;

  /// Day of month this mortgage payment is usually taken.
  final int paymentDay;

  /// When the current fixed-rate deal expires (null = unknown / tracker / SVR).
  final DateTime? dealEndDate;

  double get monthlyInterest =>
      balance <= 0 || annualRate <= 0 ? 0 : balance * (annualRate / 100) / 12;

  double get totalMonthlyPayment => monthlyPayment + overpayment;

  Mortgage copyWith({
    String? id,
    String? name,
    double? balance,
    double? annualRate,
    double? monthlyPayment,
    int? remainingTermMonths,
    double? overpayment,
    int? paymentDay,
    // Use Object? sentinel so callers can explicitly clear dealEndDate to null.
    Object? dealEndDate = _sentinel,
  }) {
    return Mortgage(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      annualRate: annualRate ?? this.annualRate,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      remainingTermMonths: remainingTermMonths ?? this.remainingTermMonths,
      overpayment: overpayment ?? this.overpayment,
      paymentDay: paymentDay ?? this.paymentDay,
      dealEndDate: dealEndDate == _sentinel
          ? this.dealEndDate
          : dealEndDate as DateTime?,
    );
  }
}

const Object _sentinel = Object();
