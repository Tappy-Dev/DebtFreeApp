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
    required this.currency,
  });

  final double totalDebt;
  final String debtFreeDate;
  final double totalInterest;
  final double totalMonthlyInterest;
  final double totalMonthlyMinPayment;
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
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'Total Debt',
                    value: currency.format(totalDebt),
                    icon: Icons.account_balance_outlined,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    label: 'Debt-Free',
                    value: debtFreeDate,
                    icon: Icons.flag_outlined,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    label: 'Total Interest',
                    value: currency.format(totalInterest),
                    icon: Icons.percent_rounded,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'Monthly Interest',
                    value: currency.format(totalMonthlyInterest),
                    icon: Icons.trending_up_rounded,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    label: 'Min. Payments',
                    value: currency.format(totalMonthlyMinPayment),
                    icon: Icons.payments_outlined,
                    color: theme.colorScheme.primary,
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
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
