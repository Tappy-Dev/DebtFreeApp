import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/utils/financial_month.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FinanceSettingsScreen extends StatefulWidget {
  const FinanceSettingsScreen({super.key});

  @override
  State<FinanceSettingsScreen> createState() => _FinanceSettingsScreenState();
}

class _FinanceSettingsScreenState extends State<FinanceSettingsScreen> {
  final _repository = SessionFinancialRepository.instance;

  Future<void> _pickStartMonth() async {
    final now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            const months = [
              'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December',
            ];
            return AlertDialog(
              title: const Text('Set Budget Start Month'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose the earliest month that should appear in Tracking.',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: selectedMonth,
                          items: List.generate(
                            12,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text(months[i]),
                            ),
                          ),
                          onChanged: (v) =>
                              setDialogState(() => selectedMonth = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: selectedYear,
                          items: List.generate(
                            now.year - (now.year - 5) + 1,
                            (i) => DropdownMenuItem(
                              value: now.year - 5 + i,
                              child: Text('${now.year - 5 + i}'),
                            ),
                          ),
                          onChanged: (v) =>
                              setDialogState(() => selectedYear = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, DateTime(selectedYear, selectedMonth)),
                  child: const Text('Set'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    final monthKey =
        '${result.year}-${result.month.toString().padLeft(2, '0')}';
    await _repository.setAppStartMonth(monthKey);
    if (mounted) setState(() {});
  }

  Future<void> _pickFinancialMonthStartDay(int currentDay) async {
    int selected = currentDay;
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Financial Month Start Day'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose the day of the month your financial cycle begins '
                    '(e.g. your pay day).',
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Day of Month',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: selected,
                    items: List.generate(
                      28,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_ordinal(i + 1)),
                      ),
                    ),
                    onChanged: (v) => setDialogState(() => selected = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text('Set'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    await _repository.setFinancialMonthStartDay(result);
    if (mounted) setState(() {});
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Finance Settings')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _repository,
          builder: (context, _) {
            final startMonth = _repository.appStartMonth;
            final startDay = _repository.financialMonthStartDay;
            final (year, month) =
                FinancialMonth.parseKey(_repository.activeBudgetMonth);
            final periodLabel =
                FinancialMonth.periodLabel(year, month, startDay);

            String startMonthLabel;
            if (startMonth == null || startMonth.isEmpty) {
              startMonthLabel = 'Not set (no limit)';
            } else {
              final parts = startMonth.split('-');
              if (parts.length >= 2) {
                final y = int.tryParse(parts[0]) ?? 0;
                final m = int.tryParse(parts[1]) ?? 0;
                startMonthLabel = DateFormat.yMMMM().format(DateTime(y, m));
              } else {
                startMonthLabel = startMonth;
              }
            }

            final startDayLabel = startDay == 1
                ? '1st (calendar month)'
                : '${_ordinal(startDay)} of each month';

            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      'These settings control how months are defined across the app. '
                      'They affect Tracking navigation limits, period boundaries, '
                      'budget summaries, and setup guidance on the dashboard.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                // ── Budget Start Month ──
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  title: const Text('Budget Start Month'),
                  subtitle: Text(startMonthLabel),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (startMonth != null && startMonth.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            await _repository.setAppStartMonth('');
                          },
                          child: Text(
                            'Clear',
                            style:
                                TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: _pickStartMonth,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Defines the earliest month available in Tracking. '
                    'Use this to prevent scrolling into older empty months that are '
                    'not relevant to your real budgeting timeline. '
                    'This does not change existing debt balances or payment calculations.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
                const Divider(height: 24, indent: 20, endIndent: 20),
                // ── Financial Month Start Day ──
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  title: const Text('Financial Month Start Day'),
                  subtitle: Text(startDayLabel),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (startDay > 1)
                        TextButton(
                          onPressed: () async {
                            await _repository.setFinancialMonthStartDay(1);
                          },
                          child: Text(
                            'Reset',
                            style:
                                TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _pickFinancialMonthStartDay(startDay),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    startDay > 1
                        ? 'Your active period is currently: $periodLabel. '
                            'Changing this day shifts month boundaries used by '
                            'Tracking, monthly summaries, and budget period grouping. '
                            'For example, day 25 means each period runs from the 25th '
                            'to the 24th of the next month.'
                        : 'Using day 1 means standard calendar months. '
                            'If your income arrives later in the month, choose that day '
                            'to align cashflow, spending analysis, and period summaries '
                            'with your real pay cycle.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}
