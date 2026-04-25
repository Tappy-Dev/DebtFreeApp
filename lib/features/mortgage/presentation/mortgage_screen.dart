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
  String? _selectedMortgageId;
  double _extraOverpayment = 0;
  MortgageDetail? _detail;
  final _currencyFormat = NumberFormat.currency(symbol: '£', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepositoryChange);
    final mortgages = _repository.getMortgages();
    _selectedMortgageId = mortgages.isEmpty ? null : mortgages.first.id;
    _extraOverpayment = _selectedMortgage?.overpayment ?? 0;
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
    if (mortgages.isEmpty) {
      _selectedMortgageId = null;
      _extraOverpayment = 0;
      return;
    }
    final stillExists = mortgages.any((m) => m.id == _selectedMortgageId);
    if (!stillExists) {
      _selectedMortgageId = mortgages.first.id;
      _extraOverpayment = mortgages.first.overpayment;
      return;
    }
    final selected = _selectedMortgage;
    if (selected != null) {
      _extraOverpayment = selected.overpayment;
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

    final result = MortgageProjectionEngine().simulate(
      mortgage,
      startDate: DateTime(now.year, now.month),
    );
    if (result.monthlyBreakdown.isEmpty) {
      return mortgage;
    }

    final index = math.min(monthOffset - 1, result.monthlyBreakdown.length - 1);
    final month = result.monthlyBreakdown[index];
    final remainingTerm =
        math.max(0, mortgage.remainingTermMonths - monthOffset);

    return mortgage.copyWith(
      balance: month.balanceRemaining,
      remainingTermMonths: remainingTerm,
    );
  }

  void _applyOverpayment() {
    final mortgage = _selectedMortgage;
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
            value: selectedMortgage.id,
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
              setState(() {
                _selectedMortgageId = value;
                _extraOverpayment = _selectedMortgage?.overpayment ?? 0;
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
                if (selectedMortgage.dealEndDate != null) ...[
                  const SizedBox(height: 10),
                  _MortgageStatChip(
                    label: 'Deal Ends',
                    value: DateFormat('MMM yyyy')
                        .format(selectedMortgage.dealEndDate!),
                    icon: Icons.event_outlined,
                    color: _dealEndColor(context, selectedMortgage),
                  ),
                ],
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

  void _showAddMortgageDialog(
    BuildContext context, {
    Mortgage? existing,
  }) {
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
    int selectedPaymentDay =
        existing?.paymentDay ?? _repository.financialMonthStartDay;
    DateTime? selectedDealEndDate = existing?.dealEndDate;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setDialogState) {
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
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Remaining term (months)',
                      ),
                    ),
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
                    final balance =
                        AmountParser.tryParse(balanceController.text);
                    final rate = double.tryParse(rateController.text.trim());
                    final payment =
                        AmountParser.tryParse(paymentController.text);
                    final term = int.tryParse(termController.text.trim());

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
                    if (balance == null || balance <= 0) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Outstanding balance must be greater than 0.'),
                          ),
                        );
                      return;
                    }
                    if (!AmountParser.hasMaxDecimalPlaces(
                          balanceController.text,
                          2,
                        ) ||
                        !AmountParser.hasMaxDecimalPlaces(
                          rateController.text,
                          2,
                        ) ||
                        !AmountParser.hasMaxDecimalPlaces(
                          paymentController.text,
                          2,
                        )) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Balance, APR and payment can have at most 2 decimal places.'),
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
                    if (payment == null || payment <= 0) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content:
                                Text('Monthly payment must be greater than 0.'),
                          ),
                        );
                      return;
                    }
                    if (term == null || term <= 0) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Remaining term (months) must be greater than 0.'),
                          ),
                        );
                      return;
                    }

                    final monthlyInterestOnly = balance * (rate / 100) / 12;
                    if (rate > 0 && payment <= monthlyInterestOnly) {
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

                    if (balance > 5000000 || payment > 50000) {
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
                              title: const Text('Payment day far from salary day'),
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
                      balance: balance,
                      annualRate: rate,
                      monthlyPayment: payment,
                      remainingTermMonths: term,
                      paymentDay: selectedPaymentDay,
                      dealEndDate: selectedDealEndDate,
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

  // ── Deal expiry helpers ──────────────────────────────────────────────────

  /// Returns the number of months until the deal ends (0 if already past).
  int _monthsUntilDealEnd(DateTime dealEnd) {
    final now = DateTime.now();
    final months =
        (dealEnd.year - now.year) * 12 + (dealEnd.month - now.month);
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
      message =
          'Fixed deal ends ${DateFormat('MMM yyyy').format(dealEnd)} '
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
              DateTime(now.year + monthsAhead ~/ 12,
                  now.month + monthsAhead % 12))
          : current;
    } else {
      projected = current;
    }

    final projectedBalance = projected.balance;
    final balanceController = TextEditingController(
      text: projectedBalance.toStringAsFixed(2),
    );
    final rateController = TextEditingController();
    final termController = TextEditingController(
      text: projected.remainingTermMonths.toString(),
    );
    // Calculated payment, updated reactively.
    String calculatedPayment = '—';
    DateTime? newDealEndDate;

    void updatePayment(
        void Function(void Function()) setDialogState, String _) {
      final bal = AmountParser.tryParse(balanceController.text) ?? 0;
      final rate = double.tryParse(rateController.text.trim());
      final term = int.tryParse(termController.text.trim());
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
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
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
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
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
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'New term (months)',
                        helperText: 'Pre-filled with remaining term',
                      ),
                      onChanged: (v) => updatePayment(setDialogState, v),
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
                          initialDate: newDealEndDate ??
                              DateTime(n.year + 2, n.month),
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
                    final bal =
                        AmountParser.tryParse(balanceController.text);
                    final rate =
                        double.tryParse(rateController.text.trim());
                    final term = int.tryParse(termController.text.trim());
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
                            content: Text(
                                'Rate must be between 0 and 100.')));
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
                    _repository.saveMortgage(
                      current.copyWith(
                        balance: bal,
                        annualRate: rate,
                        monthlyPayment: payment,
                        remainingTermMonths: term,
                        overpayment: 0,
                        dealEndDate: newDealEndDate,
                      ),
                    );
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(this.context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text(
                            'Remortgage applied — new payment '
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
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
