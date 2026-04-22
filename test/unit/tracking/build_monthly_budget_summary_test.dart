import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/simulation/models/salary_sacrifice.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/features/tracking/domain/build_monthly_budget_summary.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackingRepository implements FinancialRepository {
  final List<DebtAccount> debts;
  final List<IncomeSource> income;
  final List<Expense> expenses;
  final List<Expense> bills;

  final Map<String, BudgetPeriod> _periods = {};
  final Map<String, List<BudgetActual>> _actuals = {};

  _TrackingRepository({
    this.debts = const [],
    this.income = const [],
    this.expenses = const [],
    this.bills = const [],
  });

  @override
  List<DebtAccount> getDebts() => debts;
  @override
  List<IncomeSource> getIncomeSources() => income;
  @override
  List<Expense> getExpenses() => expenses;
  @override
  List<Expense> getBills() => bills;
  @override
  List<ScenarioChange> getScenarioChanges() => const [];
  @override
  Mortgage? getMortgage() => null;
  @override
  List<SalarySacrifice> getSalarySacrifices() => const [];

  // Month-specific methods — return same lists (no versioning in mock)
  @override
  String get activeBudgetMonth => '2026-04';
  @override
  List<String> get availableBudgetMonths => income.isNotEmpty || expenses.isNotEmpty || bills.isNotEmpty ? ['2026-04'] : [];
  @override
  List<IncomeSource> getIncomeSourcesForMonth(String monthKey) => income;
  @override
  List<Expense> getExpensesForMonth(String monthKey) => expenses;
  @override
  List<Expense> getBillsForMonth(String monthKey) => bills;

  @override
  void saveDebt(DebtAccount debtAccount) {}
  @override
  void deleteDebt(String debtId) {}
  @override
  void saveIncomeSource(IncomeSource incomeSource) {}
  @override
  void deleteIncomeSource(String incomeSourceId) {}
  @override
  void saveExpense(Expense expense) {}
  @override
  void deleteExpense(String expenseId) {}
  @override
  void saveScenarioChanges(List<ScenarioChange> scenarioChanges) {}
  @override
  void saveMortgage(Mortgage mortgage) {}
  @override
  void deleteMortgage() {}
  @override
  void saveSalarySacrifice(SalarySacrifice sacrifice) {}
  @override
  void deleteSalarySacrifice(String id) {}
  @override
  void saveBill(Expense bill) {}
  @override
  void deleteBill(String billId) {}

  @override
  Future<List<BudgetPeriod>> getBudgetPeriods() async =>
      _periods.values.toList();

  @override
  Future<BudgetPeriod?> getBudgetPeriod(String periodId) async =>
      _periods[periodId];

  @override
  Future<void> saveBudgetPeriod(BudgetPeriod period) async {
    _periods[period.id] = period;
  }

  @override
  Future<List<BudgetActual>> getBudgetActuals(String periodId) async =>
      _actuals[periodId] ?? const [];

  @override
  Future<void> saveBudgetActual(BudgetActual actual) async {
    final list = _actuals.putIfAbsent(actual.periodId, () => []);
    final index = list.indexWhere((a) => a.id == actual.id);
    if (index == -1) {
      list.add(actual);
    } else {
      list[index] = actual;
    }
  }

  @override
  Future<void> saveBudgetActuals(List<BudgetActual> actuals) async {
    for (final a in actuals) {
      await saveBudgetActual(a);
    }
  }
}

void main() {
  test('BuildMonthlyBudgetSummary seeds period from current budget', () async {
    final repo = _TrackingRepository(
      income: const [
        IncomeSource(id: 'salary', name: 'Salary', annualGross: 34800, overrideMonthlyNet: 2900),
      ],
      expenses: const [
        Expense(id: 'rent', name: 'Rent', amount: 400),
        Expense(id: 'food', name: 'Food', amount: 300),
      ],
      debts: [
        DebtAccount(
          id: 'visa',
          name: 'Visa',
          balance: 1000,
          apr: 20,
          minimumPayment: 50,
          minPaymentRule: const MinPaymentRule(type: MinPaymentType.fixed),
        ),
      ],
    );

    final builder = BuildMonthlyBudgetSummary(repo);
    final summary = await builder(year: 2026, month: 4);

    expect(summary.period.year, 2026);
    expect(summary.period.month, 4);
    expect(summary.period.isOpen, true);
    expect(summary.actuals.length, 4); // 1 income + 2 expenses + 1 debt

    expect(summary.totalBudgetedIncome, 2900);
    expect(summary.totalActualIncome, 0);
    expect(summary.totalBudgetedExpenses, 700);
    expect(summary.totalActualExpenses, 0);
    expect(summary.totalBudgetedDebtPayments, 50);
    expect(summary.totalActualDebtPayments, 0);

    // Net variance should be positive (under budget since nothing spent yet)
    expect(summary.netVariance, -2900 + 700 + 50); // income shortfall
  });

  test('BuildMonthlyBudgetSummary returns existing period on second call',
      () async {
    final repo = _TrackingRepository(
      income: const [
        IncomeSource(id: 'salary', name: 'Salary', annualGross: 34800, overrideMonthlyNet: 2900),
      ],
      expenses: const [
        Expense(id: 'rent', name: 'Rent', amount: 400),
      ],
    );

    final builder = BuildMonthlyBudgetSummary(repo);

    // First call creates the period
    await builder(year: 2026, month: 5);
    expect((await repo.getBudgetPeriods()).length, 1);

    // Second call returns the same period - no duplicate
    final summary = await builder(year: 2026, month: 5);
    expect((await repo.getBudgetPeriods()).length, 1);
    expect(summary.actuals.length, 2); // 1 income + 1 expense
  });

  test('BuildMonthlyBudgetSummary detects over-budget items', () async {
    final repo = _TrackingRepository(
      income: const [
        IncomeSource(id: 'salary', name: 'Salary', annualGross: 24000, overrideMonthlyNet: 2000),
      ],
      expenses: const [
        Expense(id: 'food', name: 'Food', amount: 300),
      ],
    );

    final builder = BuildMonthlyBudgetSummary(repo);
    await builder(year: 2026, month: 4);

    // Set actuals: income matched, food over budget
    final actuals = await repo.getBudgetActuals('2026-04');
    for (final a in actuals) {
      if (a.categoryType == ActualCategoryType.income) {
        await repo.saveBudgetActual(a.copyWith(actual: 2000));
      } else if (a.categoryId == 'food') {
        await repo.saveBudgetActual(a.copyWith(actual: 450));
      }
    }

    final summary = await builder(year: 2026, month: 4);
    expect(summary.totalActualExpenses, 450);
    expect(summary.overBudgetItems.length, 1);
    expect(summary.overBudgetItems.first.categoryName, 'Food');
    expect(summary.overBudgetItems.first.variance, 150);
    // Net: income OK (+0), expenses over (-150) = -150
    expect(summary.netVariance, -150);
    expect(summary.isOverBudget, true);
  });

  test('BuildMonthlyBudgetSummary handles on-track month', () async {
    final repo = _TrackingRepository(
      income: const [
        IncomeSource(id: 'salary', name: 'Salary', annualGross: 24000, overrideMonthlyNet: 2000),
      ],
      expenses: const [
        Expense(id: 'food', name: 'Food', amount: 300),
      ],
    );

    final builder = BuildMonthlyBudgetSummary(repo);
    await builder(year: 2026, month: 6);

    final actuals = await repo.getBudgetActuals('2026-06');
    for (final a in actuals) {
      if (a.categoryType == ActualCategoryType.income) {
        await repo.saveBudgetActual(a.copyWith(actual: 2000));
      } else {
        await repo.saveBudgetActual(a.copyWith(actual: 250));
      }
    }

    final summary = await builder(year: 2026, month: 6);
    expect(summary.isOverBudget, false);
    expect(summary.netVariance, 50); // 50 under on expenses
    expect(summary.overBudgetItems, isEmpty);
  });

  test('BudgetPeriod.buildId formats correctly', () {
    expect(BudgetPeriod.buildId(2026, 1), '2026-01');
    expect(BudgetPeriod.buildId(2026, 12), '2026-12');
  });

  test('BudgetActual variance and flags work correctly', () {
    const overExpense = BudgetActual(
      id: 'test:food',
      periodId: 'test',
      categoryId: 'food',
      categoryName: 'Food',
      categoryType: ActualCategoryType.expense,
      budgeted: 300,
      actual: 400,
    );
    expect(overExpense.variance, 100);
    expect(overExpense.isOverBudget, true);
    expect(overExpense.isUnderBudget, false);

    const underExpense = BudgetActual(
      id: 'test:rent',
      periodId: 'test',
      categoryId: 'rent',
      categoryName: 'Rent',
      categoryType: ActualCategoryType.expense,
      budgeted: 400,
      actual: 350,
    );
    expect(underExpense.variance, -50);
    expect(underExpense.isOverBudget, false);
    expect(underExpense.isUnderBudget, true);

    // Income is never "over budget" (earning more is good)
    const incomeActual = BudgetActual(
      id: 'test:salary',
      periodId: 'test',
      categoryId: 'salary',
      categoryName: 'Salary',
      categoryType: ActualCategoryType.income,
      budgeted: 2000,
      actual: 2500,
    );
    expect(incomeActual.isOverBudget, false);
    expect(incomeActual.isUnderBudget, false);
  });
}
