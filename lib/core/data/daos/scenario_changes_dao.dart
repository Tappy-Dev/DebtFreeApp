import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/records/scenario_change_record.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:debt_free_app/features/scenarios/domain/active_scenario_plan.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';

class ScenarioChangesDao {
  const ScenarioChangesDao(this._database);

  final DriftFinancialDatabase _database;

  Future<List<ScenarioChange>> loadAll() async {
    final rows = await _database.customSelect(
      'SELECT ${ScenarioChangeRecord.selectColumns} '
      'FROM ${DriftSchema.scenarioChangesTable} '
      'ORDER BY ${ScenarioChangeRecord.startMonthColumn}, id',
    ).get();

    return rows
        .map((row) => ScenarioChangeRecord.fromRow(row).toScenarioChange())
        .toList(growable: false);
  }

  Future<ActiveScenarioPlan> loadPlan() async {
    final changes = await loadAll();
    return ActiveScenarioPlan.fromChanges(changes);
  }

  Future<void> replaceAll(List<ScenarioChange> changes) async {
    await _database.customStatement(
      'DELETE FROM ${DriftSchema.scenarioChangesTable}',
    );

    for (int index = 0; index < changes.length; index++) {
      final record = ScenarioChangeRecord.fromChange(
        id: 'scenario-change-$index',
        change: changes[index],
      );
      await _database.customStatement(
        '''
        INSERT INTO ${DriftSchema.scenarioChangesTable}
          ${ScenarioChangeRecord.insertColumns}
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        record.toSqlVariables(),
      );
    }
  }

  Future<void> replacePlan(ActiveScenarioPlan plan) {
    return replaceAll(plan.toChanges());
  }
}
