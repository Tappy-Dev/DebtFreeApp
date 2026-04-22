import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:debt_free_app/core/data/records/mortgage_record.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';

class MortgageDao {
  const MortgageDao(this._database);

  final DriftFinancialDatabase _database;

  Future<Mortgage?> load() async {
    final rows = await _database.customSelect(
      'SELECT ${MortgageRecord.selectColumns} '
      'FROM ${DriftSchema.mortgageTable} LIMIT 1',
    ).get();

    if (rows.isEmpty) return null;

    return MortgageRecord.fromRow(rows.first).toMortgage();
  }

  Future<void> upsert(Mortgage mortgage) {
    final record = MortgageRecord.fromMortgage(mortgage);

    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.mortgageTable}
        ${MortgageRecord.insertColumns}
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        balance = excluded.balance,
        annual_rate = excluded.annual_rate,
        monthly_payment = excluded.monthly_payment,
        remaining_term_months = excluded.remaining_term_months,
        overpayment = excluded.overpayment
      ''',
      record.toSqlVariables(),
    );
  }

  Future<void> deleteAll() {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.mortgageTable}',
    );
  }
}
