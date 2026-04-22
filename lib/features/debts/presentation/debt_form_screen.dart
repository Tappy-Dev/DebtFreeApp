import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/features/debts/application/debt_form_controller.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DebtFormScreen extends StatefulWidget {
  const DebtFormScreen({
    super.key,
    this.debtId,
  });

  final String? debtId;

  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _aprController = TextEditingController();
  final _minimumPaymentController = TextEditingController();
  final _percentageController = TextEditingController(text: '1.0');
  final _floorController = TextEditingController(text: '25');
  final _controller = DebtFormController(SessionFinancialRepository.instance);

  DebtType _selectedDebtType = DebtType.creditCard;
  MinPaymentType _selectedPaymentType =
      MinPaymentType.interestPlusPercentage;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _loanEndDate;
  final _dateFormat = DateFormat('MMMM yyyy');

  DebtAccount? get _existingDebt {
    final debtId = widget.debtId;
    if (debtId == null || debtId.isEmpty) {
      return null;
    }

    for (final debt in SessionFinancialRepository.instance.getDebts()) {
      if (debt.id == debtId) {
        return debt;
      }
    }

    return null;
  }

  bool get _isEditing => _existingDebt != null;

  @override
  void initState() {
    super.initState();
    final existingDebt = _existingDebt;
    if (existingDebt == null) {
      return;
    }

    _nameController.text = existingDebt.name;
    _balanceController.text = existingDebt.balance.toStringAsFixed(2);
    _aprController.text = existingDebt.apr.toStringAsFixed(2);
    _minimumPaymentController.text =
        existingDebt.minimumPayment.toStringAsFixed(2);
    _selectedDebtType = existingDebt.debtType;
    _selectedPaymentType = existingDebt.minPaymentRule.type;
    _startDate = existingDebt.startDate ??
        DateTime(DateTime.now().year, DateTime.now().month);
    _loanEndDate = existingDebt.loanEndDate;
    _percentageController.text =
        existingDebt.minPaymentRule.percentage.toStringAsFixed(1);
    _floorController.text =
        existingDebt.minPaymentRule.floor.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _aprController.dispose();
    _minimumPaymentController.dispose();
    _percentageController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoan = _selectedDebtType == DebtType.loan;
    final showRuleFields = _selectedPaymentType != MinPaymentType.fixed;
    final loanTermError = isLoan
        ? _controller.validateLoanTerm(_startDate, _loanEndDate)
        : null;
    final estimatedLoanPayment = isLoan
        ? _controller.estimateLoanPayment(
            balance: _balanceController.text,
            apr: _aprController.text,
            startDate: _startDate,
            endDate: _loanEndDate,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Debt' : 'Add Debt'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              children: <Widget>[
                Text(
                  'Debt type',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<DebtType>(
                  segments: DebtType.values
                      .map(
                        (type) => ButtonSegment<DebtType>(
                          value: type,
                          label: Text(type.label),
                        ),
                      )
                      .toList(growable: false),
                  selected: <DebtType>{_selectedDebtType},
                  onSelectionChanged: (Set<DebtType> selected) {
                    setState(() {
                      _selectedDebtType = selected.first;
                      if (_selectedDebtType == DebtType.loan) {
                        _selectedPaymentType = MinPaymentType.fixed;
                        _loanEndDate ??= _startDate;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Debt name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    return _controller.validateRequired(value, 'Debt name');
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _balanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Balance',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    return _controller.validateBalance(value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aprController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'APR (%)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    return _controller.validateApr(value);
                  },
                ),
                const SizedBox(height: 16),
                // ── Start date picker ──
                InkWell(
                  onTap: _pickStartDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Balance as of',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                              Text(_dateFormat.format(_startDate),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                if (isLoan) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickLoanEndDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: loanTermError == null
                              ? Theme.of(context).colorScheme.outlineVariant
                              : Theme.of(context).colorScheme.error,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Loan end date',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                Text(
                                  _loanEndDate == null
                                      ? 'Select end month'
                                      : _dateFormat.format(_loanEndDate!),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (loanTermError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      loanTermError,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated monthly payment',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          estimatedLoanPayment == null
                              ? 'Enter balance, APR, and dates to calculate the loan payment.'
                              : '£${estimatedLoanPayment.toStringAsFixed(2)} per month',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This is calculated from the balance, APR, and remaining loan term.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (!isLoan) ...[
                  Text(
                    'Minimum payment formula',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<MinPaymentType>(
                    segments: const <ButtonSegment<MinPaymentType>>[
                      ButtonSegment(
                        value: MinPaymentType.fixed,
                        label: Text('Fixed'),
                      ),
                      ButtonSegment(
                        value: MinPaymentType.interestPlusPercentage,
                        label: Text('Interest + %'),
                      ),
                      ButtonSegment(
                        value: MinPaymentType.percentageOfBalance,
                        label: Text('% of bal'),
                      ),
                    ],
                    selected: <MinPaymentType>{_selectedPaymentType},
                    onSelectionChanged: (Set<MinPaymentType> selected) {
                      setState(() {
                        _selectedPaymentType = selected.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_selectedPaymentType == MinPaymentType.fixed)
                    TextFormField(
                      controller: _minimumPaymentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Minimum payment (£)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        return _controller.validateMinimumPayment(value);
                      },
                    ),
                  if (showRuleFields) ...[
                    TextFormField(
                      controller: _percentageController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _selectedPaymentType ==
                                MinPaymentType.interestPlusPercentage
                            ? 'Balance percentage (%)'
                            : 'Percentage of balance (%)',
                        helperText: _selectedPaymentType ==
                                MinPaymentType.interestPlusPercentage
                            ? 'UK typical: 1% (interest is added automatically)'
                            : 'UK typical: 2.25%',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        return _controller.validatePercentage(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _floorController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Minimum floor (£)',
                        helperText: 'The lowest monthly payment allowed',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        return _controller.validateFloor(value);
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submit,
                  child: Text(_isEditing ? 'Update debt' : 'Save debt'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year - 30, 1),
      lastDate: DateTime(now.year + 30, 12),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month);
        if (_loanEndDate != null && _loanEndDate!.isBefore(_startDate)) {
          _loanEndDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickLoanEndDate() async {
    final now = DateTime.now();
    final initialDate = _loanEndDate != null && !_loanEndDate!.isBefore(_startDate)
        ? _loanEndDate!
        : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _startDate,
      lastDate: DateTime(now.year + 40, 12),
    );
    if (picked != null) {
      setState(() {
        _loanEndDate = DateTime(picked.year, picked.month);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final loanTermError = _selectedDebtType == DebtType.loan
        ? _controller.validateLoanTerm(_startDate, _loanEndDate)
        : null;
    if (loanTermError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(loanTermError)),
        );
      return;
    }

    _controller.saveDebt(
      debtId: _existingDebt?.id,
      name: _nameController.text,
      debtType: _selectedDebtType,
      balance: _balanceController.text,
      apr: _aprController.text,
      minimumPayment: _selectedDebtType == DebtType.loan
          ? '0'
          : _selectedPaymentType == MinPaymentType.fixed
          ? _minimumPaymentController.text
          : '0',
      minPaymentType: _selectedPaymentType,
      percentage: _percentageController.text,
      floor: _floorController.text,
      startDate: _startDate,
      loanEndDate: _selectedDebtType == DebtType.loan ? _loanEndDate : null,
      extraPayments: _existingDebt?.extraPayments,
    );

    if (!mounted) {
      return;
    }

    if (context.canPop()) {
      Navigator.of(context).pop(true);
      return;
    }

    context.go('/debts');
  }
}
