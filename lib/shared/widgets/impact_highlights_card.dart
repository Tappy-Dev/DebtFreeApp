import 'package:flutter/material.dart';

class ImpactHighlightsCard extends StatelessWidget {
  const ImpactHighlightsCard({
    super.key,
    required this.monthsSaved,
    required this.interestSaved,
    required this.monthlyFlexibilityGain,
  });

  final int monthsSaved;
  final double interestSaved;
  final double monthlyFlexibilityGain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.secondaryContainer.withOpacity(0.55),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Impact Highlights',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ImpactMetric(
                    label: 'Months Saved',
                    value: '$monthsSaved',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImpactMetric(
                    label: 'Interest Saved',
                    value: '\u00A3${interestSaved.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ImpactMetric(
              label: 'Monthly Flexibility Created',
              value: '\u00A3${monthlyFlexibilityGain.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactMetric extends StatelessWidget {
  const _ImpactMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
