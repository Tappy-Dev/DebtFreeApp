import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/features/budget/presentation/budget_screen.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BudgetScreen shows empty-state cards for income and expenses', (
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
        home: BudgetScreen(repository: repository),
      ),
    );

    expect(find.text('No income sources yet'), findsOneWidget);
    expect(
      find.text('Add income so the app can calculate available cash.'),
      findsOneWidget,
    );
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(
      find.text('Add your monthly expenses to improve the projection.'),
      findsOneWidget,
    );
  });

  testWidgets('BudgetScreen confirms income deletion and shows feedback', (
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
    repository.saveIncomeSource(
      const IncomeSource(
        id: 'salary',
        name: 'Salary',
        annualGross: 38400,
        overrideMonthlyNet: 3200,
      ),
    );
    await repository.waitForPendingWrites();

    await tester.pumpWidget(
      MaterialApp(
        home: BudgetScreen(repository: repository),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Delete income?'), findsOneWidget);
    expect(find.text('Remove "Salary" from this budget?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Income removed.'), findsOneWidget);
    expect(repository.getIncomeSources(), isEmpty);
    expect(find.text('No income sources yet'), findsOneWidget);
  });
}
