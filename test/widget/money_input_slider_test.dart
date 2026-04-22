import 'package:debt_free_app/shared/widgets/money_input_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MoneyInputSlider displays label and current value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoneyInputSlider(
            label: 'Extra payment',
            value: 100,
            min: 0,
            max: 500,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Extra payment'), findsOneWidget);
    expect(find.text('\u00A3100'), findsOneWidget);
    expect(find.text('\u00A30'), findsOneWidget);
    expect(find.text('\u00A3500'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
}
