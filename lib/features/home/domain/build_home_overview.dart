import 'dart:math' as math;

import 'package:debt_free_app/core/data/financial_repository_extensions.dart';
import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/features/budget/domain/build_budget_snapshot.dart';
import 'package:debt_free_app/features/home/domain/home_overview.dart';
import 'package:debt_free_app/features/simulation/engine/mortgage_projection_engine.dart';
import 'package:debt_free_app/features/simulation/engine/projection_engine.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/simulation/models/projection_result.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/shared/widgets/timeline_chart.dart';
import 'package:intl/intl.dart';

class BuildHomeOverview {
  BuildHomeOverview({
    required FinancialRepository repository,
    ProjectionEngine? projectionEngine,
    DateTime? referenceDate,
  })  : _repository = repository,
        _projectionEngine = projectionEngine ?? ProjectionEngine(),
        _referenceDate = referenceDate;

  final FinancialRepository _repository;
  final ProjectionEngine _projectionEngine;
  final DateTime? _referenceDate;

  HomeOverview call() {
    final debts = _repository.getDebts();
    final mortgages = _repository.getMortgages();
    final referenceDate = _referenceDate ?? DateTime.now();
    final income = _repository.getAdjustedIncomeSources();
    final expenses = _repository.getAllOutgoings();
    final scenarioChanges = _repository.getScenarioChanges();
    final budgetSnapshot = BuildBudgetSnapshot(_repository)();

    final debtsAtReference = debts
        .map(
          (d) => DebtAccount(
            id: d.id,
            name: d.name,
            debtType: d.debtType,
            balance: d.currentProjectedBalance(referenceDate),
            apr: d.apr,
            minimumPayment: d.minimumPayment,
            payoffDate: d.payoffDate,
            startDate: d.startDate,
            loanEndDate: d.loanEndDate,
            minPaymentRule: d.minPaymentRule,
            originalBalance: d.originalBalance,
            extraPayments: d.extraPayments,
          ),
        )
        .toList(growable: false);

    final boosted = _projectionEngine.simulate(
      debtsAtReference,
      income,
      expenses,
      scenarioChanges,
      startDate: referenceDate,
    );
    final plan = _repository.getActiveScenarioPlan();

    final totalDebt = debtsAtReference.fold<double>(
      0,
      (double sum, debt) => sum + debt.balance,
    );
    final nextMonthBalance = boosted.monthlyBreakdown.isEmpty
        ? null
        : boosted.monthlyBreakdown.first.totalDebtRemaining;
    final debtChangeFromPreviousMonth = nextMonthBalance == null
        ? 0.0
        : totalDebt - nextMonthBalance;
    final incomeIncrease = plan.incomeIncrease;
    final expenseReduction = plan.expenseReduction;
    // Include both global and per-debt extra payments for display
    final extraPayment = scenarioChanges
        .where((c) => c.changeType == ChangeType.extraPayment)
        .fold(0.0, (sum, c) => sum + c.amount);
    final startMonth = plan.startMonth;
    final durationInMonths = plan.durationInMonths;
    final monthlyFlexibilityGain = incomeIncrease + expenseReduction;
    final availableCashAfterScenario =
        budgetSnapshot.remainingCash + monthlyFlexibilityGain;
    final planSummary = _buildPlanSummary(
      incomeIncrease: incomeIncrease,
      expenseReduction: expenseReduction,
      extraPayment: extraPayment,
    );
    final recommendation = _buildRecommendation(
      incomeIncrease: incomeIncrease,
      expenseReduction: expenseReduction,
      remainingCash: budgetSnapshot.remainingCash,
      availableCashAfterScenario: availableCashAfterScenario,
      extraPayment: extraPayment,
      startMonth: startMonth,
      durationInMonths: durationInMonths,
      monthsSaved: boosted.monthsSaved,
      interestSaved: boosted.totalInterestSaved,
    );

    final projectedMortgages = _projectMortgagesToReference(
      mortgages,
      referenceDate,
    );
    final aggregateMortgage = _aggregateMortgage(projectedMortgages);

    return HomeOverview(
      totalDebt: totalDebt,
      debtFreeDateLabel: _formatMonthYear(boosted.updatedPayoffDate),
      interestProjection: boosted.totalInterestPaid,
      interestSaved: boosted.totalInterestSaved,
      monthsSaved: boosted.monthsSaved,
      nextMonthBalance: nextMonthBalance,
      debtChangeFromPreviousMonth: debtChangeFromPreviousMonth,
      remainingCash: budgetSnapshot.remainingCash,
      availableCashAfterScenario: availableCashAfterScenario,
      incomeIncrease: incomeIncrease,
      expenseReduction: expenseReduction,
      extraPayment: extraPayment,
      monthlyFlexibilityGain: monthlyFlexibilityGain,
      planSummaryTitle: planSummary.title,
      planSummaryMessage: planSummary.message,
      scheduleSummary: _buildScheduleSummary(
        hasActiveScenario:
            incomeIncrease > 0 || expenseReduction > 0 || extraPayment > 0,
        startMonth: startMonth,
        durationInMonths: durationInMonths,
      ),
      scheduleWarningMessage: plan.hasMixedSchedules
          ? 'Some saved scenario changes use different schedules. Re-saving the plan will normalize them.'
          : null,
      recommendationTitle: recommendation.title,
      recommendationMessage: recommendation.message,
      debtChartData: _buildChartData(boosted.monthlyBreakdown),
      mortgage: aggregateMortgage,
      mortgageCount: projectedMortgages.length,
      mortgagePayoffLabel: _buildMortgagePayoffLabel(projectedMortgages),
      mortgageTotalInterest: _buildMortgageTotalInterest(projectedMortgages),
      monthlyDebtInterest: debtsAtReference.fold(
        0,
        (sum, d) => sum + (d.balance <= 0 ? 0 : d.balance * (d.apr / 100) / 12),
      ),
      monthlyMortgageInterest: projectedMortgages.isEmpty
          ? null
          : projectedMortgages.fold<double>(
              0,
              (sum, m) => sum + (m.balance <= 0 ? 0 : m.balance * m.annualRate / 100 / 12),
            ),
      monthlyForecast: _buildMonthlyForecast(boosted.monthlyBreakdown),
    );
  }

  List<MonthForecast> _buildMonthlyForecast(
    List<ProjectionMonth> breakdown,
  ) {
    final projectedMortgages = _projectMortgagesToReference(
      _repository.getMortgages(),
      _referenceDate ?? DateTime.now(),
    );
    final mortgageBreakdowns = projectedMortgages
        .map(
          (m) => MortgageProjectionEngine()
              .simulate(m, startDate: _referenceDate ?? DateTime.now())
              .monthlyBreakdown,
        )
        .toList(growable: false);

    final forecasts = <MonthForecast>[];
    for (int i = 0; i < 3 && i < breakdown.length; i++) {
      final month = breakdown[i];
      final label = DateFormat('MMM yyyy').format(month.month);
      final mortgageInterest = mortgageBreakdowns.isEmpty
          ? null
          : mortgageBreakdowns.fold<double>(
              0,
              (sum, b) => sum + (i < b.length ? b[i].interestPaid : 0),
            );
      forecasts.add(MonthForecast(
        label: label,
        cashLeft: month.remainingCash,
        debtInterest: month.totalInterest,
        debtBalance: month.totalDebtRemaining,
        mortgageInterest: mortgageInterest,
      ));
    }
    return forecasts;
  }

  String? _buildMortgagePayoffLabel(List<Mortgage> mortgages) {
    if (mortgages.isEmpty) return null;
    DateTime? latestPayoff;
    for (final mortgage in mortgages) {
      final result = MortgageProjectionEngine().simulate(
        mortgage,
        startDate: _referenceDate ?? DateTime.now(),
      );
      if (latestPayoff == null || result.payoffDate.isAfter(latestPayoff)) {
        latestPayoff = result.payoffDate;
      }
    }
    return _formatMonthYear(latestPayoff);
  }

  double? _buildMortgageTotalInterest(List<Mortgage> mortgages) {
    if (mortgages.isEmpty) return null;
    return mortgages.fold<double>(
      0,
      (sum, mortgage) =>
          sum +
          MortgageProjectionEngine()
              .simulate(mortgage, startDate: _referenceDate ?? DateTime.now())
              .totalInterestPaid,
    );
  }

  List<Mortgage> _projectMortgagesToReference(
    List<Mortgage> mortgages,
    DateTime referenceDate,
  ) {
    return mortgages
        .map((mortgage) => _projectMortgageToReference(mortgage, referenceDate))
        .toList(growable: false);
  }

  Mortgage _projectMortgageToReference(
    Mortgage mortgage,
    DateTime referenceDate,
  ) {
    final now = DateTime.now();
    final monthOffset =
        (referenceDate.year - now.year) * 12 + (referenceDate.month - now.month);
    if (monthOffset <= 0) return mortgage;

    final result = MortgageProjectionEngine().simulate(
      mortgage,
      startDate: DateTime(now.year, now.month),
    );
    if (result.monthlyBreakdown.isEmpty) return mortgage;

    final index = monthOffset - 1;
    final capped = index < result.monthlyBreakdown.length
        ? result.monthlyBreakdown[index]
        : result.monthlyBreakdown.last;
    final adjustedTerm =
      (mortgage.remainingTermMonths - monthOffset).clamp(0, 1200).toInt();

    return mortgage.copyWith(
      balance: capped.balanceRemaining,
      remainingTermMonths: adjustedTerm,
    );
  }

  Mortgage? _aggregateMortgage(List<Mortgage> mortgages) {
    if (mortgages.isEmpty) return null;
    final totalBalance = mortgages.fold<double>(0, (sum, m) => sum + m.balance);
    final totalMonthly = mortgages.fold<double>(0, (sum, m) => sum + m.totalMonthlyPayment);
    final weightedRate = totalBalance <= 0
      ? 0.0
        : mortgages.fold<double>(0, (sum, m) => sum + (m.annualRate * m.balance)) /
        totalBalance.toDouble();
    final longestTerm = mortgages.fold<int>(0, (maxTerm, m) => math.max(maxTerm, m.remainingTermMonths));

    return Mortgage(
      id: 'mortgage-aggregate',
      name: mortgages.length == 1 ? mortgages.first.name : '${mortgages.length} mortgages',
      balance: totalBalance,
      annualRate: weightedRate,
      monthlyPayment: totalMonthly,
      remainingTermMonths: longestTerm,
      overpayment: 0,
    );
  }

  List<TimelineDataPoint> _buildChartData(
    List<ProjectionMonth> monthlyBreakdown,
  ) {
    final monthFormat = DateFormat('MMM yy');
    return monthlyBreakdown.map((ProjectionMonth month) {
      return TimelineDataPoint(
        label: monthFormat.format(month.month),
        value: month.totalDebtRemaining,
      );
    }).toList(growable: false);
  }

  String _formatMonthYear(DateTime? date) {
    if (date == null) {
      return 'In progress';
    }

    return DateFormat.yMMM().format(date);
  }

  _Recommendation _buildRecommendation({
    required double incomeIncrease,
    required double expenseReduction,
    required double remainingCash,
    required double availableCashAfterScenario,
    required double extraPayment,
    required int startMonth,
    required int? durationInMonths,
    required int monthsSaved,
    required double interestSaved,
  }) {
    final safeAvailableCash = math.max(0, availableCashAfterScenario);
    final monthlyFlexibilityGain = incomeIncrease + expenseReduction;

    if (incomeIncrease <= 0 && expenseReduction <= 0 && extraPayment <= 0) {
      return const _Recommendation(
        title: 'Plan your next move',
        message:
            'Use the Planner tab to explore what-if events like pay rises, one-off expenses, or extra debt payments — AI will project the impact.',
      );
    }

    if (monthlyFlexibilityGain > 0 && extraPayment <= 0) {
      if (startMonth > 0) {
        return _Recommendation(
          title: 'This scenario starts later',
          message:
              'These budget changes begin in $startMonth month${startMonth == 1 ? '' : 's'}, so your current month still follows the baseline plan.',
        );
      }

      return _Recommendation(
        title: 'You have created more monthly room',
        message:
            'Your scenario adds \u00A3${monthlyFlexibilityGain.toStringAsFixed(2)} of monthly flexibility, but none of it is flowing to debt yet.',
      );
    }

    if (startMonth > 0) {
      final durationMessage = durationInMonths == null
          ? 'Once active, it remains in place until the debts are paid off.'
          : 'Once active, it lasts for $durationInMonths month${durationInMonths == 1 ? '' : 's'}.';
      return _Recommendation(
        title: 'This scenario starts later',
        message:
            'These changes begin in $startMonth month${startMonth == 1 ? '' : 's'}. Until then, your baseline cash left after essentials stays around \u00A3${math.max(0, remainingCash).toStringAsFixed(2)}. $durationMessage',
      );
    }

    if (availableCashAfterScenario <= 0) {
      return _Recommendation(
        title: 'Your budget is already under pressure',
        message:
            'You are currently short on monthly cash, so an extra payment of \u00A3${extraPayment.toStringAsFixed(0)} may be hard to sustain.',
      );
    }

    if (extraPayment > safeAvailableCash) {
      return _Recommendation(
        title: 'Your scenario is larger than your free cash',
        message:
            'After your active scenario changes, you have about \u00A3${safeAvailableCash.toStringAsFixed(0)} available for extra debt payments, so \u00A3${extraPayment.toStringAsFixed(0)} extra may still be too aggressive.',
      );
    }

    if (monthsSaved > 0) {
      if (durationInMonths != null && durationInMonths > 0) {
        return _Recommendation(
          title: 'This is a temporary push',
          message:
              'Your active scenario runs for $durationInMonths month${durationInMonths == 1 ? '' : 's'} and is projected to save $monthsSaved months and \u00A3${interestSaved.toStringAsFixed(2)}.',
        );
      }

      return _Recommendation(
        title: 'This plan fits your current budget',
        message:
            'Your active scenario is projected to save $monthsSaved months and \u00A3${interestSaved.toStringAsFixed(2)} while staying within your current budget.',
      );
    }

    return _Recommendation(
      title: 'Your payment fits, but the impact is limited',
      message:
          'The current extra payment is affordable, but it is not moving the payoff date much yet. Try increasing it gradually.',
    );
  }

  _Recommendation _buildPlanSummary({
    required double incomeIncrease,
    required double expenseReduction,
    required double extraPayment,
  }) {
    if (incomeIncrease <= 0 && expenseReduction <= 0 && extraPayment <= 0) {
      return const _Recommendation(
        title: 'No active scenario',
        message: 'You are currently viewing your baseline monthly plan.',
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
      parts.add('pays \u00A3${extraPayment.toStringAsFixed(2)} extra toward debt');
    }

    return _Recommendation(
      title: 'Active monthly scenario',
      message: 'This plan ${parts.join(', ')}.',
    );
  }

  String _buildScheduleSummary({
    required bool hasActiveScenario,
    required int startMonth,
    required int? durationInMonths,
  }) {
    if (!hasActiveScenario) {
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

class _Recommendation {
  const _Recommendation({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}
