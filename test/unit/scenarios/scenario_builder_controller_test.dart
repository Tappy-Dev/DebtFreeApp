import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/features/scenarios/application/scenario_builder_controller.dart';
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

class _FakeScenarioRepository implements FinancialRepository {
  _FakeScenarioRepository({
    this.income = const <IncomeSource>[],
    this.expenses = const <Expense>[],
    this.debts = const <DebtAccount>[],
  });

  final List<IncomeSource> income;
  final List<Expense> expenses;
  final List<DebtAccount> debts;
  List<ScenarioChange> changes = const <ScenarioChange>[];

  @override
  List<DebtAccount> getDebts() => debts;

  @override
  List<Expense> getExpenses() => expenses;

  @override
  List<IncomeSource> getIncomeSources() => income;

  @override
  List<ScenarioChange> getScenarioChanges() => changes;

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
  void saveScenarioChanges(List<ScenarioChange> scenarioChanges) {
    changes = List<ScenarioChange>.from(scenarioChanges);
  }

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
  test('ScenarioBuilderController saves extra payment scenario', () {
    final repository = _FakeScenarioRepository(
      income: const <IncomeSource>[
        IncomeSource(id: 'salary', name: 'Salary', annualGross: 6000, overrideMonthlyNet: 500),
      ],
      expenses: const <Expense>[
        Expense(id: 'bills', name: 'Bills', amount: 200),
      ],
      debts: <DebtAccount>[
        DebtAccount(
          id: 'card',
          name: 'Card',
          balance: 1000,
          apr: 12,
          minimumPayment: 100,
        ),
      ],
    );
    final controller = ScenarioBuilderController(repository);

    controller.saveExtraPayment('\u00A3150');

    expect(repository.changes, hasLength(1));
    expect(repository.changes.first.changeType, ChangeType.extraPayment);
    expect(repository.changes.first.amount, 150);
  });

  test('ScenarioBuilderController saves a multi-change scenario plan', () {
    final repository = _FakeScenarioRepository(
      income: const <IncomeSource>[
        IncomeSource(id: 'salary', name: 'Salary', annualGross: 6000, overrideMonthlyNet: 500),
      ],
      expenses: const <Expense>[
        Expense(id: 'bills', name: 'Bills', amount: 200),
      ],
      debts: <DebtAccount>[
        DebtAccount(
          id: 'card',
          name: 'Card',
          balance: 1000,
          apr: 12,
          minimumPayment: 100,
        ),
      ],
    );
    final controller = ScenarioBuilderController(repository);

    controller.saveScenarioPlan(
      extraPayment: '150',
      incomeIncrease: '75',
      expenseReduction: '25',
      startMonth: '2',
      durationInMonths: '6',
    );

    expect(repository.changes, hasLength(3));
    expect(
      repository.changes.map((ScenarioChange change) => change.changeType),
      <ChangeType>[
        ChangeType.increaseIncome,
        ChangeType.reduceExpenses,
        ChangeType.extraPayment,
      ],
    );
    expect(repository.changes.first.startMonth, 2);
    expect(repository.changes.first.durationInMonths, 6);
  });

  test('ScenarioBuilderController rejects standalone extra payment above free cash', () {
    final repository = _FakeScenarioRepository(
      income: const <IncomeSource>[
        IncomeSource(id: 'salary', name: 'Salary', annualGross: 4800, overrideMonthlyNet: 400),
      ],
      expenses: const <Expense>[
        Expense(id: 'bills', name: 'Bills', amount: 250),
      ],
      debts: <DebtAccount>[
        DebtAccount(
          id: 'card',
          name: 'Card',
          balance: 1000,
          apr: 12,
          minimumPayment: 100,
        ),
      ],
    );
    final controller = ScenarioBuilderController(repository);

    expect(
      controller.validateStandaloneExtraPayment('75'),
      'Extra payment exceeds available monthly cash.',
    );
  });

  test('ScenarioBuilderController uses scenario changes in plan affordability', () {
    final repository = _FakeScenarioRepository(
      income: const <IncomeSource>[
        IncomeSource(id: 'salary', name: 'Salary', annualGross: 4800, overrideMonthlyNet: 400),
      ],
      expenses: const <Expense>[
        Expense(id: 'bills', name: 'Bills', amount: 250),
      ],
      debts: <DebtAccount>[
        DebtAccount(
          id: 'card',
          name: 'Card',
          balance: 1000,
          apr: 12,
          minimumPayment: 100,
        ),
      ],
    );
    final controller = ScenarioBuilderController(repository);

    expect(
      controller.validateScenarioPlan(
        extraPayment: '100',
        incomeIncrease: '75',
        expenseReduction: '25',
      ),
      isNull,
    );
    expect(
      controller.validateScenarioPlan(
        extraPayment: '200',
        incomeIncrease: '75',
        expenseReduction: '25',
      ),
      'Extra payment exceeds available monthly cash after your scenario changes.',
    );
  });

  test('ScenarioBuilderController reads current scenario amounts by type', () {
    final repository = _FakeScenarioRepository()
      ..changes = const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.increaseIncome,
          amount: 90,
          startMonth: 3,
          durationInMonths: 5,
        ),
        ScenarioChange(
          changeType: ChangeType.reduceExpenses,
          amount: 30,
          startMonth: 3,
          durationInMonths: 5,
        ),
        ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 120,
          startMonth: 3,
          durationInMonths: 5,
        ),
      ];
    final controller = ScenarioBuilderController(repository);

    expect(controller.currentIncomeIncrease(), 90);
    expect(controller.currentExpenseReduction(), 30);
    expect(controller.currentExtraPayment(), 120);
    expect(controller.currentStartMonth(), 3);
    expect(controller.currentDurationInMonths(), 5);
  });

  test('ScenarioBuilderController validates schedule inputs', () {
    final controller = ScenarioBuilderController(_FakeScenarioRepository());

    expect(
      controller.validateStartMonth('-1'),
      'Start month must be a whole number of 0 or more.',
    );
    expect(
      controller.validateDurationInMonths('0'),
      'Duration must be a whole number above 0.',
    );
    expect(controller.validateStartMonth('2'), isNull);
    expect(controller.validateDurationInMonths('6'), isNull);
    expect(controller.validateDurationInMonths(''), isNull);
  });

  test('ScenarioBuilderController removes only the requested scenario change', () {
    final repository = _FakeScenarioRepository()
      ..changes = const <ScenarioChange>[
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
          amount: 150,
          startMonth: 2,
          durationInMonths: 6,
        ),
      ];
    final controller = ScenarioBuilderController(repository);

    controller.removeChange(ChangeType.increaseIncome);

    expect(repository.changes, hasLength(2));
    expect(
      repository.changes.map((ScenarioChange change) => change.changeType),
      <ChangeType>[
        ChangeType.reduceExpenses,
        ChangeType.extraPayment,
      ],
    );
    expect(repository.changes.first.startMonth, 2);
    expect(repository.changes.first.durationInMonths, 6);
  });

  test('ScenarioBuilderController normalizes mixed schedules into one plan', () {
    final repository = _FakeScenarioRepository()
      ..changes = const <ScenarioChange>[
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
    final controller = ScenarioBuilderController(repository);

    controller.normalizeCurrentPlan();

    expect(repository.changes, hasLength(2));
    expect(repository.changes.first.startMonth, 1);
    expect(repository.changes.first.durationInMonths, 2);
    expect(repository.changes.last.startMonth, 1);
    expect(repository.changes.last.durationInMonths, 2);
  });
}
