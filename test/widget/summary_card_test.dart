import 'package:debt_free_app/shared/widgets/summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SummaryCard displays correct financial information', (
    WidgetTester tester,
  ) async {
    const totalDebt = 10000.0;
    const debtFreeDate = '2025-12-31';
    const interestProjection = 1500.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryCard(
            totalDebt: totalDebt,
            debtFreeDate: debtFreeDate,
            interestProjection: interestProjection,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Total Debt: \u00A310,000.00'), findsOneWidget);
    expect(find.text('Debt-Free Date: $debtFreeDate'), findsOneWidget);
    expect(find.text('Interest Projection: \u00A31,500.00'), findsOneWidget);
  });
}
