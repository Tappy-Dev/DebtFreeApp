import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:debt_free_app/core/data/records/salary_sacrifice_record.dart';
import 'package:debt_free_app/features/simulation/models/salary_sacrifice.dart';

class SalarySacrificesDao {
  const SalarySacrificesDao(this._database);

  final DriftFinancialDatabase _database;

  Future<List<SalarySacrifice>> loadAll() async {
    final rows = await _database.customSelect(
      'SELECT ${SalarySacrificeRecord.selectColumns} '
      'FROM ${DriftSchema.salarySacrificesTable} ORDER BY name',
    ).get();

    return rows
        .map((row) => SalarySacrificeRecord.fromRow(row).toSalarySacrifice())
        .toList(growable: false);
  }

  Future<void> upsert(SalarySacrifice sacrifice) {
    final record = SalarySacrificeRecord.fromSacrifice(sacrifice);

    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.salarySacrificesTable}
        ${SalarySacrificeRecord.insertColumns}
      VALUES (?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        gross_amount = excluded.gross_amount,
        tax_band = excluded.tax_band
      ''',
      record.toSqlVariables(),
    );
  }

  Future<void> deleteById(String id) {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.salarySacrificesTable} WHERE id = ?',
      <Object?>[id],
    );
  }
}
