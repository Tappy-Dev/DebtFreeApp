import 'dart:math' as math;

class Mortgage {
  const Mortgage({
    this.id = 'mortgage',
    this.name = 'Mortgage',
    required this.startDate,
    required this.originalLoanAmount,
    required this.mortgageTermMonths,
    required this.annualRate,
    required this.monthlyPayment,
    this.overpayment = 0,
    this.overpaymentStartDate,
    this.paymentDay = 1,
    this.dealEndDate,
    this.ownershipType = MortgageOwnershipType.standard,
    this.repaymentType = MortgageRepaymentType.repayment,
    this.ownedSharePercent = 100,
    this.monthlyRent = 0,
    this.monthlyServiceCharge = 0,
    this.monthlyGroundRent = 0,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final double originalLoanAmount;
  final int mortgageTermMonths;
  final double annualRate;
  final double monthlyPayment;

  /// Extra monthly amount the user pays on top of the standard payment.
  final double overpayment;

  /// The month from which the overpayment starts to apply (null = always).
  final DateTime? overpaymentStartDate;

  /// Day of month this mortgage payment is usually taken.
  final int paymentDay;

  /// When the current fixed-rate deal expires (null = unknown / tracker / SVR).
  final DateTime? dealEndDate;

  /// Standard mortgage or Shared Ownership mortgage.
  final MortgageOwnershipType ownershipType;

  /// How the loan is serviced: repayment or interest-only.
  final MortgageRepaymentType repaymentType;

  /// Share of the property currently owned by the borrower.
  final double ownedSharePercent;

  /// Shared Ownership rent paid on the unowned share.
  final double monthlyRent;

  /// Monthly service charge for the property.
  final double monthlyServiceCharge;

  /// Monthly ground rent.
  final double monthlyGroundRent;

  /// Elapsed time since mortgage start.
  int get elapsedMonths {
    final now = DateTime.now();
    return math.max(
        0, (now.year - startDate.year) * 12 + (now.month - startDate.month));
  }

  /// Remaining months on the original mortgage term.
  int get remainingTermMonths => math.max(0, mortgageTermMonths - elapsedMonths);

  /// Outstanding balance calculated via amortization formula.
  double get balance {
    if (remainingTermMonths <= 0) return 0;
    final r = annualRate / 100 / 12;
    if (r <= 0) {
      // Simple linear repayment (no interest).
      return math.max(0, originalLoanAmount - (monthlyPayment * elapsedMonths));
    }
    // Present value of remaining annuity: B = (M/r) * (1 - (1+r)^-n)
    final n = remainingTermMonths;
    return (monthlyPayment / r) * (1 - math.pow(1 + r, -n));
  }

  double get monthlyInterest =>
      balance <= 0 || annualRate <= 0 ? 0 : balance * (annualRate / 100) / 12;

  double get totalMonthlyPayment => monthlyPayment + overpayment;

  double get totalMonthlyHousingCost =>
      totalMonthlyPayment +
      monthlyRent +
      monthlyServiceCharge +
      monthlyGroundRent;

  Mortgage copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    double? originalLoanAmount,
    int? mortgageTermMonths,
    double? annualRate,
    double? monthlyPayment,
    double? overpayment,
    // Use Object? sentinel so callers can explicitly clear nullable dates.
    Object? overpaymentStartDate = _sentinel,
    int? paymentDay,
    Object? dealEndDate = _sentinel,
    MortgageOwnershipType? ownershipType,
    MortgageRepaymentType? repaymentType,
    double? ownedSharePercent,
    double? monthlyRent,
    double? monthlyServiceCharge,
    double? monthlyGroundRent,
  }) {
    return Mortgage(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      originalLoanAmount: originalLoanAmount ?? this.originalLoanAmount,
      mortgageTermMonths: mortgageTermMonths ?? this.mortgageTermMonths,
      annualRate: annualRate ?? this.annualRate,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      overpayment: overpayment ?? this.overpayment,
      overpaymentStartDate: overpaymentStartDate == _sentinel
          ? this.overpaymentStartDate
          : overpaymentStartDate as DateTime?,
      paymentDay: paymentDay ?? this.paymentDay,
      dealEndDate: dealEndDate == _sentinel
          ? this.dealEndDate
          : dealEndDate as DateTime?,
      ownershipType: ownershipType ?? this.ownershipType,
      repaymentType: repaymentType ?? this.repaymentType,
      ownedSharePercent: ownedSharePercent ?? this.ownedSharePercent,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      monthlyServiceCharge: monthlyServiceCharge ?? this.monthlyServiceCharge,
      monthlyGroundRent: monthlyGroundRent ?? this.monthlyGroundRent,
    );
  }
}

const Object _sentinel = Object();

enum MortgageOwnershipType {
  standard,
  sharedOwnership,
}

enum MortgageRepaymentType {
  repayment,
  interestOnly,
}

class MortgageMath {
  static double monthlyInterest(double balance, double annualRate) {
    if (balance <= 0 || annualRate <= 0) return 0;
    return balance * (annualRate / 100) / 12;
  }

  // Standard amortization payment formula.
  static double paymentForTerm({
    required double principal,
    required double annualRate,
    required int termMonths,
  }) {
    if (principal <= 0 || termMonths <= 0) return 0;
    if (annualRate <= 0) return principal / termMonths;

    final r = annualRate / 100 / 12;
    final denom = 1 - (1 / math.pow(1 + r, termMonths));
    if (denom <= 0) return principal / termMonths;
    return principal * r / denom;
  }

  // Infer term months from principal/rate/payment.
  static int? termForPayment({
    required double principal,
    required double annualRate,
    required double monthlyPayment,
  }) {
    if (principal <= 0 || monthlyPayment <= 0) return null;

    if (annualRate <= 0) {
      return (principal / monthlyPayment).ceil();
    }

    final r = annualRate / 100 / 12;
    final monthlyInterestOnly = principal * r;
    if (monthlyPayment <= monthlyInterestOnly) {
      return null;
    }

    final ratio = monthlyPayment / (monthlyPayment - principal * r);
    final n = (math.log(ratio) / math.log(1 + r)).ceil();
    if (n.isNaN || n.isInfinite || n <= 0) return null;
    return n;
  }
}
