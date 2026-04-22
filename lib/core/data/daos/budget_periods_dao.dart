import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:debt_free_app/core/data/records/budget_actual_record.dart';
import 'package:debt_free_app/core/data/records/budget_period_record.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual_entry.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';
import 'package:drift/drift.dart';

class BudgetPeriodsDao {
  const BudgetPeriodsDao(this._database);

  final DriftFinancialDatabase _database;

  // ── Periods ──

  Future<List<BudgetPeriod>> loadAllPeriods() async {
    final rows = await _database.customSelect(
      'SELECT * FROM ${DriftSchema.budgetPeriodsTable} ORDER BY year DESC, month DESC',
    ).get();

    return rows
        .map((row) => BudgetPeriodRecord.fromRow(row).toBudgetPeriod())
        .toList(growable: false);
  }

  Future<BudgetPeriod?> loadPeriod(String periodId) async {
    final rows = await _database.customSelect(
      'SELECT * FROM ${DriftSchema.budgetPeriodsTable} WHERE id = ?',
      variables: [Variable<String>(periodId)],
    ).get();

    if (rows.isEmpty) return null;
    return BudgetPeriodRecord.fromRow(rows.first).toBudgetPeriod();
  }

  Future<void> upsertPeriod(BudgetPeriod period) {
    final record = BudgetPeriodRecord.fromPeriod(period);
    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.budgetPeriodsTable}
        (id, year, month, status, notes, closed_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        status = excluded.status,
        notes = excluded.notes,
        closed_at = excluded.closed_at
      ''',
      record.toSqlVariables(),
    );
  }

  // ── Actuals ──

  Future<List<BudgetActual>> loadActualsForPeriod(String periodId) async {
    final rows = await _database.customSelect(
      'SELECT * FROM ${DriftSchema.budgetActualsTable} '
      'WHERE period_id = ? ORDER BY category_type, category_name',
      variables: [Variable<String>(periodId)],
    ).get();

    return rows
        .map((row) => BudgetActualRecord.fromRow(row).toBudgetActual())
        .toList(growable: false);
  }

  Future<void> upsertActual(BudgetActual actual) {
    final record = BudgetActualRecord.fromActual(actual);
    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.budgetActualsTable}
        (id, period_id, category_id, category_name, category_type, budgeted, actual, debt_balance)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        category_name = excluded.category_name,
        budgeted = excluded.budgeted,
        actual = excluded.actual,
        debt_balance = excluded.debt_balance
      ''',
      record.toSqlVariables(),
    );
  }

  Future<void> upsertAllActuals(List<BudgetActual> actuals) async {
    for (final actual in actuals) {
      await upsertActual(actual);
    }
  }

  Future<void> deleteActualsForPeriod(String periodId) {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.budgetActualsTable} WHERE period_id = ?',
      <Object?>[periodId],
    );
  }

  Future<void> deleteActual(String actualId) {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.budgetActualsTable} WHERE id = ?',
      <Object?>[actualId],
    );
  }

  Future<void> deleteSeededBudgetActuals(String periodId) {
    return _database.customStatement(
      "DELETE FROM ${DriftSchema.budgetActualsTable} "
      "WHERE period_id = ? AND category_type IN ('income','expense','bill') "
      "AND budgeted > 0",
      <Object?>[periodId],
    );
  }

  // ── Actual Entries ──

  Future<List<BudgetActualEntry>> loadEntriesForPeriod(
      String periodId) async {
    final rows = await _database.customSelect(
      'SELECT e.* FROM ${DriftSchema.budgetActualEntriesTable} e '
      'JOIN ${DriftSchema.budgetActualsTable} a ON a.id = e.actual_id '
      'WHERE a.period_id = ? ORDER BY e.entry_date',
      variables: [Variable<String>(periodId)],
    ).get();

    return rows
        .map((row) => BudgetActualEntry(
              id: row.read<String>('id'),
              actualId: row.read<String>('actual_id'),
              reference: row.read<String>('reference'),
              date: DateTime.parse(row.read<String>('entry_date')),
              amount: row.read<double>('amount'),
            ))
        .toList(growable: false);
  }

  Future<void> upsertEntry(BudgetActualEntry entry) {
    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.budgetActualEntriesTable}
        (id, actual_id, reference, entry_date, amount)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        reference = excluded.reference,
        entry_date = excluded.entry_date,
        amount = excluded.amount
      ''',
      <Object?>[
        entry.id,
        entry.actualId,
        entry.reference,
        entry.date.toIso8601String().substring(0, 10),
        entry.amount,
      ],
    );
  }

  Future<void> deleteEntry(String entryId) {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.budgetActualEntriesTable} WHERE id = ?',
      <Object?>[entryId],
    );
  }
}
