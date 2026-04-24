import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/utils/amount_parser.dart';
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
  final _loanLengthController = TextEditingController();
  final _controller = DebtFormController(SessionFinancialRepository.instance);

  DebtType _selectedDebtType = DebtType.creditCard;
  MinPaymentType _selectedPaymentType = MinPaymentType.interestPlusPercentage;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month);
  int _paymentDay = SessionFinancialRepository.instance.financialMonthStartDay;
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
    _paymentDay = existingDebt.paymentDay;
    if (existingDebt.loanEndDate != null && existingDebt.startDate != null) {
      final months =
          (existingDebt.loanEndDate!.year - existingDebt.startDate!.year) * 12 +
              existingDebt.loanEndDate!.month -
              existingDebt.startDate!.month;
      _loanLengthController.text =
          (months / 12).round().clamp(1, 99).toString();
    }
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
    _loanLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoan = _selectedDebtType == DebtType.loan;
    final isOther = _selectedDebtType == DebtType.other;
    final showRuleFields = _selectedPaymentType != MinPaymentType.fixed;
    final loanEndDate = isLoan ? _computeLoanEndDate() : null;
    final loanTermError =
        isLoan ? _controller.validateLoanTerm(_startDate, loanEndDate) : null;
    final estimatedLoanPayment = isLoan
        ? _controller.estimateLoanPayment(
            balance: _balanceController.text,
            apr: _aprController.text,
            startDate: _startDate,
            endDate: loanEndDate,
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
                if (!isOther) ...[
                  TextFormField(
                    controller: _aprController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'APR (%)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? value) {
                      return _controller.validateAprForDebtType(
                        value,
                        _selectedDebtType,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
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
                              Text(isLoan ? 'Loan start date' : 'Balance as of',
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
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 20,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _paymentDay,
                  decoration: const InputDecoration(
                    labelText: 'Payment day',
                    helperText:
                        'Day of the month this debt payment is normally taken',
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
                    setState(() {
                      _paymentDay = value;
                    });
                  },
                ),
                if (isLoan) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _loanLengthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Loan length',
                      helperText: 'e.g. 5 for a 5-year loan',
                      border: OutlineInputBorder(),
                      suffixText: 'years',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final v = int.tryParse(value?.trim() ?? '');
                      if (v == null || v <= 0)
                        return 'Enter a valid loan length in years';
                      return null;
                    },
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
                    isOther ? 'Monthly payment' : 'Minimum payment formula',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (isOther)
                    TextFormField(
                      controller: _minimumPaymentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Manual monthly payment (£)',
                        helperText:
                            'Used as a fixed payment each month for personal/other debts.',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        return _controller.validateMinimumPayment(value);
                      },
                    )
                  else ...[
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
                    ],
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
      });
    }
  }

  DateTime? _computeLoanEndDate() {
    final years = int.tryParse(_loanLengthController.text.trim());
    if (years == null || years <= 0) return null;
    final totalMonths = _startDate.month + years * 12;
    return DateTime(
      _startDate.year + (totalMonths - 1) ~/ 12,
      ((totalMonths - 1) % 12) + 1,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final isOther = _selectedDebtType == DebtType.other;
    final loanTermError = _selectedDebtType == DebtType.loan
        ? _controller.validateLoanTerm(_startDate, _computeLoanEndDate())
        : null;
    if (loanTermError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(loanTermError)),
        );
      return;
    }

    final balance = AmountParser.tryParse(_balanceController.text) ?? 0;
    final apr =
      isOther ? 0.0 : (AmountParser.tryParse(_aprController.text) ?? 0.0);

    if (!isOther && apr > 60) {
      final proceedHighApr = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Very high APR'),
              content: const Text(
                'APR is above 60%. Please confirm this is intentional.',
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
      if (!proceedHighApr) {
        return;
      }
    }

    double projectedMinPayment;
    if (_selectedDebtType == DebtType.loan) {
      projectedMinPayment = _controller.estimateLoanPayment(
            balance: _balanceController.text,
            apr: _aprController.text,
            startDate: _startDate,
            endDate: _computeLoanEndDate(),
          ) ??
          0;
    } else if (isOther || _selectedPaymentType == MinPaymentType.fixed) {
      projectedMinPayment =
          AmountParser.tryParse(_minimumPaymentController.text) ?? 0;
    } else {
      final rule = MinPaymentRule(
        type: _selectedPaymentType,
        percentage: AmountParser.tryParse(_percentageController.text) ?? 1.0,
        floor: AmountParser.tryParse(_floorController.text) ?? 25.0,
      );
      projectedMinPayment = rule.calculate(balance, apr, 0);
    }

    final monthlyInterest = balance * (apr / 100) / 12;
    if (apr > 0 && projectedMinPayment <= monthlyInterest) {
      final proceedLowPayment = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Payment may not reduce balance'),
              content: Text(
                'Estimated minimum payment (£${projectedMinPayment.toStringAsFixed(2)}) '
                'is less than or equal to monthly interest '
                '(£${monthlyInterest.toStringAsFixed(2)}).\n\n'
                'This debt could grow over time. Continue anyway?',
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
      if (!proceedLowPayment) {
        return;
      }
    }

    try {
      _controller.saveDebt(
        debtId: _existingDebt?.id,
        name: _nameController.text,
        debtType: _selectedDebtType,
        balance: _balanceController.text,
        apr: isOther ? '0' : _aprController.text,
        minimumPayment: _selectedDebtType == DebtType.loan
            ? '0'
            : isOther
                ? _minimumPaymentController.text
                : _selectedPaymentType == MinPaymentType.fixed
                    ? _minimumPaymentController.text
                    : '0',
        paymentDay: _paymentDay,
        minPaymentType: isOther ? MinPaymentType.fixed : _selectedPaymentType,
        percentage: _percentageController.text,
        floor: _floorController.text,
        startDate: _startDate,
        loanEndDate:
            _selectedDebtType == DebtType.loan ? _computeLoanEndDate() : null,
        extraPayments: _existingDebt?.extraPayments,
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message.toString())));
      return;
    }

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
