import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/records/budget_item_record.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';

class BudgetItemsDao {
  const BudgetItemsDao(this._database);

  final DriftFinancialDatabase _database;

  Future<List<IncomeSource>> loadIncomeSources() async {
    final rows = await _database
        .customSelect(
          'SELECT ${BudgetItemRecord.selectIncomeColumns} '
          'FROM ${DriftSchema.incomeSourcesTable} ORDER BY name',
        )
        .get();

    return rows
        .map((row) => BudgetItemRecord.incomeFromRow(row).toIncomeSource())
        .toList(growable: false);
  }

  Future<List<Expense>> loadExpenses() async {
    final rows = await _database
        .customSelect(
          'SELECT ${BudgetItemRecord.selectExpenseColumns} '
          'FROM ${DriftSchema.expensesTable} ORDER BY name',
        )
        .get();

    return rows
        .map((row) => BudgetItemRecord.expenseFromRow(row).toExpense())
        .toList(growable: false);
  }

  Future<void> upsertIncomeSource(IncomeSource incomeSource) {
    final record = BudgetItemRecord.fromIncomeSource(incomeSource);

    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.incomeSourcesTable} ${BudgetItemRecord.insertIncomeColumns}
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        amount = excluded.amount,
        annual_gross = excluded.annual_gross,
        student_loan_plan = excluded.student_loan_plan,
        monthly_pension_sacrifice = excluded.monthly_pension_sacrifice,
        monthly_car_sacrifice = excluded.monthly_car_sacrifice,
        monthly_other_sacrifice = excluded.monthly_other_sacrifice,
        monthly_taxable_benefits = excluded.monthly_taxable_benefits,
        monthly_niable_benefits = excluded.monthly_niable_benefits,
        monthly_student_loanable_benefits = excluded.monthly_student_loanable_benefits,
        month_key = excluded.month_key
      ''',
      record.toIncomeSqlVariables(),
    );
  }

  Future<void> deleteIncomeSource(String incomeSourceId) {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.incomeSourcesTable} WHERE id = ?',
      <Object?>[incomeSourceId],
    );
  }

  Future<void> upsertExpense(Expense expense) {
    final record = BudgetItemRecord.fromExpense(expense);

    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.expensesTable} ${BudgetItemRecord.insertColumns}
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        amount = excluded.amount,
        month_key = excluded.month_key,
        is_trackable = excluded.is_trackable
      ''',
      record.toSqlVariables(),
    );
  }

  Future<void> deleteExpense(String expenseId) {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.expensesTable} WHERE id = ?',
      <Object?>[expenseId],
    );
  }

  // ── Bills ──

  Future<List<Expense>> loadBills() async {
    final rows = await _database
        .customSelect(
          'SELECT ${BudgetItemRecord.selectColumns} '
          'FROM ${DriftSchema.billsTable} ORDER BY name',
        )
        .get();

    return rows
        .map((row) => BudgetItemRecord.fromRow(row).toExpense())
        .toList(growable: false);
  }

  Future<void> upsertBill(Expense bill) {
    final record = BudgetItemRecord.fromExpense(bill);

    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.billsTable} (id, name, amount, month_key, is_subscription, payment_day)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        amount = excluded.amount,
        month_key = excluded.month_key,
        is_subscription = excluded.is_subscription,
        payment_day = excluded.payment_day
      ''',
      [
        record.id,
        record.name,
        record.amount,
        record.monthKey,
        record.isSubscription ? 1 : 0,
        record.paymentDay ?? 1,
      ],
    );
  }

  Future<void> deleteBill(String billId) {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.billsTable} WHERE id = ?',
      <Object?>[billId],
    );
  }

  Future<void> clearMonth(String monthKey) async {
    await _database.customStatement(
      'DELETE FROM ${DriftSchema.incomeSourcesTable} WHERE month_key = ?',
      <Object?>[monthKey],
    );
    await _database.customStatement(
      'DELETE FROM ${DriftSchema.expensesTable} WHERE month_key = ?',
      <Object?>[monthKey],
    );
    await _database.customStatement(
      'DELETE FROM ${DriftSchema.billsTable} WHERE month_key = ?',
      <Object?>[monthKey],
    );
  }
}
