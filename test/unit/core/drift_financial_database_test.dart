import 'package:debt_free_app/core/data/daos/scenario_changes_dao.dart';
import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DriftFinancialDatabase upgrades legacy scenario tables safely', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    addTearDown(() => database.close());

    await database.customStatement(
      'DROP TABLE ${DriftSchema.scenarioChangesTable}',
    );
    await database.customStatement(
      DriftSchema.createLegacyScenarioChangesTable,
    );
    await database.customStatement(
      '''
      INSERT INTO ${DriftSchema.scenarioChangesTable} (id, change_type, amount)
      VALUES (?, ?, ?)
      ''',
      <Object?>['legacy-1', 'extraPayment', 150.0],
    );

    await database.ensureScenarioChangeScheduleColumns();

    final columns = await database.customSelect(
      'PRAGMA table_info(${DriftSchema.scenarioChangesTable})',
    ).get();
    final columnNames = columns
        .map((row) => row.read<String>('name'))
        .toSet();

    expect(
      columnNames,
      contains(DriftSchema.scenarioStartMonthColumn),
    );
    expect(
      columnNames,
      contains(DriftSchema.scenarioDurationInMonthsColumn),
    );

    final dao = ScenarioChangesDao(database);
    final changes = await dao.loadAll();

    expect(changes, hasLength(1));
    expect(changes.single.changeType, ChangeType.extraPayment);
    expect(changes.single.amount, 150);
    expect(changes.single.startMonth, 0);
    expect(changes.single.durationInMonths, isNull);
  });
}
