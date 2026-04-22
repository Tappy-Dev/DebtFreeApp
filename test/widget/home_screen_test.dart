import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/features/home/presentation/home_screen.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeScreen shows an empty-state prompt with no debts', (
    WidgetTester tester,
  ) async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final repository = SessionFinancialRepository.test(
      database: database,
    );
    addTearDown(() async {
      await repository.waitForPendingWrites();
      await database.close();
    });

    await repository.hydrate();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repository),
      ),
    );

    expect(find.text('Start with your first debt'), findsOneWidget);
    expect(
      find.text(
        'Add a debt and some budget details to unlock a more useful payoff forecast.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('HomeScreen reacts to repository debt updates', (
    WidgetTester tester,
  ) async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final repository = SessionFinancialRepository.test(
      database: database,
    );
    addTearDown(() async {
      await repository.waitForPendingWrites();
      await database.close();
    });

    await repository.hydrate();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repository),
      ),
    );

    expect(find.text('Start with your first debt'), findsOneWidget);

    repository.saveDebt(
      DebtAccount(
        id: 'card-1',
        name: 'Credit Card',
        balance: 2500,
        apr: 18.9,
        minimumPayment: 90,
      ),
    );
    await repository.waitForPendingWrites();
    await tester.pump();

    expect(find.text('Start with your first debt'), findsNothing);
    expect(find.text('Total Debt: \u00A32,500.00'), findsOneWidget);
  });

  testWidgets('HomeScreen shows full scenario impact in monthly snapshot', (
    WidgetTester tester,
  ) async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final repository = SessionFinancialRepository.test(
      database: database,
    );
    addTearDown(() async {
      await repository.waitForPendingWrites();
      await database.close();
    });

    await repository.hydrate();
    repository.saveDebt(
      DebtAccount(
        id: 'card-1',
        name: 'Credit Card',
        balance: 2500,
        apr: 18.9,
        minimumPayment: 90,
      ),
    );
    repository.saveIncomeSource(
      const IncomeSource(
        id: 'salary',
        name: 'Salary',
        annualGross: 36000,
        overrideMonthlyNet: 3000,
      ),
    );
    repository.saveExpense(
      const Expense(
        id: 'rent',
        name: 'Rent',
        amount: 1200,
      ),
    );
    repository.saveScenarioChanges(
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
    await repository.waitForPendingWrites();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repository),
      ),
    );

    expect(find.text('Active monthly scenario'), findsOneWidget);
    expect(find.textContaining('adds \u00A375.00 income'), findsOneWidget);
    expect(find.text('Impact Highlights'), findsOneWidget);
    expect(find.text('Months Saved'), findsOneWidget);
    expect(find.text('Interest Saved'), findsOneWidget);
    expect(
      find.text('starts in 2 months and lasts for 6 months.'),
      findsOneWidget,
    );
    expect(find.text('Monthly flexibility gained: \u00A3100.00'), findsOneWidget);
    expect(find.text('Extra debt payment: \u00A3150.00'), findsOneWidget);
  });

  testWidgets('HomeScreen shows a warning for inconsistent saved schedules', (
    WidgetTester tester,
  ) async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final writer = SessionFinancialRepository.test(
      database: database,
    );
    addTearDown(() async {
      await writer.waitForPendingWrites();
      await database.close();
    });

    await writer.hydrate();
    writer.saveDebt(
      DebtAccount(
        id: 'card-1',
        name: 'Credit Card',
        balance: 2500,
        apr: 18.9,
        minimumPayment: 90,
      ),
    );
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

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: reader),
      ),
    );

    expect(find.text('Active monthly scenario'), findsOneWidget);
    expect(
      find.textContaining('different schedules'),
      findsOneWidget,
    );
  });
}
