import 'package:drift/drift.dart';

class IncomeSourcesTable extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  RealColumn get amount => real()();

  @override
  Set<Column> get primaryKey => {id};
}
