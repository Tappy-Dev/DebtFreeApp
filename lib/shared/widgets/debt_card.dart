import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DebtCard extends StatelessWidget {
  DebtCard({
    super.key,
    required this.title,
    required this.balance,
    required this.apr,
    required this.payment,
  });

  final String title;
  final double balance;
  final double apr;
  final double payment;

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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${apr.toStringAsFixed(1)}% APR',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _currency.format(balance),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                color: scheme.onSurface,
              ),
            ),
            Text('Outstanding balance', style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined,
                      size: 16, color: scheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'Min payment: ${_currency.format(payment)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
