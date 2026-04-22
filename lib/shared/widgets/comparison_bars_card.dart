import 'dart:math' as math;

import 'package:flutter/material.dart';

class ComparisonBarsCard extends StatelessWidget {
  const ComparisonBarsCard({
    super.key,
    required this.title,
    required this.baselineLabel,
    required this.baselineValue,
    required this.scenarioLabel,
    required this.scenarioValue,
    required this.valuePrefix,
  });

  final String title;
  final String baselineLabel;
  final num baselineValue;
  final String scenarioLabel;
  final num scenarioValue;
  final String valuePrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = math.max(
      math.max(baselineValue, scenarioValue),
      1,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _ComparisonBar(
              label: baselineLabel,
              value: baselineValue,
              maxValue: maxValue,
              valuePrefix: valuePrefix,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            _ComparisonBar(
              label: scenarioLabel,
              value: scenarioValue,
              maxValue: maxValue,
              valuePrefix: valuePrefix,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.valuePrefix,
    required this.color,
  });

  final String label;
  final num value;
  final num maxValue;
  final String valuePrefix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final widthFactor = (value.toDouble() / maxValue.toDouble()).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$label: $valuePrefix${value.toStringAsFixed(2)}'),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: widthFactor,
            minHeight: 12,
            backgroundColor: color.withOpacity(0.16),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
