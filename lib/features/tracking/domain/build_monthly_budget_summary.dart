import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual_entry.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';
import 'package:debt_free_app/features/tracking/models/monthly_budget_summary.dart';

class BuildMonthlyBudgetSummary {
  const BuildMonthlyBudgetSummary(this._repository);

  final FinancialRepository _repository;

  /// Build or retrieve the summary for a given month.
  /// If the period doesn't exist yet, it is created and seeded from the
  /// budget configured for that specific month (or the closest prior month
  /// if no budget for that month exists yet).
  Future<MonthlyBudgetSummary> call({
    required int year,
    required int month,
  }) async {
    final periodId = BudgetPeriod.buildId(year, month);

    var period = await _repository.getBudgetPeriod(periodId);
    var actuals = await _repository.getBudgetActuals(periodId);

    if (period == null) {
      period = BudgetPeriod(
        id: periodId,
        year: year,
        month: month,
      );
      actuals = _seedActualsFromBudget(
        periodId,
        year,
        month,
      );
      await _repository.saveBudgetPeriod(period);
      await _repository.saveBudgetActuals(actuals);
    } else {
      // Remove any non-debt rows that were auto-seeded in a previous version
      // (old seeded rows have budgeted > 0; trackable-expense rows are fine to
      // keep because we re-sync them below).
      final legacySeeded = actuals
          .where((a) =>
              a.categoryType != ActualCategoryType.debtPayment &&
              a.categoryType != ActualCategoryType.expense &&
              a.budgeted > 0)
          .toList();
      if (legacySeeded.isNotEmpty) {
        await _repository.deleteSeededBudgetActuals(periodId);
        actuals = actuals
            .where((a) =>
                a.categoryType == ActualCategoryType.debtPayment ||
                a.categoryType == ActualCategoryType.expense)
            .toList();
      }
      // Fully reconcile trackable expense rows with current budget month.
      final trackableSync = _syncTrackableExpenses(periodId, actuals);
      if (trackableSync.staleActualIds.isNotEmpty) {
        for (final staleId in trackableSync.staleActualIds) {
          await _repository.deleteBudgetActual(staleId);
        }
        actuals = actuals
            .where((a) => !trackableSync.staleActualIds.contains(a.id))
            .toList(growable: false);
      }
      if (trackableSync.updatedActuals.isNotEmpty) {
        await _repository.saveBudgetActuals(trackableSync.updatedActuals);
        final updatedById = {
          for (final a in trackableSync.updatedActuals) a.id: a,
        };
        actuals = actuals
            .map((a) => updatedById[a.id] ?? a)
            .toList(growable: false);
      }
      if (trackableSync.newActuals.isNotEmpty) {
        await _repository.saveBudgetActuals(trackableSync.newActuals);
        actuals = [...actuals, ...trackableSync.newActuals];
      }

    }

    // Load entries for trackable expense actuals
    final allEntries =
        await _repository.getBudgetActualEntries(periodId);
    final Map<String, List<BudgetActualEntry>> entriesByActualId = {};
    for (final entry in allEntries) {
      entriesByActualId.putIfAbsent(entry.actualId, () => []).add(entry);
    }

    return _buildSummary(period, actuals, entriesByActualId);
  }

  /// Add trackable-expense rows for any trackable budget expenses that don't
  /// have an actual yet (or update budgeted amount if it changed).
  _TrackableSyncResult _syncTrackableExpenses(
    String periodId,
    List<BudgetActual> existing,
  ) {
    final budgetMonthKey = _repository.activeBudgetMonth;
    final trackableExpenses = _repository
        .getExpensesForMonth(budgetMonthKey)
        .where((expense) => expense.trackable)
        .toList(growable: false);
    final trackableById = {
      for (final expense in trackableExpenses) expense.id: expense,
    };

    final existingTrackable = existing
        .where((a) =>
            a.categoryType == ActualCategoryType.expense && a.budgeted > 0)
        .toList(growable: false);

    final existingIds = existingTrackable.map((a) => a.categoryId).toSet();
    final staleActualIds = existingTrackable
        .where((a) => !trackableById.containsKey(a.categoryId))
        .map((a) => a.id)
        .toList(growable: false);

    final updatedActuals = <BudgetActual>[];
    for (final actual in existingTrackable) {
      final source = trackableById[actual.categoryId];
      if (source == null) continue;
      if (actual.categoryName != source.name || actual.budgeted != source.amount) {
        updatedActuals.add(BudgetActual(
          id: actual.id,
          periodId: actual.periodId,
          categoryId: actual.categoryId,
          categoryName: source.name,
          categoryType: actual.categoryType,
          budgeted: source.amount,
          actual: actual.actual,
          debtBalance: actual.debtBalance,
        ));
      }
    }

    final newActuals = <BudgetActual>[];
    for (final expense in trackableExpenses) {
      if (!existingIds.contains(expense.id)) {
        newActuals.add(BudgetActual(
          id: BudgetActual.buildId(periodId, expense.id),
          periodId: periodId,
          categoryId: expense.id,
          categoryName: expense.name,
          categoryType: ActualCategoryType.expense,
          budgeted: expense.amount,
        ));
      }
    }

    return _TrackableSyncResult(
      newActuals: newActuals,
      updatedActuals: updatedActuals,
      staleActualIds: staleActualIds,
    );
  }

  /// Resolve which budget month to use for seeding. Tries the exact month
  /// first, then walks back up to 12 months to find the most recent one.
  String _resolveBudgetMonthKey(int year, int month) {
    final target =
        '${year}-${month.toString().padLeft(2, '0')}';
    final available = _repository.availableBudgetMonths;
    if (available.isEmpty) return target;
    if (available.contains(target)) return target;
    // Walk back from target to find the most recent prior month with data
    for (int i = 1; i <= 12; i++) {
      var m = month - i;
      var y = year;
      while (m < 1) {
        m += 12;
        y -= 1;
      }
      final key = '${y}-${m.toString().padLeft(2, '0')}';
      if (available.contains(key)) return key;
    }
    return available.last;
  }

  /// Seed actuals from the budget configured for this month.
  List<BudgetActual> _seedActualsFromBudget(
    String periodId,
    int year,
    int month,
  ) {
    final result = <BudgetActual>[];
    final budgetMonthKey = _resolveBudgetMonthKey(year, month);

    // Trackable expense rows
    for (final expense in _repository.getExpensesForMonth(budgetMonthKey)) {
      if (!expense.trackable) continue;
      result.add(BudgetActual(
        id: BudgetActual.buildId(periodId, expense.id),
        periodId: periodId,
        categoryId: expense.id,
        categoryName: expense.name,
        categoryType: ActualCategoryType.expense,
        budgeted: expense.amount,
      ));
    }

    return result;
  }

  MonthlyBudgetSummary _buildSummary(
    BudgetPeriod period,
    List<BudgetActual> actuals,
    Map<String, List<BudgetActualEntry>> entriesByActualId,
  ) {
    double totalBudgetedIncome = 0;
    double totalActualIncome = 0;
    double totalBudgetedBills = 0;
    double totalActualBills = 0;
    double totalBudgetedExpenses = 0;
    double totalActualExpenses = 0;
    double totalBudgetedDebtPayments = 0;
    double totalActualDebtPayments = 0;

    for (final actual in actuals) {
      switch (actual.categoryType) {
        case ActualCategoryType.income:
          totalBudgetedIncome += actual.budgeted;
          totalActualIncome += actual.actual;
          break;
        case ActualCategoryType.bill:
          totalBudgetedBills += actual.budgeted;
          totalActualBills += actual.actual;
          break;
        case ActualCategoryType.expense:
          totalBudgetedExpenses += actual.budgeted;
          totalActualExpenses += actual.actual;
          break;
        case ActualCategoryType.debtPayment:
          totalBudgetedDebtPayments += actual.budgeted;
          totalActualDebtPayments += actual.actual;
          break;
      }
    }

    // Net variance: positive means under-budget (good), negative means over
    final incomeVariance = totalActualIncome - totalBudgetedIncome;
    final billVariance = totalBudgetedBills - totalActualBills;
    // Expenses: spending within budget keeps the budgeted amount reserved (no
    // benefit from underspend). Only overspend reduces the remaining balance.
    final expenseVariance =
        (totalBudgetedExpenses - totalActualExpenses).clamp(double.negativeInfinity, 0.0);
    final netVariance = incomeVariance + billVariance + expenseVariance;

    return MonthlyBudgetSummary(
      period: period,
      actuals: actuals,
      totalBudgetedIncome: totalBudgetedIncome,
      totalActualIncome: totalActualIncome,
      totalBudgetedBills: totalBudgetedBills,
      totalActualBills: totalActualBills,
      totalBudgetedExpenses: totalBudgetedExpenses,
      totalActualExpenses: totalActualExpenses,
      totalBudgetedDebtPayments: totalBudgetedDebtPayments,
      totalActualDebtPayments: totalActualDebtPayments,
      netVariance: netVariance,
      entriesByActualId: entriesByActualId,
    );
  }
}

class _TrackableSyncResult {
  const _TrackableSyncResult({
    required this.newActuals,
    required this.updatedActuals,
    required this.staleActualIds,
  });

  final List<BudgetActual> newActuals;
  final List<BudgetActual> updatedActuals;
  final List<String> staleActualIds;
}
