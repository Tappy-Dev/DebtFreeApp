import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimelineChart extends StatelessWidget {
  const TimelineChart({
    super.key,
    required this.dataPoints,
    this.height = 220,
  });

  final List<TimelineDataPoint> dataPoints;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No projection data available.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currency = NumberFormat.compact(locale: 'en_GB');
    const accent = Color(0xFF6F7CFF);

    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i].value));
    }

    final maxY = dataPoints.fold<double>(
      0,
      (double max, TimelineDataPoint point) =>
          point.value > max ? point.value : max,
    );

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (double value) {
              return FlLine(
                color: colorScheme.outline.withValues(alpha: 0.25),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: maxY > 0 ? maxY / 4 : 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    '\u00A3${currency.format(value)}',
                    style: theme.textTheme.bodySmall,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _bottomInterval(),
                getTitlesWidget: (double value, TitleMeta meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= dataPoints.length) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      dataPoints[index].label,
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              gradient: const LinearGradient(
                colors: [Color(0xFF29C6FF), accent],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: 0.35),
                    accent.withValues(alpha: 0.03),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (LineBarSpot touchedSpot) => colorScheme.surface,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot spot) {
                  return LineTooltipItem(
                    '\u00A3${spot.y.toStringAsFixed(0)}',
                    TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  double _bottomInterval() {
    if (dataPoints.length <= 6) {
      return 1;
    }

    if (dataPoints.length <= 12) {
      return 2;
    }

    if (dataPoints.length <= 24) {
      return 3;
    }

    return (dataPoints.length / 6).ceilToDouble();
  }
}

class TimelineDataPoint {
  const TimelineDataPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}
