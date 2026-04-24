import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/records/debt_record.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';

class DebtsDao {
  const DebtsDao(this._database);

  final DriftFinancialDatabase _database;

  Future<List<DebtAccount>> loadAll() async {
    final rows = await _database
        .customSelect(
          'SELECT ${DebtRecord.selectColumns} '
          'FROM ${DriftSchema.debtsTable} ORDER BY name',
        )
        .get();

    final debts = rows
        .map((row) => DebtRecord.fromRow(row).toDebtAccount())
        .toList(growable: false);

    // Load extra payments for all debts
    final extraRows = await _database
        .customSelect(
          'SELECT id, debt_id, amount, start_date, end_date '
          'FROM ${DriftSchema.debtExtraPaymentsTable}',
        )
        .get();

    final extraByDebt = <String, List<DebtExtraPayment>>{};
    for (final row in extraRows) {
      final debtId = row.read<String>('debt_id');
      extraByDebt.putIfAbsent(debtId, () => []).add(DebtExtraPayment(
            id: row.read<String>('id'),
            debtId: debtId,
            amount: row.read<double>('amount'),
            startDate: DateTime.parse(row.read<String>('start_date')),
            endDate: DateTime.parse(row.read<String>('end_date')),
          ));
    }

    return debts.map((d) {
      final extras = extraByDebt[d.id];
      if (extras == null) return d;
      return DebtAccount(
        id: d.id,
        name: d.name,
        debtType: d.debtType,
        balance: d.balance,
        apr: d.apr,
        minimumPayment: d.minimumPayment,
        payoffDate: d.payoffDate,
        startDate: d.startDate,
        loanEndDate: d.loanEndDate,
        paymentDay: d.paymentDay,
        minPaymentRule: d.minPaymentRule,
        originalBalance: d.originalBalance,
        extraPayments: extras,
      );
    }).toList(growable: false);
  }

  Future<void> upsert(DebtAccount debt) {
    final record = DebtRecord.fromDebt(debt);

    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.debtsTable}
        ${DebtRecord.insertColumns}
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        debt_type = excluded.debt_type,
        balance = excluded.balance,
        apr = excluded.apr,
        minimum_payment = excluded.minimum_payment,
        payoff_date = excluded.payoff_date,
        min_payment_type = excluded.min_payment_type,
        min_payment_percentage = excluded.min_payment_percentage,
        min_payment_floor = excluded.min_payment_floor,
        start_date = excluded.start_date,
        loan_end_date = excluded.loan_end_date,
        payment_day = excluded.payment_day,
        original_balance = excluded.original_balance
      ''',
      record.toSqlVariables(),
    );
  }

  Future<void> upsertExtraPayment(DebtExtraPayment extra) {
    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.debtExtraPaymentsTable}
        (id, debt_id, amount, start_date, end_date)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        amount = excluded.amount,
        start_date = excluded.start_date,
        end_date = excluded.end_date
      ''',
      [
        extra.id,
        extra.debtId,
        extra.amount,
        extra.startDate.toIso8601String(),
        extra.endDate.toIso8601String(),
      ],
    );
  }

  Future<void> deleteExtraPayment(String extraId) {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.debtExtraPaymentsTable} WHERE id = ?',
      <Object?>[extraId],
    );
  }

  Future<void> deleteExtraPaymentsForDebt(String debtId) {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.debtExtraPaymentsTable} WHERE debt_id = ?',
      <Object?>[debtId],
    );
  }

  Future<void> deleteById(String debtId) async {
    await deleteExtraPaymentsForDebt(debtId);
    await _database.customStatement(
      'DELETE FROM ${DriftSchema.debtsTable} WHERE id = ?',
      <Object?>[debtId],
    );
  }
}
