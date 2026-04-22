import 'dart:math' as math;

import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/projection_result.dart';

class SnowballStrategy {
  ProjectionResult calculate(
    List<DebtAccount> debts,
    double totalMonthlyPayment, {
    DateTime? startDate,
    int maxMonths = 600,
  }) {
    final workingDebts = debts
        .map((DebtAccount debt) => debt.copy())
        .where((DebtAccount debt) => !debt.isPaidOff)
        .toList();
    final currentDate = startDate ?? DateTime.now();
    final projectionStart = DateTime(currentDate.year, currentDate.month);

    if (workingDebts.isEmpty) {
      return const ProjectionResult(
        monthlyBreakdown: <ProjectionMonth>[],
        totalInterestPaid: 0,
        totalInterestSaved: 0,
        updatedPayoffDate: null,
        monthsSaved: 0,
      );
    }

    double totalInterestPaid = 0;
    DateTime? payoffDate;
    final List<ProjectionMonth> monthlyBreakdown = <ProjectionMonth>[];

    for (int monthIndex = 0; monthIndex < maxMonths; monthIndex++) {
      final activeDebts = workingDebts
          .where((DebtAccount debt) => !debt.isPaidOff)
          .toList();
      if (activeDebts.isEmpty) {
        break;
      }

      activeDebts.sort(
        (DebtAccount a, DebtAccount b) {
          final balanceCompare = a.balance.compareTo(b.balance);
          if (balanceCompare != 0) {
            return balanceCompare;
          }
          return b.apr.compareTo(a.apr);
        },
      );

      double monthInterest = 0;
      for (final DebtAccount debt in activeDebts) {
        final interest = debt.calculateMonthlyInterest();
        debt.balance += interest;
        monthInterest += interest;
      }
      totalInterestPaid += monthInterest;

      double remainingBudget = math.max(0.0, totalMonthlyPayment);
      double totalPayment = 0;

      for (final DebtAccount debt in activeDebts) {
        if (remainingBudget <= 0) {
          break;
        }

        final paymentApplied = debt.makePayment(
          math.min(remainingBudget, debt.currentMinPayment()),
        );
        totalPayment += paymentApplied;
        remainingBudget -= paymentApplied;
      }

      for (final DebtAccount debt in activeDebts) {
        if (remainingBudget <= 0) {
          break;
        }

        final paymentApplied = debt.makePayment(remainingBudget);
        totalPayment += paymentApplied;
        remainingBudget -= paymentApplied;
      }

      final month = DateTime(
        projectionStart.year,
        projectionStart.month + monthIndex,
      );
      final totalDebtRemaining = workingDebts.fold<double>(
        0,
        (double sum, DebtAccount debt) => sum + math.max(0.0, debt.balance),
      );
      monthlyBreakdown.add(
        ProjectionMonth(
          monthIndex: monthIndex,
          month: month,
          totalDebtRemaining: totalDebtRemaining,
          totalInterest: monthInterest,
          totalPayment: totalPayment,
          remainingCash: 0,
        ),
      );

      if (totalDebtRemaining <= 0) {
        payoffDate = month;
        break;
      }
    }

    payoffDate ??=
        monthlyBreakdown.isEmpty ? projectionStart : monthlyBreakdown.last.month;

    return ProjectionResult(
      monthlyBreakdown: monthlyBreakdown,
      totalInterestPaid: totalInterestPaid,
      totalInterestSaved: 0,
      updatedPayoffDate: payoffDate,
      monthsSaved: 0,
    );
  }
}
