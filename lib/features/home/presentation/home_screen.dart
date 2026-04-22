import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/utils/financial_month.dart';
import 'package:debt_free_app/features/budget/domain/build_budget_snapshot.dart';
import 'package:debt_free_app/features/home/domain/build_home_overview.dart';
import 'package:debt_free_app/features/home/domain/home_overview.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/features/tracking/domain/build_monthly_budget_summary.dart';
import 'package:debt_free_app/features/tracking/models/monthly_budget_summary.dart';
import 'package:debt_free_app/shared/widgets/app_shell_scaffold.dart';
import 'package:debt_free_app/shared/widgets/empty_state_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.repository,
  });

  final SessionFinancialRepository? repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SessionFinancialRepository _repository;
  MonthlyBudgetSummary? _trackingSummary;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SessionFinancialRepository.instance;
    _repository.addListener(_onRepositoryChange);
    _loadTracking();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChange);
    super.dispose();
  }

  void _onRepositoryChange() {
    if (mounted) {
      _loadTracking();
    }
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
    final overview = BuildHomeOverview(
      repository: _repository,
      referenceDate: _repository.effectiveNow,
    )();
    final snapshot = BuildBudgetSnapshot(_repository)();
    final currency = NumberFormat.currency(
        locale: 'en_GB', symbol: '\u00A3', decimalDigits: 2);

    return AppShellScaffold(
      title: 'Debt Free',
      currentIndex: 0,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text('Summary',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 16),
          if (_repository.getDebts().isEmpty) ...<Widget>[
            const EmptyStateCard(
              title: 'Start with your first debt',
              message: 'Add a debt and some budget details to unlock a more useful payoff forecast.',
            ),
            const SizedBox(height: 16),
          ],
          _MonthlySummaryCard(
            snapshot: snapshot,
            trackingSummary: _trackingSummary,
            extraDebtPayment: _repository.getScenarioChanges()
                .where((c) => c.changeType == ChangeType.extraPayment)
                .fold(0.0, (sum, c) => sum + c.amount),
            currency: currency,
            onTap: () => context.push('/monthly-summary'),
          ),
          const SizedBox(height: 16),
          _DebtSnapshotCard(
            totalDebt: overview.totalDebt,
            debtFreeDate: overview.debtFreeDateLabel,
            interestProjection: overview.interestProjection,
            debtChangeFromPreviousMonth: overview.debtChangeFromPreviousMonth,
            currency: currency,
            onTap: () => context.push('/debt-summary'),
          ),
          const SizedBox(height: 16),
          if (overview.mortgage != null) ...<Widget>[
            _MortgageSummaryCard(
              balance: overview.mortgage!.balance,
              monthlyPayment: overview.mortgage!.monthlyPayment,
              annualRate: overview.mortgage!.annualRate,
              payoffLabel: overview.mortgagePayoffLabel ?? 'N/A',
              totalInterest: overview.mortgageTotalInterest ?? 0,
              onTap: () => context.push('/mortgage'),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _DebtSnapshotCard extends StatelessWidget {
  const _DebtSnapshotCard({
    required this.totalDebt,
    required this.debtFreeDate,
    required this.interestProjection,
    required this.debtChangeFromPreviousMonth,
    required this.currency,
    required this.onTap,
  });

  final double totalDebt;
  final String debtFreeDate;
  final double interestProjection;
  final double debtChangeFromPreviousMonth;
  final NumberFormat currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = debtChangeFromPreviousMonth;
    final hasReduction = delta > 0;
    final deltaLabel = hasReduction
      ? '${currency.format(delta.abs())} lower vs previous month'
      : delta < 0
        ? '${currency.format(delta.abs())} higher vs previous month'
        : 'No change vs previous month';
    final deltaColor = hasReduction
      ? Colors.green
      : delta < 0
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_down_rounded,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Debt Summary',
                      style: theme.textTheme.titleLarge),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DebtStatChip(
                    label: 'Total Debt',
                    value: currency.format(totalDebt),
                    icon: Icons.account_balance_outlined,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DebtStatChip(
                    label: 'Debt-Free',
                    value: debtFreeDate,
                    icon: Icons.flag_outlined,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DebtStatChip(
                    label: 'Total Interest',
                    value: currency.format(interestProjection),
                    icon: Icons.percent_rounded,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  hasReduction
                      ? Icons.arrow_downward_rounded
                      : delta < 0
                          ? Icons.arrow_upward_rounded
                          : Icons.remove_rounded,
                  size: 16,
                  color: deltaColor,
                ),
                const SizedBox(width: 6),
                Text(
                  deltaLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: deltaColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _DebtStatChip extends StatelessWidget {
  const _DebtStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({
    required this.snapshot,
    required this.currency,
    required this.onTap,
    this.trackingSummary,
    this.extraDebtPayment = 0,
  });

  final dynamic snapshot;
  final MonthlyBudgetSummary? trackingSummary;
  final double extraDebtPayment;
  final NumberFormat currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackableOverspend = trackingSummary == null
        ? 0.0
        : trackingSummary!.trackableExpenseActuals.fold(0.0, (sum, a) {
            final over = a.actual - a.budgeted;
            return sum + (over > 0 ? over : 0.0);
          });
    final extraExpenses = trackingSummary == null
        ? 0.0
        : trackingSummary!.extraExpenseActuals
            .fold(0.0, (sum, a) => sum + a.actual);
    final budgetedRemaining = snapshot.remainingCash as double;
    final remaining =
        budgetedRemaining - trackableOverspend - extraExpenses - extraDebtPayment;
    final income = snapshot.totalIncome as double;
    final spentPct =
        income > 0 ? ((income - remaining) / income).clamp(0.0, 1.0) : 0.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(builder: (context) {
                      final repo = SessionFinancialRepository.instance;
                      final startDay = repo.financialMonthStartDay;
                      if (startDay > 1) {
                        final key = repo.currentMonthKeyWithStartDay();
                        final (y, m) = FinancialMonth.parseKey(key);
                        return Text(
                            FinancialMonth.periodLabel(y, m, startDay),
                            style: theme.textTheme.titleLarge);
                      }
                      return Text('Monthly Summary',
                          style: theme.textTheme.titleLarge);
                    }),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 16),

              // ── Remaining cash highlight ──
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: remaining < 0
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
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
                      currency.format(remaining),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: remaining < 0
                            ? theme.colorScheme.onErrorContainer
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: spentPct,
                        minHeight: 6,
                        backgroundColor: remaining < 0
                            ? theme.colorScheme.error.withValues(alpha: 0.3)
                            : theme.colorScheme.primary.withValues(alpha: 0.25),
                        valueColor: AlwaysStoppedAnimation<Color>(remaining < 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Condensed stat chips ──
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'Income',
                      value: currency.format(income),
                      icon: Icons.arrow_downward_rounded,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatChip(
                      label: 'Bills',
                      value: currency.format(snapshot.totalBills),
                      icon: Icons.receipt_long_outlined,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatChip(
                      label: 'Expenses',
                      value: currency.format(snapshot.totalExpenses),
                      icon: Icons.shopping_bag_outlined,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              )),
        ],
      ),
    );
  }
}

class _MortgageSummaryCard extends StatelessWidget {
  const _MortgageSummaryCard({
    required this.balance,
    required this.monthlyPayment,
    required this.annualRate,
    required this.payoffLabel,
    required this.totalInterest,
    required this.onTap,
  });

  final double balance;
  final double monthlyPayment;
  final double annualRate;
  final String payoffLabel;
  final double totalInterest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '£', decimalDigits: 2);
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Icon(Icons.home_outlined,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Mortgage', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 16),

              // ── Balance highlight ──
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding Balance',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(balance),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Stat chips row 1 ──
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'Monthly',
                      value: currency.format(monthlyPayment),
                      icon: Icons.payments_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatChip(
                      label: 'Rate',
                      value: '${annualRate.toStringAsFixed(2)}%',
                      icon: Icons.percent_rounded,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Stat chips row 2 ──
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'Payoff',
                      value: payoffLabel,
                      icon: Icons.flag_outlined,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatChip(
                      label: 'Total Interest',
                      value: currency.format(totalInterest),
                      icon: Icons.trending_up_rounded,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForecastTable extends StatelessWidget {
  const _ForecastTable({
    required this.forecasts,
    required this.showMortgage,
  });

  final List<MonthForecast> forecasts;
  final bool showMortgage;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '£', decimalDigits: 0);
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(1.6),
        3: FlexColumnWidth(1.6),
      },
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.8,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('', style: headerStyle),
            ),
            for (final f in forecasts)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(f.label, style: headerStyle, textAlign: TextAlign.right),
              ),
          ],
        ),
        _dataRow(
          label: 'Cash left',
          values: forecasts.map((f) => currency.format(f.cashLeft)).toList(),
          labelStyle: labelStyle,
          theme: theme,
          highlight: true,
        ),
        _dataRow(
          label: 'Debt interest',
          values: forecasts.map((f) => currency.format(f.debtInterest)).toList(),
          labelStyle: labelStyle,
          theme: theme,
        ),
        if (showMortgage)
          _dataRow(
            label: 'Mortgage interest',
            values: forecasts
                .map((f) => f.mortgageInterest != null
                    ? currency.format(f.mortgageInterest!)
                    : '—')
                .toList(),
            labelStyle: labelStyle,
            theme: theme,
          ),
        _dataRow(
          label: 'Debt balance',
          values: forecasts.map((f) => currency.format(f.debtBalance)).toList(),
          labelStyle: labelStyle,
          theme: theme,
        ),
      ],
    );
  }

  TableRow _dataRow({
    required String label,
    required List<String> values,
    TextStyle? labelStyle,
    required ThemeData theme,
    bool highlight = false,
  }) {
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
    );
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(label, style: labelStyle),
        ),
        for (final v in values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(v, style: valueStyle, textAlign: TextAlign.right),
          ),
      ],
    );
  }
}
