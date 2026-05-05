import 'dart:math' as math;

import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/features/debts/domain/build_debt_detail.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/shared/widgets/money_input_slider.dart';
import 'package:debt_free_app/shared/widgets/timeline_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DebtDetailScreen extends StatefulWidget {
  const DebtDetailScreen({
    super.key,
    required this.debtId,
  });

  final String debtId;

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  final _repository = SessionFinancialRepository.instance;
  double _extraPayment = 0;
  double _savedExtraPayment = 0;
  static const int _recurringExtraEndYear = 2100;

  final _currency = NumberFormat.currency(
    locale: 'en_GB',
    symbol: '£',
    decimalDigits: 2,
  );
  final _dateFormat = DateFormat('MMMM yyyy');

  DebtAccount? get _debt {
    for (final debt in _repository.getDebts()) {
      if (debt.id == widget.debtId) {
        return debt;
      }
    }
    return null;
  }

  String get _recurringExtraPaymentId => 'recurring-extra-${widget.debtId}';

  DebtExtraPayment? _recurringExtraPaymentFor(DebtAccount debt) {
    for (final extra in debt.extraPayments) {
      if (extra.id == _recurringExtraPaymentId) {
        return extra;
      }
    }
    return null;
  }

  bool _isRecurringActiveAt(DateTime month, DebtExtraPayment recurring) {
    final m = month.year * 12 + month.month;
    final s = recurring.startDate.year * 12 + recurring.startDate.month;
    final e = recurring.endDate.year * 12 + recurring.endDate.month;
    return m >= s && m <= e;
  }

  List<DebtExtraPayment> _additionalExtraPaymentsFor(DebtAccount debt) {
    return debt.extraPayments
        .where((extra) => extra.id != _recurringExtraPaymentId)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    final debt = _debt;
    final recurring = debt == null ? null : _recurringExtraPaymentFor(debt);
    if (recurring != null) {
      final effectiveMonth = DateTime(
        _repository.effectiveNow.year,
        _repository.effectiveNow.month,
      );
      final recurringActive = _isRecurringActiveAt(effectiveMonth, recurring);
      _extraPayment = recurringActive ? recurring.amount : 0;
      _savedExtraPayment = _extraPayment;
      return;
    }

    final changes = _repository.getScenarioChanges();
    for (final change in changes) {
      if (change.changeType == ChangeType.extraPayment &&
          change.debtId == widget.debtId) {
        _extraPayment = change.amount;
        _savedExtraPayment = change.amount;
        break;
      }
    }
  }

  void _applyExtraPayment() {
    final debt = _debt;
    if (debt == null) return;

    final changes = _repository.getScenarioChanges();
    final updated = <ScenarioChange>[
      ...changes.where((c) =>
          c.changeType != ChangeType.extraPayment ||
          c.debtId != widget.debtId),
      if (_extraPayment > 0)
        ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: _extraPayment,
          startMonth: 0,
          debtId: widget.debtId,
        ),
    ];
    _repository.saveScenarioChanges(updated);

    final existingRecurring = _recurringExtraPaymentFor(debt);
    DateTime? appliedFrom;
    if (_extraPayment > 0) {
      final start = DateTime(
        _repository.effectiveNow.year,
        _repository.effectiveNow.month,
      );
      appliedFrom = start;
      _repository.saveDebtExtraPayment(
        DebtExtraPayment(
          id: _recurringExtraPaymentId,
          debtId: debt.id,
          amount: _extraPayment,
          startDate: start,
          endDate: DateTime(_recurringExtraEndYear, 12),
        ),
      );
    } else if (existingRecurring != null) {
      _repository.deleteDebtExtraPayment(existingRecurring.id, debt.id);
    }

    setState(() {
      _savedExtraPayment = _extraPayment;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_extraPayment > 0
              ? 'Extra payment of ${_currency.format(_extraPayment)}/mo applied from ${_dateFormat.format(appliedFrom!)}'
              : 'Extra payment removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final debt = _debt;
    if (debt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Debt Detail')),
        body: const Center(child: Text('Debt not found.')),
      );
    }

    final recurringExtraPayment = _recurringExtraPaymentFor(debt);
    final effectiveMonth = DateTime(
      _repository.effectiveNow.year,
      _repository.effectiveNow.month,
    );
    final recurringActive = recurringExtraPayment != null &&
        _isRecurringActiveAt(effectiveMonth, recurringExtraPayment);
    final detail = BuildDebtDetail()(
      debt: debt,
      extraPayment: _extraPayment,
      referenceDate: _repository.effectiveNow,
    );
    final theme = Theme.of(context);
    final maxSlider = math.max(debt.currentMinPayment() * 5, 500.0);
    final monthlyInterest = debt.calculateMonthlyInterest();
    final currentBal = debt.currentProjectedBalance(_repository.effectiveNow);
    final additionalExtraPayments = _additionalExtraPaymentsFor(debt);
    final aprColor = debt.apr >= 30
        ? theme.colorScheme.error
        : debt.apr >= 20
            ? Colors.orange
            : Colors.green;
    final hasUnsavedChanges = _extraPayment != _savedExtraPayment;

    return Scaffold(
      appBar: AppBar(title: Text(detail.debtName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Header stats ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Outstanding Balance',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer)),
                  const SizedBox(height: 4),
                  Text(
                    _currency.format(currentBal),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (debt.originalBalance != currentBal) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Original: ${_currency.format(debt.originalBalance)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  if (debt.startDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Balance as of ${_dateFormat.format(debt.startDate!)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  if (debt.isLoan && debt.loanEndDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Loan ends ${_dateFormat.format(debt.loanEndDate!)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildHeaderStat(
                          'APR',
                          '${detail.apr.toStringAsFixed(1)}%',
                          aprColor,
                          theme),
                      Container(
                          width: 1,
                          height: 30,
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.2)),
                      _buildHeaderStat(
                          'Monthly Interest',
                          _currency.format(monthlyInterest),
                          theme.colorScheme.error,
                          theme),
                      Container(
                          width: 1,
                          height: 30,
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.2)),
                      _buildHeaderStat(
                          'Min Payment',
                          _currency.format(detail.minimumPayment),
                          theme.colorScheme.onPrimaryContainer,
                          theme),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Payoff projection ──
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
                        Icon(Icons.calendar_today_outlined,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Payoff Projection',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildProjectionStat(
                            'Debt-free date',
                            _extraPayment > 0
                                ? detail.overpaymentPayoffDateLabel
                                : detail.payoffDateLabel,
                            theme,
                          ),
                        ),
                        Expanded(
                          child: _buildProjectionStat(
                            'Total interest',
                            _currency.format(_extraPayment > 0
                                ? detail.overpaymentTotalInterest
                                : detail.totalInterest),
                            theme,
                            isNegative: true,
                          ),
                        ),
                        Expanded(
                          child: _buildProjectionStat(
                            'Months left',
                            '${_extraPayment > 0 ? detail.overpaymentMonthsToPayoff : detail.monthsToPayoff}',
                            theme,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Balance Over Time Chart ──
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
                        Icon(Icons.show_chart_rounded,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Balance Over Time',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TimelineChart(
                      dataPoints: _extraPayment > 0
                          ? detail.overpaymentChartData
                          : detail.chartData,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Extra Payment Slider ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: hasUnsavedChanges
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: hasUnsavedChanges ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.rocket_launch_outlined,
                            size: 18, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text('Pay Extra',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the slider to set your regular monthly extra payment from now on. It updates your payoff projection and the extra debt payment used in budget totals.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (recurringExtraPayment != null && recurringActive) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Currently applied from ${_dateFormat.format(recurringExtraPayment.startDate)}.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (recurringExtraPayment != null && !recurringActive) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled to start ${_dateFormat.format(recurringExtraPayment.startDate)}. Not active in this month.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    MoneyInputSlider(
                      label: 'Extra monthly payment',
                      value: _extraPayment,
                      min: 0,
                      max: maxSlider,
                      divisions: (maxSlider / 10).round(),
                      onChanged: (double value) {
                        setState(() => _extraPayment = value);
                      },
                    ),
                    if (_extraPayment > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.savings_outlined,
                                color: Colors.green, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You save ${detail.overpaymentMonthsSaved} months',
                                    style:
                                        theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Text(
                                    '${_currency.format(detail.overpaymentInterestSaved)} less interest',
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: hasUnsavedChanges ? _applyExtraPayment : null,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(hasUnsavedChanges
                          ? 'Apply Recurring Extra Payment'
                          : 'Applied'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Additional Extra Payment Periods ──
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
                        Icon(Icons.date_range_outlined,
                            size: 18, color: theme.colorScheme.tertiary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Additional Extra Payment Periods',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 22),
                          onPressed: () => _showExtraPaymentDialog(debt),
                          tooltip: 'Add extra payment period',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    if (additionalExtraPayments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'No additional timed boosts. The slider above controls your regular recurring extra payment. Tap + to add temporary date-range boosts.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      ...additionalExtraPayments.map((ep) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_currency.format(ep.amount)}/mo',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_dateFormat.format(ep.startDate)} – ${_dateFormat.format(ep.endDate)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        size: 18,
                                        color: theme.colorScheme.primary),
                                    onPressed: () =>
                                        _showExtraPaymentDialog(debt, ep),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        size: 18,
                                        color: theme.colorScheme.error),
                                    onPressed: () {
                                      _repository.deleteDebtExtraPayment(
                                          ep.id, debt.id);
                                      setState(() {});
                                    },
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExtraPaymentDialog(DebtAccount debt, [DebtExtraPayment? existing]) {
    final amountController = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(2) : '');
    final now = _repository.effectiveNow;
    var startDate = existing?.startDate ??
      DateTime(now.year, now.month);
    var endDate = existing?.endDate ??
      DateTime(now.year, now.month + 6);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title:
                  Text(existing != null ? 'Edit Extra Payment' : 'Add Extra Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount per month (£)',
                      prefixText: '£',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start'),
                    subtitle: Text(_dateFormat.format(startDate)),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startDate = DateTime(picked.year, picked.month);
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End'),
                    subtitle: Text(_dateFormat.format(endDate)),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: endDate,
                        firstDate: startDate,
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          endDate = DateTime(picked.year, picked.month);
                        });
                      }
                    },
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
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) return;
                    final ep = DebtExtraPayment(
                      id: existing?.id ??
                          'ep-${DateTime.now().millisecondsSinceEpoch}',
                      debtId: debt.id,
                      amount: amount,
                      startDate: startDate,
                      endDate: endDate,
                    );
                    _repository.saveDebtExtraPayment(ep);
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderStat(
      String label, String value, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
            )),
      ],
    );
  }

  Widget _buildProjectionStat(String label, String value, ThemeData theme,
      {bool isNegative = false}) {
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isNegative ? theme.colorScheme.error : null,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center),
      ],
    );
  }
}
