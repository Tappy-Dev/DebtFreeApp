import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/utils/financial_month.dart';
import 'package:debt_free_app/features/budget/domain/build_budget_snapshot.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/features/tracking/domain/build_monthly_budget_summary.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/monthly_budget_summary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthlySummaryScreen extends StatefulWidget {
  const MonthlySummaryScreen({super.key});

  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  final _repository = SessionFinancialRepository.instance;
  MonthlyBudgetSummary? _trackingSummary;

  final _currency = NumberFormat.currency(
      locale: 'en_GB', symbol: '\u00A3', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepositoryChange);
    _loadTracking();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChange);
    super.dispose();
  }

  void _onRepositoryChange() {
    if (mounted) _loadTracking();
  }

  Future<void> _loadTracking() async {
    final monthKey = _repository.currentMonthKeyWithStartDay();
    final (year, month) = FinancialMonth.parseKey(monthKey);
    final summary = await BuildMonthlyBudgetSummary(_repository)(
      year: year,
      month: month,
    );
    if (mounted) setState(() => _trackingSummary = summary);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = BuildBudgetSnapshot(_repository)();
    final trackingSummary = _trackingSummary;
    final extraDebtPayment = _repository
        .getScenarioChanges()
        .where((c) => c.changeType == ChangeType.extraPayment)
        .fold(0.0, (sum, c) => sum + c.amount);

    final trackableOverspend = trackingSummary == null
        ? 0.0
        : trackingSummary.trackableExpenseActuals.fold(0.0, (sum, a) {
            final over = a.actual - a.budgeted;
            return sum + (over > 0 ? over : 0.0);
          });
    final extraExpenses = trackingSummary == null
        ? 0.0
        : trackingSummary.extraExpenseActuals
            .fold(0.0, (sum, a) => sum + a.actual);
    final budgetedRemaining = snapshot.remainingCash;
    final remaining =
        budgetedRemaining - trackableOverspend - extraExpenses - extraDebtPayment;
    final income = snapshot.totalIncome;
    final spentPct =
        income > 0 ? ((income - remaining) / income).clamp(0.0, 1.0) : 0.0;
    final remainingColor =
        remaining < 0 ? theme.colorScheme.error : theme.colorScheme.primary;

    // Period title
    final startDay = _repository.financialMonthStartDay;
    final monthKey = _repository.currentMonthKeyWithStartDay();
    final (year, month) = FinancialMonth.parseKey(monthKey);
    final title = startDay > 1
        ? FinancialMonth.periodLabel(year, month, startDay)
        : 'Monthly Summary';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Remaining cash highlight ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: remaining < 0
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remaining this month',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: remaining < 0
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currency.format(remaining),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: remaining < 0
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: spentPct,
                    minHeight: 8,
                    backgroundColor: remaining < 0
                        ? theme.colorScheme.error.withValues(alpha: 0.3)
                        : theme.colorScheme.primary.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        remaining < 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Income & Outgoings breakdown ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Budget Breakdown',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  _Row(
                    icon: Icons.arrow_downward_rounded,
                    iconColor: Colors.green,
                    label: 'Net income',
                    value: _currency.format(snapshot.totalIncome),
                  ),
                  const Divider(height: 24),
                  _Row(
                    icon: Icons.receipt_long_outlined,
                    iconColor: theme.colorScheme.secondary,
                    label: 'Bills',
                    value: _currency.format(snapshot.totalBills),
                  ),
                  const SizedBox(height: 10),
                  _Row(
                    icon: Icons.shopping_bag_outlined,
                    iconColor: theme.colorScheme.secondary,
                    label: 'Expenses',
                    value: _currency.format(snapshot.totalExpenses),
                  ),
                  const SizedBox(height: 10),
                  _Row(
                    icon: Icons.credit_card_outlined,
                    iconColor: theme.colorScheme.secondary,
                    label: 'Debt payments',
                    value: _currency.format(
                        snapshot.totalMinimumPayments + extraDebtPayment),
                  ),
                  if (extraDebtPayment > 0) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rocket_launch_outlined,
                                size: 13, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'incl. ${_currency.format(extraDebtPayment)} extra',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (snapshot.mortgagePayment > 0) ...[
                    const SizedBox(height: 10),
                    _Row(
                      icon: Icons.home_outlined,
                      iconColor: theme.colorScheme.secondary,
                      label: 'Mortgage',
                      value: _currency.format(snapshot.mortgagePayment),
                    ),
                  ],
                  if (snapshot.salarySacrificeNetCost > 0) ...[
                    const SizedBox(height: 10),
                    _Row(
                      icon: Icons.savings_outlined,
                      iconColor: theme.colorScheme.secondary,
                      label: 'Salary sacrifice net impact',
                      value:
                          _currency.format(snapshot.salarySacrificeNetCost),
                    ),
                  ],
                  const Divider(height: 24),
                  _Row(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: remainingColor,
                    label: 'Remaining cash',
                    value: _currency.format(remaining),
                    valueColor: remainingColor,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),

          // ── Trackable expenses ──
          if (trackingSummary != null &&
              trackingSummary.trackableExpenseActuals.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.track_changes_outlined,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Trackable Expenses',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...trackingSummary.trackableExpenseActuals
                        .map((a) => _TrackableRow(
                              actual: a,
                              currency: _currency,
                            )),
                  ],
                ),
              ),
            ),
          ],

          // ── Extra expenses ──
          if (trackingSummary != null &&
              trackingSummary.extraExpenseActuals.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_bag_outlined,
                            size: 18, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Text('Extra Expenses',
                            style: theme.textTheme.titleMedium),
                        const Spacer(),
                        Text(
                          _currency.format(trackingSummary
                              .extraExpenseActuals
                              .fold(0.0, (s, a) => s + a.actual)),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...trackingSummary.extraExpenseActuals
                        .map((a) => _ExtraRow(
                              actual: a,
                              currency: _currency,
                            )),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: style)),
        Text(value, style: style?.copyWith(color: valueColor)),
      ],
    );
  }
}

class _TrackableRow extends StatelessWidget {
  const _TrackableRow({required this.actual, required this.currency});

  final BudgetActual actual;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spent = actual.actual;
    final budgeted = actual.budgeted;
    final isOver = spent > budgeted;
    final pct = budgeted > 0 ? (spent / budgeted).clamp(0.0, 1.0) : 0.0;

    final statusColor = isOver
        ? theme.colorScheme.error
        : spent >= budgeted * 0.9
            ? Colors.orange
            : Colors.green;
    final statusLabel = isOver
        ? 'Over by ${currency.format(spent - budgeted)}'
        : '${currency.format(spent)} of ${currency.format(budgeted)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(actual.categoryName, style: theme.textTheme.bodyMedium),
              Text(statusLabel,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: statusColor)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({required this.actual, required this.currency});

  final BudgetActual actual;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(actual.categoryName,
                style: theme.textTheme.bodyMedium),
          ),
          Text(
            currency.format(actual.actual),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
