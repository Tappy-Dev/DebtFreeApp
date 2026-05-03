import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/features/budget/application/budget_item_form_controller.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/simulation/models/salary_sacrifice.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/core/utils/uk_tax_calculator.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual_entry.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBudgetRepository implements FinancialRepository {
  final List<IncomeSource> income = <IncomeSource>[];
  final List<Expense> expenses = <Expense>[];

  @override
  List<DebtAccount> getDebts() => const <DebtAccount>[];

  @override
  List<IncomeSource> getIncomeSources() =>
      List<IncomeSource>.unmodifiable(income);

  @override
  List<Expense> getExpenses() => List<Expense>.unmodifiable(expenses);

  @override
  List<ScenarioChange> getScenarioChanges() => const <ScenarioChange>[];

  @override
  void saveDebt(DebtAccount debtAccount) {}

  @override
  void deleteDebt(String debtId) {}

  @override
  void saveIncomeSource(IncomeSource incomeSource) {
    final index =
        income.indexWhere((IncomeSource item) => item.id == incomeSource.id);
    if (index == -1) {
      income.add(incomeSource);
      return;
    }

    income[index] = incomeSource;
  }

  @override
  void deleteIncomeSource(String incomeSourceId) {}

  @override
  void saveExpense(Expense expense) {
    final index = expenses.indexWhere((Expense item) => item.id == expense.id);
    if (index == -1) {
      expenses.add(expense);
      return;
    }

    expenses[index] = expense;
  }

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
  test('BudgetItemFormController saves income items', () {
    final repository = _FakeBudgetRepository();
    final controller = BudgetItemFormController(repository);

    controller.saveItem(
      type: BudgetItemType.income,
      name: 'Salary',
      amount: '\u00A33,000',
    );

    expect(repository.income, hasLength(1));
    expect(repository.income.first.name, 'Salary');
    expect(repository.income.first.annualGross, 3000);
  });

  test('BudgetItemFormController saves expense items', () {
    final repository = _FakeBudgetRepository();
    final controller = BudgetItemFormController(repository);

    controller.saveItem(
      type: BudgetItemType.expense,
      name: 'Rent',
      amount: '1200',
    );

    expect(repository.expenses, hasLength(1));
    expect(repository.expenses.first.name, 'Rent');
    expect(repository.expenses.first.amount, 1200);
  });

  test('BudgetItemFormController preserves item id when editing', () {
    final repository = _FakeBudgetRepository();
    final controller = BudgetItemFormController(repository);

    controller.saveItem(
      type: BudgetItemType.income,
      itemId: 'income-salary',
      name: 'Salary',
      amount: '3200',
    );
    controller.saveItem(
      type: BudgetItemType.income,
      itemId: 'income-salary',
      name: 'Updated Salary',
      amount: '3500',
    );

    expect(repository.income, hasLength(1));
    expect(repository.income.first.id, 'income-salary');
    expect(repository.income.first.name, 'Updated Salary');
    expect(repository.income.first.annualGross, 3500);
  });

  test('BudgetItemFormController rejects zero amounts', () {
    final controller = BudgetItemFormController(_FakeBudgetRepository());

    expect(
      controller.validateAmount('0', 'Amount'),
      'Amount must be greater than 0.',
    );
  });

  test('BudgetItemFormController saves income payslip adjustments', () {
    final repository = _FakeBudgetRepository();
    final controller = BudgetItemFormController(repository);

    controller.saveIncomeItem(
      name: 'Salary',
      annualGross: '50000',
      studentLoanPlan: StudentLoanPlan.plan2,
      monthlyTaxableBenefits: '138.22',
      monthlyNiableBenefits: '0',
      monthlyStudentLoanableBenefits: '0',
    );

    expect(repository.income, hasLength(1));
    expect(repository.income.first.monthlyTaxableBenefits, 138.22);
    expect(repository.income.first.monthlyNiableBenefits, 0);
    expect(repository.income.first.monthlyStudentLoanableBenefits, 0);
  });
}
