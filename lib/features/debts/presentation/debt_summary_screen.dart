import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/features/home/domain/build_home_overview.dart';
import 'package:debt_free_app/features/home/domain/home_overview.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/shared/widgets/preview_month_badge.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DebtSummaryScreen extends StatefulWidget {
  const DebtSummaryScreen({super.key});

  @override
  State<DebtSummaryScreen> createState() => _DebtSummaryScreenState();
}

class _DebtSummaryScreenState extends State<DebtSummaryScreen> {
  final _repository = SessionFinancialRepository.instance;
  late HomeOverview _overview;

  final _currency =
      NumberFormat.currency(locale: 'en_GB', symbol: '\u00A3', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepositoryChange);
    _overview = BuildHomeOverview(
      repository: _repository,
      referenceDate: _repository.effectiveNow,
    )();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChange);
    super.dispose();
  }

  void _onRepositoryChange() {
    if (!mounted) return;
    setState(() {
      _overview = BuildHomeOverview(
        repository: _repository,
        referenceDate: _repository.effectiveNow,
      )();
    });
  }

  @override
  Widget build(BuildContext context) {
    final referenceDate = _repository.effectiveNow;
    final theme = Theme.of(context);
    final debts = _repository.getDebts();
    final totalDebt = debts.fold<double>(
      0,
      (sum, d) => sum + d.currentProjectedBalance(referenceDate),
    );
    final previousMonthDate = DateTime(referenceDate.year, referenceDate.month - 1);
    final previousMonthTotalDebt = debts.fold<double>(
      0,
      (sum, d) => sum + d.currentProjectedBalance(previousMonthDate),
    );
    final debtChangeVsLastMonth = previousMonthTotalDebt - totalDebt;
    final totalOriginalDebt = debts.fold<double>(
      0,
      (sum, d) => sum + d.originalBalance,
    );
    final totalRepaid = (totalOriginalDebt - totalDebt).clamp(0.0, double.infinity);
    final repaidProgress = totalOriginalDebt <= 0
        ? 0.0
        : (totalRepaid / totalOriginalDebt).clamp(0.0, 1.0);

    // Sort debts by APR descending (avalanche order)
    final sortedDebts = List<DebtAccount>.from(debts)
      ..sort((a, b) => b.apr.compareTo(a.apr));

    final totalMonthlyInterest = debts.fold<double>(
      0.0,
      (sum, d) => sum + d.projectedMonthlyInterest(referenceDate),
    );
    final totalMonthlyMinPayment = debts.fold<double>(
      0.0,
      (sum, d) => sum + d.projectedMinPayment(referenceDate),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt Summary'),
        actions: _repository.developerModeEnabled
            ? [
                PreviewMonthBadge(
                  referenceDate: referenceDate,
                  monthOffset: _repository.developerMonthOffset,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Overview stats ──
            _OverviewCard(
              totalDebt: totalDebt,
              debtFreeDate: _overview.debtFreeDateLabel,
              totalInterest: _overview.interestProjection,
              totalMonthlyInterest: totalMonthlyInterest,
              totalMonthlyMinPayment: totalMonthlyMinPayment,
              debtChangeVsLastMonth: debtChangeVsLastMonth,
              totalRepaid: totalRepaid,
              totalOriginalDebt: totalOriginalDebt,
              repaidProgress: repaidProgress,
              currency: _currency,
            ),
            const SizedBox(height: 16),

            // ── Avalanche repayment order ──
            _RepaymentOrderCard(
              debts: sortedDebts,
              totalDebt: totalDebt,
              referenceDate: referenceDate,
              currency: _currency,
              onDebtTap: (debt) => context.push('/debts/${debt.id}?from=summary'),
            ),
            const SizedBox(height: 16),

            // ── Strategy info ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Using the Avalanche strategy: debts are targeted highest APR first to minimise interest paid overall.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overview card ────────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.totalDebt,
    required this.debtFreeDate,
    required this.totalInterest,
    required this.totalMonthlyInterest,
    required this.totalMonthlyMinPayment,
    required this.debtChangeVsLastMonth,
    required this.totalRepaid,
    required this.totalOriginalDebt,
    required this.repaidProgress,
    required this.currency,
  });

  final double totalDebt;
  final String debtFreeDate;
  final double totalInterest;
  final double totalMonthlyInterest;
  final double totalMonthlyMinPayment;
  final double debtChangeVsLastMonth;
  final double totalRepaid;
  final double totalOriginalDebt;
  final double repaidProgress;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
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
                Text('Overview', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 480;

                final totalDebtPanel = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_outlined,
                            size: 16,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Total Debt',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            currency.format(totalDebt),
                            maxLines: 1,
                            softWrap: false,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                final metricRows = Column(
                  children: [
                    _MetricRowCard(
                      icon: Icons.flag_outlined,
                      label: 'Debt-Free',
                      value: debtFreeDate,
                      valueColor: Colors.green,
                      infoText:
                          'The projected date when all your debts will be fully paid off, based on your current balances, minimum payments, and repayment strategy.',
                    ),
                    const SizedBox(height: 8),
                    _MetricRowCard(
                      icon: Icons.percent_rounded,
                      label: 'Total Interest',
                      value: currency.format(totalInterest),
                      valueColor: Colors.orange,
                      infoText:
                          'The total amount of interest you are projected to pay across all your debts from now until they are fully cleared.',
                    ),
                    const SizedBox(height: 8),
                    _MetricRowCard(
                      icon: Icons.trending_up_rounded,
                      label: 'Monthly Interest',
                      value: currency.format(totalMonthlyInterest),
                      valueColor: theme.colorScheme.error,
                      infoText:
                          'How much interest is being added to your debts each month at your current balances and rates. Reducing this quickly saves the most money.',
                    ),
                    const SizedBox(height: 8),
                    _MetricRowCard(
                      icon: Icons.payments_outlined,
                      label: 'Min. Payments',
                      value: currency.format(totalMonthlyMinPayment),
                      valueColor: theme.colorScheme.primary,
                      infoText:
                          'The total of all minimum monthly payments required across your debts. Paying more than this each month will clear your debt faster.',
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    children: [
                      totalDebtPanel,
                      const SizedBox(height: 10),
                      metricRows,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: totalDebtPanel),
                    const SizedBox(width: 10),
                    Expanded(flex: 6, child: metricRows),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        debtChangeVsLastMonth >= 0
                            ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        size: 16,
                        color: debtChangeVsLastMonth >= 0
                            ? Colors.green
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        debtChangeVsLastMonth >= 0
                            ? 'Down ${currency.format(debtChangeVsLastMonth)} vs last month'
                            : 'Up ${currency.format(-debtChangeVsLastMonth)} vs last month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: debtChangeVsLastMonth >= 0
                              ? Colors.green.shade700
                              : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Repaid ${currency.format(totalRepaid)} of ${currency.format(totalOriginalDebt)}',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        '${(repaidProgress * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: repaidProgress,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Repayment order card ──────────────────────────────────────────────────────

class _RepaymentOrderCard extends StatelessWidget {
  const _RepaymentOrderCard({
    required this.debts,
    required this.totalDebt,
    required this.referenceDate,
    required this.currency,
    required this.onDebtTap,
  });

  final List<DebtAccount> debts;
  final double totalDebt;
  final DateTime referenceDate;
  final NumberFormat currency;
  final void Function(DebtAccount) onDebtTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_list_numbered_rounded,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Repayment Order', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Highest APR targeted first',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ...debts.asMap().entries.map((entry) {
              final index = entry.key;
              final debt = entry.value;
              final balance = debt.currentProjectedBalance(referenceDate);
              final pct = totalDebt > 0 ? balance / totalDebt : 0.0;
              final monthlyInterest = debt.projectedMonthlyInterest(referenceDate);
              return _DebtOrderTile(
                order: index + 1,
                debt: debt,
                balance: balance,
                pct: pct,
                monthlyInterest: monthlyInterest,
                currency: currency,
                onTap: () => onDebtTap(debt),
                isLast: index == debts.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DebtOrderTile extends StatelessWidget {
  const _DebtOrderTile({
    required this.order,
    required this.debt,
    required this.balance,
    required this.pct,
    required this.monthlyInterest,
    required this.currency,
    required this.onTap,
    required this.isLast,
  });

  final int order;
  final DebtAccount debt;
  final double balance;
  final double pct;
  final double monthlyInterest;
  final NumberFormat currency;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aprColor = debt.apr >= 30
        ? theme.colorScheme.error
        : debt.apr >= 20
            ? Colors.orange
            : Colors.green;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                // Order badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$order',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              debt.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: aprColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${debt.apr.toStringAsFixed(1)}% APR',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: aprColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            currency.format(balance),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '£${monthlyInterest.toStringAsFixed(2)}/mo interest',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              aprColor.withValues(alpha: 0.7)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(pct * 100).toStringAsFixed(1)}% of total debt',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _MetricRowCard extends StatelessWidget {
  const _MetricRowCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.valueColor,
    this.infoText,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;
  final String? infoText;

  void _showInfo(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, size: 18, color: valueColor),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        content: Text(
          infoText!,
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: valueColor.withValues(alpha: 0.12),
            child: Icon(icon, size: 14, color: valueColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (infoText != null) ...
            [
              const SizedBox(width: 2),
              GestureDetector(
                onTap: () => _showInfo(context),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
        ],
      ),
    );
  }
}
