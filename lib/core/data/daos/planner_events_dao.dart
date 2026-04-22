import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:debt_free_app/core/data/records/planner_event_record.dart';
import 'package:debt_free_app/features/planner/models/planner_event.dart';

class PlannerEventsDao {
  const PlannerEventsDao(this._database);

  final DriftFinancialDatabase _database;

  Future<List<PlannerEvent>> loadAll() async {
    final rows = await _database.customSelect(
      'SELECT * FROM ${DriftSchema.plannerEventsTable} '
      'ORDER BY scheduled_year, scheduled_month',
    ).get();

    return rows
        .map((row) => PlannerEventRecord.fromRow(row).toEvent())
        .toList(growable: false);
  }

  Future<void> upsert(PlannerEvent event) {
    final record = PlannerEventRecord.fromEvent(event);

    return _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.plannerEventsTable}
        (id, title, event_type, amount, scheduled_month, scheduled_year, is_recurring, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        event_type = excluded.event_type,
        amount = excluded.amount,
        scheduled_month = excluded.scheduled_month,
        scheduled_year = excluded.scheduled_year,
        is_recurring = excluded.is_recurring,
        notes = excluded.notes
      ''',
      record.toSqlVariables(),
    );
  }

  Future<void> deleteById(String id) {
    return _database.customStatement(
      'DELETE FROM ${DriftSchema.plannerEventsTable} WHERE id = ?',
      <Object?>[id],
    );
  }
}
