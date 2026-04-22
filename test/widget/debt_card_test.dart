import 'package:debt_free_app/shared/widgets/debt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DebtCard displays correct information', (
    WidgetTester tester,
  ) async {
    final testDebt = DebtCard(
      title: 'Credit Card',
      balance: 5000.0,
      apr: 15.0,
      payment: 200.0,
      payoffDate: '2025-12-31',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: testDebt),
      ),
    );

    expect(find.text('Credit Card'), findsOneWidget);
    expect(find.text('Balance: \u00A35,000.00'), findsOneWidget);
    expect(find.text('APR: 15.0%'), findsOneWidget);
    expect(find.text('Payment: \u00A3200.00'), findsOneWidget);
    expect(find.text('Payoff Date: 2025-12-31'), findsOneWidget);
  });
}
