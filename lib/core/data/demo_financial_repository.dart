import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/core/sample/demo_data.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual_entry.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';

class DemoFinancialRepository implements FinancialRepository {
  const DemoFinancialRepository();

  @override
  List<DebtAccount> getDebts() {
    return DemoData.debts
        .map((DebtAccount debt) => debt.copy())
        .toList(growable: false);
  }

  @override
  List<Expense> getExpenses() {
    return List<Expense>.unmodifiable(DemoData.expenses);
  }

  @override
  List<Expense> getBills() {
    return List<Expense>.unmodifiable(DemoData.bills);
  }

  @override
  List<IncomeSource> getIncomeSources() {
    return List<IncomeSource>.unmodifiable(DemoData.income);
  }

  @override
  List<ScenarioChange> getScenarioChanges() {
    return List<ScenarioChange>.unmodifiable(DemoData.extraPaymentScenario);
  }

  @override
  Mortgage? getMortgage() {
    return DemoData.mortgage;
  }

  @override
  List<String> get availableBudgetMonths => const [];

  @override
  String get activeBudgetMonth => '';

  @override
  List<IncomeSource> getIncomeSourcesForMonth(String monthKey) =>
      getIncomeSources();

  @override
  List<Expense> getExpensesForMonth(String monthKey) => getExpenses();

  @override
  List<Expense> getBillsForMonth(String monthKey) => getBills();

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
  void saveBill(Expense bill) {}

  @override
  void deleteBill(String billId) {}

  @override
  void saveScenarioChanges(List<ScenarioChange> scenarioChanges) {}

  @override
  void saveMortgage(Mortgage mortgage) {}

  @override
  void deleteMortgage() {}

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
  Future<void> deleteBudgetActual(String actualId) async {}

  @override
  Future<void> deleteSeededBudgetActuals(String periodId) async {}
  @override
  Future<List<BudgetActualEntry>> getBudgetActualEntries(
      String periodId) async => const [];
  @override
  Future<void> saveBudgetActualEntry(BudgetActualEntry entry) async {}
  @override
  Future<void> deleteBudgetActualEntry(String entryId) async {}
  @override
  String? get appStartMonth => null;
  @override
  Future<void> setAppStartMonth(String monthKey) async {}
}
