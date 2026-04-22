import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PreviewMonthBadge extends StatelessWidget {
  const PreviewMonthBadge({
    super.key,
    required this.referenceDate,
    required this.monthOffset,
  });

  final DateTime referenceDate;
  final int monthOffset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = DateFormat('MMM yyyy').format(referenceDate);
    final delta = monthOffset > 0
        ? '+${monthOffset}m'
        : monthOffset < 0
            ? '${monthOffset}m'
            : 'Now';

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 14,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($delta)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
