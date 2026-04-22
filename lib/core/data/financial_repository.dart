import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual_entry.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';

abstract class FinancialRepository {
  List<DebtAccount> getDebts();

  List<IncomeSource> getIncomeSources();

  List<Expense> getExpenses();

  List<Expense> getBills();

  List<ScenarioChange> getScenarioChanges();

  Mortgage? getMortgage();

  // ── Month-specific budget access (for month-versioned budgets) ──

  String get activeBudgetMonth;

  List<String> get availableBudgetMonths;

  List<IncomeSource> getIncomeSourcesForMonth(String monthKey);

  List<Expense> getExpensesForMonth(String monthKey);

  List<Expense> getBillsForMonth(String monthKey);

  void saveDebt(DebtAccount debtAccount);

  void deleteDebt(String debtId);

  void saveIncomeSource(IncomeSource incomeSource);

  void deleteIncomeSource(String incomeSourceId);

  void saveExpense(Expense expense);

  void deleteExpense(String expenseId);

  void saveBill(Expense bill);

  void deleteBill(String billId);

  void saveScenarioChanges(List<ScenarioChange> scenarioChanges);

  void saveMortgage(Mortgage mortgage);

  void deleteMortgage();

  // ── App settings ──

  String? get appStartMonth;

  Future<void> setAppStartMonth(String monthKey);

  // ── Budget tracking ──

  Future<List<BudgetPeriod>> getBudgetPeriods();

  Future<BudgetPeriod?> getBudgetPeriod(String periodId);

  Future<void> saveBudgetPeriod(BudgetPeriod period);

  Future<List<BudgetActual>> getBudgetActuals(String periodId);

  Future<void> saveBudgetActual(BudgetActual actual);

  Future<void> saveBudgetActuals(List<BudgetActual> actuals);

  Future<void> deleteBudgetActual(String actualId);

  Future<void> deleteSeededBudgetActuals(String periodId);

  Future<List<BudgetActualEntry>> getBudgetActualEntries(String periodId);

  Future<void> saveBudgetActualEntry(BudgetActualEntry entry);

  Future<void> deleteBudgetActualEntry(String entryId);
}
