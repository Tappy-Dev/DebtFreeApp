import 'dart:math' as math;

import 'package:debt_free_app/features/simulation/engine/strategies/avalanche_strategy.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/projection_result.dart';
import 'package:debt_free_app/features/simulation/models/scenario.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';

class ProjectionEngine {
  ProjectionResult simulate(
    List<DebtAccount> debts,
    List<IncomeSource> incomeSources,
    List<Expense> expenses,
    List<ScenarioChange> scenarioChanges, {
    RepaymentStrategy strategy = RepaymentStrategy.avalanche,
    DateTime? startDate,
    int maxMonths = 600,
  }) {
    final baseline = _runProjection(
      debts,
      incomeSources,
      expenses,
      const <ScenarioChange>[],
      strategy: strategy,
      startDate: startDate,
      maxMonths: maxMonths,
    );

    final projected = _runProjection(
      debts,
      incomeSources,
      expenses,
      scenarioChanges,
      strategy: strategy,
      startDate: startDate,
      maxMonths: maxMonths,
    );

    final interestSaved = math.max(
      0.0,
      baseline.totalInterestPaid - projected.totalInterestPaid,
    );
    final monthsSaved = _calculateMonthsSaved(
      baseline.updatedPayoffDate,
      projected.updatedPayoffDate,
    );

    return projected.copyWith(
      totalInterestSaved: interestSaved,
      monthsSaved: monthsSaved,
    );
  }

  ProjectionResult _runProjection(
    List<DebtAccount> debts,
    List<IncomeSource> incomeSources,
    List<Expense> expenses,
    List<ScenarioChange> scenarioChanges, {
    required RepaymentStrategy strategy,
    DateTime? startDate,
    required int maxMonths,
  }) {
    final workingDebts = debts
        .map((DebtAccount debt) => debt.copy())
        .where((DebtAccount debt) => !debt.isPaidOff)
        .toList();
    final currentDate = startDate ?? DateTime.now();
    final projectionStart = DateTime(currentDate.year, currentDate.month);

    if (workingDebts.isEmpty) {
      return ProjectionResult(
        monthlyBreakdown: const <ProjectionMonth>[],
        totalInterestPaid: 0,
        totalInterestSaved: 0,
        updatedPayoffDate: projectionStart,
        monthsSaved: 0,
      );
    }

    final baseIncome = incomeSources.fold<double>(
      0,
      (double sum, IncomeSource item) => sum + item.amount,
    );
    final baseExpenses = expenses.fold<double>(
      0,
      (double sum, Expense item) => sum + item.amount,
    );

    double totalInterestPaid = 0;
    final List<ProjectionMonth> monthlyBreakdown = <ProjectionMonth>[];
    DateTime? payoffDate;

    for (int monthIndex = 0; monthIndex < maxMonths; monthIndex++) {
      final activeDebts = workingDebts
          .where((DebtAccount debt) => !debt.isPaidOff)
          .toList();
      if (activeDebts.isEmpty) {
        break;
      }

      final month = DateTime(
        projectionStart.year,
        projectionStart.month + monthIndex,
      );
      final activeChanges = scenarioChanges
          .where((ScenarioChange change) => change.appliesToMonth(monthIndex))
          .toList();
      final incomeBoost = activeChanges
          .where(
            (ScenarioChange change) =>
                change.changeType == ChangeType.increaseIncome,
          )
          .fold<double>(
            0,
            (double sum, ScenarioChange change) => sum + change.amount,
          );
      final expenseReduction = activeChanges
          .where(
            (ScenarioChange change) =>
                change.changeType == ChangeType.reduceExpenses,
          )
          .fold<double>(
            0,
            (double sum, ScenarioChange change) => sum + change.amount,
          );
      final extraPayment = activeChanges
          .where(
            (ScenarioChange change) =>
                change.changeType == ChangeType.extraPayment,
          )
          .fold<double>(
            0,
            (double sum, ScenarioChange change) => sum + change.amount,
          );

      final prioritized = _prioritizeDebts(activeDebts, strategy);

      double monthInterest = 0;
      for (final DebtAccount debt in prioritized) {
        final interest = debt.calculateMonthlyInterest();
        debt.balance += interest;
        monthInterest += interest;
      }
      totalInterestPaid += monthInterest;

      final monthlyCashBeforeDebt =
          baseIncome + incomeBoost - (baseExpenses - expenseReduction);
      double remainingBudget = math.max(0.0, monthlyCashBeforeDebt) + extraPayment;
      double totalPayment = 0;

      for (final DebtAccount debt in prioritized) {
        final minimumPayment = math.min(debt.balance, debt.currentMinPayment());
        final paymentApplied = debt.makePayment(
          math.min(minimumPayment, remainingBudget),
        );
        totalPayment += paymentApplied;
        remainingBudget -= paymentApplied;
      }

      for (final DebtAccount debt in prioritized) {
        if (remainingBudget <= 0) {
          break;
        }

        final paymentApplied = debt.makePayment(remainingBudget);
        totalPayment += paymentApplied;
        remainingBudget -= paymentApplied;
      }

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
          remainingCash: math.max(0.0, monthlyCashBeforeDebt - totalPayment),
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

  List<DebtAccount> _prioritizeDebts(
    List<DebtAccount> debts,
    RepaymentStrategy strategy,
  ) {
    switch (strategy) {
      case RepaymentStrategy.snowball:
        final sorted = debts.toList()
          ..sort(
            (DebtAccount a, DebtAccount b) {
              final balanceCompare = a.balance.compareTo(b.balance);
              if (balanceCompare != 0) {
                return balanceCompare;
              }
              return b.apr.compareTo(a.apr);
            },
          );
        return sorted;
      case RepaymentStrategy.minimum:
      case RepaymentStrategy.custom:
        return debts.toList();
      case RepaymentStrategy.avalanche:
        return AvalancheStrategy().prioritizeDebts(debts);
    }
  }

  int _calculateMonthsSaved(DateTime? baselineDate, DateTime? scenarioDate) {
    if (baselineDate == null || scenarioDate == null) {
      return 0;
    }

    final difference = (baselineDate.year - scenarioDate.year) * 12 +
        baselineDate.month -
        scenarioDate.month;

    return difference < 0 ? 0 : difference;
  }
}
