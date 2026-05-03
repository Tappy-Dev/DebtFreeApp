import 'dart:math' as math;

import 'package:debt_free_app/features/simulation/models/mortgage.dart';

class MortgageProjectionMonth {
  const MortgageProjectionMonth({
    required this.monthIndex,
    required this.month,
    required this.balanceRemaining,
    required this.interestPaid,
    required this.principalPaid,
    required this.overpaymentPaid,
  });

  final int monthIndex;
  final DateTime month;
  final double balanceRemaining;
  final double interestPaid;
  final double principalPaid;
  final double overpaymentPaid;
}

class MortgageProjectionResult {
  const MortgageProjectionResult({
    required this.monthlyBreakdown,
    required this.totalInterestPaid,
    required this.payoffDate,
    required this.monthsToPayoff,
  });

  final List<MortgageProjectionMonth> monthlyBreakdown;
  final double totalInterestPaid;
  final DateTime payoffDate;
  final int monthsToPayoff;
}

class MortgageProjectionEngine {
  /// Simulate a mortgage with optional overpayment.
  MortgageProjectionResult simulate(
    Mortgage mortgage, {
    double extraMonthlyOverpayment = 0,
    DateTime? overpaymentStartDate,
    DateTime? startDate,
    int? maxMonths,
  }) {
    final effectiveMax = maxMonths ?? mortgage.remainingTermMonths + 120;
    final now = startDate ?? DateTime.now();
    final projectionStart = DateTime(now.year, now.month);

    if (mortgage.balance <= 0) {
      return MortgageProjectionResult(
        monthlyBreakdown: const <MortgageProjectionMonth>[],
        totalInterestPaid: 0,
        payoffDate: projectionStart,
        monthsToPayoff: 0,
      );
    }

    double balance = mortgage.balance;
    double totalInterest = 0;
    final List<MortgageProjectionMonth> breakdown =
        <MortgageProjectionMonth>[];
    final monthlyRate = mortgage.annualRate / 100 / 12;
    final totalOverpayment = mortgage.overpayment + extraMonthlyOverpayment;
    // Resolve the effective overpayment start date (model field wins if set,
    // otherwise caller-supplied param, otherwise no restriction).
    final effectiveOverpaymentStart =
        mortgage.overpaymentStartDate ?? overpaymentStartDate;

    for (int i = 0; i < effectiveMax; i++) {
      if (balance <= 0) break;

      final month = DateTime(
        projectionStart.year,
        projectionStart.month + i,
      );

      final interest = balance * monthlyRate;
      totalInterest += interest;

      final scheduledPrincipal = mortgage.monthlyPayment - interest;
      final maxPrincipal = balance;
      final double principalPaid = math.min(
        math.max(0.0, scheduledPrincipal),
        maxPrincipal,
      ).toDouble();
      balance -= principalPaid;

      double overpaymentApplied = 0;
      final overpaymentActive = effectiveOverpaymentStart == null ||
          !month.isBefore(DateTime(
            effectiveOverpaymentStart.year,
            effectiveOverpaymentStart.month,
          ));
      if (totalOverpayment > 0 && balance > 0 && overpaymentActive) {
        overpaymentApplied = math.min(totalOverpayment, balance).toDouble();
        balance -= overpaymentApplied;
      }

      breakdown.add(MortgageProjectionMonth(
        monthIndex: i,
        month: month,
        balanceRemaining: math.max(0.0, balance),
        interestPaid: interest,
        principalPaid: principalPaid.toDouble(),
        overpaymentPaid: overpaymentApplied,
      ));

      if (balance <= 0) break;
    }

    final payoffDate = breakdown.isEmpty
        ? projectionStart
        : breakdown.last.month;

    return MortgageProjectionResult(
      monthlyBreakdown: breakdown,
      totalInterestPaid: totalInterest,
      payoffDate: payoffDate,
      monthsToPayoff: breakdown.length,
    );
  }

  /// Compare baseline (no overpayment) vs with overpayment.
  MortgageComparisonResult compare(
    Mortgage mortgage, {
    required double overpaymentAmount,
    DateTime? startDate,
  }) {
    final baseline = simulate(
      mortgage.copyWith(overpayment: 0),
      startDate: startDate,
    );
    final withOverpayment = simulate(
      mortgage.copyWith(overpayment: 0),
      extraMonthlyOverpayment: overpaymentAmount,
      startDate: startDate,
    );

    return MortgageComparisonResult(
      baseline: baseline,
      withOverpayment: withOverpayment,
      interestSaved: math.max(
        0,
        baseline.totalInterestPaid - withOverpayment.totalInterestPaid,
      ),
      monthsSaved: math.max(
        0,
        baseline.monthsToPayoff - withOverpayment.monthsToPayoff,
      ),
    );
  }
}

class MortgageComparisonResult {
  const MortgageComparisonResult({
    required this.baseline,
    required this.withOverpayment,
    required this.interestSaved,
    required this.monthsSaved,
  });

  final MortgageProjectionResult baseline;
  final MortgageProjectionResult withOverpayment;
  final double interestSaved;
  final int monthsSaved;
}
