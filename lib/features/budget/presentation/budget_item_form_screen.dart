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

  @override
  void initState() {
    super.initState();
    _controller = BudgetItemFormController(_repository);
    _seedExistingValues();
  }

  bool get _isIncome => widget.type == BudgetItemType.income;
  bool get _isBill => widget.type == BudgetItemType.bill;

  String get _title {
    final label = _isIncome ? 'Income' : _isBill ? 'Bill' : 'Expense';
    return _isEditing ? 'Edit $label' : 'Add $label';
  }

  String get _nameLabel {
    return _isIncome ? 'Income name' : _isBill ? 'Bill name' : 'Expense name';
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

    if (_isBill) {
      for (final item in _repository.getBills()) {
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
                if (_isIncome) ...<Widget>[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<StudentLoanPlan>(
                    value: _selectedStudentLoan,
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
                    validator: (String? value) => _controller
                        .validateNonNegativeMoney(value, 'Pension sacrifice'),
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
                    validator: (String? value) => _controller
                        .validateNonNegativeMoney(value, 'Car sacrifice'),
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
                    validator: (String? value) => _controller
                        .validateNonNegativeMoney(value, 'Other sacrifice'),
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
                    validator: (String? value) => _controller.validateNonNegativeMoney(
                      value,
                      'Student-loanable benefits',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPayBreakdownCard(currency),
                ],
                if (!_isIncome && !_isBill) ...<Widget>[
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
            style: bold
                ? const TextStyle(fontWeight: FontWeight.bold)
                : null,
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

    for (final item in _repository.getBills()) {
      if (item.id == itemId) {
        _nameController.text = item.name;
        _amountController.text = item.amount.toStringAsFixed(2);
        return;
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isIncome) {
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
        monthlyStudentLoanableBenefits: _studentLoanableBenefitsController.text,
      );
    } else {
      _controller.saveItem(
        type: widget.type,
        itemId: widget.itemId,
        name: _nameController.text,
        amount: _amountController.text,
        trackable: _trackable,
      );
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
