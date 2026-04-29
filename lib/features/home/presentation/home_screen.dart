import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/utils/financial_month.dart';
import 'package:debt_free_app/features/budget/domain/build_budget_snapshot.dart';
import 'package:debt_free_app/features/home/domain/build_home_overview.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/features/tracking/domain/build_monthly_budget_summary.dart';
import 'package:debt_free_app/features/tracking/domain/find_overdue_open_budget_period.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';
import 'package:debt_free_app/features/tracking/models/monthly_budget_summary.dart';
import 'package:debt_free_app/features/tracking/models/tracking_workflow_status.dart';
import 'package:debt_free_app/shared/widgets/app_shell_scaffold.dart';
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
  BudgetPeriod? _oldestOverdueOpenPeriod;
  bool _hasPastTrackingHistory = false;

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
    final overdue = await findOldestOverdueOpenPeriod(
      repository: _repository,
      now: _repository.effectiveNow,
      financialMonthStartDay: _repository.financialMonthStartDay,
      excludePeriodId: summary.period.id,
      appStartMonth: _repository.appStartMonth,
    );
    final allPeriods = await _repository.getBudgetPeriods();
    final hasPast = allPeriods.any((p) => p.isClosed);
    if (mounted) {
      setState(() {
        _trackingSummary = summary;
        _oldestOverdueOpenPeriod = overdue;
        _hasPastTrackingHistory = hasPast;
      });
    }
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

    final hasIncome = _repository.getIncomeSources().isNotEmpty;
    final hasDebts = _repository.getDebts().isNotEmpty;
    final hasBudgetItems = _repository.getBills().isNotEmpty ||
        _repository.getSubscriptions().isNotEmpty;
    final hasFinanceSettings =
      (_repository.appStartMonth != null &&
        _repository.appStartMonth!.isNotEmpty) ||
      _repository.financialMonthStartDay != 1;
    final hasAnyData = hasIncome || hasDebts || hasBudgetItems;
    final allSetupDone =
      hasIncome && hasBudgetItems && hasDebts && hasFinanceSettings;

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
          if (!allSetupDone) ...<Widget>[
            _SetupGuideCard(
              hasIncome: hasIncome,
              hasBudgetItems: hasBudgetItems,
              hasDebts: hasDebts,
              hasFinanceSettings: hasFinanceSettings,
              onTap: (route) => context.push(route),
            ),
            const SizedBox(height: 16),
          ],
          if (hasAnyData) ...<Widget>[
            if (_oldestOverdueOpenPeriod != null) ...<Widget>[
              _OverdueMonthNoticeCard(
                period: _oldestOverdueOpenPeriod!,
                financialMonthStartDay: _repository.financialMonthStartDay,
                onReview: () => context.push(
                  '/tracking?month=${_oldestOverdueOpenPeriod!.id}',
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_trackingSummary != null && !_trackingSummary!.period.isClosed) ...<Widget>[
              Builder(builder: (context) {
                final s = _trackingSummary!;
                final repo = _repository;
                final currentKey = repo.currentMonthKeyWithStartDay();
                final summaryKey = '${s.period.year}-${s.period.month.toString().padLeft(2, '0')}';
                final status = buildTrackingWorkflowStatus(
                  summary: s,
                  now: repo.effectiveNow,
                  financialMonthStartDay: repo.financialMonthStartDay,
                  isCurrentPeriod: summaryKey == currentKey,
                  hasAnyPastPeriodActivity: _hasPastTrackingHistory,
                );
                if (!status.showOnDashboard) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TrackingWorkflowReminderCard(
                      summary: s,
                      onOpenTracking: () => context.push('/tracking'),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),
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
          ],
          if (overview.mortgage != null) ...<Widget>[
            _MortgageSummaryCard(
              mortgageCount: overview.mortgageCount,
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

class _OverdueMonthNoticeCard extends StatelessWidget {
  const _OverdueMonthNoticeCard({
    required this.period,
    required this.financialMonthStartDay,
    required this.onReview,
  });

  final BudgetPeriod period;
  final int financialMonthStartDay;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = FinancialMonth.startDate(period.year, period.month, financialMonthStartDay);
    final end = FinancialMonth.endDate(period.year, period.month, financialMonthStartDay);
    final periodLabel = financialMonthStartDay <= 1
        ? FinancialMonth.periodLabel(period.year, period.month, financialMonthStartDay)
        : '${start.day} ${DateFormat('MMM').format(start)} – ${end.day} ${DateFormat('MMM').format(end)} ${end.year}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.withValues(alpha: 0.18),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 20, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Previous month still open',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$periodLabel has ended and is still open. Close it to lock results before finalising newer months.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onReview,
                icon: const Icon(Icons.checklist_rounded, size: 18),
                label: const Text('Review & close month'),
              ),
            ],
          ),
        ),
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
    final carriedForward = trackingSummary?.period.carriedForwardBalance ?? 0.0;
    final remaining =
        budgetedRemaining + carriedForward - trackableOverspend - extraExpenses - extraDebtPayment;
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingWorkflowReminderCard extends StatelessWidget {
  const _TrackingWorkflowReminderCard({
    required this.summary,
    required this.onOpenTracking,
  });

  final MonthlyBudgetSummary summary;
  final VoidCallback onOpenTracking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = SessionFinancialRepository.instance;
    final currentKey = repo.currentMonthKeyWithStartDay();
    final summaryKey = '${summary.period.year}-${summary.period.month.toString().padLeft(2, '0')}';
    final status = buildTrackingWorkflowStatus(
      summary: summary,
      now: repo.effectiveNow,
      financialMonthStartDay: repo.financialMonthStartDay,
      isCurrentPeriod: summaryKey == currentKey,
      hasAnyPastPeriodActivity: false,
    );
    final (icon, accentColor) = _workflowPresentation(theme, status.stage);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor.withValues(alpha: 0.16),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
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
                      style: theme.textTheme.titleMedium,
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _WorkflowPill(
                    label: 'Trackable',
                    value: '${status.trackableStartedCount}/${status.trackableTotalCount}',
                  ),
                  _WorkflowPill(
                    label: 'Extra items',
                    value: '${status.extraExpenseCount}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onOpenTracking,
                icon: const Icon(Icons.checklist_rounded, size: 18),
                label: Text(status.canCloseMonth ? 'Review in Tracking' : 'Open Tracking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(IconData, Color) _workflowPresentation(ThemeData theme, TrackingWorkflowStage stage) {
  switch (stage) {
    case TrackingWorkflowStage.gettingStarted:
      return (Icons.play_circle_outline_rounded, theme.colorScheme.primary);
    case TrackingWorkflowStage.inProgress:
      return (Icons.timeline_rounded, theme.colorScheme.tertiary);
    case TrackingWorkflowStage.readyToClose:
      return (Icons.task_alt_rounded, Colors.orange.shade700);
    case TrackingWorkflowStage.overdue:
      return (Icons.notification_important_outlined, theme.colorScheme.error);
    case TrackingWorkflowStage.closed:
      return (Icons.lock_outline_rounded, Colors.green.shade700);
  }
}

class _WorkflowPill extends StatelessWidget {
  const _WorkflowPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
}

class _MortgageSummaryCard extends StatelessWidget {
  const _MortgageSummaryCard({
    required this.mortgageCount,
    required this.balance,
    required this.monthlyPayment,
    required this.annualRate,
    required this.payoffLabel,
    required this.totalInterest,
    required this.onTap,
  });

  final int mortgageCount;
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
                  Text(
                    mortgageCount > 1 ? 'Mortgages' : 'Mortgage',
                    style: theme.textTheme.titleLarge,
                  ),
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
                      label: mortgageCount > 1 ? 'Avg Rate' : 'Rate',
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

class _SetupGuideCard extends StatelessWidget {
  const _SetupGuideCard({
    required this.hasIncome,
    required this.hasBudgetItems,
    required this.hasDebts,
    required this.hasFinanceSettings,
    required this.onTap,
  });

  final bool hasIncome;
  final bool hasBudgetItems;
  final bool hasDebts;
  final bool hasFinanceSettings;
  final void Function(String route) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final steps = <Widget>[];
    if (!hasIncome) {
      steps.add(_SetupStep(
        icon: Icons.attach_money_rounded,
        title: 'Add your income',
        description: 'So we can calculate how much cash you have each month.',
        route: '/budget/income/new',
        onTap: onTap,
      ));
    }
    if (!hasBudgetItems) {
      if (steps.isNotEmpty) steps.add(const SizedBox(height: 12));
      steps.add(_SetupStep(
        icon: Icons.receipt_long_outlined,
        title: 'Add your bills & expenses',
        description: 'Regular outgoings so your remaining cash is accurate.',
        route: '/budget',
        onTap: onTap,
      ));
    }
    if (!hasDebts) {
      if (steps.isNotEmpty) steps.add(const SizedBox(height: 12));
      steps.add(_SetupStep(
        icon: Icons.credit_card_outlined,
        title: 'Add a debt',
        description: 'Credit cards, loans or any balance you want to pay off.',
        route: '/debts',
        onTap: onTap,
      ));
    }
    if (!hasFinanceSettings) {
      if (steps.isNotEmpty) steps.add(const SizedBox(height: 12));
      steps.add(_SetupStep(
        icon: Icons.tune_rounded,
        title: 'Set up finance settings',
        description:
            'Set budget start month and financial month start day for accurate periods.',
        route: '/settings/finance',
        onTap: onTap,
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rocket_launch_outlined, color: cs.primary, size: 22),
                const SizedBox(width: 10),
                Text('Get started', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Complete these steps to unlock your personalised debt payoff forecast and monthly budget overview.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ...steps,
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.help_outline_rounded,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Not sure where to start? Tap the ? button above.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String route;
  final void Function(String route) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onTap(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
