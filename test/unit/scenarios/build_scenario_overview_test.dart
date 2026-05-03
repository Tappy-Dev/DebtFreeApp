import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/features/scenarios/domain/build_scenario_overview.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/simulation/models/salary_sacrifice.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual_entry.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScenarioRepository implements FinancialRepository {
  _ScenarioRepository({
    this.changes = const <ScenarioChange>[
      ScenarioChange(changeType: ChangeType.extraPayment, amount: 200),
    ],
  });

  final List<ScenarioChange> changes;

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
  List<IncomeSource> getIncomeSources() {
    return const <IncomeSource>[
      IncomeSource(id: 'salary', name: 'Salary', annualGross: 4800, overrideMonthlyNet: 400),
    ];
  }

  @override
  List<Expense> getExpenses() {
    return const <Expense>[
      Expense(id: 'bills', name: 'Bills', amount: 250),
    ];
  }

  @override
  List<ScenarioChange> getScenarioChanges() {
    return changes;
  }

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
  List<Expense> getSubscriptions() => const [];  @override
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
  @override
  List<Mortgage> getMortgages() {
    final m = getMortgage();
    return m == null ? const <Mortgage>[] : <Mortgage>[m];
  }
  @override
  void deleteMortgageById(String mortgageId) {
    final m = getMortgage();
    if (m != null && m.id == mortgageId) deleteMortgage();
  }
  @override
  String? get appStartMonth => null;
  @override
  Future<void> setAppStartMonth(String monthKey) async {}
  @override
  Future<void> deleteBudgetActual(String actualId) async {}
  @override
  Future<void> deleteSeededBudgetActuals(String periodId) async {}
  @override
  Future<List<BudgetActualEntry>> getBudgetActualEntries(String periodId) async => const [];
  @override
  Future<void> saveBudgetActualEntry(BudgetActualEntry entry) async {}
  @override
  Future<void> deleteBudgetActualEntry(String entryId) async {}
}

void main() {
  test('BuildScenarioOverview flags when scenario exceeds free cash', () {
    final overview = BuildScenarioOverview(
      repository: _ScenarioRepository(),
    )();

    expect(overview.extraPayment, 200);
    expect(overview.incomeIncrease, 0);
    expect(overview.expenseReduction, 0);
    expect(overview.remainingCash, 50);
    expect(overview.availableCashAfterAdjustments, 50);
    expect(overview.isAffordable, isFalse);
    expect(overview.hasActiveChanges, isTrue);
    expect(
      overview.activeChangeLabels,
      contains('Extra debt payment: \u00A3200.00'),
    );
    expect(overview.guidanceTitle, isNotEmpty);
    expect(overview.planSummaryTitle, isNotEmpty);
    expect(overview.planSummaryMessage, isNotEmpty);
    expect(overview.guidanceMessage, isNotEmpty);
  });

  test('BuildScenarioOverview summarizes mixed scenario changes', () {
    final overview = BuildScenarioOverview(
      repository: _ScenarioRepository(
        changes: const <ScenarioChange>[
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
        ],
      ),
    )();

    expect(overview.incomeIncrease, 75);
    expect(overview.expenseReduction, 25);
    expect(overview.extraPayment, 50);
    expect(overview.hasActiveChanges, isTrue);
    expect(overview.availableCashAfterAdjustments, 150);
    expect(overview.cashBufferAfterPlan, 100);
    expect(
      overview.activeChangeLabels,
      contains('Extra monthly income: \u00A375.00'),
    );
    expect(
      overview.activeChangeLabels,
      contains('Monthly expense reduction: \u00A325.00'),
    );
    expect(
      overview.activeChangeLabels,
      contains('Extra debt payment: \u00A350.00'),
    );
    expect(overview.startMonth, 2);
    expect(overview.durationInMonths, 6);
    expect(
      overview.scheduleSummary,
      'starts in 2 months and lasts for 6 months.',
    );
    expect(overview.guidanceTitle, 'This scenario starts later');
    expect(
      overview.guidanceMessage,
      contains('These changes begin in 2 months.'),
    );
    expect(overview.planSummaryTitle, 'Active plan changes');
    expect(
      overview.planSummaryMessage,
      contains('adds \u00A375.00 income'),
    );
    expect(
      overview.planSummaryMessage,
      contains('cuts \u00A325.00 of expenses'),
    );
    expect(
      overview.planSummaryMessage,
      contains('sends \u00A350.00 extra to debt'),
    );
  });

  test('BuildScenarioOverview uses income and expense changes in affordability', () {
    final overview = BuildScenarioOverview(
      repository: _ScenarioRepository(
        changes: const <ScenarioChange>[
          ScenarioChange(
            changeType: ChangeType.increaseIncome,
            amount: 75,
          ),
          ScenarioChange(
            changeType: ChangeType.extraPayment,
            amount: 100,
          ),
        ],
      ),
    )();

    expect(overview.remainingCash, 50);
    expect(overview.availableCashAfterAdjustments, 125);
    expect(overview.isAffordable, isTrue);
  });

  test('BuildScenarioOverview shows no active labels for baseline plan', () {
    final overview = BuildScenarioOverview(
      repository: _ScenarioRepository(
        changes: const <ScenarioChange>[],
      ),
    )();

    expect(overview.hasActiveChanges, isFalse);
    expect(overview.activeChangeLabels, isEmpty);
    expect(overview.scheduleSummary, 'No scheduled scenario is active.');
    expect(overview.planSummaryTitle, 'Baseline plan');
  });

  test('BuildScenarioOverview highlights temporary active scenarios', () {
    final overview = BuildScenarioOverview(
      repository: _ScenarioRepository(
        changes: const <ScenarioChange>[
          ScenarioChange(
            changeType: ChangeType.extraPayment,
            amount: 50,
            durationInMonths: 3,
          ),
        ],
      ),
    )();

    expect(overview.guidanceTitle, 'This is a temporary scenario');
    expect(overview.guidanceMessage, contains('runs for 3 months'));
  });

  test('BuildScenarioOverview warns when saved schedules are inconsistent', () {
    final overview = BuildScenarioOverview(
      repository: _ScenarioRepository(
        changes: const <ScenarioChange>[
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
        ],
      ),
    )();

    expect(overview.scheduleWarningMessage, isNotNull);
    expect(
      overview.scheduleWarningMessage,
      contains('different schedules'),
    );
  });
}
