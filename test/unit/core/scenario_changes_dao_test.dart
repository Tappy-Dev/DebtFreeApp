import 'package:debt_free_app/core/data/daos/scenario_changes_dao.dart';
import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/features/scenarios/domain/active_scenario_plan.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ScenarioChangesDao replaces stored scenario changes', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final dao = ScenarioChangesDao(database);

    await dao.replaceAll(
      const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 150,
        ),
        ScenarioChange(
          changeType: ChangeType.reduceExpenses,
          amount: 75,
          startMonth: 1,
          durationInMonths: 6,
        ),
      ],
    );

    final initialChanges = await dao.loadAll();

    expect(initialChanges, hasLength(2));
    expect(initialChanges.first.changeType, ChangeType.extraPayment);
    expect(initialChanges.first.amount, 150);
    expect(initialChanges.last.changeType, ChangeType.reduceExpenses);
    expect(initialChanges.last.durationInMonths, 6);

    await dao.replaceAll(
      const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.increaseIncome,
          amount: 200,
          startMonth: 2,
        ),
      ],
    );

    final replacedChanges = await dao.loadAll();

    expect(replacedChanges, hasLength(1));
    expect(replacedChanges.single.changeType, ChangeType.increaseIncome);
    expect(replacedChanges.single.amount, 200);
    expect(replacedChanges.single.startMonth, 2);
  });

  test('ScenarioChangesDao preserves duration when loading changes', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final dao = ScenarioChangesDao(database);

    await dao.replaceAll(
      const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.reduceExpenses,
          amount: 80,
          startMonth: 3,
          durationInMonths: 4,
        ),
      ],
    );

    final changes = await dao.loadAll();

    expect(changes, hasLength(1));
    expect(changes.single.changeType, ChangeType.reduceExpenses);
    expect(changes.single.amount, 80);
    expect(changes.single.startMonth, 3);
    expect(changes.single.durationInMonths, 4);
  });

  test('ScenarioChangesDao loads scheduled changes in timeline order', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final dao = ScenarioChangesDao(database);

    await dao.replaceAll(
      const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 50,
          startMonth: 3,
        ),
        ScenarioChange(
          changeType: ChangeType.increaseIncome,
          amount: 75,
          startMonth: 1,
        ),
        ScenarioChange(
          changeType: ChangeType.reduceExpenses,
          amount: 25,
          startMonth: 2,
        ),
      ],
    );

    final changes = await dao.loadAll();

    expect(changes, hasLength(3));
    expect(changes.map((change) => change.startMonth), <int>[1, 2, 3]);
    expect(
      changes.map((change) => change.changeType),
      <ChangeType>[
        ChangeType.increaseIncome,
        ChangeType.reduceExpenses,
        ChangeType.extraPayment,
      ],
    );
  });

  test('ScenarioChangesDao replaces and loads an active scenario plan', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final dao = ScenarioChangesDao(database);

    await dao.replacePlan(
      const ActiveScenarioPlan(
        incomeIncrease: 75,
        expenseReduction: 25,
        extraPayment: 150,
        startMonth: 2,
        durationInMonths: 6,
      ),
    );

    final plan = await dao.loadPlan();

    expect(plan.incomeIncrease, 75);
    expect(plan.expenseReduction, 25);
    expect(plan.extraPayment, 150);
    expect(plan.startMonth, 2);
    expect(plan.durationInMonths, 6);
  });
}
