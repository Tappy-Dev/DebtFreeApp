import 'package:debt_free_app/features/scenarios/domain/active_scenario_plan.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ActiveScenarioPlan rebuilds a scheduled plan from changes', () {
    final plan = ActiveScenarioPlan.fromChanges(
      const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.increaseIncome,
          amount: 75,
          startMonth: 2,
          durationInMonths: 6,
        ),
        ScenarioChange(
          changeType: ChangeType.reduceExpenses,
          amount: 25,
          startMonth: 2,
          durationInMonths: 6,
        ),
        ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 150,
          startMonth: 2,
          durationInMonths: 6,
        ),
      ],
    );

    expect(plan.incomeIncrease, 75);
    expect(plan.expenseReduction, 25);
    expect(plan.extraPayment, 150);
    expect(plan.startMonth, 2);
    expect(plan.durationInMonths, 6);
    expect(plan.hasChanges, isTrue);
  });

  test('ActiveScenarioPlan removes one type and preserves schedule', () {
    final plan = const ActiveScenarioPlan(
      incomeIncrease: 75,
      expenseReduction: 25,
      extraPayment: 150,
      startMonth: 2,
      durationInMonths: 6,
    );

    final updated = plan.removeType(ChangeType.increaseIncome);

    expect(updated.incomeIncrease, 0);
    expect(updated.expenseReduction, 25);
    expect(updated.extraPayment, 150);
    expect(updated.startMonth, 2);
    expect(updated.durationInMonths, 6);
  });

  test('ActiveScenarioPlan converts back to scenario changes', () {
    final changes = const ActiveScenarioPlan(
      incomeIncrease: 75,
      expenseReduction: 0,
      extraPayment: 150,
      startMonth: 1,
      durationInMonths: 3,
    ).toChanges();

    expect(changes, hasLength(2));
    expect(changes.first.startMonth, 1);
    expect(changes.first.durationInMonths, 3);
    expect(
      changes.map((ScenarioChange change) => change.changeType),
      <ChangeType>[
        ChangeType.increaseIncome,
        ChangeType.extraPayment,
      ],
    );
  });

  test('ActiveScenarioPlan flags mixed schedules and keeps the earliest one', () {
    final plan = ActiveScenarioPlan.fromChanges(
      const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 150,
          startMonth: 3,
          durationInMonths: 6,
        ),
        ScenarioChange(
          changeType: ChangeType.increaseIncome,
          amount: 75,
          startMonth: 1,
          durationInMonths: 2,
        ),
      ],
    );

    expect(plan.hasMixedSchedules, isTrue);
    expect(plan.startMonth, 1);
    expect(plan.durationInMonths, 2);
    expect(plan.incomeIncrease, 75);
    expect(plan.extraPayment, 150);
  });
}
