import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/utils/financial_month.dart';
import 'package:debt_free_app/features/budget/domain/build_budget_snapshot.dart';
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
    if (month < 1) { month = 12; year--; }
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
    final bills = _repository.getBills();
    final expenses = _repository.getExpenses();
    final mortgage = _repository.getMortgage();
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
          // ── Copy / Clear month (top actions) ──
          if (!isClosed && (!isCurrentMonth || income.isNotEmpty || bills.isNotEmpty || expenses.isNotEmpty))
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          // ── Budget Summary Chips ──
          Row(
            children: [
              Expanded(child: _StatChip(label: 'Income', value: currency.format(snapshot.totalIncome), color: Colors.green.shade700)),
              const SizedBox(width: 8),
              Expanded(child: _StatChip(label: 'Bills', value: currency.format(snapshot.totalBills), color: colorScheme.error)),
              const SizedBox(width: 8),
              Expanded(child: _StatChip(label: 'Expenses', value: currency.format(snapshot.totalExpenses), color: Colors.orange.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatChip(label: 'Mortgage', value: currency.format(snapshot.mortgagePayment), color: colorScheme.primary)),
              const SizedBox(width: 8),
              Expanded(child: _StatChip(label: 'Sacrifice', value: currency.format(snapshot.salarySacrificeNetCost), color: Colors.purple.shade600)),
            ],
          ),
          const SizedBox(height: 12),
          // ── Main content ──
          AbsorbPointer(
            absorbing: isClosed,
            child: Opacity(
              opacity: isClosed ? 0.45 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
          // ── Income ──
          _SectionHeader(title: 'Income', icon: Icons.account_balance_wallet_outlined, actionLabel: 'Add income', onPressed: _openNewIncomeForm),
          const SizedBox(height: 8),
          if (income.isEmpty) ...<Widget>[
            const EmptyStateCard(title: 'No income sources yet', message: 'Add income so the app can calculate available cash.'),
            const SizedBox(height: 8),
          ],
          for (final item in income) ...<Widget>[
            _BudgetItemTile(
              icon: Icons.payments_outlined,
              iconColor: Colors.green.shade700,
              name: item.name,
              primaryValue: '${currency.format(item.monthlyNetAfterSacrifice())}/mo net',
              secondaryValue: '${currency.format(item.annualGross)}/yr gross',
              onEdit: () => _openEditIncomeForm(item.id),
              onDelete: () => _confirmDeleteIncome(item.id, item.name),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          // ── Bills ──
          _SectionHeader(title: 'Bills', icon: Icons.receipt_long_outlined, actionLabel: 'Add bill', onPressed: _openNewBillForm),
          const SizedBox(height: 8),
          if (bills.isEmpty) ...<Widget>[
            const EmptyStateCard(title: 'No bills yet', message: 'Add monthly bills (rent, utilities, subscriptions, etc.).'),
            const SizedBox(height: 8),
          ],
          for (final item in bills) ...<Widget>[
            _BudgetItemTile(
              icon: Icons.receipt_outlined,
              iconColor: colorScheme.error,
              name: item.name,
              primaryValue: '${currency.format(item.amount)}/mo',
              onEdit: () => _openEditBillForm(item.id),
              onDelete: () => _confirmDeleteBill(item.id, item.name),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          // ── Expenses ──
          _SectionHeader(title: 'Expenses', icon: Icons.shopping_cart_outlined, actionLabel: 'Add expense', onPressed: _openNewExpenseForm),
          const SizedBox(height: 8),
          if (expenses.isEmpty) ...<Widget>[
            const EmptyStateCard(title: 'No expenses yet', message: 'Add your monthly expenses to improve the projection.'),
            const SizedBox(height: 8),
          ],
          for (final item in expenses) ...<Widget>[
            _BudgetItemTile(
              icon: Icons.shopping_bag_outlined,
              iconColor: Colors.orange.shade700,
              name: item.name,
              primaryValue: '${currency.format(item.amount)}/mo',
              badge: item.trackable ? 'Trackable' : null,
              onEdit: () => _openEditExpenseForm(item.id),
              onDelete: () => _confirmDeleteExpense(item.id, item.name),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          // ── Mortgage ──
          _SectionHeader(title: 'Mortgage', icon: Icons.home_outlined, actionLabel: mortgage == null ? 'Add' : 'Details', onPressed: () => context.push('/mortgage')),
          const SizedBox(height: 8),
          if (mortgage == null)
            const EmptyStateCard(title: 'No mortgage added', message: 'Add your mortgage to track overpayments.')
          else
            _BudgetItemTile(
              icon: Icons.home_work_outlined,
              iconColor: colorScheme.primary,
              name: mortgage.name,
              primaryValue: '${currency.format(mortgage.totalMonthlyPayment)}/mo',
              secondaryValue: '${mortgage.annualRate.toStringAsFixed(2)}% rate  \u2022  ${currency.format(mortgage.balance)} balance',
              onEdit: () => context.push('/mortgage'),
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

  Future<void> _openEditExpenseForm(String expenseId) async {
    context.push('/budget/expense/$expenseId/edit');
  }

  Future<void> _openNewBillForm() async {
    context.push('/budget/bill/new');
  }

  Future<void> _openEditBillForm(String billId) async {
    context.push('/budget/bill/$billId/edit');
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          )),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
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
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    this.onEdit,
    this.onDelete,
  });

  final String name;
  final String primaryValue;
  final String? secondaryValue;
  final IconData? icon;
  final Color? iconColor;
  final String? badge;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                  color: (iconColor ?? colorScheme.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor ?? colorScheme.primary),
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
                        child: Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text(primaryValue, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (secondaryValue != null) ...[
                    const SizedBox(height: 3),
                    Text(secondaryValue!, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                  if (badge != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(badge!, style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      )),
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
                    child: Icon(Icons.edit_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              if (onDelete != null)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline, size: 16, color: colorScheme.error.withValues(alpha: 0.7)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}


