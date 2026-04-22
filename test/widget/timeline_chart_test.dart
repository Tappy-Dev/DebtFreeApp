import 'package:debt_free_app/shared/widgets/timeline_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TimelineChart renders with data points', (
    WidgetTester tester,
  ) async {
    final dataPoints = <TimelineDataPoint>[
      const TimelineDataPoint(label: 'Jan', value: 5000),
      const TimelineDataPoint(label: 'Feb', value: 4500),
      const TimelineDataPoint(label: 'Mar', value: 4000),
      const TimelineDataPoint(label: 'Apr', value: 3400),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineChart(dataPoints: dataPoints),
        ),
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('TimelineChart shows empty message with no data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineChart(dataPoints: const <TimelineDataPoint>[]),
        ),
      ),
    );

    expect(find.text('No projection data available.'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });
}
