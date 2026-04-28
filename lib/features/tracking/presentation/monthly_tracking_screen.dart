import 'dart:math' as math;

import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/core/utils/amount_parser.dart';
import 'package:debt_free_app/core/utils/financial_month.dart';
import 'package:debt_free_app/features/tracking/domain/build_monthly_budget_summary.dart';
import 'package:debt_free_app/features/tracking/domain/find_overdue_open_budget_period.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual_entry.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';
import 'package:debt_free_app/features/tracking/models/monthly_budget_summary.dart';
import 'package:debt_free_app/features/tracking/models/tracking_workflow_status.dart';
import 'package:debt_free_app/shared/widgets/app_shell_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthlyTrackingScreen extends StatefulWidget {
  const MonthlyTrackingScreen({
    super.key,
    this.initialMonthKey,
  });

  final String? initialMonthKey;

  @override
  State<MonthlyTrackingScreen> createState() => _MonthlyTrackingScreenState();
}

class _MonthlyTrackingScreenState extends State<MonthlyTrackingScreen> {
  late int _year;
  late int _month;
  MonthlyBudgetSummary? _summary;
  bool _loading = true;
  bool _extraIncomeExpanded = false;
  final _expandedTrackableIds = <String>{};
  // Tracks the effective "current month" at last sync – used to detect when
  // developer-mode offset changes so the screen auto-navigates to the new month.
  late String _effectiveCurrentMonthKey;

  final _currency = NumberFormat.currency(
    locale: 'en_GB',
    symbol: '£',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    final repo = SessionFinancialRepository.instance;
    final monthKey = widget.initialMonthKey ?? repo.currentMonthKeyWithStartDay();
    final (y, m) = FinancialMonth.parseKey(monthKey);
    _year = y;
    _month = m;
    _effectiveCurrentMonthKey = repo.currentMonthKeyWithStartDay();
    // If a start month is set and current month is before it, jump to start
    final startMonth = repo.appStartMonth;
    if (startMonth != null && startMonth.isNotEmpty) {
      final currentKey =
          '${_year}-${_month.toString().padLeft(2, '0')}';
      if (currentKey.compareTo(startMonth) < 0) {
        final parts = startMonth.split('-');
        _year = int.parse(parts[0]);
        _month = int.parse(parts[1]);
      }
    }
    _loadMonth();
    repo.addListener(_onRepositoryChange);
  }

  @override
  void dispose() {
    SessionFinancialRepository.instance.removeListener(_onRepositoryChange);
    super.dispose();
  }

  void _onRepositoryChange() {
    final repo = SessionFinancialRepository.instance;
    final newMonthKey = repo.currentMonthKeyWithStartDay();
    if (newMonthKey == _effectiveCurrentMonthKey) return;
    // Effective current month changed (developer mode offset changed).
    // Only auto-jump if the user is still viewing the old effective current month
    // (i.e. they haven't manually browsed to a different period).
    final oldKey = _effectiveCurrentMonthKey;
    _effectiveCurrentMonthKey = newMonthKey;
    final currentViewKey =
        '${_year}-${_month.toString().padLeft(2, '0')}';
    if (currentViewKey == oldKey) {
      final (y, m) = FinancialMonth.parseKey(newMonthKey);
      setState(() {
        _year = y;
        _month = m;
      });
      _loadMonth();
    }
  }

  Future<void> _loadMonth() async {
    // Only show the full loading spinner on first load. For refreshes (when
    // content is already on screen) we silently update to avoid tearing down
    // InheritedWidget dependents mid-frame after a dialog dismiss.
    final isFirstLoad = _summary == null;
    if (isFirstLoad) {
      setState(() => _loading = true);
    }
    final builder = BuildMonthlyBudgetSummary(
      SessionFinancialRepository.instance,
    );
    final summary = await builder(year: _year, month: _month);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  /// Defers [_loadMonth] to the next frame. Use this after any dialog dismiss
  /// to avoid calling setState while the Navigator is still processing the pop.
  void _scheduleReload() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMonth();
    });
  }

  void _previousMonth() {
    if (!_canGoBack) return;
    setState(() {
      _summary = null;
      _month--;
      if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
    _loadMonth();
  }

  bool get _canGoBack {
    final startMonth =
        SessionFinancialRepository.instance.appStartMonth;
    if (startMonth == null || startMonth.isEmpty) return true;
    // Compute what the previous month key would be
    var prevYear = _year;
    var prevMonth = _month - 1;
    if (prevMonth < 1) { prevMonth = 12; prevYear--; }
    final prevKey = '$prevYear-${prevMonth.toString().padLeft(2, '0')}';
    return prevKey.compareTo(startMonth) >= 0;
  }

  void _nextMonth() {
    setState(() {
      _summary = null;
      _month++;
      if (_month > 12) {
        _month = 1;
        _year++;
      }
    });
    _loadMonth();
  }

  void _jumpToMonth(int year, int month) {
    setState(() {
      _summary = null;
      _year = year;
      _month = month;
    });
    _loadMonth();
  }

  String _periodLabel() {
    final startDay =
        SessionFinancialRepository.instance.financialMonthStartDay;
    if (startDay > 1) {
      return FinancialMonth.periodLabel(_year, _month, startDay);
    }
    return DateFormat.yMMMM().format(DateTime(_year, _month));
  }

  Future<void> _closeMonth() async {
    final summary = _summary;
    if (summary == null) return;

    final repo = SessionFinancialRepository.instance;
    final overdueOpen = await findOldestOverdueOpenPeriod(
      repository: repo,
      now: repo.effectiveNow,
      financialMonthStartDay: repo.financialMonthStartDay,
      excludePeriodId: summary.period.id,
    );
    if (!mounted) return;
    if (overdueOpen != null) {
      final overdueLabel = FinancialMonth.periodLabel(
        overdueOpen.year,
        overdueOpen.month,
        repo.financialMonthStartDay,
      );
      final action = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Close Older Month First'),
          content: Text(
            '$overdueLabel is still open and has already ended. '
            'Close that month first before finalizing newer months.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open overdue month'),
            ),
          ],
        ),
      );
      if (action == true) {
        _jumpToMonth(overdueOpen.year, overdueOpen.month);
      }
      return;
    }

    // ── Step 1: confirm close ──
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Month'),
        content: Text(
          'Close ${_periodLabel()}? '
          'This locks all actuals for this period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close Month'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // ── Step 2: trackable underspend prompt ──
    double trackableCarry = 0;
    if (summary.hasTrackableUnderspend) {
      final underspend = summary.trackableUnderspend;
      final carry = await showDialog<bool>(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: const Text('Trackable Expenses Under Budget'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your trackable expenses came in ${_currency.format(underspend)} under budget this month.',
                ),
                const SizedBox(height: 12),
                _buildCarryBreakdownRows(summary, theme),
                const SizedBox(height: 16),
                const Text(
                  'Would you like to carry this saving forward into next month\'s balance?',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No, discard'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, carry forward'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      if (carry == true) {
        trackableCarry = underspend;
      }
    }

    // ── Step 3: overall remaining prompt ──
    double overallCarry = 0;
    final remainingAfterTrackable =
        summary.overallActualRemaining + trackableCarry;
    if (remainingAfterTrackable > 0) {
      final choice = await showDialog<_SurplusChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Positive Balance Remaining'),
          content: Text(
            'After all income, bills, expenses and debt payments, '
            'you have ${_currency.format(remainingAfterTrackable)} left over this month.\n\n'
            'What would you like to do with it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _SurplusChoice.discard),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _SurplusChoice.addToSavings),
              child: const Text('Add to savings'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _SurplusChoice.carryForward),
              child: const Text('Carry forward'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == _SurplusChoice.carryForward) {
        overallCarry = remainingAfterTrackable;
      } else if (choice == _SurplusChoice.addToSavings) {
        await _addSurplusToSavings(remainingAfterTrackable, summary.period.month, summary.period.year);
        if (!mounted) return;
      }
    }

    // ── Close the period, storing the total carry-forward ──
    final totalCarry = trackableCarry + overallCarry;
    final closedPeriod = summary.period.copyWith(
      status: BudgetPeriodStatus.closed,
      closedAt: DateTime.now(),
      carriedForwardBalance: totalCarry,
    );
    await SessionFinancialRepository.instance.saveBudgetPeriod(closedPeriod);

    // If there's a carry-forward, immediately create/update next month's
    // period so the balance is visible right away.
    if (totalCarry > 0) {
      var nextMonth = summary.period.month + 1;
      var nextYear = summary.period.year;
      if (nextMonth > 12) { nextMonth = 1; nextYear++; }
      final nextPeriodId = BudgetPeriod.buildId(nextYear, nextMonth);
      final nextPeriod = await SessionFinancialRepository.instance
          .getBudgetPeriod(nextPeriodId);
      if (nextPeriod != null) {
        await SessionFinancialRepository.instance.saveBudgetPeriod(
          nextPeriod.copyWith(carriedForwardBalance: totalCarry),
        );
      }
      // If next period doesn't exist yet it will pick up the carry when first opened
      // via BuildMonthlyBudgetSummary.
    }

    _scheduleReload();
  }

  /// Build a small breakdown of which trackable items are under budget.
  Widget _buildCarryBreakdownRows(
      MonthlyBudgetSummary summary, ThemeData theme) {
    final underItems = summary.trackableExpenseActuals
        .where((a) => a.budgeted > a.actual)
        .toList();
    if (underItems.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: underItems.map((a) {
        final saving = a.budgeted - a.actual;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(a.categoryName,
                    style: theme.textTheme.bodySmall),
              ),
              Text(
                '+${_currency.format(saving)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.green),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _addSurplusToSavings(
      double amount, int month, int year) async {
    final repo = SessionFinancialRepository.instance;
    // Build next month's key for the savings entry
    var nextMonth = month + 1;
    var nextYear = year;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }
    final monthKey = '$nextYear-${nextMonth.toString().padLeft(2, '0')}';
    final id = '$monthKey-expense-monthly-surplus-${DateTime.now().millisecondsSinceEpoch}';
    final expense = Expense(
      id: id,
      name: 'Monthly surplus',
      amount: amount,
      monthKey: monthKey,
      category: ExpenseCategory.savings,
      trackable: true,
    );
    repo.saveExpense(expense);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_currency.format(amount)} added to savings for next month.',
        ),
      ),
    );
  }

  Future<void> _reopenMonth() async {
    final summary = _summary;
    if (summary == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-open Month'),
        content: Text(
          'Re-open ${_periodLabel()}? '
          'This will allow editing actuals again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Re-open'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final reopenedPeriod = summary.period.copyWith(
      status: BudgetPeriodStatus.open,
      clearClosedAt: true,
    );
    await SessionFinancialRepository.instance.saveBudgetPeriod(reopenedPeriod);
    _scheduleReload();
  }

  Future<void> _editActual(BudgetActual actual) async {
    if (_summary?.period.isClosed == true) return;

    final controller = TextEditingController(
      text: actual.actual > 0 ? actual.actual.toStringAsFixed(2) : '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(actual.categoryName),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Actual amount',
            helperText: 'Budgeted: ${_currency.format(actual.budgeted)}',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = AmountParser.tryParse(controller.text) ?? 0.0;
              Navigator.pop(context, math.max(0.0, value));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null || !mounted) return;

    final updated = actual.copyWith(actual: result);
    await SessionFinancialRepository.instance.saveBudgetActual(updated);
    _scheduleReload();
  }

  Future<void> _addTrackedIncome(MonthlyBudgetSummary summary) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Extra Income'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Description (e.g. Bonus, Overtime)',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '£',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount = AmountParser.tryParse(amountController.text);
              if (name.isEmpty || amount == null || amount <= 0) return;
              Navigator.pop(context, {'name': name, 'amount': amount});
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    nameController.dispose();
    amountController.dispose();

    if (result == null || !mounted) return;

    final name = result['name'] as String;
    final amount = result['amount'] as double;
    final periodId = summary.period.id;

    final incomeId =
        'tracked-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch}';

    final newActual = BudgetActual(
      id: BudgetActual.buildId(periodId, incomeId),
      periodId: periodId,
      categoryId: incomeId,
      categoryName: name,
      categoryType: ActualCategoryType.income,
      budgeted: 0,
      actual: amount,
    );

    await SessionFinancialRepository.instance.saveBudgetActual(newActual);
    _scheduleReload();
  }

  Future<void> _addTrackedExpense(MonthlyBudgetSummary summary) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Expense name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '£',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount = AmountParser.tryParse(amountController.text);
              if (name.isEmpty || amount == null || amount <= 0) return;
              Navigator.pop(context, {'name': name, 'amount': amount});
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    nameController.dispose();
    amountController.dispose();

    if (result == null || !mounted) return;

    final name = result['name'] as String;
    final amount = result['amount'] as double;
    final periodId = summary.period.id;

    // Create a unique ID for this ad-hoc expense
    final expenseId =
        'tracked-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch}';

    final newActual = BudgetActual(
      id: BudgetActual.buildId(periodId, expenseId),
      periodId: periodId,
      categoryId: expenseId,
      categoryName: name,
      categoryType: ActualCategoryType.expense,
      budgeted: 0,
      actual: amount,
    );

    await SessionFinancialRepository.instance.saveBudgetActual(newActual);
    _scheduleReload();
  }

  Future<void> _addEntryToTrackable(BudgetActual actual) async {
    final refController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Add to ${actual.categoryName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: refController,
                  decoration: const InputDecoration(
                    labelText: 'Reference (e.g. Asda, Amazon)',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(selectedDate.year - 1),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(DateFormat.yMMMd().format(selectedDate)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '£',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final ref = refController.text.trim();
                  final amount = AmountParser.tryParse(amountController.text);
                  if (ref.isEmpty || amount == null || amount <= 0) return;
                  Navigator.pop(context,
                      {'reference': ref, 'date': selectedDate, 'amount': amount});
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );

    refController.dispose();
    amountController.dispose();

    if (result == null || !mounted) return;

    final repo = SessionFinancialRepository.instance;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final entry = BudgetActualEntry(
      id: BudgetActualEntry.buildId(actual.id, ts),
      actualId: actual.id,
      reference: result['reference'] as String,
      date: result['date'] as DateTime,
      amount: result['amount'] as double,
    );
    await repo.saveBudgetActualEntry(entry);

    // Re-load to get updated entries, then sync actual total
    final allEntries = await repo.getBudgetActualEntries(actual.periodId);
    final sum = allEntries
        .where((e) => e.actualId == actual.id)
        .fold(0.0, (s, e) => s + e.amount);
    await repo.saveBudgetActual(actual.copyWith(actual: sum));
    _scheduleReload();
  }

  Future<void> _deleteEntry(
      BudgetActual actual, BudgetActualEntry entry) async {
    final repo = SessionFinancialRepository.instance;
    await repo.deleteBudgetActualEntry(entry.id);

    final allEntries = await repo.getBudgetActualEntries(actual.periodId);
    final sum = allEntries
        .where((e) => e.actualId == actual.id)
        .fold(0.0, (s, e) => s + e.amount);
    await repo.saveBudgetActual(actual.copyWith(actual: sum));
    _scheduleReload();
  }

  Future<void> _deleteActual(BudgetActual actual) async {
    await SessionFinancialRepository.instance.deleteBudgetActual(actual.id);
    _scheduleReload();
  }

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      title: 'Monthly Tracking',
      currentIndex: 3,
      body: Column(
        children: [
          _buildMonthPicker(),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_summary != null)
            Expanded(child: _buildContent(_summary!)),
        ],
      ),
    );
  }

  Widget _buildMonthPicker() {
    final label = _periodLabel();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _canGoBack ? _previousMonth : null,
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(MonthlyBudgetSummary summary) {
    final theme = Theme.of(context);
    final repo = SessionFinancialRepository.instance;
    final currentKey = repo.currentMonthKeyWithStartDay();
    final viewKey = BudgetPeriod.buildId(summary.period.year, summary.period.month);
    final workflowStatus = buildTrackingWorkflowStatus(
      summary: summary,
      now: repo.effectiveNow,
      financialMonthStartDay: repo.financialMonthStartDay,
      isCurrentPeriod: viewKey == currentKey,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (workflowStatus.isActionable) ...[
          _buildWorkflowBanner(workflowStatus),
          const SizedBox(height: 12),
        ],
        // ── Carried Forward Balance ──
        if (summary.period.carriedForwardBalance > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined, size: 18, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Balance carried forward from last month',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ),
                Text(
                  '+${_currency.format(summary.period.carriedForwardBalance)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // ── Extra Income ──
        _buildCollapsibleCard(
          icon: Icons.arrow_downward_rounded,
          iconColor: Colors.green,
          title: 'Extra Income',
          subtitle: 'Non-taxed money received outside your regular salary — e.g. selling items, cash gifts, cashback, or one-off windfalls.',
          actual: summary.totalActualIncome,
          budgeted: summary.totalBudgetedIncome,
          expanded: _extraIncomeExpanded,
          onTap: () => setState(() => _extraIncomeExpanded = !_extraIncomeExpanded),
          children: [
            ...summary.incomeActuals.map((a) => _buildActualRow(a)),
            if (summary.period.isOpen)
              _buildAddButton('Add income', () => _addTrackedIncome(summary)),
          ],
        ),
        const SizedBox(height: 12),

        // ── Trackable Expenses ──
        if (summary.trackableExpenseActuals.isNotEmpty) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Trackable Expenses',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      _buildAmountChip(
                        summary.trackableExpenseActuals
                            .fold(0.0, (s, a) => s + a.actual),
                        summary.trackableExpenseActuals
                            .fold(0.0, (s, a) => s + a.budgeted),
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...summary.trackableExpenseActuals.map((a) =>
                      _buildTrackableExpenseTile(
                          a, summary.entriesFor(a.id), summary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Extra Expenses ──
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined,
                        size: 20, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Extra Expenses',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            'One-off or unplanned spending not covered in your monthly budget — e.g. car repairs, medical bills, or unexpected purchases.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currency.format(summary.extraExpenseActuals
                          .fold(0.0, (s, a) => s + a.actual)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: summary.extraExpenseActuals
                                .any((a) => a.actual > 0)
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
                if (summary.extraExpenseActuals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...summary.extraExpenseActuals
                      .map((a) => _buildExtraExpenseRow(a)),
                ],
                if (summary.period.isOpen) ...[
                  const SizedBox(height: 8),
                  _buildAddButton(
                      'Add expense', () => _addTrackedExpense(summary)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Close / Re-open month ──
        if (summary.period.isOpen)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.tonalIcon(
                onPressed: _closeMonth,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Close Month'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Once you\'re happy all spending and income has been recorded, close the month to lock it in. Closed months feed into your progress reports and debt payoff timeline.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 16,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Closed ${summary.period.closedAt != null ? DateFormat.yMMMd().format(summary.period.closedAt!) : ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _reopenMonth,
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                label: const Text('Re-open Month'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWorkflowBanner(TrackingWorkflowStatus status) {
    final theme = Theme.of(context);
    final accentColor = switch (status.stage) {
      TrackingWorkflowStage.gettingStarted => theme.colorScheme.primary,
      TrackingWorkflowStage.inProgress => theme.colorScheme.tertiary,
      TrackingWorkflowStage.readyToClose => Colors.orange.shade700,
      TrackingWorkflowStage.overdue => theme.colorScheme.error,
      TrackingWorkflowStage.closed => Colors.green.shade700,
    };
    final icon = switch (status.stage) {
      TrackingWorkflowStage.gettingStarted => Icons.play_circle_outline_rounded,
      TrackingWorkflowStage.inProgress => Icons.timeline_rounded,
      TrackingWorkflowStage.readyToClose => Icons.task_alt_rounded,
      TrackingWorkflowStage.overdue => Icons.warning_amber_rounded,
      TrackingWorkflowStage.closed => Icons.lock_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildWorkflowChip(
                'Trackable',
                '${status.trackableStartedCount}/${status.trackableTotalCount}',
              ),
              _buildWorkflowChip('Extra', '${status.extraExpenseCount}'),
            ],
          ),
          if (status.canCloseMonth) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _closeMonth,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Close Month'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkflowChip(String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelMedium,
      ),
    );
  }

  Widget _buildCollapsibleCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required double actual,
    required double budgeted,
    required bool expanded,
    required VoidCallback onTap,
    required List<Widget> children,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        if (subtitle != null) ...[  
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildAmountChip(actual, budgeted, theme),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(children: children),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountChip(double actual, double budgeted, ThemeData theme) {
    return Text(
      '${_currency.format(actual)} / ${_currency.format(budgeted)}',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildActualRow(BudgetActual actual) {
    final theme = Theme.of(context);
    final isClosed = _summary?.period.isClosed == true;
    final hasEntry = actual.actual > 0;
    final isOver = actual.isOverBudget;
    final variance = actual.variance;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(actual.categoryName,
                    style: theme.textTheme.bodyMedium),
                Text('Budget: ${_currency.format(actual.budgeted)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currency.format(hasEntry ? actual.actual : 0),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isOver ? theme.colorScheme.error : null,
                  fontWeight: isOver ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              if (hasEntry && variance != 0)
                Text(
                  '${variance > 0 ? '+' : ''}${_currency.format(variance)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isOver ? theme.colorScheme.error : Colors.green,
                  ),
                ),
            ],
          ),
          if (!isClosed) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _editActual(actual),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExtraExpenseRow(BudgetActual actual) {
    final theme = Theme.of(context);
    final isClosed = _summary?.period.isClosed == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(actual.categoryName,
                style: theme.textTheme.bodyMedium),
          ),
          Text(
            _currency.format(actual.actual),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.error,
            ),
          ),
          if (!isClosed) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _editActual(actual),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => _deleteActual(actual),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.delete_outline,
                    size: 16, color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildTrackableExpenseTile(
    BudgetActual actual,
    List<BudgetActualEntry> entries,
    MonthlyBudgetSummary summary,
  ) {
    final theme = Theme.of(context);
    final isClosed = summary.period.isClosed;
    final isExpanded = _expandedTrackableIds.contains(actual.id);
    final total = entries.fold(0.0, (s, e) => s + e.amount);
    final isOver = total > actual.budgeted && actual.budgeted > 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedTrackableIds.remove(actual.id);
              } else {
                _expandedTrackableIds.add(actual.id);
              }
            }),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(actual.categoryName,
                        style: theme.textTheme.bodyMedium),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currency.format(total),
                        style: TextStyle(
                          color: isOver ? theme.colorScheme.error : null,
                          fontWeight:
                              isOver ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Text(
                        'of ${_currency.format(actual.budgeted)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            if (entries.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'No entries yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ...entries.map((entry) => ListTile(
                  dense: true,
                  title: Text(entry.reference),
                  subtitle: Text(DateFormat.yMMMd().format(entry.date)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_currency.format(entry.amount)),
                      if (!isClosed) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          color: theme.colorScheme.error,
                          onPressed: () => _deleteEntry(actual, entry),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                )),
            if (!isClosed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _addEntryToTrackable(actual),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add entry'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

}

enum _SurplusChoice { discard, carryForward, addToSavings }
