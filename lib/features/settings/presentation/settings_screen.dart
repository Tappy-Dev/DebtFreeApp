import 'dart:convert';

import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/services/subscription_service.dart';
import 'package:debt_free_app/core/utils/financial_month.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
            final months = [
              'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December',
            ];
            return AlertDialog(
              title: const Text('Set Budget Start Month'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Choose the earliest month that should appear in Tracking.'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedMonth,
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
                          value: selectedYear,
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
                  onPressed: () => Navigator.pop(
                    context,
                    DateTime(selectedYear, selectedMonth),
                  ),
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Budget start month set to ${DateFormat.yMMMM().format(result)}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
                    value: selected,
                    items: List.generate(
                      28,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${_ordinal(i + 1)}'),
                      ),
                    ),
                    onChanged: (v) =>
                        setDialogState(() => selected = v!),
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == 1
                ? 'Financial month reset to calendar month'
                : 'Financial month starts on the ${_ordinal(result)}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'App Info',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text('Debt Free v1.0.0'),
                    const SizedBox(height: 8),
                    const Text(
                      'Budget tracking, debt repayment strategies, mortgage overpayment analysis, salary sacrifice modelling, what-if scenario planning, and AI-powered financial advice — all in one place.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Subscription ──
            ListenableBuilder(
              listenable: SubscriptionService.instance,
              builder: (context, _) {
                final sub = SubscriptionService.instance;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 22,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Subscription',
                              style: theme.textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (sub.isSubscribed)
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 8),
                              const Text('Premium — Active'),
                            ],
                          )
                        else if (sub.isTrialActive) ...[
                          Row(
                            children: [
                              Icon(Icons.timer_outlined,
                                  color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Free Trial — ${sub.trialDaysRemaining} day${sub.trialDaysRemaining == 1 ? '' : 's'} remaining',
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: theme.colorScheme.error, size: 20),
                              const SizedBox(width: 8),
                              const Text('Trial expired'),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (!sub.isSubscribed)
                              FilledButton.icon(
                                onPressed: sub.isStoreAvailable
                                    ? () => sub.purchase()
                                    : null,
                                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                                label: Text(
                                  'From ${sub.monthlyProduct?.price ?? '£3.99'}/month',
                                ),
                              ),
                            if (!sub.isSubscribed)
                              const SizedBox(width: 8),
                            TextButton(
                              onPressed: sub.isStoreAvailable
                                  ? () => sub.restorePurchases()
                                  : null,
                              child: const Text('Restore Purchases'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showBugReport(context),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.bug_report_outlined,
                          size: 20,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submit a Bug',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Report an issue or something that doesn\'t look right',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Developer Mode ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ListenableBuilder(
                  listenable: _repository,
                  builder: (context, _) {
                    final enabled = _repository.developerModeEnabled;
                    final offset = _repository.developerMonthOffset;
                    final previewDate = _repository.effectiveNow;
                    final previewMonthLabel = DateFormat.yMMMM().format(previewDate);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: [
                            Text(
                              'Developer Mode',
                              style: theme.textTheme.titleLarge,
                            ),
                            const Spacer(),
                            Switch.adaptive(
                              value: enabled,
                              onChanged: (value) async {
                                await _repository.setDeveloperModeEnabled(value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Preview app logic as time moves forward/backward '
                          'without changing your device date.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (enabled) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Month offset: ${offset >= 0 ? '+' : ''}$offset',
                            style: theme.textTheme.titleSmall,
                          ),
                          Slider(
                            value: offset.toDouble(),
                            min: -12,
                            max: 24,
                            divisions: 36,
                            label: '${offset >= 0 ? '+' : ''}$offset months',
                            onChanged: (value) async {
                              await _repository
                                  .setDeveloperMonthOffset(value.round());
                            },
                          ),
                          Text(
                            'Preview date: ${DateFormat.yMMMd().format(previewDate)} '
                            '($previewMonthLabel)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () async {
                                await _repository.setDeveloperMonthOffset(0);
                              },
                              child: const Text('Reset Offset'),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Budget Start Month',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sets how far back you can navigate in the Tracking screen. '
                      'Use this to prevent accidental creation of empty months before your app start date.',
                    ),
                    const SizedBox(height: 12),
                    ListenableBuilder(
                      listenable: _repository,
                      builder: (context, _) {
                        final startMonth = _repository.appStartMonth;
                        String label;
                        if (startMonth == null) {
                          label = 'Not set (no limit)';
                        } else {
                          final parts = startMonth.split('-');
                          if (parts.length >= 2) {
                            final y = int.tryParse(parts[0]) ?? 0;
                            final m = int.tryParse(parts[1]) ?? 0;
                            label = DateFormat.yMMMM()
                                .format(DateTime(y, m));
                          } else {
                            label = startMonth;
                          }
                        }
                        return Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _pickStartMonth,
                              child: Text(
                                startMonth == null ? 'Set' : 'Change',
                              ),
                            ),
                            if (startMonth != null)
                              TextButton(
                                onPressed: () async {
                                  await _repository.setAppStartMonth('');
                                },
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                      color: theme.colorScheme.error),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Financial Month Start Day ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Financial Month Start Day',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set the day your financial month begins (e.g. your pay day). '
                      'All budget periods and summaries will use this as the month boundary.',
                    ),
                    const SizedBox(height: 12),
                    ListenableBuilder(
                      listenable: _repository,
                      builder: (context, _) {
                        final startDay = _repository.financialMonthStartDay;
                        final (year, month) = FinancialMonth.parseKey(
                            _repository.activeBudgetMonth);
                        final periodLabel = FinancialMonth.periodLabel(
                            year, month, startDay);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    startDay == 1
                                        ? '1st (calendar month)'
                                        : '${_ordinal(startDay)} of each month',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _pickFinancialMonthStartDay(startDay),
                                  child: Text(
                                    startDay == 1 ? 'Set' : 'Change',
                                  ),
                                ),
                                if (startDay > 1)
                                  TextButton(
                                    onPressed: () async {
                                      await _repository.setFinancialMonthStartDay(1);
                                    },
                                    child: Text(
                                      'Reset',
                                      style: TextStyle(
                                          color: theme.colorScheme.error),
                                    ),
                                  ),
                              ],
                            ),
                            if (startDay > 1) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Current period: $periodLabel',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Data & Privacy',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'All your financial data is stored locally on this device. '
                      'When AI Insights is used, a summary of your financial '
                      'data is sent to Google Gemini via Firebase to generate advice. '
                      'No data is shared otherwise.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _confirmResetApp(context),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.restart_alt_rounded,
                          size: 20,
                          color: theme.colorScheme.onError,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reset App',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Erase all data and return to factory state',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBugReport(BuildContext context) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final theme = Theme.of(context);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.bug_report_outlined,
                size: 22, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Text('Submit a Bug'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                  hintText: 'e.g. Budget totals wrong after copy',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  hintText:
                      'Describe the steps to reproduce, what you expected, '
                      'and what actually happened.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx, {
                'title': title,
                'description': descController.text.trim(),
              });
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      final response = await http.post(
        Uri.parse('https://formspree.io/f/xnjlvrjq'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          '_subject': 'Bug Report: ${result['title']}',
          'summary': result['title'],
          'description': result['description']!.isEmpty
              ? '(none)'
              : result['description'],
          'app_version': 'Debt Free v1.0.0',
          'platform': 'Windows',
          'date': DateFormat.yMMMd().format(DateTime.now()),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bug report submitted — thank you!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit (${response.statusCode}). Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect. Check your internet and try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmResetApp(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            size: 40, color: theme.colorScheme.error),
        title: const Text('Reset App?'),
        content: const Text(
          'This will permanently delete all your data — budgets, debts, '
          'mortgage, tracking history, planner events, and settings.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _repository.resetAll();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App has been reset to factory state.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
