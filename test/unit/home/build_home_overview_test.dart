import 'package:debt_free_app/core/data/demo_financial_repository.dart';
import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/features/home/domain/build_home_overview.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/simulation/models/salary_sacrifice.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';
import 'package:flutter_test/flutter_test.dart';

class _HomeScenarioRepository implements FinancialRepository {
  @override
  List<DebtAccount> getDebts() {
    return <DebtAccount>[
      DebtAccount(
        id: 'card',
        name: 'Card',
        balance: 1000,
        apr: 12,
        minimumPayment: 100,
      ),
    ];
  }

  @override
  List<Expense> getExpenses() {
    return const <Expense>[
      Expense(id: 'bills', name: 'Bills', amount: 250),
    ];
  }

  @override
  List<IncomeSource> getIncomeSources() {
    return const <IncomeSource>[
      IncomeSource(id: 'salary', name: 'Salary', annualGross: 6000, overrideMonthlyNet: 500),
    ];
  }

  @override
  List<ScenarioChange> getScenarioChanges() {
    return const <ScenarioChange>[
      ScenarioChange(
        changeType: ChangeType.increaseIncome,
        amount: 75,
        startMonth: 2,
        durationInMonths: 6,
      ),
      ScenarioChange(
        changeType: ChangeType.reduceExpenses,
        amount: 25,
        startMonth: 2,
        durationInMonths: 6,
      ),
      ScenarioChange(
        changeType: ChangeType.extraPayment,
        amount: 50,
        startMonth: 2,
        durationInMonths: 6,
      ),
    ];
  }

  @override
  void deleteDebt(String debtId) {}

  @override
  void deleteExpense(String expenseId) {}

  @override
  void deleteIncomeSource(String incomeSourceId) {}

  @override
  void saveDebt(DebtAccount debtAccount) {}

  @override
  void saveExpense(Expense expense) {}

  @override
  void saveIncomeSource(IncomeSource incomeSource) {}

  @override
  void saveScenarioChanges(List<ScenarioChange> scenarioChanges) {}

  @override
  Mortgage? getMortgage() => null;

  @override
  List<SalarySacrifice> getSalarySacrifices() => const <SalarySacrifice>[];

  @override
  void saveMortgage(Mortgage mortgage) {}

  @override
  void deleteMortgage() {}

  @override
  void saveSalarySacrifice(SalarySacrifice sacrifice) {}

  @override
  void deleteSalarySacrifice(String id) {}
  @override
  List<Expense> getBills() => const [];
  @override
  List<Expense> getSubscriptions() => const [];
  @override
  String get activeBudgetMonth => '';
  @override
  List<String> get availableBudgetMonths => const [];
  @override
  List<IncomeSource> getIncomeSourcesForMonth(String monthKey) => getIncomeSources();
  @override
  List<Expense> getExpensesForMonth(String monthKey) => getExpenses();
  @override
  List<Expense> getBillsForMonth(String monthKey) => const [];
  @override
  void saveBill(Expense bill) {}
  @override
  void deleteBill(String billId) {}
  @override
  Future<List<BudgetPeriod>> getBudgetPeriods() async => const [];
  @override
  Future<BudgetPeriod?> getBudgetPeriod(String periodId) async => null;
  @override
  Future<void> saveBudgetPeriod(BudgetPeriod period) async {}
  @override
  Future<List<BudgetActual>> getBudgetActuals(String periodId) async => const [];
  @override
  Future<void> saveBudgetActual(BudgetActual actual) async {}
  @override
  Future<void> saveBudgetActuals(List<BudgetActual> actuals) async {}
}

void main() {
  test('BuildHomeOverview returns a usable dashboard snapshot', () {
    final overview = BuildHomeOverview(
      repository: const DemoFinancialRepository(),
    )();

    expect(overview.totalDebt, greaterThan(0));
    expect(overview.interestProjection, greaterThanOrEqualTo(0));
    expect(overview.interestSaved, greaterThanOrEqualTo(0));
    expect(overview.debtFreeDateLabel, isNotEmpty);
    expect(overview.recommendationTitle, isNotEmpty);
    expect(overview.recommendationMessage, isNotEmpty);
  });

  test('BuildHomeOverview summarizes full monthly scenario impact', () {
    final overview = BuildHomeOverview(
      repository: _HomeScenarioRepository(),
    )();

    expect(overview.incomeIncrease, 75);
    expect(overview.expenseReduction, 25);
    expect(overview.extraPayment, 50);
    expect(overview.monthlyFlexibilityGain, 100);
    expect(overview.availableCashAfterScenario, 250);
    expect(overview.planSummaryTitle, 'Active monthly scenario');
    expect(overview.planSummaryMessage, contains('adds \u00A375.00 income'));
    expect(overview.recommendationTitle, 'This scenario starts later');
    expect(
      overview.scheduleSummary,
      'starts in 2 months and lasts for 6 months.',
    );
    expect(
      overview.recommendationMessage,
      contains('These changes begin in 2 months.'),
    );
    expect(
      overview.planSummaryMessage,
      contains('cuts \u00A325.00 of expenses'),
    );
    expect(
      overview.planSummaryMessage,
      contains('pays \u00A350.00 extra toward debt'),
    );
  });

  test('BuildHomeOverview warns when saved schedules are inconsistent', () {
    final overview = BuildHomeOverview(
      repository: _InconsistentHomeScenarioRepository(),
    )();

    expect(overview.scheduleWarningMessage, isNotNull);
    expect(
      overview.scheduleWarningMessage,
      contains('different schedules'),
    );
  });
}

class _InconsistentHomeScenarioRepository implements FinancialRepository {
  @override
  List<DebtAccount> getDebts() {
    return <DebtAccount>[
      DebtAccount(
        id: 'card',
        name: 'Card',
        balance: 1000,
        apr: 12,
        minimumPayment: 100,
      ),
    ];
  }

  @override
  List<Expense> getExpenses() {
    return const <Expense>[
      Expense(id: 'bills', name: 'Bills', amount: 250),
    ];
  }

  @override
  List<IncomeSource> getIncomeSources() {
    return const <IncomeSource>[
      IncomeSource(id: 'salary', name: 'Salary', annualGross: 6000, overrideMonthlyNet: 500),
    ];
  }

  @override
  List<ScenarioChange> getScenarioChanges() {
    return const <ScenarioChange>[
      ScenarioChange(
        changeType: ChangeType.increaseIncome,
        amount: 75,
        startMonth: 1,
        durationInMonths: 2,
      ),
      ScenarioChange(
        changeType: ChangeType.extraPayment,
        amount: 150,
        startMonth: 3,
        durationInMonths: 6,
      ),
    ];
  }

  @override
  void deleteDebt(String debtId) {}

  @override
  void deleteExpense(String expenseId) {}

  @override
  void deleteIncomeSource(String incomeSourceId) {}

  @override
  void saveDebt(DebtAccount debtAccount) {}

  @override
  void saveExpense(Expense expense) {}

  @override
  void saveIncomeSource(IncomeSource incomeSource) {}

  @override
  void saveScenarioChanges(List<ScenarioChange> scenarioChanges) {}

  @override
  Mortgage? getMortgage() => null;

  @override
  List<SalarySacrifice> getSalarySacrifices() => const <SalarySacrifice>[];

  @override
  void saveMortgage(Mortgage mortgage) {}

  @override
  void deleteMortgage() {}

  @override
  void saveSalarySacrifice(SalarySacrifice sacrifice) {}

  @override
  void deleteSalarySacrifice(String id) {}
  @override
  List<Expense> getBills() => const [];
  @override
  List<Expense> getSubscriptions() => const [];
  @override
  String get activeBudgetMonth => '';
  @override
  List<String> get availableBudgetMonths => const [];
  @override
  List<IncomeSource> getIncomeSourcesForMonth(String monthKey) => getIncomeSources();
  @override
  List<Expense> getExpensesForMonth(String monthKey) => getExpenses();
  @override
  List<Expense> getBillsForMonth(String monthKey) => const [];
  @override
  void saveBill(Expense bill) {}
  @override
  void deleteBill(String billId) {}
  @override
  Future<List<BudgetPeriod>> getBudgetPeriods() async => const [];
  @override
  Future<BudgetPeriod?> getBudgetPeriod(String periodId) async => null;
  @override
  Future<void> saveBudgetPeriod(BudgetPeriod period) async {}
  @override
  Future<List<BudgetActual>> getBudgetActuals(String periodId) async => const [];
  @override
  Future<void> saveBudgetActual(BudgetActual actual) async {}
  @override
  Future<void> saveBudgetActuals(List<BudgetActual> actuals) async {}
}
