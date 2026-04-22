import 'dart:math' as math;

import 'package:debt_free_app/features/debts/domain/debt_detail.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/shared/widgets/timeline_chart.dart';
import 'package:intl/intl.dart';

class BuildDebtDetail {
  DebtDetail call({
    required DebtAccount debt,
    double extraPayment = 0,
    int maxMonths = 600,
  }) {
    final baseline = _simulate(
      balance: debt.balance,
      apr: debt.apr,
      rule: debt.minPaymentRule,
      fixedMinPayment: debt.minimumPayment,
      extraPayment: 0,
      maxMonths: maxMonths,
    );

    final overpayment = _simulate(
      balance: debt.balance,
      apr: debt.apr,
      rule: debt.minPaymentRule,
      fixedMinPayment: debt.minimumPayment,
      extraPayment: extraPayment,
      maxMonths: maxMonths,
    );

    final monthsSaved = math.max(0, baseline.months - overpayment.months);
    final interestSaved =
        math.max(0.0, baseline.totalInterest - overpayment.totalInterest);

    return DebtDetail(
      debtName: debt.name,
      balance: debt.balance,
      apr: debt.apr,
      minimumPayment: debt.currentMinPayment(),
      payoffDateLabel: _formatPayoffDate(baseline.months),
      totalInterest: baseline.totalInterest,
      monthsToPayoff: baseline.months,
      chartData: baseline.chartData,
      overpaymentPayoffDateLabel: _formatPayoffDate(overpayment.months),
      overpaymentTotalInterest: overpayment.totalInterest,
      overpaymentMonthsToPayoff: overpayment.months,
      overpaymentMonthsSaved: monthsSaved,
      overpaymentInterestSaved: interestSaved,
      overpaymentChartData: overpayment.chartData,
    );
  }

  _SimulationResult _simulate({
    required double balance,
    required double apr,
    required MinPaymentRule rule,
    required double fixedMinPayment,
    required double extraPayment,
    required int maxMonths,
  }) {
    if (balance <= 0) {
      return const _SimulationResult(
        months: 0,
        totalInterest: 0,
        chartData: <TimelineDataPoint>[],
      );
    }

    final monthFormat = DateFormat('MMM yy');
    final now = DateTime.now();
    double remaining = balance;
    double totalInterest = 0;
    final chartData = <TimelineDataPoint>[];

    chartData.add(
      TimelineDataPoint(
        label: monthFormat.format(DateTime(now.year, now.month)),
        value: remaining,
      ),
    );

    int month = 0;
    while (remaining > 0 && month < maxMonths) {
      final interest = remaining * (apr / 100) / 12;
      remaining += interest;
      totalInterest += interest;

      final minPayment = rule.calculate(remaining, apr, fixedMinPayment);
      final monthlyPayment = minPayment + extraPayment;
      final payment = math.min(monthlyPayment, remaining);
      remaining -= payment;
      remaining = math.max(0, remaining);
      month++;

      final date = DateTime(now.year, now.month + month);
      chartData.add(
        TimelineDataPoint(
          label: monthFormat.format(date),
          value: remaining,
        ),
      );
    }

    return _SimulationResult(
      months: month,
      totalInterest: totalInterest,
      chartData: chartData,
    );
  }

  String _formatPayoffDate(int months) {
    if (months <= 0) {
      return 'Already paid off';
    }

    final now = DateTime.now();
    final payoffDate = DateTime(now.year, now.month + months);
    return DateFormat.yMMM().format(payoffDate);
  }
}

class _SimulationResult {
  const _SimulationResult({
    required this.months,
    required this.totalInterest,
    required this.chartData,
  });

  final int months;
  final double totalInterest;
  final List<TimelineDataPoint> chartData;
}
