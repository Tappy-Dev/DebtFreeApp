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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Debt Snapshot',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Total Debt: ${_currency.format(totalDebt)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Debt-Free Date: $debtFreeDate',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Interest Projection: ${_currency.format(interestProjection)}',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
