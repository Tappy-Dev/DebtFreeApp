import 'dart:math' as math;

enum DebtType {
  loan,
  creditCard,
  other,
}

extension DebtTypeLabel on DebtType {
  String get label {
    switch (this) {
      case DebtType.loan:
        return 'Loan';
      case DebtType.creditCard:
        return 'Credit Card';
      case DebtType.other:
        return 'Other';
    }
  }
}

/// How the minimum payment is calculated each month.
enum MinPaymentType {
  /// Fixed amount set by the user (legacy behaviour).
  fixed,

  /// Interest + percentage of balance, with a floor.
  /// Typical UK: interest + 1% of balance, min £25.
  interestPlusPercentage,

  /// Flat percentage of balance, with a floor.
  /// E.g. 2.25% of balance, min £5.
  percentageOfBalance,
}

class MinPaymentRule {
  const MinPaymentRule({
    this.type = MinPaymentType.interestPlusPercentage,
    this.percentage = 1.0,
    this.floor = 25.0,
  });

  /// UK typical default: interest + 1% of balance, min £25.
  static const MinPaymentRule ukDefault = MinPaymentRule();

  /// Legacy fixed-amount rule (uses DebtAccount.minimumPayment directly).
  static const MinPaymentRule fixedRule = MinPaymentRule(
    type: MinPaymentType.fixed,
  );

  final MinPaymentType type;

  /// The percentage component (e.g. 1.0 means 1%).
  final double percentage;

  /// The minimum floor (e.g. £25).
  final double floor;

  /// Calculate the minimum payment for a given balance and APR.
  double calculate(double balance, double apr, double fixedAmount) {
    if (balance <= 0) return 0;

    switch (type) {
      case MinPaymentType.fixed:
        return math.min(fixedAmount, balance);

      case MinPaymentType.interestPlusPercentage:
        final interest = balance * (apr / 100) / 12;
        final calculated = interest + (balance * percentage / 100);
        return math.min(math.max(calculated, floor), balance);

      case MinPaymentType.percentageOfBalance:
        final calculated = balance * percentage / 100;
        return math.min(math.max(calculated, floor), balance);
    }
  }

  MinPaymentRule copyWith({
    MinPaymentType? type,
    double? percentage,
    double? floor,
  }) {
    return MinPaymentRule(
      type: type ?? this.type,
      percentage: percentage ?? this.percentage,
      floor: floor ?? this.floor,
    );
  }

  String get label {
    switch (type) {
      case MinPaymentType.fixed:
        return 'Fixed amount';
      case MinPaymentType.interestPlusPercentage:
        return 'Interest + ${percentage.toStringAsFixed(1)}% (min £${floor.toStringAsFixed(0)})';
      case MinPaymentType.percentageOfBalance:
        return '${percentage.toStringAsFixed(1)}% of balance (min £${floor.toStringAsFixed(0)})';
    }
  }
}

class DebtAccount {
  DebtAccount({
    this.id = '',
    this.name = '',
    this.debtType = DebtType.other,
    required this.balance,
    required this.apr,
    double? payment,
    double? minimumPayment,
    this.payoffDate,
    this.startDate,
    this.loanEndDate,
    int paymentDay = 1,
    this.minPaymentRule = const MinPaymentRule(type: MinPaymentType.fixed),
    double? originalBalance,
    List<DebtExtraPayment>? extraPayments,
  })  : minimumPayment = minimumPayment ?? payment ?? 0,
        paymentDay = paymentDay.clamp(1, 28),
        originalBalance = originalBalance ?? balance,
        extraPayments = extraPayments ?? const [];

  final String id;
  final String name;
  final DebtType debtType;
  double balance;
  final double apr;

  /// The fixed minimum payment amount (used as fallback or with fixed rule).
  final double minimumPayment;
  DateTime? payoffDate;

  /// The date the balance was recorded (when repayments begin).
  final DateTime? startDate;

  /// Scheduled final payment month for amortizing loans.
  final DateTime? loanEndDate;

  /// Day of month this debt payment is usually collected.
  final int paymentDay;

  /// The rule that determines how minimum payments are calculated.
  final MinPaymentRule minPaymentRule;

  /// The balance the user originally entered.
  final double originalBalance;

  /// Extra payment periods defined by the user for this debt.
  final List<DebtExtraPayment> extraPayments;

  bool get isPaidOff => balance <= 0;

  bool get isLoan => debtType == DebtType.loan;

  static int loanTermInMonths({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = DateTime(startDate.year, startDate.month);
    final end = DateTime(endDate.year, endDate.month);
    return (end.year - start.year) * 12 + (end.month - start.month) + 1;
  }

  static double calculateAmortizedPayment({
    required double principal,
    required double apr,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final months = loanTermInMonths(startDate: startDate, endDate: endDate);
    if (principal <= 0 || months <= 0) {
      return 0;
    }

    if (apr <= 0) {
      return principal / months;
    }

    final monthlyRate = apr / 100 / 12;
    final denominator = 1 - math.pow(1 + monthlyRate, -months).toDouble();
    if (denominator == 0) {
      return principal / months;
    }

    return principal * monthlyRate / denominator;
  }

  double scheduledLoanPayment() {
    if (!isLoan || startDate == null || loanEndDate == null) {
      return minimumPayment;
    }

    return calculateAmortizedPayment(
      principal: originalBalance,
      apr: apr,
      startDate: startDate!,
      endDate: loanEndDate!,
    );
  }

  /// Calculate the current minimum payment based on the rule and current balance.
  double currentMinPayment() {
    if (isLoan) {
      final scheduledPayment = scheduledLoanPayment();
      final dueThisMonth = balance + calculateMonthlyInterest();
      return math.min(scheduledPayment, dueThisMonth);
    }

    return minPaymentRule.calculate(balance, apr, minimumPayment);
  }

  double calculateMonthlyInterest() {
    if (balance <= 0 || apr <= 0) {
      return 0;
    }

    return balance * (apr / 100) / 12;
  }

  double makePayment(double amount) {
    if (amount <= 0 || balance <= 0) {
      return 0;
    }

    final paymentApplied = amount > balance ? balance : amount;
    balance -= paymentApplied;
    return paymentApplied;
  }

  /// Calculate the projected balance for the current month by simulating
  /// from startDate: each elapsed month adds interest and subtracts the
  /// minimum payment (and any extra payments active in that month).
  double currentProjectedBalance([DateTime? referenceDate]) {
    if (startDate == null) return originalBalance;
    final now = referenceDate ?? DateTime.now();
    final start = DateTime(startDate!.year, startDate!.month);
    final current = DateTime(now.year, now.month);
    final elapsedMonths =
        (current.year - start.year) * 12 + (current.month - start.month);
    if (elapsedMonths <= 0) return originalBalance;

    double bal = originalBalance;
    final scheduledLoanPayment = isLoan ? this.scheduledLoanPayment() : 0.0;
    for (int m = 0; m < elapsedMonths; m++) {
      if (bal <= 0) break;
      // Add interest
      final interest = bal * (apr / 100) / 12;
      bal += interest;
      // Subtract minimum payment
      final minPay = isLoan
          ? math.min(scheduledLoanPayment, bal)
          : minPaymentRule.calculate(bal, apr, minimumPayment);
      bal -= minPay;
      // Subtract any extra payments active this month
      final monthDate = DateTime(start.year, start.month + m);
      for (final extra in extraPayments) {
        if (_monthInRange(monthDate, extra.startDate, extra.endDate)) {
          bal -= extra.amount;
        }
      }
      if (bal < 0) bal = 0;
    }
    return bal;
  }

  /// Monthly interest based on projected balance at [referenceDate].
  double projectedMonthlyInterest([DateTime? referenceDate]) {
    final bal = currentProjectedBalance(referenceDate);
    if (bal <= 0 || apr <= 0) return 0;
    return bal * (apr / 100) / 12;
  }

  /// Minimum payment based on projected balance at [referenceDate].
  double projectedMinPayment([DateTime? referenceDate]) {
    final bal = currentProjectedBalance(referenceDate);
    if (bal <= 0) return 0;
    if (isLoan) {
      final scheduledPayment = scheduledLoanPayment();
      final dueThisMonth = bal + (bal * (apr / 100) / 12);
      return math.min(scheduledPayment, dueThisMonth);
    }
    return minPaymentRule.calculate(bal, apr, minimumPayment);
  }

  static bool _monthInRange(DateTime month, DateTime start, DateTime end) {
    final m = month.year * 12 + month.month;
    final s = start.year * 12 + start.month;
    final e = end.year * 12 + end.month;
    return m >= s && m <= e;
  }

  DebtAccount copy() {
    return DebtAccount(
      id: id,
      name: name,
      debtType: debtType,
      balance: balance,
      apr: apr,
      minimumPayment: minimumPayment,
      payoffDate: payoffDate,
      startDate: startDate,
      loanEndDate: loanEndDate,
      paymentDay: paymentDay,
      minPaymentRule: minPaymentRule,
      originalBalance: originalBalance,
      extraPayments: extraPayments,
    );
  }
}

/// Represents an extra payment period for a specific debt.
class DebtExtraPayment {
  const DebtExtraPayment({
    this.id = '',
    required this.debtId,
    required this.amount,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String debtId;
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
}
