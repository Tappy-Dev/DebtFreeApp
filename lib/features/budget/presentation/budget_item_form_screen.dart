import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/utils/amount_parser.dart';
import 'package:debt_free_app/core/utils/uk_tax_calculator.dart';
import 'package:debt_free_app/features/budget/application/budget_item_form_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BudgetItemFormScreen extends StatefulWidget {
  const BudgetItemFormScreen({
    super.key,
    required this.type,
    this.itemId,
  });

  final BudgetItemType type;
  final String? itemId;

  @override
  State<BudgetItemFormScreen> createState() => _BudgetItemFormScreenState();
}

class _BudgetItemFormScreenState extends State<BudgetItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _pensionSacrificeController = TextEditingController();
  final _carSacrificeController = TextEditingController();
  final _otherSacrificeController = TextEditingController();
  final _taxableBenefitsController = TextEditingController();
  final _niableBenefitsController = TextEditingController();
  final _studentLoanableBenefitsController = TextEditingController();
  final _repository = SessionFinancialRepository.instance;
  late final BudgetItemFormController _controller;

  StudentLoanPlan _selectedStudentLoan = StudentLoanPlan.none;
  bool _trackable = false;
  int _paymentDay = 1;
  bool _guidanceExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = BudgetItemFormController(_repository);
    _paymentDay = _repository.financialMonthStartDay;
    _seedExistingValues();
  }

  bool get _isIncome => widget.type == BudgetItemType.income;
  bool get _isBill => widget.type == BudgetItemType.bill;
  bool get _isSubscription => widget.type == BudgetItemType.subscription;

  String get _title {
    if (_isIncome) return _isEditing ? 'Edit Income' : 'Add Income';
    if (_isBill) return _isEditing ? 'Edit Bill' : 'Add Bill';
    if (_isSubscription)
      return _isEditing ? 'Edit Subscription' : 'Add Subscription';
    return _isEditing ? 'Edit Expense' : 'Add Expense';
  }

  String get _nameLabel {
    if (_isIncome) return 'Income name';
    if (_isBill) return 'Bill name';
    if (_isSubscription) return 'Subscription name';
    return 'Expense name';
  }

  String get _amountLabel {
    return _isIncome ? 'Annual gross salary' : 'Amount';
  }

  bool get _isEditing => _existingName != null;

  String? get _existingName {
    final itemId = widget.itemId;
    if (itemId == null || itemId.isEmpty) {
      return null;
    }

    if (_isIncome) {
      for (final item in _repository.getIncomeSources()) {
        if (item.id == itemId) {
          return item.name;
        }
      }
      return null;
    }

    if (_isBill || _isSubscription) {
      for (final item in _repository.getBills()) {
        if (item.id == itemId) {
          return item.name;
        }
      }
      for (final item in _repository.getSubscriptions()) {
        if (item.id == itemId) {
          return item.name;
        }
      }
      return null;
    }

    for (final item in _repository.getExpenses()) {
      if (item.id == itemId) {
        return item.name;
      }
    }

    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _pensionSacrificeController.dispose();
    _carSacrificeController.dispose();
    _otherSacrificeController.dispose();
    _taxableBenefitsController.dispose();
    _niableBenefitsController.dispose();
    _studentLoanableBenefitsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_GB',
      symbol: '\u00A3',
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              children: <Widget>[
                if (_isIncome) ...<Widget>[
                  _IncomeGuidanceCard(
                    expanded: _guidanceExpanded,
                    onToggle: () => setState(() => _guidanceExpanded = !_guidanceExpanded),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: _nameLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    return _controller.validateRequired(value, _nameLabel);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _amountLabel,
                    border: const OutlineInputBorder(),
                    prefixText: '\u00A3',
                    helperText: _isIncome
                        ? 'Your annual salary before tax (e.g. 50000)'
                        : null,
                  ),
                  onChanged: _isIncome ? (_) => setState(() {}) : null,
                  validator: (String? value) {
                    return _controller.validateAmount(value, _amountLabel);
                  },
                ),
                if (_isBill || _isSubscription) ...<Widget>[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _paymentDay,
                    decoration: const InputDecoration(
                      labelText: 'Payment day',
                      helperText:
                          'Day of the month this payment is usually taken',
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
                      setState(() => _paymentDay = value);
                    },
                  ),
                ],
                if (_isIncome) ...<Widget>[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<StudentLoanPlan>(
                    initialValue: _selectedStudentLoan,
                    decoration: const InputDecoration(
                      labelText: 'Student loan plan',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<StudentLoanPlan>>[
                      DropdownMenuItem(
                        value: StudentLoanPlan.none,
                        child: Text('None'),
                      ),
                      DropdownMenuItem(
                        value: StudentLoanPlan.plan1,
                        child: Text('Plan 1'),
                      ),
                      DropdownMenuItem(
                        value: StudentLoanPlan.plan2,
                        child: Text('Plan 2'),
                      ),
                      DropdownMenuItem(
                        value: StudentLoanPlan.plan4,
                        child: Text('Plan 4'),
                      ),
                      DropdownMenuItem(
                        value: StudentLoanPlan.plan5,
                        child: Text('Plan 5'),
                      ),
                      DropdownMenuItem(
                        value: StudentLoanPlan.postgraduate,
                        child: Text('Postgraduate'),
                      ),
                    ],
                    onChanged: (StudentLoanPlan? value) {
                      setState(() {
                        _selectedStudentLoan = value ?? StudentLoanPlan.none;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Salary sacrifice breakdown (monthly)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _pensionSacrificeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Pension sacrifice',
                      border: OutlineInputBorder(),
                      prefixText: '\u00A3',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (String? value) {
                      final fieldError = _controller.validateNonNegativeMoney(
                        value,
                        'Pension sacrifice',
                      );
                      if (fieldError != null) {
                        return fieldError;
                      }
                      return _controller.validateSalarySacrificeTotal(
                        annualGross: _amountController.text,
                        monthlyPensionSacrifice:
                            _pensionSacrificeController.text,
                        monthlyCarSacrifice: _carSacrificeController.text,
                        monthlyOtherSacrifice:
                            _otherSacrificeController.text,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _carSacrificeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Car sacrifice',
                      border: OutlineInputBorder(),
                      prefixText: '\u00A3',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (String? value) {
                      final fieldError = _controller.validateNonNegativeMoney(
                        value,
                        'Car sacrifice',
                      );
                      if (fieldError != null) {
                        return fieldError;
                      }
                      return _controller.validateSalarySacrificeTotal(
                        annualGross: _amountController.text,
                        monthlyPensionSacrifice:
                            _pensionSacrificeController.text,
                        monthlyCarSacrifice: _carSacrificeController.text,
                        monthlyOtherSacrifice:
                            _otherSacrificeController.text,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otherSacrificeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Other sacrifice',
                      border: OutlineInputBorder(),
                      prefixText: '\u00A3',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (String? value) {
                      final fieldError = _controller.validateNonNegativeMoney(
                        value,
                        'Other sacrifice',
                      );
                      if (fieldError != null) {
                        return fieldError;
                      }
                      return _controller.validateSalarySacrificeTotal(
                        annualGross: _amountController.text,
                        monthlyPensionSacrifice:
                            _pensionSacrificeController.text,
                        monthlyCarSacrifice: _carSacrificeController.text,
                        monthlyOtherSacrifice:
                            _otherSacrificeController.text,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _taxableBenefitsController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Taxable benefits (monthly)',
                      border: OutlineInputBorder(),
                      prefixText: '\u00A3',
                      helperText:
                          'Examples: private medical, fuel benefit, BIK taxable value',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (String? value) => _controller
                        .validateNonNegativeMoney(value, 'Taxable benefits'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _niableBenefitsController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'NI-able benefits (monthly)',
                      border: OutlineInputBorder(),
                      prefixText: '\u00A3',
                      helperText:
                          'Leave 0 unless this benefit is NI-able on your payroll',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (String? value) => _controller
                        .validateNonNegativeMoney(value, 'NI-able benefits'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _studentLoanableBenefitsController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Student-loanable benefits (monthly)',
                      border: OutlineInputBorder(),
                      prefixText: '\u00A3',
                      helperText:
                          'Leave 0 unless these benefits are included for student loan',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (String? value) =>
                        _controller.validateNonNegativeMoney(
                      value,
                      'Student-loanable benefits',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPayBreakdownCard(currency),
                ],
                if (!_isIncome && !_isBill && !_isSubscription) ...<Widget>[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _trackable,
                    onChanged: (bool? v) =>
                        setState(() => _trackable = v ?? false),
                    title: const Text('Trackable'),
                    subtitle: const Text(
                        'Show in Monthly Tracking to record actual spend'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submit,
                  child: Text(_isEditing ? 'Update' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPayBreakdownCard(NumberFormat currency) {
    final grossText = _amountController.text;
    final parsed = AmountParser.tryParse(grossText);
    if (parsed == null || parsed <= 0) {
      return const SizedBox.shrink();
    }

    final totalMonthlySacrifice =
        (AmountParser.tryParse(_pensionSacrificeController.text) ?? 0) +
            (AmountParser.tryParse(_carSacrificeController.text) ?? 0) +
            (AmountParser.tryParse(_otherSacrificeController.text) ?? 0);

    final breakdown = UkTaxCalculator.calculateMonthlyNet(
      annualGross: parsed,
      monthlySalarySacrifice: totalMonthlySacrifice,
      monthlyTaxableBenefits:
          AmountParser.tryParse(_taxableBenefitsController.text) ?? 0,
      monthlyNiableBenefits:
          AmountParser.tryParse(_niableBenefitsController.text) ?? 0,
      monthlyStudentLoanableBenefits:
          AmountParser.tryParse(_studentLoanableBenefitsController.text) ?? 0,
      studentLoanPlan: _selectedStudentLoan,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Monthly Pay Breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _breakdownRow('Gross monthly', breakdown.monthlyGross, currency),
            if (totalMonthlySacrifice > 0)
              _breakdownRow(
                'Salary sacrifice',
                -breakdown.monthlySalarySacrifice,
                currency,
              ),
            if (breakdown.monthlyTaxableBenefits > 0)
              _breakdownRow(
                'Taxable benefits',
                breakdown.monthlyTaxableBenefits,
                currency,
              ),
            if (breakdown.monthlyNiableBenefits > 0)
              _breakdownRow(
                'NI-able benefits',
                breakdown.monthlyNiableBenefits,
                currency,
              ),
            if (breakdown.monthlyStudentLoanableBenefits > 0)
              _breakdownRow(
                'Student-loanable benefits',
                breakdown.monthlyStudentLoanableBenefits,
                currency,
              ),
            _breakdownRow('Income tax', -breakdown.monthlyTax, currency),
            _breakdownRow('National Insurance', -breakdown.monthlyNI, currency),
            if (breakdown.monthlyStudentLoan > 0)
              _breakdownRow(
                'Student loan',
                -breakdown.monthlyStudentLoan,
                currency,
              ),
            const Divider(),
            _breakdownRow('Net take-home', breakdown.monthlyNet, currency,
                bold: true),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(
    String label,
    double value,
    NumberFormat currency, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label),
          Text(
            currency.format(value),
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }

  void _seedExistingValues() {
    final itemId = widget.itemId;
    if (itemId == null || itemId.isEmpty) {
      return;
    }

    if (_isIncome) {
      for (final item in _repository.getIncomeSources()) {
        if (item.id == itemId) {
          _nameController.text = item.name;
          _amountController.text = item.annualGross.toStringAsFixed(2);
          _selectedStudentLoan = item.studentLoanPlan;
          _pensionSacrificeController.text =
              item.monthlyPensionSacrifice.toStringAsFixed(2);
          _carSacrificeController.text =
              item.monthlyCarSacrifice.toStringAsFixed(2);
          _otherSacrificeController.text =
              item.monthlyOtherSacrifice.toStringAsFixed(2);
          _taxableBenefitsController.text =
              item.monthlyTaxableBenefits.toStringAsFixed(2);
          _niableBenefitsController.text =
              item.monthlyNiableBenefits.toStringAsFixed(2);
          _studentLoanableBenefitsController.text =
              item.monthlyStudentLoanableBenefits.toStringAsFixed(2);
          return;
        }
      }
      return;
    }

    for (final item in _repository.getExpenses()) {
      if (item.id == itemId) {
        _nameController.text = item.name;
        _amountController.text = item.amount.toStringAsFixed(2);
        _trackable = item.trackable;
        return;
      }
    }

    for (final item in [
      ..._repository.getBills(),
      ..._repository.getSubscriptions()
    ]) {
      if (item.id == itemId) {
        _nameController.text = item.name;
        _amountController.text = item.amount.toStringAsFixed(2);
        _paymentDay = item.paymentDay ?? _repository.financialMonthStartDay;
        return;
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isIncome) {
      final sacrificeError = _controller.validateSalarySacrificeTotal(
        annualGross: _amountController.text,
        monthlyPensionSacrifice: _pensionSacrificeController.text,
        monthlyCarSacrifice: _carSacrificeController.text,
        monthlyOtherSacrifice: _otherSacrificeController.text,
      );
      if (sacrificeError != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(sacrificeError)));
        return;
      }

      final gross = AmountParser.tryParse(_amountController.text) ?? 0;
      if (gross > 5000000) {
        final proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Very high salary amount'),
                content: const Text(
                  'This annual salary is above £5,000,000. Please confirm this is intentional.',
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
        if (!proceed) {
          return;
        }
      }

      try {
        _controller.saveIncomeItem(
          itemId: widget.itemId,
          name: _nameController.text,
          annualGross: _amountController.text,
          studentLoanPlan: _selectedStudentLoan,
          monthlyPensionSacrifice: _pensionSacrificeController.text,
          monthlyCarSacrifice: _carSacrificeController.text,
          monthlyOtherSacrifice: _otherSacrificeController.text,
          monthlyTaxableBenefits: _taxableBenefitsController.text,
          monthlyNiableBenefits: _niableBenefitsController.text,
          monthlyStudentLoanableBenefits:
              _studentLoanableBenefitsController.text,
        );
      } on ArgumentError catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message.toString())));
        return;
      }
    } else {
      try {
        _controller.saveItem(
          type: widget.type,
          itemId: widget.itemId,
          name: _nameController.text,
          amount: _amountController.text,
          trackable: _trackable,
          paymentDay: _isBill || _isSubscription ? _paymentDay : null,
        );
      } on ArgumentError catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message.toString())));
        return;
      }
    }

    if (!mounted) {
      return;
    }

    if (context.canPop()) {
      Navigator.of(context).pop(true);
      return;
    }

    context.go('/budget');
  }
}

class _IncomeGuidanceCard extends StatelessWidget {
  const _IncomeGuidanceCard({
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Where do I find this information?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: cs.outlineVariant, height: 1),
                  const SizedBox(height: 12),
                  _GuidanceRow(
                    label: 'Annual gross salary',
                    detail: 'Your employment contract, P60, or payslip — look for "Total pay" or "Gross pay" before tax.',
                    theme: theme,
                    cs: cs,
                  ),
                  const SizedBox(height: 10),
                  _GuidanceRow(
                    label: 'Student loan plan',
                    detail: 'Check your payslip for a "Student Loan" deduction, or your original loan agreement / HMRC online account.',
                    theme: theme,
                    cs: cs,
                  ),
                  const SizedBox(height: 10),
                  _GuidanceRow(
                    label: 'Pension / Car / Other sacrifice',
                    detail: 'Your payslip — listed as pre-tax deductions before "Gross for tax" is calculated. Your HR portal will also show scheme details.',
                    theme: theme,
                    cs: cs,
                  ),
                  const SizedBox(height: 10),
                  _GuidanceRow(
                    label: 'Taxable benefits',
                    detail: 'Your P11D (issued by your employer after each tax year) or payslip if benefits are payrolled. Includes private medical, company car BIK, fuel benefit.',
                    theme: theme,
                    cs: cs,
                  ),
                  const SizedBox(height: 10),
                  _GuidanceRow(
                    label: 'NI-able / Student-loanable benefits',
                    detail: 'Leave 0 if unsure — most employees can ignore these. Check your payslip or ask your payroll team if you have complex benefit arrangements.',
                    theme: theme,
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tip: You can add multiple income sources — salary, freelance, rental income, etc. — separately.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GuidanceRow extends StatelessWidget {
  const _GuidanceRow({
    required this.label,
    required this.detail,
    required this.theme,
    required this.cs,
  });

  final String label;
  final String detail;
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
