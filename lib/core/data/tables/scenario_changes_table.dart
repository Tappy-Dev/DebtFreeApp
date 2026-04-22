import 'package:drift/drift.dart';

class ScenarioChangesTable extends Table {
  TextColumn get id => text()();

  TextColumn get changeType => text().named('change_type')();

  RealColumn get amount => real()();

  IntColumn get startMonth => integer().named('start_month')();

  IntColumn get durationInMonths =>
      integer().named('duration_in_months').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
