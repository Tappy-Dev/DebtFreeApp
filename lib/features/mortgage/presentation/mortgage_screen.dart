import 'dart:math' as math;

import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/utils/amount_parser.dart';
import 'package:debt_free_app/features/mortgage/domain/build_mortgage_detail.dart';
import 'package:debt_free_app/features/mortgage/domain/mortgage_detail.dart';
import 'package:debt_free_app/features/simulation/engine/mortgage_projection_engine.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/shared/widgets/money_input_slider.dart';
import 'package:debt_free_app/shared/widgets/preview_month_badge.dart';
import 'package:debt_free_app/shared/widgets/timeline_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MortgageScreen extends StatefulWidget {
  const MortgageScreen({super.key});

  @override
  State<MortgageScreen> createState() => _MortgageScreenState();
}

class _MortgageScreenState extends State<MortgageScreen> {
  final _repository = SessionFinancialRepository.instance;
  double _extraOverpayment = 0;
  MortgageDetail? _detail;
  final _currencyFormat = NumberFormat.currency(symbol: '£', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepositoryChange);
    _extraOverpayment = _repository.getMortgage()?.overpayment ?? 0;
    _recalculate();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChange);
    super.dispose();
  }

  void _onRepositoryChange() {
    if (!mounted) return;
    _recalculate();
    setState(() {});
  }

  void _recalculate() {
    final mortgage = _repository.getMortgage();
    if (mortgage == null) {
      _detail = null;
      return;
    }
    final referenceDate = _repository.effectiveNow;
    final displayedMortgage = _projectMortgageForReference(
      mortgage,
      referenceDate,
    );
    _detail = BuildMortgageDetail().call(
      mortgage: displayedMortgage,
      extraOverpayment: _extraOverpayment,
      referenceDate: referenceDate,
    );
  }

  Mortgage _projectMortgageForReference(
    Mortgage mortgage,
    DateTime referenceDate,
  ) {
    final now = DateTime.now();
    final monthOffset =
        (referenceDate.year - now.year) * 12 + (referenceDate.month - now.month);
    if (monthOffset <= 0) {
      return mortgage;
    }

    final result = MortgageProjectionEngine().simulate(
      mortgage,
      startDate: DateTime(now.year, now.month),
    );
    if (result.monthlyBreakdown.isEmpty) {
      return mortgage;
    }

    final index = math.min(monthOffset - 1, result.monthlyBreakdown.length - 1);
    final month = result.monthlyBreakdown[index];
    final remainingTerm = math.max(0, mortgage.remainingTermMonths - monthOffset);

    return mortgage.copyWith(
      balance: month.balanceRemaining,
      remainingTermMonths: remainingTerm,
    );
  }

  void _applyOverpayment() {
    final mortgage = _repository.getMortgage();
    if (mortgage == null) return;
    _repository.saveMortgage(mortgage.copyWith(overpayment: _extraOverpayment));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _extraOverpayment > 0
              ? 'Monthly overpayment of £${_extraOverpayment.toStringAsFixed(0)} applied'
              : 'Overpayment cleared',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mortgage = _repository.getMortgage();
    final referenceDate = _repository.effectiveNow;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mortgage'),
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: mortgage == null ? _buildEmptyState(context) : _buildDetail(context),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.home_outlined, size: 48,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('No mortgage added yet',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Add your mortgage details to track overpayments.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _showAddMortgageDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Mortgage'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context) {
    final theme = Theme.of(context);
    final detail = _detail!;

    return ListView(
      children: <Widget>[
        // ── Overview Card ──
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.home_outlined,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Mortgage Overview',
                          style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _showAddMortgageDialog(context),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: _confirmDelete,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Balance banner ──
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
                      Text('Outstanding Balance',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          )),
                      const SizedBox(height: 4),
                      Text(_currencyFormat.format(detail.balance),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Stat chips row 1 ──
                Row(
                  children: [
                    Expanded(
                      child: _MortgageStatChip(
                        label: 'Interest Rate',
                        value: '${detail.annualRate.toStringAsFixed(2)}%',
                        icon: Icons.percent_rounded,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MortgageStatChip(
                        label: 'Monthly Payment',
                        value: _currencyFormat.format(detail.monthlyPayment),
                        icon: Icons.payments_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Stat chips row 2 ──
                Row(
                  children: [
                    Expanded(
                      child: _MortgageStatChip(
                        label: 'Remaining Term',
                        value: _formatTerm(detail.remainingTermMonths),
                        icon: Icons.timelapse_rounded,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MortgageStatChip(
                        label: 'Payoff Date',
                        value: detail.payoffDateLabel,
                        icon: Icons.flag_outlined,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Total interest chip (full width) ──
                _MortgageStatChip(
                  label: 'Total Interest',
                  value: _currencyFormat.format(detail.totalInterest),
                  icon: Icons.trending_up_rounded,
                  color: theme.colorScheme.error,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Balance Over Time Chart ──
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    Icon(Icons.show_chart_rounded,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Balance Over Time',
                        style: theme.textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: TimelineChart(
                    dataPoints: _extraOverpayment > 0
                        ? detail.overpaymentChartData
                        : detail.chartData,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Overpayment Slider ──
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    Icon(Icons.savings_outlined,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Overpayment Simulator',
                        style: theme.textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 16),
                MoneyInputSlider(
                  label: 'Monthly overpayment',
                  value: _extraOverpayment,
                  min: 0,
                  max: 500,
                  onChanged: (double value) {
                    setState(() {
                      _extraOverpayment = value;
                      _recalculate();
                    });
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _applyOverpayment,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Apply'),
                  ),
                ),
                if (_extraOverpayment > 0) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.eco_outlined,
                                size: 18, color: Colors.green),
                            const SizedBox(width: 6),
                            Text('Savings Breakdown',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SavingsChip(
                                label: 'Months Saved',
                                value:
                                    '${detail.overpaymentMonthsSaved}',
                                icon: Icons.calendar_today_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SavingsChip(
                                label: 'Interest Saved',
                                value: _currencyFormat
                                    .format(detail.overpaymentInterestSaved),
                                icon: Icons.savings_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _SavingsChip(
                                label: 'New Payoff',
                                value: detail.overpaymentPayoffDateLabel,
                                icon: Icons.event_available_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SavingsChip(
                                label: 'New Term',
                                value: _formatTerm(
                                    detail.overpaymentMonthsToPayoff),
                                icon: Icons.timelapse_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Info Card ──
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline_rounded,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('About mortgage overpayments',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                        'Most UK mortgage lenders allow overpayments of up to 10% '
                        'of the outstanding balance per year without an early '
                        'repayment charge. Check your mortgage terms before '
                        'overpaying.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddMortgageDialog(BuildContext context) {
    final existing = _repository.getMortgage();
    final nameController = TextEditingController(
      text: existing?.name ?? 'Mortgage',
    );
    final balanceController = TextEditingController(
      text: existing != null ? existing.balance.toStringAsFixed(2) : '',
    );
    final rateController = TextEditingController(
      text: existing != null ? existing.annualRate.toStringAsFixed(2) : '',
    );
    final paymentController = TextEditingController(
      text: existing != null ? existing.monthlyPayment.toStringAsFixed(2) : '',
    );
    final termController = TextEditingController(
      text: existing != null ? existing.remainingTermMonths.toString() : '',
    );

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(existing != null ? 'Edit Mortgage' : 'Add Mortgage'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: balanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Outstanding balance',
                    prefixText: '£',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Annual interest rate (%)',
                    suffixText: '%',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: paymentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monthly payment',
                    prefixText: '£',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: termController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Remaining term (months)',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final balance = AmountParser.tryParse(balanceController.text);
                final rate = double.tryParse(rateController.text.trim());
                final payment = AmountParser.tryParse(paymentController.text);
                final term = int.tryParse(termController.text.trim());
                if (name.isEmpty ||
                    balance == null ||
                    rate == null ||
                    payment == null ||
                    term == null) {
                  return;
                }

                _repository.saveMortgage(Mortgage(
                  id: existing?.id ?? 'mortgage',
                  name: name,
                  balance: balance,
                  annualRate: rate,
                  monthlyPayment: payment,
                  remainingTermMonths: term,
                ));
                Navigator.pop(dialogContext);
              },
              child: Text(existing != null ? 'Update' : 'Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete mortgage?'),
          content: const Text('This will remove your mortgage from the app.'),
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
    if (shouldDelete == true) {
      _repository.deleteMortgage();
    }
  }

  String _formatTerm(int months) {
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (years == 0) return '$remainingMonths months';
    if (remainingMonths == 0) return '$years years';
    return '$years years $remainingMonths months';
  }
}

class _MortgageStatChip extends StatelessWidget {
  const _MortgageStatChip({
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

class _SavingsChip extends StatelessWidget {
  const _SavingsChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.green),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.green),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              )),
        ],
      ),
    );
  }
}
