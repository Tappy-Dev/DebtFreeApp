import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryCard extends StatelessWidget {
  SummaryCard({
    super.key,
    required this.totalDebt,
    required this.debtFreeDate,
    required this.interestProjection,
  });

  final double totalDebt;
  final String debtFreeDate;
  final double interestProjection;

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_GB',
    symbol: '\u00A3',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'OVERVIEW',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Debt Snapshot',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              _currency.format(totalDebt),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 30,
                color: scheme.onSurface,
              ),
            ),
            Text('Total debt', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    label: 'Debt-Free Date',
                    value: debtFreeDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniMetric(
                    label: 'Projected Interest',
                    value: _currency.format(interestProjection),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
