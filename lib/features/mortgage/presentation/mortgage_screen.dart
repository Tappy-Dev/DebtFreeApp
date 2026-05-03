import 'dart:math' as math;

import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/utils/amount_parser.dart';
import 'package:debt_free_app/features/mortgage/domain/build_mortgage_detail.dart';
import 'package:debt_free_app/features/mortgage/domain/mortgage_detail.dart';
import 'package:debt_free_app/features/simulation/engine/mortgage_projection_engine.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/shared/widgets/money_input_slider.dart';
import 'package:debt_free_app/shared/widgets/preview_month_badge.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MortgageScreen extends StatefulWidget {
  const MortgageScreen({super.key});

  @override
  State<MortgageScreen> createState() => _MortgageScreenState();
}

class _MortgageScreenState extends State<MortgageScreen> {
  final _repository = SessionFinancialRepository.instance;
  String? _selectedMortgageId;
  double _extraOverpayment = 0;
  double _savedExtraOverpayment = 0;
  late DateTime _overpaymentApplyFrom;
  MortgageDetail? _detail;
  final _currencyFormat = NumberFormat.currency(symbol: '£', decimalDigits: 2);
  final _monthFormat = DateFormat('MMMM yyyy');

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepositoryChange);
    final mortgages = _repository.getMortgages();
    _selectedMortgageId = mortgages.isEmpty ? null : mortgages.first.id;
    final now = _repository.effectiveNow;
    _overpaymentApplyFrom = _selectedMortgage?.overpaymentStartDate ??
        DateTime(now.year, now.month);
    _extraOverpayment = _selectedMortgage?.overpayment ?? 0;
    _savedExtraOverpayment = _extraOverpayment;
    _recalculate();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChange);
    super.dispose();
  }

  void _onRepositoryChange() {
    if (!mounted) return;
    _syncSelectedMortgage();
    _recalculate();
    setState(() {});
  }

  Mortgage? get _selectedMortgage {
    final mortgages = _repository.getMortgages();
    if (_selectedMortgageId == null) {
      return mortgages.isEmpty ? null : mortgages.first;
    }
    for (final mortgage in mortgages) {
      if (mortgage.id == _selectedMortgageId) {
        return mortgage;
      }
    }
    return mortgages.isEmpty ? null : mortgages.first;
  }

  void _syncSelectedMortgage() {
    final mortgages = _repository.getMortgages();
    final now = _repository.effectiveNow;
    if (mortgages.isEmpty) {
      _selectedMortgageId = null;
      _extraOverpayment = 0;
      _savedExtraOverpayment = 0;
      _overpaymentApplyFrom = DateTime(now.year, now.month);
      return;
    }
    final stillExists = mortgages.any((m) => m.id == _selectedMortgageId);
    if (!stillExists) {
      _selectedMortgageId = mortgages.first.id;
      _extraOverpayment = mortgages.first.overpayment;
      _savedExtraOverpayment = _extraOverpayment;
      _overpaymentApplyFrom = mortgages.first.overpaymentStartDate ??
          DateTime(now.year, now.month);
      return;
    }
    final selected = _selectedMortgage;
    if (selected != null) {
      _extraOverpayment = selected.overpayment;
      _savedExtraOverpayment = _extraOverpayment;
      _overpaymentApplyFrom = selected.overpaymentStartDate ??
          DateTime(now.year, now.month);
    }
  }

  void _recalculate() {
    final mortgage = _selectedMortgage;
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
      overpaymentStartDate: _overpaymentApplyFrom,
      referenceDate: referenceDate,
    );
  }

  Mortgage _projectMortgageForReference(
    Mortgage mortgage,
    DateTime referenceDate,
  ) {
    final now = DateTime.now();
    final monthOffset = (referenceDate.year - now.year) * 12 +
        (referenceDate.month - now.month);
    if (monthOffset <= 0) {
      return mortgage;
    }

    // Move startDate backwards by monthOffset so elapsed time increases and
    // the projected balance/term reflect a future date.
    final projectedStartDate = DateTime(
      mortgage.startDate.year,
      mortgage.startDate.month - monthOffset,
      mortgage.startDate.day,
    );
    return mortgage.copyWith(startDate: projectedStartDate);
  }

  void _applyOverpayment() {
    final mortgage = _selectedMortgage;
    if (mortgage == null) return;
    final now = _repository.effectiveNow;
    final applyFrom = _extraOverpayment > 0
        ? _overpaymentApplyFrom
        : null;
    _repository.saveMortgage(mortgage.copyWith(
      overpayment: _extraOverpayment,
      overpaymentStartDate: applyFrom,
    ));
    setState(() {
      _savedExtraOverpayment = _extraOverpayment;
      if (_extraOverpayment == 0) {
        _overpaymentApplyFrom = DateTime(now.year, now.month);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _extraOverpayment > 0
              ? 'Overpayment of £${_extraOverpayment.toStringAsFixed(0)}/mo applied from ${_monthFormat.format(_overpaymentApplyFrom)}'
              : 'Overpayment cleared',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mortgages = _repository.getMortgages();
    final referenceDate = _repository.effectiveNow;
    final selectedMortgage = _selectedMortgage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mortgage'),
        actions: [
          IconButton(
            onPressed: () => _showAddMortgageDialog(context),
            icon: const Icon(Icons.add),
            tooltip: 'Add mortgage',
          ),
          if (_repository.developerModeEnabled)
            PreviewMonthBadge(
              referenceDate: referenceDate,
              monthOffset: _repository.developerMonthOffset,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: mortgages.isEmpty
              ? _buildEmptyState(context)
              : _buildDetail(context, mortgages, selectedMortgage),
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
              Icon(Icons.home_outlined,
                  size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('No mortgage added yet', style: theme.textTheme.titleMedium),
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

  Widget _buildDetail(
    BuildContext context,
    List<Mortgage> mortgages,
    Mortgage? selectedMortgage,
  ) {
    final theme = Theme.of(context);
    if (selectedMortgage == null || _detail == null) {
      return _buildEmptyState(context);
    }
    final detail = _detail!;

    return ListView(
      children: <Widget>[
        if (mortgages.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: selectedMortgage.id,
            decoration: const InputDecoration(
              labelText: 'Selected mortgage',
              border: OutlineInputBorder(),
            ),
            items: mortgages
                .map(
                  (m) => DropdownMenuItem<String>(
                    value: m.id,
                    child: Text(m.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              final now = _repository.effectiveNow;
              final m = _repository.getMortgages()
                  .firstWhere((m) => m.id == value);
              setState(() {
                _selectedMortgageId = value;
                _extraOverpayment = m.overpayment;
                _savedExtraOverpayment = _extraOverpayment;
                _overpaymentApplyFrom = m.overpaymentStartDate ??
                    DateTime(now.year, now.month);
                _recalculate();
              });
            },
          ),
          const SizedBox(height: 12),
        ],
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
                      onPressed: () => _showAddMortgageDialog(context,
                          existing: selectedMortgage),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _confirmDelete(selectedMortgage),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Deal expiry warning / info ──
                _buildDealExpiryBanner(context, selectedMortgage),
                const SizedBox(height: 4),

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
                if (selectedMortgage.ownershipType ==
                    MortgageOwnershipType.sharedOwnership) ...[
                  const SizedBox(height: 10),
                  _buildSharedOwnershipBreakdown(context, selectedMortgage),
                ],
                const SizedBox(height: 12),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 480;

                    final balancePanel = Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.home_outlined,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Outstanding Balance',
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
                                _currencyFormat.format(detail.balance),
                                maxLines: 1,
                                softWrap: false,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: theme.colorScheme.primary,
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
                        _MortgageMetricRowCard(
                          icon: Icons.percent_rounded,
                          label: 'Interest Rate',
                          value: '${detail.annualRate.toStringAsFixed(2)}%',
                          valueColor: Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        _MortgageMetricRowCard(
                          icon: Icons.payments_outlined,
                          label: 'Monthly Payment',
                          value: _currencyFormat
                              .format(selectedMortgage.totalMonthlyPayment),
                          valueColor: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        _MortgageMetricRowCard(
                          icon: Icons.timelapse_rounded,
                          label: 'Remaining Term',
                          value: _formatTerm(detail.remainingTermMonths),
                          valueColor: theme.colorScheme.secondary,
                        ),
                        const SizedBox(height: 8),
                        _MortgageMetricRowCard(
                          icon: Icons.flag_outlined,
                          label: 'Payoff Date',
                          value: detail.payoffDateLabel,
                          valueColor: Colors.green,
                        ),
                        if (selectedMortgage.ownershipType ==
                            MortgageOwnershipType.sharedOwnership) ...[
                          const SizedBox(height: 8),
                          _MortgageMetricRowCard(
                            icon: Icons.pie_chart_outline_rounded,
                            label: 'Owned Share',
                            value:
                                '${selectedMortgage.ownedSharePercent.toStringAsFixed(1)}%',
                            valueColor: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(height: 8),
                          _MortgageMetricRowCard(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Housing Total',
                            value: _currencyFormat
                                .format(selectedMortgage.totalMonthlyHousingCost),
                            valueColor: Colors.indigo,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _MortgageMetricRowCard(
                          icon: Icons.trending_up_rounded,
                          label: 'Total Interest',
                          value: _currencyFormat.format(detail.totalInterest),
                          valueColor: theme.colorScheme.error,
                        ),
                        if (selectedMortgage.dealEndDate != null) ...[
                          const SizedBox(height: 8),
                          _MortgageMetricRowCard(
                            icon: Icons.event_outlined,
                            label: 'Deal Ends',
                            value: DateFormat('MMM yyyy')
                                .format(selectedMortgage.dealEndDate!),
                            valueColor: _dealEndColor(context, selectedMortgage),
                          ),
                        ],
                      ],
                    );

                    if (compact) {
                      return Column(
                        children: [
                          balancePanel,
                          const SizedBox(height: 10),
                          metricRows,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: balancePanel),
                        const SizedBox(width: 10),
                        Expanded(flex: 6, child: metricRows),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        _showRemortgageDialog(context, selectedMortgage),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Remortgage'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Repayment Outlook (text-first summary) ──
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    Icon(Icons.insights_outlined,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Repayment Outlook',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _extraOverpayment > 0
                      ? 'Projection includes your current overpayment scenario.'
                      : 'Projection based on your current mortgage terms.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _MortgageMetricRowCard(
                        label: 'Estimated Payoff',
                        value: _extraOverpayment > 0
                            ? detail.overpaymentPayoffDateLabel
                            : detail.payoffDateLabel,
                        icon: Icons.flag_outlined,
                        valueColor: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      _MortgageMetricRowCard(
                        label: 'Time Remaining',
                        value: _formatTerm(
                          _extraOverpayment > 0
                              ? detail.overpaymentMonthsToPayoff
                              : detail.monthsToPayoff,
                        ),
                        icon: Icons.timelapse_rounded,
                        valueColor: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: 8),
                      _MortgageMetricRowCard(
                        label: 'Projected Interest',
                        value: _currencyFormat.format(
                          _extraOverpayment > 0
                              ? detail.overpaymentTotalInterest
                              : detail.totalInterest,
                        ),
                        icon: Icons.trending_up_rounded,
                        valueColor: theme.colorScheme.error,
                      ),
                    ],
                  ),
                ),
                if (_extraOverpayment > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.eco_outlined, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You could save ${detail.overpaymentMonthsSaved} months and '
                            '${_currencyFormat.format(detail.overpaymentInterestSaved)} in interest.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
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
        ),
        const SizedBox(height: 16),

        // ── Overpayment Slider ──
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Builder(builder: (context) {
              // 10% of outstanding balance per year is the typical UK lender
              // allowance without early repayment charges.
              final maxOverpayment =
                  (selectedMortgage.balance * 0.10 / 12).clamp(50.0, 10000.0);
              final roundedMax =
                  (maxOverpayment / 50).ceil() * 50.0; // round up to £50
              final hasUnsavedChanges =
                  _extraOverpayment != _savedExtraOverpayment;
              final savedApplyFrom =
                  selectedMortgage.overpaymentStartDate;
              return Column(
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
                  const SizedBox(height: 4),
                  Text(
                    'Slider capped at 10% of your outstanding balance per year '
                    '(${_currencyFormat.format(roundedMax * 12)}/yr) — the '
                    'typical UK lender penalty-free limit.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (savedApplyFrom != null &&
                      _savedExtraOverpayment > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Currently applied from ${_monthFormat.format(savedApplyFrom)}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  MoneyInputSlider(
                    label: 'Monthly overpayment',
                    value: _extraOverpayment.clamp(0, roundedMax),
                    min: 0,
                    max: roundedMax,
                    divisions: (roundedMax / 25).round().clamp(1, 200),
                    onChanged: (double value) {
                      setState(() {
                        _extraOverpayment = value;
                        _recalculate();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // ── Apply from month picker ──
                  Row(
                    children: [
                      Text('Apply from:',
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: Icon(Icons.calendar_month_outlined,
                            size: 16,
                            color: theme.colorScheme.primary),
                        label: Text(_monthFormat.format(_overpaymentApplyFrom)),
                        onPressed: () async {
                          final now = _repository.effectiveNow;
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _overpaymentApplyFrom,
                            firstDate:
                                DateTime(now.year - 2, now.month),
                            lastDate:
                                DateTime(now.year + 5, now.month),
                            helpText: 'Overpayment starts from',
                          );
                          if (picked != null) {
                            setState(() {
                              _overpaymentApplyFrom =
                                  DateTime(picked.year, picked.month);
                              _recalculate();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: hasUnsavedChanges ? _applyOverpayment : null,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(hasUnsavedChanges ? 'Apply' : 'Applied'),
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
                                  value: '${detail.overpaymentMonthsSaved}',
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
              );
            }),
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
                      Text('Overpayment simulator',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                        'Use the slider to model how extra monthly payments '
                        'could reduce your balance over time. Results are '
                        'estimates only — always check your mortgage terms '
                        'for any overpayment limits or fees.',
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

  void _showAddMortgageDialog(
    BuildContext context, {
    Mortgage? existing,
  }) {
    final nameController = TextEditingController(
      text: existing?.name ?? 'Mortgage',
    );
    final originalLoanAmountController = TextEditingController(
      text: existing != null
          ? existing.originalLoanAmount.toStringAsFixed(2)
          : '',
    );
    final rateController = TextEditingController(
      text: existing != null ? existing.annualRate.toStringAsFixed(2) : '',
    );
    final paymentController = TextEditingController(
      text: existing != null ? existing.monthlyPayment.toStringAsFixed(2) : '',
    );
    bool termInYears = true;
    final termController = TextEditingController(
      text: existing != null
          ? (existing.mortgageTermMonths / 12).round().toString()
          : '',
    );
    DateTime selectedStartDate =
        existing?.startDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    int selectedPaymentDay =
        existing?.paymentDay ?? _repository.financialMonthStartDay;
    DateTime? selectedDealEndDate = existing?.dealEndDate;
    bool advancedMode = false;
    MortgageRepaymentType repaymentType =
        existing?.repaymentType ?? MortgageRepaymentType.repayment;
    MortgageOwnershipType ownershipType =
        existing?.ownershipType ?? MortgageOwnershipType.standard;
    final ownedShareController = TextEditingController(
      text: existing != null &&
              existing.ownershipType == MortgageOwnershipType.sharedOwnership
          ? existing.ownedSharePercent.toStringAsFixed(1)
          : '',
    );
    final monthlyRentController = TextEditingController(
      text: existing != null &&
              existing.ownershipType == MortgageOwnershipType.sharedOwnership
          ? existing.monthlyRent.toStringAsFixed(2)
          : '',
    );
    final monthlyServiceChargeController = TextEditingController(
      text: existing != null &&
              existing.ownershipType == MortgageOwnershipType.sharedOwnership
          ? existing.monthlyServiceCharge.toStringAsFixed(2)
          : '',
    );
    final monthlyGroundRentController = TextEditingController(
      text: existing != null &&
              existing.ownershipType == MortgageOwnershipType.sharedOwnership
          ? existing.monthlyGroundRent.toStringAsFixed(2)
          : '',
    );
    if (existing != null &&
        (existing.ownershipType == MortgageOwnershipType.sharedOwnership ||
            existing.repaymentType == MortgageRepaymentType.interestOnly)) {
      advancedMode = true;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setDialogState) {
            final previewOriginalAmount =
                AmountParser.tryParse(originalLoanAmountController.text);
            final previewRate = AmountParser.tryParse(rateController.text);
            final previewPayment =
                AmountParser.tryParse(paymentController.text);
            final previewTermRaw = double.tryParse(termController.text.trim());
            final previewTermMonths = previewTermRaw != null
                ? (termInYears
                    ? (previewTermRaw * 12).round()
                    : previewTermRaw.toInt())
                : null;
            final previewMonthlyInterest =
                (previewOriginalAmount != null && previewRate != null)
                    ? MortgageMath.monthlyInterest(previewOriginalAmount, previewRate)
                    : null;
            final inferredTerm = (previewOriginalAmount != null &&
                    previewRate != null &&
                    previewPayment != null)
                ? MortgageMath.termForPayment(
                    principal: previewOriginalAmount,
                    annualRate: previewRate,
                    monthlyPayment: previewPayment,
                  )
                : null;
            final inferredPayment = (previewOriginalAmount != null &&
                    previewRate != null &&
                    previewTermMonths != null &&
                    previewTermMonths > 0)
                ? MortgageMath.paymentForTerm(
                    principal: previewOriginalAmount,
                    annualRate: previewRate,
                    termMonths: previewTermMonths,
                  )
                : null;

            return AlertDialog(
              title: Text(existing != null ? 'Edit Mortgage' : 'Add Mortgage'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      value: advancedMode,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Advanced mode'),
                      subtitle: const Text(
                        'Auto-infer term/payment, repayment type and Shared Ownership fields.',
                      ),
                      onChanged: (value) =>
                          setDialogState(() => advancedMode = value),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<MortgageOwnershipType>(
                      segments: const [
                        ButtonSegment(
                          value: MortgageOwnershipType.standard,
                          label: Text('Standard'),
                        ),
                        ButtonSegment(
                          value: MortgageOwnershipType.sharedOwnership,
                          label: Text('Shared Ownership'),
                        ),
                      ],
                      selected: <MortgageOwnershipType>{ownershipType},
                      onSelectionChanged: (selected) {
                        setDialogState(() {
                          ownershipType = selected.first;
                        });
                      },
                    ),
                    if (advancedMode) ...[
                      const SizedBox(height: 8),
                      SegmentedButton<MortgageRepaymentType>(
                        segments: const [
                          ButtonSegment(
                            value: MortgageRepaymentType.repayment,
                            label: Text('Repayment'),
                          ),
                          ButtonSegment(
                            value: MortgageRepaymentType.interestOnly,
                            label: Text('Interest-only'),
                          ),
                        ],
                        selected: <MortgageRepaymentType>{repaymentType},
                        onSelectionChanged: (selected) {
                          setDialogState(() {
                            repaymentType = selected.first;
                            if (repaymentType ==
                                    MortgageRepaymentType.interestOnly &&
                                previewMonthlyInterest != null) {
                              paymentController.text =
                                  previewMonthlyInterest.toStringAsFixed(2);
                            }
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 8),
                    // Mortgage start date picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mortgage start date'),
                      subtitle: Text(
                        '${selectedStartDate.day.toString().padLeft(2, '0')}/'
                        '${selectedStartDate.month.toString().padLeft(2, '0')}/'
                        '${selectedStartDate.year}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedStartDate,
                          firstDate: DateTime(1980),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedStartDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: originalLoanAmountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Original loan amount',
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
                      decoration: InputDecoration(
                        labelText:
                            repaymentType == MortgageRepaymentType.interestOnly
                                ? 'Monthly payment (interest-only)'
                                : 'Monthly payment',
                        prefixText: '£',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: selectedPaymentDay,
                      decoration: const InputDecoration(
                        labelText: 'Payment day',
                        helperText:
                            'Day of the month your mortgage payment is taken',
                        border: OutlineInputBorder(),
                      ),
                      items: List<DropdownMenuItem<int>>.generate(
                        28,
                        (int index) => DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text('Day ${index + 1}'),
                        ),
                      ),
                      onChanged: (int? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedPaymentDay = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: termController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: termInYears
                            ? 'Mortgage term (years)'
                            : 'Mortgage term (months)',
                        helperText: advancedMode
                            ? 'Leave blank to auto-infer from payment.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SegmentedButton<bool>(
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity:
                            VisualDensity(horizontal: -1, vertical: -2),
                      ),
                      segments: const [
                        ButtonSegment(value: true, label: Text('Years')),
                        ButtonSegment(value: false, label: Text('Months')),
                      ],
                      selected: {termInYears},
                      onSelectionChanged: (selected) {
                        final newInYears = selected.first;
                        if (newInYears == termInYears) return;
                        setDialogState(() {
                          final raw = termController.text.trim();
                          if (newInYears) {
                            final months = int.tryParse(raw);
                            if (months != null) {
                              termController.text =
                                  (months / 12).round().toString();
                            }
                          } else {
                            final years = double.tryParse(raw);
                            if (years != null) {
                              termController.text =
                                  (years * 12).round().toString();
                            }
                          }
                          termInYears = newInYears;
                        });
                      },
                    ),
                    if (ownershipType ==
                        MortgageOwnershipType.sharedOwnership) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: ownedShareController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Owned share (%)',
                          suffixText: '%',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: monthlyRentController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Monthly rent (unowned share)',
                          prefixText: '£',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: monthlyServiceChargeController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Monthly service charge',
                          prefixText: '£',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: monthlyGroundRentController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Monthly ground rent',
                          prefixText: '£',
                        ),
                      ),
                    ],
                    if (advancedMode) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-calculation',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            if (previewMonthlyInterest != null)
                              Text(
                                'Monthly interest only: £${previewMonthlyInterest.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (inferredTerm != null)
                              Text(
                                'Inferred term from payment: $inferredTerm months',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (inferredPayment != null)
                              Text(
                                'Inferred payment from term: £${inferredPayment.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: inferredTerm == null
                                      ? null
                                      : () => setDialogState(() {
                                            termController.text = termInYears
                                                ? (inferredTerm / 12)
                                                    .round()
                                                    .toString()
                                                : inferredTerm.toString();
                                          }),
                                  child: const Text('Use inferred term'),
                                ),
                                OutlinedButton(
                                  onPressed: inferredPayment == null
                                      ? null
                                      : () => setDialogState(() {
                                            paymentController.text =
                                                inferredPayment
                                                    .toStringAsFixed(2);
                                          }),
                                  child: const Text('Use inferred payment'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // ── Deal end date picker ──
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDealEndDate ??
                              DateTime(now.year + 2, now.month),
                          firstDate: DateTime(now.year, now.month),
                          lastDate: DateTime(now.year + 30),
                          helpText: 'Select deal end date',
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDealEndDate =
                                DateTime(picked.year, picked.month);
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fixed deal ends (optional)',
                          suffixIcon: selectedDealEndDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: 'Clear',
                                  onPressed: () => setDialogState(
                                      () => selectedDealEndDate = null),
                                )
                              : const Icon(Icons.calendar_month_outlined,
                                  size: 18),
                        ),
                        child: Text(
                          selectedDealEndDate != null
                              ? DateFormat('MMM yyyy')
                                  .format(selectedDealEndDate!)
                              : 'Tap to set',
                          style: selectedDealEndDate != null
                              ? null
                              : TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
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
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final originalLoanAmount =
                        AmountParser.tryParse(originalLoanAmountController.text);
                    final rate = AmountParser.tryParse(rateController.text);
                    final paymentInput =
                        AmountParser.tryParse(paymentController.text);
                    final termText = termController.text.trim();
                    final term = termInYears
                        ? (double.tryParse(termText) != null
                            ? (double.parse(termText) * 12).round()
                            : null)
                        : int.tryParse(termText);
                    final ownedShareInput =
                        AmountParser.tryParse(ownedShareController.text);
                    final monthlyRentInput =
                        AmountParser.tryParse(monthlyRentController.text);
                    final monthlyServiceChargeInput = AmountParser.tryParse(
                      monthlyServiceChargeController.text,
                    );
                    final monthlyGroundRentInput =
                        AmountParser.tryParse(monthlyGroundRentController.text);

                    final messenger = ScaffoldMessenger.of(this.context);
                    if (name.isEmpty) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Mortgage name is required.'),
                          ),
                        );
                      return;
                    }
                    if (originalLoanAmount == null || originalLoanAmount <= 0) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Original loan amount must be greater than 0.'),
                          ),
                        );
                      return;
                    }
                    if (!AmountParser.hasMaxDecimalPlaces(
                          originalLoanAmountController.text,
                          2,
                        ) ||
                        !AmountParser.hasMaxDecimalPlaces(
                          rateController.text,
                          2,
                        ) ||
                        !AmountParser.hasMaxDecimalPlaces(
                          paymentController.text,
                          2,
                        ) ||
                        !AmountParser.hasMaxDecimalPlaces(
                          monthlyRentController.text,
                          2,
                        ) ||
                        !AmountParser.hasMaxDecimalPlaces(
                          monthlyServiceChargeController.text,
                          2,
                        ) ||
                        !AmountParser.hasMaxDecimalPlaces(
                          monthlyGroundRentController.text,
                          2,
                        )) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Amount, APR and payment can have at most 2 decimal places.'),
                          ),
                        );
                      return;
                    }
                    if (rate == null || rate < 0 || rate > 100) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Annual interest rate must be between 0 and 100.'),
                          ),
                        );
                      return;
                    }

                    if (ownershipType ==
                        MortgageOwnershipType.sharedOwnership) {
                      final ownedShare = ownedShareInput;
                      if (ownedShare == null ||
                          ownedShare <= 0 ||
                          ownedShare > 100) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Owned share must be between 0 and 100.'),
                            ),
                          );
                        return;
                      }
                      if ((monthlyRentInput ?? 0) < 0 ||
                          (monthlyServiceChargeInput ?? 0) < 0 ||
                          (monthlyGroundRentInput ?? 0) < 0) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Rent and charges cannot be negative.'),
                            ),
                          );
                        return;
                      }
                    }

                    final monthlyInterestOnly = originalLoanAmount * (rate / 100) / 12;
                    double? resolvedPayment = paymentInput;
                    int? resolvedTerm = term;

                    if (advancedMode &&
                        repaymentType == MortgageRepaymentType.interestOnly) {
                      resolvedPayment ??= monthlyInterestOnly;
                      resolvedTerm ??= existing?.mortgageTermMonths;
                      if (resolvedTerm == null || resolvedTerm <= 0) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Set a mortgage term (months) for interest-only mortgages.'),
                            ),
                          );
                        return;
                      }
                      if (resolvedPayment < monthlyInterestOnly) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Interest-only payment must be at least the monthly interest amount.',
                              ),
                            ),
                          );
                        return;
                      }
                    } else {
                      if (resolvedPayment == null || resolvedPayment <= 0) {
                        if (resolvedTerm != null && resolvedTerm > 0) {
                          resolvedPayment = MortgageMath.paymentForTerm(
                            principal: originalLoanAmount,
                            annualRate: rate,
                            termMonths: resolvedTerm,
                          );
                        } else {
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Monthly payment must be greater than 0.'),
                              ),
                            );
                          return;
                        }
                      }

                      if (resolvedTerm == null || resolvedTerm <= 0) {
                        if (resolvedPayment != null && resolvedPayment > 0) {
                          resolvedTerm = MortgageMath.termForPayment(
                            principal: originalLoanAmount,
                            annualRate: rate,
                            monthlyPayment: resolvedPayment,
                          );
                        }
                        if (resolvedTerm == null || resolvedTerm <= 0) {
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Enter a valid term or monthly payment.'),
                              ),
                            );
                          return;
                        }
                      }
                    }

                    if (rate > 0 &&
                        repaymentType == MortgageRepaymentType.repayment &&
                        resolvedPayment <= monthlyInterestOnly) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Monthly payment must be higher than monthly interest, or the balance will not reduce.',
                            ),
                          ),
                        );
                      return;
                    }

                    if (originalLoanAmount > 5000000 || resolvedPayment > 50000) {
                      final proceedHighValue = await showDialog<bool>(
                            context: dialogContext,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Very high mortgage values'),
                              content: const Text(
                                'These mortgage values are unusually high. Please confirm they are intentional.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Continue'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!proceedHighValue) {
                        return;
                      }
                    }

                    final salaryDay = _repository.financialMonthStartDay;
                    if ((selectedPaymentDay - salaryDay).abs() >= 10) {
                      final proceedDayGap = await showDialog<bool>(
                            context: dialogContext,
                            builder: (ctx) => AlertDialog(
                              title:
                                  const Text('Payment day far from salary day'),
                              content: Text(
                                'Your mortgage payment day (day $selectedPaymentDay) is quite far from your financial month start day (day $salaryDay).\n\nContinue anyway?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Adjust day'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Continue'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!proceedDayGap) {
                        return;
                      }
                    }

                    final mortgageId = existing?.id ??
                        'mortgage-${DateTime.now().millisecondsSinceEpoch}';
                    _repository.saveMortgage(Mortgage(
                      id: mortgageId,
                      name: name,
                      startDate: selectedStartDate,
                      originalLoanAmount: originalLoanAmount,
                      mortgageTermMonths: resolvedTerm,
                      annualRate: rate,
                      monthlyPayment: resolvedPayment,
                      paymentDay: selectedPaymentDay,
                      dealEndDate: selectedDealEndDate,
                      ownershipType: ownershipType,
                      repaymentType: repaymentType,
                      ownedSharePercent:
                          ownershipType == MortgageOwnershipType.sharedOwnership
                              ? (ownedShareInput ?? 100)
                              : 100,
                      monthlyRent:
                          ownershipType == MortgageOwnershipType.sharedOwnership
                              ? (monthlyRentInput ?? 0)
                              : 0,
                      monthlyServiceCharge:
                          ownershipType == MortgageOwnershipType.sharedOwnership
                              ? (monthlyServiceChargeInput ?? 0)
                              : 0,
                      monthlyGroundRent:
                          ownershipType == MortgageOwnershipType.sharedOwnership
                              ? (monthlyGroundRentInput ?? 0)
                              : 0,
                    ));
                    _selectedMortgageId = mortgageId;
                    Navigator.pop(dialogContext);
                  },
                  child: Text(existing != null ? 'Update' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(Mortgage mortgage) async {
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
      _repository.deleteMortgageById(mortgage.id);
    }
  }

  String _formatTerm(int months) {
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (years == 0) return '$remainingMonths months';
    if (remainingMonths == 0) return '$years years';
    return '$years years $remainingMonths months';
  }

  Widget _buildSharedOwnershipBreakdown(
    BuildContext context,
    Mortgage mortgage,
  ) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shared Ownership monthly costs',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Owned share: ${mortgage.ownedSharePercent.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rent: ${_currencyFormat.format(mortgage.monthlyRent)}  •  Service: ${_currencyFormat.format(mortgage.monthlyServiceCharge)}  •  Ground rent: ${_currencyFormat.format(mortgage.monthlyGroundRent)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  // ── Deal expiry helpers ──────────────────────────────────────────────────

  /// Returns the number of months until the deal ends (0 if already past).
  int _monthsUntilDealEnd(DateTime dealEnd) {
    final now = DateTime.now();
    final months = (dealEnd.year - now.year) * 12 + (dealEnd.month - now.month);
    return math.max(0, months);
  }

  Color _dealEndColor(BuildContext context, Mortgage mortgage) {
    if (mortgage.dealEndDate == null) return Colors.blue;
    final months = _monthsUntilDealEnd(mortgage.dealEndDate!);
    if (months <= 1) return Theme.of(context).colorScheme.error;
    if (months <= 3) return Colors.orange;
    return Colors.blue;
  }

  Widget _buildDealExpiryBanner(BuildContext context, Mortgage mortgage) {
    final dealEnd = mortgage.dealEndDate;
    final theme = Theme.of(context);
    if (dealEnd == null) return const SizedBox.shrink();

    final months = _monthsUntilDealEnd(dealEnd);
    final String message;
    final Color colour;
    final IconData icon;

    if (months == 0) {
      message =
          'Your fixed deal expired ${DateFormat('MMM yyyy').format(dealEnd)}. '
          'Time to remortgage!';
      colour = theme.colorScheme.error;
      icon = Icons.warning_amber_rounded;
    } else if (months <= 3) {
      message =
          'Your fixed deal ends ${DateFormat('MMM yyyy').format(dealEnd)} '
          '— $months month${months == 1 ? '' : 's'} away. Start shopping now.';
      colour = Colors.orange;
      icon = Icons.schedule_rounded;
    } else {
      message = 'Fixed deal ends ${DateFormat('MMM yyyy').format(dealEnd)} '
          '($months months).';
      colour = Colors.blue;
      icon = Icons.info_outline_rounded;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colour.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colour),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: theme.textTheme.bodySmall?.copyWith(color: colour)),
          ),
        ],
      ),
    );
  }

  // ── Remortgage dialog ────────────────────────────────────────────────────

  /// Calculates an annuity payment: P * r / (1 - (1+r)^-n)
  double _calcPayment(double balance, double annualRate, int termMonths) {
    if (balance <= 0 || termMonths <= 0) return 0;
    if (annualRate <= 0) return balance / termMonths;
    final r = annualRate / 100 / 12;
    final denom = 1 - math.pow(1 + r, -termMonths).toDouble();
    if (denom == 0) return balance / termMonths;
    return balance * r / denom;
  }

  void _showRemortgageDialog(BuildContext context, Mortgage current) {
    // Project balance to deal-end date if known, otherwise use current balance.
    final now = DateTime.now();
    final dealEnd = current.dealEndDate;
    final Mortgage projected;
    if (dealEnd != null) {
      final monthsAhead = _monthsUntilDealEnd(dealEnd);
      projected = monthsAhead > 0
          ? _projectMortgageForReference(
              current,
              DateTime(
                  now.year + monthsAhead ~/ 12, now.month + monthsAhead % 12))
          : current;
    } else {
      projected = current;
    }

    final projectedBalance = projected.balance;
    final balanceController = TextEditingController(
      text: projectedBalance.toStringAsFixed(2),
    );
    final rateController = TextEditingController();
    bool termInYears = true;
    final termController = TextEditingController(
      text: (projected.remainingTermMonths / 12).round().toString(),
    );
    // Calculated payment, updated reactively.
    String calculatedPayment = '—';
    DateTime? newDealEndDate;

    void updatePayment(
        void Function(void Function()) setDialogState, String _) {
      final bal = AmountParser.tryParse(balanceController.text) ?? 0;
      final rate = double.tryParse(rateController.text.trim());
      final termRaw = double.tryParse(termController.text.trim());
      final term = termRaw != null
          ? (termInYears ? (termRaw * 12).round() : termRaw.toInt())
          : null;
      if (rate != null && term != null && bal > 0) {
        final p = _calcPayment(bal, rate, term);
        setDialogState(() => calculatedPayment = '£${p.toStringAsFixed(2)}/mo');
      } else {
        setDialogState(() => calculatedPayment = '—');
      }
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx,
              void Function(void Function()) setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded,
                      color: Theme.of(ctx).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Remortgage')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dealEnd != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Balance projected to ${DateFormat('MMM yyyy').format(dealEnd)}: '
                          '£${projectedBalance.toStringAsFixed(2)}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                    ],
                    TextField(
                      controller: balanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'New balance',
                        prefixText: '£',
                        helperText: 'Pre-filled with projected balance',
                      ),
                      onChanged: (v) => updatePayment(setDialogState, v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'New interest rate (%)',
                        suffixText: '%',
                        helperText: 'Enter your new deal rate',
                      ),
                      onChanged: (v) => updatePayment(setDialogState, v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: termController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: termInYears
                            ? 'New term (years)'
                            : 'New term (months)',
                        helperText: termInYears
                            ? 'Pre-filled with remaining term in years'
                            : 'Pre-filled with remaining term',
                      ),
                      onChanged: (v) => updatePayment(setDialogState, v),
                    ),
                    const SizedBox(height: 4),
                    SegmentedButton<bool>(
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity:
                            VisualDensity(horizontal: -1, vertical: -2),
                      ),
                      segments: const [
                        ButtonSegment(value: true, label: Text('Years')),
                        ButtonSegment(value: false, label: Text('Months')),
                      ],
                      selected: {termInYears},
                      onSelectionChanged: (selected) {
                        final newInYears = selected.first;
                        if (newInYears == termInYears) return;
                        setDialogState(() {
                          final raw = termController.text.trim();
                          if (newInYears) {
                            final months = int.tryParse(raw);
                            if (months != null) {
                              termController.text =
                                  (months / 12).round().toString();
                            }
                          } else {
                            final years = double.tryParse(raw);
                            if (years != null) {
                              termController.text =
                                  (years * 12).round().toString();
                            }
                          }
                          termInYears = newInYears;
                        });
                        updatePayment(setDialogState, '');
                      },
                    ),
                    const SizedBox(height: 12),
                    // ── Calculated payment banner ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx)
                            .colorScheme
                            .secondaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calculate_outlined,
                              size: 18,
                              color: Theme.of(ctx).colorScheme.secondary),
                          const SizedBox(width: 8),
                          Text('Calculated payment: ',
                              style: Theme.of(ctx).textTheme.bodySmall),
                          Text(calculatedPayment,
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── New deal end date ──
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () async {
                        final n = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate:
                              newDealEndDate ?? DateTime(n.year + 2, n.month),
                          firstDate: DateTime(n.year, n.month),
                          lastDate: DateTime(n.year + 30),
                          helpText: 'New deal end date (optional)',
                        );
                        if (picked != null) {
                          setDialogState(() {
                            newDealEndDate =
                                DateTime(picked.year, picked.month);
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'New deal end date (optional)',
                          suffixIcon: newDealEndDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: 'Clear',
                                  onPressed: () => setDialogState(
                                      () => newDealEndDate = null),
                                )
                              : const Icon(Icons.calendar_month_outlined,
                                  size: 18),
                        ),
                        child: Text(
                          newDealEndDate != null
                              ? DateFormat('MMM yyyy').format(newDealEndDate!)
                              : 'Tap to set',
                          style: newDealEndDate != null
                              ? null
                              : TextStyle(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final bal = AmountParser.tryParse(balanceController.text);
                    final rate = double.tryParse(rateController.text.trim());
                    final termText = termController.text.trim();
                    final term = termInYears
                        ? (double.tryParse(termText) != null
                            ? (double.parse(termText) * 12).round()
                            : null)
                        : int.tryParse(termText);
                    final messenger = ScaffoldMessenger.of(this.context);

                    if (bal == null || bal <= 0) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(
                            content: Text('Balance must be greater than 0.')));
                      return;
                    }
                    if (rate == null || rate < 0 || rate > 100) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(
                            content: Text('Rate must be between 0 and 100.')));
                      return;
                    }
                    if (term == null || term <= 0) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(
                            content: Text('Term must be greater than 0.')));
                      return;
                    }

                    final payment = _calcPayment(bal, rate, term);
                    // For remortgage: treat the new balance as the fresh
                    // original loan amount and reset the start date to today.
                    _repository.saveMortgage(
                      current.copyWith(
                        startDate: DateTime(now.year, now.month, 1),
                        originalLoanAmount: bal,
                        mortgageTermMonths: term,
                        annualRate: rate,
                        monthlyPayment: payment,
                        overpayment: 0,
                        dealEndDate: newDealEndDate,
                      ),
                    );
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(this.context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text('Remortgage applied — new payment '
                            '£${payment.toStringAsFixed(2)}/mo at $rate%'),
                        duration: const Duration(seconds: 3),
                      ));
                  },
                  child: const Text('Apply Remortgage'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MortgageMetricRowCard extends StatelessWidget {
  const _MortgageMetricRowCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;

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
          const SizedBox(width: 8),
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
