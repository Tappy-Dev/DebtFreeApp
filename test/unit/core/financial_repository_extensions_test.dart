import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/core/data/financial_repository_extensions.dart';
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

class _RepositoryStub implements FinancialRepository {
  _RepositoryStub(this._changes);

  final List<ScenarioChange> _changes;

  @override
  void deleteDebt(String debtId) {}

  @override
  void deleteExpense(String expenseId) {}

  @override
  void deleteIncomeSource(String incomeSourceId) {}

  @override
  List<DebtAccount> getDebts() => const <DebtAccount>[];

  @override
  List<Expense> getExpenses() => const <Expense>[];

  @override
  List<IncomeSource> getIncomeSources() => const <IncomeSource>[];

  @override
  List<ScenarioChange> getScenarioChanges() => _changes;

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
  test('FinancialRepositoryScenarioPlan rebuilds the active scenario plan', () {
    final repository = _RepositoryStub(
      const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.increaseIncome,
          amount: 75,
          startMonth: 2,
          durationInMonths: 6,
        ),
        ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 150,
          startMonth: 2,
          durationInMonths: 6,
        ),
      ],
    );

    final plan = repository.getActiveScenarioPlan();

    expect(plan.incomeIncrease, 75);
    expect(plan.expenseReduction, 0);
    expect(plan.extraPayment, 150);
    expect(plan.startMonth, 2);
    expect(plan.durationInMonths, 6);
  });
}
