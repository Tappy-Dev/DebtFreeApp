import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/shared/widgets/empty_state_card.dart';
import 'package:debt_free_app/shared/widgets/app_shell_scaffold.dart';
import 'package:debt_free_app/shared/widgets/preview_month_badge.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({
    super.key,
    this.repository,
  });

  final SessionFinancialRepository? repository;

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  late final SessionFinancialRepository _repository;
  final _currency = NumberFormat.currency(
    locale: 'en_GB',
    symbol: '£',
    decimalDigits: 2,
  );
  final _monthFormat = DateFormat('MMM yyyy');

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SessionFinancialRepository.instance;
    _repository.addListener(_onRepositoryChange);
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChange);
    super.dispose();
  }

  void _onRepositoryChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final referenceDate = _repository.effectiveNow;
    final debts = _repository.getDebts();
    final totalDebt =
      debts.fold(0.0, (s, d) => s + d.currentProjectedBalance(referenceDate));
    final totalInterest =
      debts.fold(0.0, (s, d) => s + d.projectedMonthlyInterest(referenceDate));
    final totalMinPayments =
      debts.fold(0.0, (s, d) => s + d.projectedMinPayment(referenceDate));
    final theme = Theme.of(context);

    // Sort by APR descending (avalanche order)
    final sorted = List.of(debts)..sort((a, b) => b.apr.compareTo(a.apr));

    return AppShellScaffold(
      title: 'Debts',
      currentIndex: 1,
      appBarActions: _repository.developerModeEnabled
          ? [
              PreviewMonthBadge(
                referenceDate: referenceDate,
                monthOffset: _repository.developerMonthOffset,
              ),
            ]
          : const <Widget>[],
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Add debt button ──
          FilledButton.icon(
            onPressed: _openNewDebtForm,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add debt'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 16),

          if (debts.isEmpty)
            const EmptyStateCard(
              title: 'No debts yet',
              message: 'Add your first debt to start building a payoff plan.',
            )
          else ...[
            // ── Summary stats ──
            Row(
              children: [
                _buildStatChip(
                  icon: Icons.account_balance_outlined,
                  label: 'Total Debt',
                  value: _currency.format(totalDebt),
                  color: theme.colorScheme.error,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  icon: Icons.trending_down,
                  label: 'Monthly Interest',
                  value: _currency.format(totalInterest),
                  color: Colors.orange,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  icon: Icons.payments_outlined,
                  label: 'Min Payments',
                  value: _currency.format(totalMinPayments),
                  color: theme.colorScheme.primary,
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Debt list ──
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
                        Icon(Icons.account_balance_outlined,
                            size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Your Debts',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...sorted.asMap().entries.map((entry) {
                      final index = entry.key;
                      final debt = entry.value;
                        final currentBal = debt.currentProjectedBalance(referenceDate);
                      final pct =
                          totalDebt > 0 ? currentBal / totalDebt : 0.0;
                        final monthlyInterest = debt.projectedMonthlyInterest(referenceDate);
                      final aprColor = debt.apr >= 30
                          ? theme.colorScheme.error
                          : debt.apr >= 20
                              ? Colors.orange
                              : Colors.green;

                      return Column(
                        children: [
                          InkWell(
                            onTap: () => context.push('/debts/${debt.id}'),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                debt.name,
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: aprColor
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${debt.apr.toStringAsFixed(1)}% APR',
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  color: aprColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme
                                                    .secondaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                debt.debtType.label,
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _currency.format(currentBal),
                                                  style: theme
                                                      .textTheme.titleSmall,
                                                ),
                                                if (debt.originalBalance !=
                                                    currentBal)
                                                  Text(
                                                    'Original: ${_currency.format(debt.originalBalance)}',
                                                    style: theme
                                                        .textTheme.labelSmall
                                                        ?.copyWith(
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                if (debt.isLoan &&
                                                    debt.loanEndDate != null)
                                                  Text(
                                                    'Ends ${_monthFormat.format(debt.loanEndDate!)}',
                                                    style: theme
                                                        .textTheme.labelSmall
                                                        ?.copyWith(
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const Spacer(),
                                            Text(
                                              '£${monthlyInterest.toStringAsFixed(2)}/mo interest',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color:
                                                    theme.colorScheme.error,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.chevron_right,
                                                size: 16,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: pct.clamp(0.0, 1.0),
                                            minHeight: 5,
                                            backgroundColor: theme.colorScheme
                                                .surfaceContainerHighest,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              aprColor.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${(pct * 100).toStringAsFixed(1)}% of total debt',
                                              style: theme
                                                  .textTheme.labelSmall
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                InkWell(
                                                  onTap: () =>
                                                      _openEditDebtForm(
                                                          debt.id),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            4),
                                                    child: Icon(
                                                        Icons.edit_outlined,
                                                        size: 16,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                InkWell(
                                                  onTap: () =>
                                                      _confirmDeleteDebt(
                                                          debt.id, debt.name),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            4),
                                                    child: Icon(
                                                        Icons.delete_outline,
                                                        size: 16,
                                                        color: theme
                                                            .colorScheme
                                                            .error),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (index < sorted.length - 1)
                            const Divider(height: 1),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Future<void> _openNewDebtForm() async {
    context.push('/debts/new');
  }

  Future<void> _openEditDebtForm(String debtId) async {
    context.push('/debts/$debtId/edit');
  }

  Future<void> _confirmDeleteDebt(String debtId, String debtName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete debt?'),
          content: Text('Remove "$debtName" from this plan?'),
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

    if (shouldDelete != true) {
      return;
    }

    _repository.deleteDebt(debtId);
    await _repository.waitForPendingWrites();
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnackBar('Debt removed.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}
