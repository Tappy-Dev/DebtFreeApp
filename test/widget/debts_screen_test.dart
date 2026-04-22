import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/features/debts/presentation/debts_screen.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DebtsScreen shows an empty-state card with no debts', (
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
        home: DebtsScreen(repository: repository),
      ),
    );

    expect(find.text('No debts yet'), findsOneWidget);
    expect(
      find.text('Add your first debt to start building a payoff plan.'),
      findsOneWidget,
    );
  });

  testWidgets('DebtsScreen confirms deletion and shows removal feedback', (
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
        balance: 1500,
        apr: 18.9,
        minimumPayment: 75,
      ),
    );
    await repository.waitForPendingWrites();

    await tester.pumpWidget(
      MaterialApp(
        home: DebtsScreen(repository: repository),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Delete').first);
    await tester.pumpAndSettle();

    expect(find.text('Delete debt?'), findsOneWidget);
    expect(find.text('Remove "Credit Card" from this plan?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Debt removed.'), findsOneWidget);
    expect(repository.getDebts(), isEmpty);
    expect(find.text('No debts yet'), findsOneWidget);
  });
}
