import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/financial_repository_extensions.dart';
import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SessionFinancialRepository deletes a saved debt', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final repository = SessionFinancialRepository.test(
      database: database,
    );

    await repository.hydrate();
    repository.saveDebt(
      DebtAccount(
        id: 'delete-me',
        name: 'Delete Me',
        balance: 500,
        apr: 10,
        minimumPayment: 25,
      ),
    );
    repository.deleteDebt('delete-me');

    expect(
      repository.getDebts().where((DebtAccount debt) => debt.id == 'delete-me'),
      isEmpty,
    );

    await repository.waitForPendingWrites();
    await database.close();
  });

  test('SessionFinancialRepository rehydrates budget items and scenarios', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final writer = SessionFinancialRepository.test(
      database: database,
    );

    await writer.hydrate();
    writer.saveIncomeSource(
      const IncomeSource(
        id: 'salary',
        name: 'Salary',
        annualGross: 36000,
        overrideMonthlyNet: 3000,
      ),
    );
    writer.saveExpense(
      const Expense(
        id: 'rent',
        name: 'Rent',
        amount: 1200,
      ),
    );
    writer.saveScenarioChanges(
      const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.increaseIncome,
          amount: 75,
          startMonth: 2,
          durationInMonths: 6,
        ),
        ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 200,
          startMonth: 2,
          durationInMonths: 6,
        ),
      ],
    );

    await writer.waitForPendingWrites();

    final reader = SessionFinancialRepository.test(
      database: database,
    );
    await reader.hydrate();

    expect(reader.getIncomeSources(), hasLength(1));
    expect(reader.getIncomeSources().single.name, 'Salary');
    expect(reader.getExpenses(), hasLength(1));
    expect(reader.getExpenses().single.name, 'Rent');
    expect(reader.getScenarioChanges(), hasLength(2));
    expect(
      reader.getScenarioChanges().map((change) => change.changeType),
      <ChangeType>[
        ChangeType.increaseIncome,
        ChangeType.extraPayment,
      ],
    );
    expect(reader.getScenarioChanges().first.startMonth, 2);
    expect(reader.getScenarioChanges().first.durationInMonths, 6);
    expect(reader.getScenarioChanges().last.amount, 200);

    await database.close();
  });

  test('SessionFinancialRepository persists clearing the active scenario plan', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final writer = SessionFinancialRepository.test(
      database: database,
    );

    await writer.hydrate();
    writer.saveScenarioChanges(
      const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 200,
        ),
      ],
    );
    writer.saveScenarioChanges(const <ScenarioChange>[]);

    await writer.waitForPendingWrites();

    final reader = SessionFinancialRepository.test(
      database: database,
    );
    await reader.hydrate();

    expect(reader.getScenarioChanges(), isEmpty);

    await database.close();
  });

  test(
    'SessionFinancialRepository preserves inconsistent saved scenario schedules on hydrate',
    () async {
      final database = DriftFinancialDatabase(
        executor: NativeDatabase.memory(),
      );
      final writer = SessionFinancialRepository.test(
        database: database,
      );

      await writer.hydrate();
      writer.saveScenarioChanges(
        const <ScenarioChange>[
          ScenarioChange(
            changeType: ChangeType.increaseIncome,
            amount: 75,
            startMonth: 1,
            durationInMonths: 2,
          ),
          ScenarioChange(
            changeType: ChangeType.extraPayment,
            amount: 150,
            startMonth: 3,
            durationInMonths: 6,
          ),
        ],
      );
      await writer.waitForPendingWrites();

      final reader = SessionFinancialRepository.test(
        database: database,
      );
      await reader.hydrate();

      expect(reader.getScenarioChanges(), hasLength(2));
      expect(
        reader.getScenarioChanges().map((change) => change.startMonth),
        <int>[1, 3],
      );
      expect(reader.getActiveScenarioPlan().hasMixedSchedules, isTrue);

      await database.close();
    },
  );

  test('SessionFinancialRepository does not rehydrate deleted debts', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final writer = SessionFinancialRepository.test(
      database: database,
    );

    await writer.hydrate();
    writer.saveDebt(
      DebtAccount(
        id: 'temporary-debt',
        name: 'Temporary Debt',
        balance: 800,
        apr: 12,
        minimumPayment: 40,
      ),
    );
    await writer.waitForPendingWrites();

    writer.deleteDebt('temporary-debt');
    await writer.waitForPendingWrites();

    final reader = SessionFinancialRepository.test(
      database: database,
    );
    await reader.hydrate();

    expect(
      reader.getDebts().where(
        (DebtAccount debt) => debt.id == 'temporary-debt',
      ),
      isEmpty,
    );

    await database.close();
  });

  test('SessionFinancialRepository hydrate waits for queued writes', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final repository = SessionFinancialRepository.test(
      database: database,
    );

    await repository.hydrate();
    repository.saveDebt(
      DebtAccount(
        id: 'queued-debt',
        name: 'Queued Debt',
        balance: 950,
        apr: 14,
        minimumPayment: 55,
      ),
    );

    await repository.hydrate();

    expect(
      repository.getDebts().where(
        (DebtAccount debt) => debt.id == 'queued-debt',
      ),
      hasLength(1),
    );

    await database.close();
  });
}
