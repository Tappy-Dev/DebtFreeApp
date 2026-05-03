import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/features/debts/application/debt_form_controller.dart';
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

class _FakeFinancialRepository implements FinancialRepository {
  final List<DebtAccount> savedDebts = <DebtAccount>[];

  @override
  List<DebtAccount> getDebts() => List<DebtAccount>.unmodifiable(savedDebts);

  @override
  List<Expense> getExpenses() => const <Expense>[];

  @override
  List<IncomeSource> getIncomeSources() => const <IncomeSource>[];

  @override
  List<ScenarioChange> getScenarioChanges() => const <ScenarioChange>[];

  @override
  void saveDebt(DebtAccount debtAccount) {
    savedDebts.add(debtAccount);
  }

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
  test('DebtFormController saves a parsed debt account', () {
    final repository = _FakeFinancialRepository();
    final controller = DebtFormController(repository);

    final debt = controller.saveDebt(
      name: 'Visa Card',
      balance: '\u00A31,200.50',
      apr: '19.9%',
      minimumPayment: '60',
    );

    expect(repository.savedDebts, hasLength(1));
    expect(debt.name, 'Visa Card');
    expect(debt.balance, 1200.50);
    expect(debt.apr, 19.9);
    expect(debt.minimumPayment, 60);
  });

  test('DebtFormController rejects APR above 100', () {
    final controller = DebtFormController(_FakeFinancialRepository());

    expect(controller.validateApr('120'), 'APR must be 100 or less.');
  });

  test('DebtFormController rejects zero minimum payment', () {
    final controller = DebtFormController(_FakeFinancialRepository());

    expect(
      controller.validateMinimumPayment('0'),
      'Minimum payment must be greater than 0.',
    );
  });

  test('DebtFormController saves loan debt with calculated payment', () {
    final repository = _FakeFinancialRepository();
    final controller = DebtFormController(repository);

    final debt = controller.saveDebt(
      name: 'Car Loan',
      debtType: DebtType.loan,
      balance: '12000',
      apr: '6',
      minimumPayment: '0',
      startDate: DateTime(2026, 4),
      loanEndDate: DateTime(2029, 3),
    );

    expect(debt.debtType, DebtType.loan);
    expect(debt.loanEndDate, DateTime(2029, 3));
    expect(debt.minimumPayment, closeTo(374.59, 0.02));
  });
}
