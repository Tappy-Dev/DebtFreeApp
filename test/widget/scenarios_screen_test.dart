import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/features/scenarios/presentation/scenarios_screen.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ScenariosScreen shows feedback after applying a scenario', (
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
        balance: 2400,
        apr: 18.9,
        minimumPayment: 100,
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
        amount: 1000,
      ),
    );
    await repository.waitForPendingWrites();

    await tester.pumpWidget(
      MaterialApp(
        home: ScenariosScreen(repository: repository),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Extra monthly income'),
      '75',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monthly expense reduction'),
      '25',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Extra monthly payment'),
      '150',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Start after this many months'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Duration in months (optional)'),
      '6',
    );
    await tester.tap(find.text('Apply scenario'));
    await tester.pump();

    expect(find.text('Scenario updated.'), findsOneWidget);
    expect(repository.getScenarioChanges(), hasLength(3));
    expect(
      repository.getScenarioChanges().map((change) => change.changeType),
      <ChangeType>[
        ChangeType.increaseIncome,
        ChangeType.reduceExpenses,
        ChangeType.extraPayment,
      ],
    );
    expect(repository.getScenarioChanges().first.startMonth, 2);
    expect(repository.getScenarioChanges().first.durationInMonths, 6);
    expect(find.text('Active plan changes'), findsOneWidget);
    expect(find.text('Interest Comparison'), findsOneWidget);
    expect(
      find.text('starts in 2 months and lasts for 6 months.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('adds \u00A375.00 income'),
      findsOneWidget,
    );
    expect(
      find.textContaining('cuts \u00A325.00 of expenses'),
      findsOneWidget,
    );
    expect(
      find.textContaining('sends \u00A3150.00 extra to debt'),
      findsOneWidget,
    );
    expect(
      find.text('Available room after plan changes: \u00A32000.00'),
      findsOneWidget,
    );
  });

  testWidgets('ScenariosScreen blocks extra payments above available cash', (
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
        id: 'loan-1',
        name: 'Loan',
        balance: 1200,
        apr: 9.5,
        minimumPayment: 75,
      ),
    );
    repository.saveIncomeSource(
      const IncomeSource(
        id: 'salary',
        name: 'Salary',
        annualGross: 14400,
        overrideMonthlyNet: 1200,
      ),
    );
    repository.saveExpense(
      const Expense(
        id: 'bills',
        name: 'Bills',
        amount: 1100,
      ),
    );
    await repository.waitForPendingWrites();

    await tester.pumpWidget(
      MaterialApp(
        home: ScenariosScreen(repository: repository),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Extra monthly income'),
      '75',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monthly expense reduction'),
      '25',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Extra monthly payment'),
      '200',
    );
    await tester.tap(find.text('Apply scenario'));
    await tester.pump();

    expect(
      find.text(
        'Extra payment exceeds available monthly cash after your scenario changes.',
      ),
      findsOneWidget,
    );
    expect(repository.getScenarioChanges(), isEmpty);
    expect(find.text('Scenario updated.'), findsNothing);
  });

  testWidgets('ScenariosScreen syncs the field when repository state changes', (
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
        balance: 1800,
        apr: 16.5,
        minimumPayment: 80,
      ),
    );
    repository.saveIncomeSource(
      const IncomeSource(
        id: 'salary',
        name: 'Salary',
        annualGross: 31200,
        overrideMonthlyNet: 2600,
      ),
    );
    repository.saveExpense(
      const Expense(
        id: 'rent',
        name: 'Rent',
        amount: 1400,
      ),
    );
    await repository.waitForPendingWrites();

    await tester.pumpWidget(
      MaterialApp(
        home: ScenariosScreen(repository: repository),
      ),
    );

    repository.saveScenarioChanges(
      const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 90.5,
        ),
      ],
    );
    await repository.waitForPendingWrites();
    await tester.pump();

    final incomeField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Extra monthly income'),
    );
    final expenseField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Monthly expense reduction'),
    );
    final extraPaymentField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Extra monthly payment'),
    );
    final startMonthField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Start after this many months'),
    );
    final durationField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Duration in months (optional)'),
    );

    expect(incomeField.controller?.text, '0');
    expect(expenseField.controller?.text, '0');
    expect(extraPaymentField.controller?.text, '90.50');
    expect(startMonthField.controller?.text, '0');
    expect(durationField.controller?.text, '');
    expect(
      find.text('Baseline room for extra payments: \u00A31120.00'),
      findsOneWidget,
    );
  });

  testWidgets('ScenariosScreen clears the active scenario plan', (
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
        balance: 1800,
        apr: 16.5,
        minimumPayment: 80,
      ),
    );
    repository.saveIncomeSource(
      const IncomeSource(
        id: 'salary',
        name: 'Salary',
        annualGross: 31200,
        overrideMonthlyNet: 2600,
      ),
    );
    repository.saveExpense(
      const Expense(
        id: 'rent',
        name: 'Rent',
        amount: 1400,
      ),
    );
    repository.saveScenarioChanges(
      const <ScenarioChange>[
        ScenarioChange(
          changeType: ChangeType.increaseIncome,
          amount: 75,
        ),
        ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 150,
        ),
      ],
    );
    await repository.waitForPendingWrites();

    await tester.pumpWidget(
      MaterialApp(
        home: ScenariosScreen(repository: repository),
      ),
    );

    expect(find.text('Clear scenario'), findsOneWidget);
    expect(
      find.text('- Extra monthly income: \u00A375.00'),
      findsOneWidget,
    );
    expect(
      find.text('- Extra debt payment: \u00A3150.00'),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear scenario'));
    await tester.pump();

    final incomeField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Extra monthly income'),
    );
    final expenseField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Monthly expense reduction'),
    );
    final extraPaymentField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Extra monthly payment'),
    );
    final startMonthField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Start after this many months'),
    );
    final durationField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Duration in months (optional)'),
    );

    expect(find.text('Scenario cleared.'), findsOneWidget);
    expect(repository.getScenarioChanges(), isEmpty);
    expect(incomeField.controller?.text, '0');
    expect(expenseField.controller?.text, '0');
    expect(extraPaymentField.controller?.text, '0');
    expect(startMonthField.controller?.text, '0');
    expect(durationField.controller?.text, '');
    expect(find.text('Clear scenario'), findsNothing);
    expect(find.text('Baseline plan'), findsOneWidget);
  });

  testWidgets(
    'ScenariosScreen allows a plan made affordable by scenario changes',
    (WidgetTester tester) async {
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
          id: 'loan-1',
          name: 'Loan',
          balance: 1200,
          apr: 9.5,
          minimumPayment: 100,
        ),
      );
      repository.saveIncomeSource(
        const IncomeSource(
          id: 'salary',
          name: 'Salary',
          annualGross: 4800,
          overrideMonthlyNet: 400,
        ),
      );
      repository.saveExpense(
        const Expense(
          id: 'bills',
          name: 'Bills',
          amount: 250,
        ),
      );
      await repository.waitForPendingWrites();

      await tester.pumpWidget(
        MaterialApp(
          home: ScenariosScreen(repository: repository),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Extra monthly income'),
        '75',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monthly expense reduction'),
        '25',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Extra monthly payment'),
        '100',
      );
      await tester.tap(find.text('Apply scenario'));
      await tester.pump();

      expect(find.text('Scenario updated.'), findsOneWidget);
      expect(
        find.text(
          'Extra payment exceeds available monthly cash after your scenario changes.',
        ),
        findsNothing,
      );
      expect(repository.getScenarioChanges(), hasLength(3));
    },
  );

  testWidgets('ScenariosScreen removes one active adjustment without clearing the rest', (
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
        balance: 1800,
        apr: 16.5,
        minimumPayment: 80,
      ),
    );
    repository.saveIncomeSource(
      const IncomeSource(
        id: 'salary',
        name: 'Salary',
        annualGross: 31200,
        overrideMonthlyNet: 2600,
      ),
    );
    repository.saveExpense(
      const Expense(
        id: 'rent',
        name: 'Rent',
        amount: 1400,
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
        home: ScenariosScreen(repository: repository),
      ),
    );

    expect(find.text('Remove income boost'), findsOneWidget);
    expect(find.text('Remove extra payment'), findsOneWidget);

    await tester.tap(find.text('Remove income boost'));
    await tester.pump();

    final incomeField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Extra monthly income'),
    );
    final extraPaymentField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Extra monthly payment'),
    );

    expect(find.text('Scenario adjustment removed.'), findsOneWidget);
    expect(repository.getScenarioChanges(), hasLength(1));
    expect(
      repository.getScenarioChanges().single.changeType,
      ChangeType.extraPayment,
    );
    expect(repository.getScenarioChanges().single.startMonth, 2);
    expect(repository.getScenarioChanges().single.durationInMonths, 6);
    expect(incomeField.controller?.text, '0');
    expect(extraPaymentField.controller?.text, '150');
    expect(find.text('Remove income boost'), findsNothing);
    expect(find.text('Remove extra payment'), findsOneWidget);
  });

  testWidgets('ScenariosScreen normalizes an inconsistent saved schedule', (
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
        balance: 1800,
        apr: 16.5,
        minimumPayment: 80,
      ),
    );
    repository.saveIncomeSource(
      const IncomeSource(
        id: 'salary',
        name: 'Salary',
        annualGross: 31200,
        overrideMonthlyNet: 2600,
      ),
    );
    repository.saveExpense(
      const Expense(
        id: 'rent',
        name: 'Rent',
        amount: 1400,
      ),
    );
    repository.saveScenarioChanges(
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
    await repository.waitForPendingWrites();

    await tester.pumpWidget(
      MaterialApp(
        home: ScenariosScreen(repository: repository),
      ),
    );

    expect(find.text('Normalize schedule'), findsOneWidget);
    expect(
      find.textContaining('different schedules'),
      findsOneWidget,
    );

    await tester.tap(find.text('Normalize schedule'));
    await tester.pump();

    expect(find.text('Scenario schedule normalized.'), findsOneWidget);
    expect(find.text('Normalize schedule'), findsNothing);
    expect(
      find.textContaining('different schedules'),
      findsNothing,
    );
    expect(repository.getScenarioChanges(), hasLength(2));
    expect(repository.getScenarioChanges().first.startMonth, 1);
    expect(repository.getScenarioChanges().first.durationInMonths, 2);
    expect(repository.getScenarioChanges().last.startMonth, 1);
    expect(repository.getScenarioChanges().last.durationInMonths, 2);
  });
}
