import 'dart:math' as math;

import 'package:debt_free_app/core/data/financial_repository_extensions.dart';
import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/features/budget/domain/build_budget_snapshot.dart';
import 'package:debt_free_app/features/scenarios/domain/scenario_overview.dart';
import 'package:debt_free_app/features/simulation/engine/projection_engine.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:intl/intl.dart';

class BuildScenarioOverview {
  BuildScenarioOverview({
    required FinancialRepository repository,
    ProjectionEngine? projectionEngine,
  })  : _repository = repository,
        _projectionEngine = projectionEngine ?? ProjectionEngine();

  final FinancialRepository _repository;
  final ProjectionEngine _projectionEngine;

  ScenarioOverview call() {
    final debts = _repository.getDebts();
    final income = _repository.getAdjustedIncomeSources();
    final expenses = _repository.getAllOutgoings();
    final scenarioChanges = _repository.getScenarioChanges();
    final budgetSnapshot = BuildBudgetSnapshot(_repository)();

    final baseline = _projectionEngine.simulate(
      debts,
      income,
      expenses,
      const <ScenarioChange>[],
    );
    final scenario = _projectionEngine.simulate(
      debts,
      income,
      expenses,
      scenarioChanges,
    );
    final plan = _repository.getActiveScenarioPlan();
    final incomeIncrease = plan.incomeIncrease;
    final expenseReduction = plan.expenseReduction;
    final extraPayment = plan.extraPayment;
    final startMonth = plan.startMonth;
    final durationInMonths = plan.durationInMonths;
    final activeChangeLabels = _buildActiveChangeLabels(
      incomeIncrease: incomeIncrease,
      expenseReduction: expenseReduction,
      extraPayment: extraPayment,
    );
    final availableCashAfterAdjustments =
        budgetSnapshot.remainingCash + incomeIncrease + expenseReduction;
    final affordable =
        extraPayment <= math.max(0, availableCashAfterAdjustments);
    final cashBufferAfterPlan = availableCashAfterAdjustments - extraPayment;
    final planSummary = _buildPlanSummary(
      incomeIncrease: incomeIncrease,
      expenseReduction: expenseReduction,
      extraPayment: extraPayment,
    );
    final guidance = _buildGuidance(
      incomeIncrease: incomeIncrease,
      expenseReduction: expenseReduction,
      extraPayment: extraPayment,
      remainingCash: budgetSnapshot.remainingCash,
      availableCashAfterAdjustments: availableCashAfterAdjustments,
      startMonth: startMonth,
      durationInMonths: durationInMonths,
      monthsSaved: scenario.monthsSaved,
      interestSaved: scenario.totalInterestSaved,
      affordable: affordable,
    );

    return ScenarioOverview(
      incomeIncrease: incomeIncrease,
      expenseReduction: expenseReduction,
      extraPayment: extraPayment,
      startMonth: startMonth,
      durationInMonths: durationInMonths,
      scheduleSummary: _buildScheduleSummary(
        startMonth: startMonth,
        durationInMonths: durationInMonths,
        hasActiveChanges: activeChangeLabels.isNotEmpty,
      ),
      scheduleWarningMessage: plan.hasMixedSchedules
          ? 'Some saved scenario changes use different schedules. Re-saving this plan will normalize them to one shared schedule.'
          : null,
      hasActiveChanges: activeChangeLabels.isNotEmpty,
      activeChangeLabels: activeChangeLabels,
      remainingCash: budgetSnapshot.remainingCash,
      availableCashAfterAdjustments: availableCashAfterAdjustments,
      cashBufferAfterPlan: cashBufferAfterPlan,
      isAffordable: affordable,
      baselinePayoffDateLabel: _formatDate(baseline.updatedPayoffDate),
      scenarioPayoffDateLabel: _formatDate(scenario.updatedPayoffDate),
      baselineInterest: baseline.totalInterestPaid,
      scenarioInterest: scenario.totalInterestPaid,
      interestSaved: scenario.totalInterestSaved,
      monthsSaved: scenario.monthsSaved,
      planSummaryTitle: planSummary.title,
      planSummaryMessage: planSummary.message,
      guidanceTitle: guidance.title,
      guidanceMessage: guidance.message,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'In progress';
    }

    return DateFormat.yMMM().format(date);
  }

  _Guidance _buildGuidance({
    required double incomeIncrease,
    required double expenseReduction,
    required double extraPayment,
    required double remainingCash,
    required double availableCashAfterAdjustments,
    required int startMonth,
    required int? durationInMonths,
    required int monthsSaved,
    required double interestSaved,
    required bool affordable,
  }) {
    if (incomeIncrease <= 0 && expenseReduction <= 0 && extraPayment <= 0) {
      return const _Guidance(
        title: 'No scenario changes set yet',
        message:
            'Add extra income, reduce expenses, or make an extra payment to compare this plan against your baseline.',
      );
    }

    if (!affordable) {
      final startLead = startMonth > 0 ? 'when it starts, ' : '';
      return _Guidance(
        title: 'This scenario may be hard to maintain',
        message:
            'Even $startLead you would have about \u00A3${math.max(0, availableCashAfterAdjustments).toStringAsFixed(0)} available for extra debt payments, which is still below the planned amount.',
      );
    }

    if (startMonth > 0) {
      final durationMessage = durationInMonths == null
          ? 'Once active, it stays in place until the debts are paid off.'
          : 'Once active, it lasts for $durationInMonths month${durationInMonths == 1 ? '' : 's'}.';
      return _Guidance(
        title: 'This scenario starts later',
        message:
            'These changes begin in $startMonth month${startMonth == 1 ? '' : 's'}. Until then, your baseline room for extra payments stays around \u00A3${math.max(0, remainingCash).toStringAsFixed(2)}. $durationMessage',
      );
    }

    if (durationInMonths != null && durationInMonths > 0) {
      return _Guidance(
        title: 'This is a temporary scenario',
        message:
            'Your plan runs for $durationInMonths month${durationInMonths == 1 ? '' : 's'}, leaves about \u00A3${math.max(0, availableCashAfterAdjustments - extraPayment).toStringAsFixed(2)} after the extra payment, and is projected to save $monthsSaved months and \u00A3${interestSaved.toStringAsFixed(2)}.',
      );
    }

    if (monthsSaved > 0) {
      final totalCashImprovement = incomeIncrease + expenseReduction;
      return _Guidance(
        title: 'This scenario looks workable',
        message:
            'Your plan adds \u00A3${totalCashImprovement.toStringAsFixed(2)} of monthly flexibility, leaves about \u00A3${math.max(0, availableCashAfterAdjustments - extraPayment).toStringAsFixed(2)} after the extra payment, and is projected to save $monthsSaved months and \u00A3${interestSaved.toStringAsFixed(2)}.',
      );
    }

    return const _Guidance(
      title: 'This scenario fits, but barely changes the plan',
      message: 'Try increasing the extra payment if you want a more noticeable payoff improvement.',
    );
  }

  _Guidance _buildPlanSummary({
    required double incomeIncrease,
    required double expenseReduction,
    required double extraPayment,
  }) {
    if (incomeIncrease <= 0 && expenseReduction <= 0 && extraPayment <= 0) {
      return const _Guidance(
        title: 'Baseline plan',
        message: 'No scenario adjustments are active yet.',
      );
    }

    final parts = <String>[];
    if (incomeIncrease > 0) {
      parts.add('adds \u00A3${incomeIncrease.toStringAsFixed(2)} income');
    }
    if (expenseReduction > 0) {
      parts.add('cuts \u00A3${expenseReduction.toStringAsFixed(2)} of expenses');
    }
    if (extraPayment > 0) {
      parts.add('sends \u00A3${extraPayment.toStringAsFixed(2)} extra to debt');
    }

    return _Guidance(
      title: 'Active plan changes',
      message: 'This scenario ${parts.join(', ')} each month.',
    );
  }

  List<String> _buildActiveChangeLabels({
    required double incomeIncrease,
    required double expenseReduction,
    required double extraPayment,
  }) {
    final labels = <String>[];
    if (incomeIncrease > 0) {
      labels.add(
        'Extra monthly income: \u00A3${incomeIncrease.toStringAsFixed(2)}',
      );
    }
    if (expenseReduction > 0) {
      labels.add(
        'Monthly expense reduction: \u00A3${expenseReduction.toStringAsFixed(2)}',
      );
    }
    if (extraPayment > 0) {
      labels.add(
        'Extra debt payment: \u00A3${extraPayment.toStringAsFixed(2)}',
      );
    }

    return labels;
  }

  String _buildScheduleSummary({
    required int startMonth,
    required int? durationInMonths,
    required bool hasActiveChanges,
  }) {
    if (!hasActiveChanges) {
      return 'No scheduled scenario is active.';
    }

    final startLabel = startMonth == 0
        ? 'starts this month'
        : 'starts in $startMonth month${startMonth == 1 ? '' : 's'}';
    if (durationInMonths == null) {
      return '$startLabel and stays active until the debts are paid off.';
    }

    return '$startLabel and lasts for $durationInMonths month${durationInMonths == 1 ? '' : 's'}.';
  }
}

class _Guidance {
  const _Guidance({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}
