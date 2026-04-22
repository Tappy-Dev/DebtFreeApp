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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('Balance: ${_currency.format(balance)}'),
            Text('APR: ${apr.toStringAsFixed(1)}%'),
            Text('Payment: ${_currency.format(payment)}'),
          ],
        ),
      ),
    );
  }
}
