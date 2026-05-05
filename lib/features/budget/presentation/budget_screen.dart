import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/data/financial_repository_extensions.dart';
import 'package:debt_free_app/core/utils/amount_parser.dart';
import 'package:debt_free_app/core/utils/bonus_income_helper.dart';
import 'package:debt_free_app/core/utils/financial_month.dart';
import 'package:debt_free_app/features/budget/domain/build_budget_snapshot.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/shared/widgets/app_shell_scaffold.dart';
import 'package:debt_free_app/shared/widgets/empty_state_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({
    super.key,
    this.repository,
  });

  final SessionFinancialRepository? repository;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late final SessionFinancialRepository _repository;
  late String _selectedMonth;
  bool _isClosed = false;
  bool _whyMonthlyExpanded = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SessionFinancialRepository.instance;
    _selectedMonth = _repository.activeBudgetMonth;
    // Clamp to start month if needed
    final startMonth = _repository.appStartMonth;
    if (startMonth != null &&
        startMonth.isNotEmpty &&
        _selectedMonth.compareTo(startMonth) < 0) {
      _selectedMonth = startMonth;
      _repository.setActiveBudgetMonth(startMonth);
    }
    _repository.addListener(_onRepositoryChange);
    _loadClosedStatus(_selectedMonth);
  }

  Future<void> _loadClosedStatus(String monthKey) async {
    final period = await _repository.getBudgetPeriod(monthKey);
    if (!mounted) return;
    setState(() {
      _isClosed = period?.isClosed == true;
    });
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChange);
    super.dispose();
  }

  void _onRepositoryChange() {
    if (!mounted) return;
    final newMonth = _repository.activeBudgetMonth;
    setState(() {
      _selectedMonth = newMonth;
    });
    _loadClosedStatus(newMonth);
  }

  void _changeMonth(int delta) {
    final parts = _selectedMonth.split('-');
    var year = int.parse(parts[0]);
    var month = int.parse(parts[1]) + delta;
    while (month > 12) {
      month -= 12;
      year++;
    }
    while (month < 1) {
      month += 12;
      year--;
    }
    final newKey = '${year}-${month.toString().padLeft(2, '0')}';
    if (delta < 0 && !_isMonthAllowed(newKey)) return;
    setState(() => _selectedMonth = newKey);
    _repository.setActiveBudgetMonth(newKey);
    _loadClosedStatus(newKey);
  }

  bool _isMonthAllowed(String monthKey) {
    final startMonth = _repository.appStartMonth;
    if (startMonth == null || startMonth.isEmpty) return true;
    return monthKey.compareTo(startMonth) >= 0;
  }

  bool get _canGoBack {
    final parts = _selectedMonth.split('-');
    var year = int.parse(parts[0]);
    var month = int.parse(parts[1]) - 1;
    if (month < 1) {
      month = 12;
      year--;
    }
    final prevKey = '${year}-${month.toString().padLeft(2, '0')}';
    return _isMonthAllowed(prevKey);
  }

  String _nextMonthKey() {
    final parts = _selectedMonth.split('-');
    var year = int.parse(parts[0]);
    var month = int.parse(parts[1]) + 1;
    if (month > 12) {
      month = 1;
      year++;
    }
    return '${year}-${month.toString().padLeft(2, '0')}';
  }

  String _formatMonthKey(String key) {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final startDay = _repository.financialMonthStartDay;
    if (startDay > 1) {
      return FinancialMonth.periodLabel(year, month, startDay);
    }
    return DateFormat.yMMMM().format(DateTime(year, month));
  }

  Future<void> _copyToNextMonth() async {
    final nextKey = _nextMonthKey();
    final nextLabel = _formatMonthKey(nextKey);
    final hasData = _repository.getIncomeSourcesForMonth(nextKey).isNotEmpty ||
        _repository.getExpensesForMonth(nextKey).isNotEmpty ||
        _repository.getBillsForMonth(nextKey).isNotEmpty;

    if (hasData) {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Overwrite existing budget?'),
          content: Text(
            '$nextLabel already has budget items. '
            'Do you want to add the copied items alongside them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Copy anyway'),
            ),
          ],
        ),
      );
      if (overwrite != true) return;
    }

    await _repository.copyBudgetMonth(_selectedMonth, nextKey);
    if (!mounted) return;
    setState(() => _selectedMonth = nextKey);
    _showSnackBar('Budget copied to $nextLabel.');
  }

  Future<void> _clearMonth() async {
    final label = _formatMonthKey(_selectedMonth);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear month data?'),
        content: Text(
          'This will permanently delete all income, bills and expenses '
          'for $label. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.clearBudgetMonth(_selectedMonth);
    if (!mounted) return;
    _showSnackBar('$label cleared.');
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = BuildBudgetSnapshot(_repository)();
    final income = _repository.getIncomeSources();
    final regularIncome = income.where((item) => !isBonusIncome(item)).toList();
    final adjustedIncomeById = {
      for (final item in _repository.getAdjustedIncomeSources()) item.id: item,
    };
    final bills = _repository.getBills();
    final subscriptions = _repository.getSubscriptions();
    final allExpenses = _repository.getExpenses();
    final expenses = allExpenses
        .where((e) => e.category != ExpenseCategory.savings)
        .toList();
    final savings = allExpenses
        .where((e) => e.category == ExpenseCategory.savings)
        .toList();
    final mortgages = _repository.getMortgages();
    final currency = NumberFormat.currency(
      locale: 'en_GB',
      symbol: '\u00A3',
      decimalDigits: 2,
    );
    final nextMonthLabel = _formatMonthKey(_nextMonthKey());
    final currentMonthKey = () {
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}';
    }();
    final isCurrentMonth = _selectedMonth == currentMonthKey;
    final isClosed = _isClosed;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppShellScaffold(
      title: 'Income & Outgoings',
      currentIndex: 2,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          // ── Month selector ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _canGoBack ? () => _changeMonth(-1) : null,
                  tooltip: 'Previous month',
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _formatMonthKey(_selectedMonth),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                  tooltip: 'Next month',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Why monthly? collapsible ──
          _WhyMonthlyCard(
            expanded: _whyMonthlyExpanded,
            onToggle: () =>
                setState(() => _whyMonthlyExpanded = !_whyMonthlyExpanded),
          ),
          const SizedBox(height: 12),
          // ── Copy / Clear month (top actions) ──
          if (!isClosed &&
              (!isCurrentMonth ||
                  income.isNotEmpty ||
                  bills.isNotEmpty ||
                  expenses.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.copy_all, size: 16),
                      label: Text('Copy to $nextMonthLabel'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      onPressed: _copyToNextMonth,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Clear'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onPressed: _clearMonth,
                  ),
                ],
              ),
            ),
          Divider(color: colorScheme.outlineVariant, height: 24),
          // ── Closed banner ──
          if (isClosed)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outlined, size: 18, color: colorScheme.error),
                  const SizedBox(width: 10),
                  Text(
                    'This month is closed — editing is disabled.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // ── Main content ──
          AbsorbPointer(
            absorbing: isClosed,
            child: Opacity(
              opacity: isClosed ? 0.45 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Income ──
                  _SectionHeader(
                    title: 'Income',
                    amount: currency.format(snapshot.totalIncome),
                    icon: Icons.account_balance_wallet_outlined,
                    actionLabel: 'Add income',
                    onPressed: _openNewIncomeForm,
                  ),
                  const SizedBox(height: 8),
                  if (regularIncome.isEmpty) ...<Widget>[
                    const EmptyStateCard(
                        title: 'No income sources yet',
                        message:
                            'Add each income source separately — salary, freelance, rental income, etc.'),
                    const SizedBox(height: 8),
                  ],
                  for (final item in regularIncome) ...<Widget>[
                    () {
                      final linkedBonus =
                          _findLinkedBonusForParent(item, income);
                      final bonusNet = linkedBonus == null
                          ? null
                          : (adjustedIncomeById[linkedBonus.id]?.amount ??
                              resolvedMonthlyIncomeNet(linkedBonus, income));
                      final bonusGross = linkedBonus == null
                          ? null
                          : linkedBonus.annualGross / 12;
                      return _BudgetItemTile(
                        icon: Icons.payments_outlined,
                        iconColor: Colors.green.shade700,
                        name: item.name,
                        primaryValue:
                            '${currency.format(adjustedIncomeById[item.id]?.amount ?? item.monthlyNetAfterSacrifice())}/mo net',
                        secondaryValue:
                            '${currency.format(item.annualGross)}/yr gross',
                        bonusGross: bonusGross,
                        bonusNet: bonusNet,
                        onAddBonus: linkedBonus == null
                            ? () => _promptAddBonus(item)
                            : null,
                        onRemoveBonus: linkedBonus == null
                            ? null
                            : () => _removeBonus(linkedBonus, item.name),
                        onEdit: () => _openEditIncomeForm(item.id),
                        onDelete: () =>
                            _confirmDeleteIncome(item.id, item.name),
                      );
                    }(),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  // ── Bills ──
                  _SectionHeader(
                    title: 'Bills',
                    amount: currency.format(snapshot.totalBills),
                    icon: Icons.receipt_long_outlined,
                    actionLabel: 'Add bill',
                    onPressed: _openNewBillForm,
                  ),
                  const SizedBox(height: 8),
                  if (bills.isEmpty) ...<Widget>[
                    const EmptyStateCard(
                        title: 'No bills yet',
                        message:
                            'Add monthly bills (rent, utilities, subscriptions, etc.).'),
                    const SizedBox(height: 8),
                  ],
                  for (final item in bills) ...<Widget>[
                    _BudgetItemTile(
                      icon: Icons.receipt_outlined,
                      iconColor: colorScheme.error,
                      name: item.name,
                      primaryValue: '${currency.format(item.amount)}/mo',
                      secondaryValue: item.category.displayName,
                      onEdit: () => _openEditBillForm(item.id),
                      onDelete: () => _confirmDeleteBill(item.id, item.name),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  // ── Subscriptions ──
                  _SectionHeader(
                    title: 'Subscriptions',
                    amount: currency.format(snapshot.totalSubscriptions),
                    icon: Icons.subscriptions_outlined,
                    actionLabel: 'Add subscription',
                    onPressed: _openNewSubscriptionForm,
                  ),
                  const SizedBox(height: 8),
                  if (subscriptions.isEmpty) ...<Widget>[
                    const EmptyStateCard(
                        title: 'No subscriptions yet',
                        message:
                            'Add recurring subscriptions (Netflix, Gym, Spotify, etc.).'),
                    const SizedBox(height: 8),
                  ],
                  for (final item in subscriptions) ...<Widget>[
                    _BudgetItemTile(
                      icon: Icons.repeat_outlined,
                      iconColor: Colors.purple.shade400,
                      name: item.name,
                      primaryValue: '${currency.format(item.amount)}/mo',
                      onEdit: () => _openEditSubscriptionForm(item.id),
                      onDelete: () =>
                          _confirmDeleteSubscription(item.id, item.name),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  // ── Expenses ──
                  _SectionHeader(
                    title: 'Expenses',
                    amount: currency.format(snapshot.totalExpenses),
                    icon: Icons.shopping_cart_outlined,
                    actionLabel: 'Add expense',
                    onPressed: _openNewExpenseForm,
                  ),
                  const SizedBox(height: 8),
                  if (expenses.isEmpty) ...<Widget>[
                    const EmptyStateCard(
                        title: 'No expenses yet',
                        message:
                            'Add day-to-day spending by category — entertainment, transport, healthcare, and more.'),
                    const SizedBox(height: 8),
                  ],
                  for (final item in expenses) ...<Widget>[
                    _BudgetItemTile(
                      icon: Icons.shopping_bag_outlined,
                      iconColor: Colors.orange.shade700,
                      name: item.name,
                      primaryValue: '${currency.format(item.amount)}/mo',
                      secondaryValue: item.category.displayName,
                      badge: item.trackable ? 'Trackable' : null,
                      onEdit: () => _openEditExpenseForm(item.id),
                      onDelete: () => _confirmDeleteExpense(item.id, item.name),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  // ── Savings ──
                  _SectionHeader(
                    title: 'Savings',
                    amount: currency.format(snapshot.totalSavings),
                    icon: Icons.savings_outlined,
                    actionLabel: 'Add savings',
                    onPressed: _openNewSavingsForm,
                  ),
                  const SizedBox(height: 8),
                  if (savings.isEmpty) ...<Widget>[
                    const EmptyStateCard(
                        title: 'No savings pots yet',
                        message:
                            'Add a monthly savings amount — emergency fund, holiday, home deposit — to factor it into your budget.'),
                    const SizedBox(height: 8),
                  ],
                  for (final item in savings) ...<Widget>[
                    _BudgetItemTile(
                      icon: Icons.savings_outlined,
                      iconColor: Colors.teal,
                      name: item.name,
                      primaryValue: '${currency.format(item.amount)}/mo',
                      secondaryValue: 'Savings',
                      onEdit: () => _openEditExpenseForm(item.id),
                      onDelete: () => _confirmDeleteExpense(item.id, item.name),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  // ── Mortgage ──
                  _SectionHeader(
                    title: 'Mortgage',
                    amount: currency.format(snapshot.mortgagePayment),
                    icon: Icons.home_outlined,
                    actionLabel: 'Add mortgage',
                    onPressed: () => context.push('/mortgage'),
                  ),
                  const SizedBox(height: 8),
                  if (mortgages.isEmpty)
                    const EmptyStateCard(
                        title: 'No mortgage added',
                        message: 'Add your mortgage to track overpayments.')
                  else
                    ...mortgages.map(
                      (mortgage) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BudgetItemTile(
                          icon: Icons.home_work_outlined,
                          iconColor: colorScheme.primary,
                          name: mortgage.name,
                          primaryValue:
                              '${currency.format(mortgage.totalMonthlyHousingCost)}/mo',
                          secondaryValue: mortgage.ownershipType ==
                                  MortgageOwnershipType.sharedOwnership
                              ? '${mortgage.annualRate.toStringAsFixed(2)}% rate  •  ${currency.format(mortgage.balance)} balance  •  ${mortgage.ownedSharePercent.toStringAsFixed(1)}% owned'
                              : '${mortgage.annualRate.toStringAsFixed(2)}% rate  •  ${currency.format(mortgage.balance)} balance',
                          onEdit: () => context.push('/mortgage'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNewIncomeForm() async {
    context.push('/budget/income/new');
  }

  Future<void> _openEditIncomeForm(String incomeId) async {
    context.push('/budget/income/$incomeId/edit');
  }

  Future<void> _openNewExpenseForm() async {
    context.push('/budget/expense/new');
  }

  Future<void> _openNewSavingsForm() async {
    context.push('/budget/expense/new?category=savings');
  }

  Future<void> _openEditExpenseForm(String expenseId) async {
    context.push('/budget/expense/$expenseId/edit');
  }

  Future<void> _openNewBillForm() async {
    context.push('/budget/bill/new');
  }

  Future<void> _openEditBillForm(String billId) async {
    context.push('/budget/bill/$billId/edit');
  }

  Future<void> _openNewSubscriptionForm() async {
    context.push('/budget/subscription/new');
  }

  Future<void> _openEditSubscriptionForm(String subId) async {
    context.push('/budget/subscription/$subId/edit');
  }

  Future<void> _confirmDeleteIncome(String id, String name) async {
    final shouldDelete = await _showDeleteDialog('Delete income?', name);
    if (shouldDelete != true) {
      return;
    }

    _repository.deleteIncomeSource(id);
    await _repository.waitForPendingWrites();
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnackBar('Income removed.');
  }

  Future<void> _promptAddBonus(IncomeSource source) async {
    final existingBonus =
        _findLinkedBonusForParent(source, _repository.getIncomeSources());
    if (existingBonus != null) {
      _showSnackBar('A bonus has already been added for ${source.name}.');
      return;
    }

    final controller = TextEditingController();
    String? errorText;
    final monthLabel = _formatMonthKey(_selectedMonth);

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Add bonus to ${source.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This applies only to $monthLabel and is added on top of '
                    'the current salary so tax, NI, student loan and '
                    'salary-sacrifice effects stay aligned.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Bonus gross',
                      prefixText: '£',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final raw = controller.text.trim();
                    final parsed = AmountParser.tryParse(raw);
                    if (parsed == null || parsed <= 0) {
                      setDialogState(() {
                        errorText = 'Enter a valid amount greater than 0.';
                      });
                      return;
                    }
                    if (!AmountParser.hasMaxDecimalPlaces(raw, 2)) {
                      setDialogState(() {
                        errorText = 'Use at most 2 decimal places.';
                      });
                      return;
                    }
                    Navigator.pop(ctx, parsed);
                  },
                  child: const Text('Apply bonus'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final bonusIncome = IncomeSource(
      id: '${_selectedMonth}-income-bonus-${DateTime.now().millisecondsSinceEpoch}${bonusParentMarker}${source.id}',
      name: 'Bonus (${source.name})',
      annualGross: result * 12,
      studentLoanPlan: source.studentLoanPlan,
      monthKey: _selectedMonth,
    );
    _repository.saveIncomeSource(bonusIncome);
    await _repository.waitForPendingWrites();
    if (!mounted) return;

    setState(() {});
    _showSnackBar(
      'Bonus added to ${source.name} for $monthLabel.',
    );
  }

  IncomeSource? _findLinkedBonusForParent(
    IncomeSource parent,
    List<IncomeSource> allIncome,
  ) {
    for (final source in allIncome) {
      if (!isBonusIncome(source)) {
        continue;
      }

      final linkedParentId = parentIncomeIdFromBonusId(source.id);
      if (linkedParentId != null && linkedParentId == parent.id) {
        return source;
      }

      final linkedParentName = parentIncomeNameFromBonusName(source.name);
      if (linkedParentName != null && linkedParentName == parent.name) {
        return source;
      }
    }

    return null;
  }

  Future<void> _removeBonus(IncomeSource bonus, String parentName) async {
    _repository.deleteIncomeSource(bonus.id);
    await _repository.waitForPendingWrites();
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnackBar('Bonus removed from $parentName.');
  }

  Future<void> _confirmDeleteExpense(String id, String name) async {
    final shouldDelete = await _showDeleteDialog('Delete expense?', name);
    if (shouldDelete != true) {
      return;
    }

    _repository.deleteExpense(id);
    await _repository.waitForPendingWrites();
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnackBar('Expense removed.');
  }

  Future<void> _confirmDeleteBill(String id, String name) async {
    final shouldDelete = await _showDeleteDialog('Delete bill?', name);
    if (shouldDelete != true) {
      return;
    }

    _repository.deleteBill(id);
    await _repository.waitForPendingWrites();
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnackBar('Bill removed.');
  }

  Future<void> _confirmDeleteSubscription(String id, String name) async {
    final shouldDelete = await _showDeleteDialog('Delete subscription?', name);
    if (shouldDelete != true) {
      return;
    }

    _repository.deleteBill(id);
    await _repository.waitForPendingWrites();
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnackBar('Subscription removed.');
  }

  Future<bool?> _showDeleteDialog(String title, String name) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text('Remove "$name" from this budget?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onPressed,
    this.amount,
  });

  final String title;
  final String? amount;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (amount != null)
                Text(
                  amount!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            textStyle: theme.textTheme.labelMedium,
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _BudgetItemTile extends StatelessWidget {
  const _BudgetItemTile({
    required this.name,
    required this.primaryValue,
    this.secondaryValue,
    this.icon,
    this.iconColor,
    this.badge,
    this.bonusGross,
    this.bonusNet,
    this.onAddBonus,
    this.onRemoveBonus,
    this.onEdit,
    this.onDelete,
  });

  final String name;
  final String primaryValue;
  final String? secondaryValue;
  final IconData? icon;
  final Color? iconColor;
  final String? badge;
  final double? bonusGross;
  final double? bonusNet;
  final VoidCallback? onAddBonus;
  final VoidCallback? onRemoveBonus;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currency = NumberFormat.currency(
      locale: 'en_GB',
      symbol: '\u00A3',
      decimalDigits: 2,
    );
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      (iconColor ?? colorScheme.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 18, color: iconColor ?? colorScheme.primary),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text(primaryValue,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (secondaryValue != null) ...[
                    const SizedBox(height: 3),
                    Text(secondaryValue!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                  if (badge != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(badge!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ],
                  if (onAddBonus != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onAddBonus,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Add bonus',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (bonusGross != null && bonusNet != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Bonus added: ${currency.format(bonusGross)} gross • ${currency.format(bonusNet)} net',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (onRemoveBonus != null)
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: onRemoveBonus,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color:
                                      colorScheme.error.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(width: 8),
              if (onEdit != null)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.edit_outlined,
                        size: 16, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              if (onDelete != null)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline,
                        size: 16,
                        color: colorScheme.error.withValues(alpha: 0.7)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WhyMonthlyCard extends StatelessWidget {
  const _WhyMonthlyCard({
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Why is this set up per month?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: cs.outlineVariant, height: 1),
                  const SizedBox(height: 12),
                  _BulletPoint(
                    icon: Icons.trending_up_rounded,
                    text:
                        'Salary going up in two months? Change it then — your forecast updates automatically.',
                    cs: cs,
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  _BulletPoint(
                    icon: Icons.receipt_long_rounded,
                    text:
                        'Expenses vary — car service, dentist, annual renewals. Log them in the right month without skewing every other month.',
                    cs: cs,
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  _BulletPoint(
                    icon: Icons.bolt_rounded,
                    text:
                        'Seasonal costs like higher energy bills in winter can be reflected accurately.',
                    cs: cs,
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  _BulletPoint(
                    icon: Icons.savings_rounded,
                    text:
                        'The Planner uses each month\'s real available cash to project exactly when you\'ll be debt-free — not an optimistic annual average.',
                    cs: cs,
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  _BulletPoint(
                    icon: Icons.checklist_rounded,
                    text:
                        'At month-end, Tracking compares what you planned here against what actually happened.',
                    cs: cs,
                    theme: theme,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Use Copy to next month to carry your setup forward — then tweak only what changes.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({
    required this.icon,
    required this.text,
    required this.cs,
    required this.theme,
  });

  final IconData icon;
  final String text;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
