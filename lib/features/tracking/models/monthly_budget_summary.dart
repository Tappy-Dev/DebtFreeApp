import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual_entry.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';

class MonthlyBudgetSummary {
  const MonthlyBudgetSummary({
    required this.period,
    required this.actuals,
    required this.totalBudgetedIncome,
    required this.totalActualIncome,
    required this.totalBudgetedBills,
    required this.totalActualBills,
    required this.totalBudgetedExpenses,
    required this.totalActualExpenses,
    required this.totalBudgetedDebtPayments,
    required this.totalActualDebtPayments,
    required this.netVariance,
    this.entriesByActualId = const {},
  });

  final BudgetPeriod period;
  final List<BudgetActual> actuals;
  final double totalBudgetedIncome;
  final double totalActualIncome;
  final double totalBudgetedBills;
  final double totalActualBills;
  final double totalBudgetedExpenses;
  final double totalActualExpenses;
  final double totalBudgetedDebtPayments;
  final double totalActualDebtPayments;

  /// Positive = surplus (under budget), negative = deficit (over budget).
  final double netVariance;

  /// Entries for trackable expense actuals, keyed by actualId.
  final Map<String, List<BudgetActualEntry>> entriesByActualId;

  List<BudgetActualEntry> entriesFor(String actualId) =>
      entriesByActualId[actualId] ?? const [];

  List<BudgetActual> get incomeActuals => actuals
      .where((a) => a.categoryType == ActualCategoryType.income)
      .toList(growable: false);

  /// Expenses seeded from trackable budget items (budgeted > 0).
  List<BudgetActual> get trackableExpenseActuals => actuals
      .where((a) =>
          a.categoryType == ActualCategoryType.expense && a.budgeted > 0)
      .toList(growable: false);

  /// Ad-hoc extra expenses added manually in Tracking (budgeted == 0).
  List<BudgetActual> get extraExpenseActuals => actuals
      .where((a) =>
          a.categoryType == ActualCategoryType.expense && a.budgeted == 0)
      .toList(growable: false);

  /// All expense actuals (for backwards-compat totals).
  List<BudgetActual> get expenseActuals => actuals
      .where((a) => a.categoryType == ActualCategoryType.expense)
      .toList(growable: false);

  List<BudgetActual> get billActuals => actuals
      .where((a) => a.categoryType == ActualCategoryType.bill)
      .toList(growable: false);

  List<BudgetActual> get debtActuals => actuals
      .where((a) => a.categoryType == ActualCategoryType.debtPayment)
      .toList(growable: false);

  List<BudgetActual> get overBudgetItems =>
      actuals.where((a) => a.isOverBudget).toList(growable: false);

  bool get isOverBudget => netVariance < 0;

  /// True if any actual amount has been recorded (month is in progress).
  bool get hasAnyActuals => actuals.any((a) => a.actual != 0);

  /// Projected surplus/deficit when income is budgeted but nothing recorded yet.
  /// = budgetedIncome - budgetedBills - budgetedExpenses - budgetedDebtPayments
  double get projectedRemaining =>
      totalBudgetedIncome -
      totalBudgetedBills -
      totalBudgetedExpenses;

  /// Show projected view: income is budgeted but no actuals entered yet.
  /// Without this, unearned income registers as a large deficit.
  bool get isProjectedView => !hasAnyActuals && totalBudgetedIncome > 0;
}
