import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:debt_free_app/core/data/records/mortgage_record.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';

class MortgageDao {
  const MortgageDao(this._database);

  final DriftFinancialDatabase _database;

  Future<Mortgage?> load() async {
    final mortgages = await loadAll();
    if (mortgages.isEmpty) return null;
    return mortgages.first;
  }

  Future<List<Mortgage>> loadAll() async {
    final rows = await _database
        .customSelect(
          'SELECT ${MortgageRecord.selectColumns} '
          'FROM ${DriftSchema.mortgageTable}',
        )
        .get();

    return rows
        .map((row) => MortgageRecord.fromRow(row).toMortgage())
        .toList(growable: false);
  }

  Future<void> upsert(Mortgage mortgage) {
    final record = MortgageRecord.fromMortgage(mortgage);

    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.mortgageTable}
        ${MortgageRecord.insertColumns}
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        balance = excluded.balance,
        annual_rate = excluded.annual_rate,
        monthly_payment = excluded.monthly_payment,
        remaining_term_months = excluded.remaining_term_months,
        overpayment = excluded.overpayment,
        payment_day = excluded.payment_day,
        deal_end_date = excluded.deal_end_date
      ''',
      record.toSqlVariables(),
    );
  }

  Future<void> deleteAll() {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.mortgageTable}',
    );
  }

  Future<void> deleteById(String id) {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.mortgageTable} WHERE id = ?',
      <Object?>[id],
    );
  }
}
