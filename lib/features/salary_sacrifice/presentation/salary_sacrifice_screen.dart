import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/utils/uk_tax_calculator.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalarySacrificeScreen extends StatefulWidget {
  const SalarySacrificeScreen({super.key});

  @override
  State<SalarySacrificeScreen> createState() => _SalarySacrificeScreenState();
}

class _SalarySacrificeScreenState extends State<SalarySacrificeScreen> {
  final _repository = SessionFinancialRepository.instance;
  final _currencyFormat = NumberFormat.currency(symbol: '£', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incomeSources = _repository.getIncomeSources();

    final totalMonthlySacrifice = incomeSources.fold<double>(
      0,
      (double sum, s) => sum + s.monthlySalarySacrificeTotal,
    );

    final comparison = _buildComparison(incomeSources: incomeSources);

    return Scaffold(
      appBar: AppBar(title: const Text('Salary Sacrifice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ── Explanation Card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('How salary sacrifice works',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Salary sacrifice is now entered per income source '
                    'inside the Income form. Use Pension, Car, and Other '
                    'fields there to model your payslip accurately.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (incomeSources.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No income sources found.\n'
                    'Add income first to model salary sacrifice.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),

          if (incomeSources.isNotEmpty)
            ...incomeSources.map((IncomeSource income) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(income.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        _buildRow(
                          'Pension',
                          _currencyFormat.format(income.monthlyPensionSacrifice),
                        ),
                        _buildRow(
                          'Car',
                          _currencyFormat.format(income.monthlyCarSacrifice),
                        ),
                        _buildRow(
                          'Other',
                          _currencyFormat.format(income.monthlyOtherSacrifice),
                        ),
                        const Divider(height: 20),
                        _buildRow(
                          'Total sacrificed/mo',
                          _currencyFormat.format(income.monthlySalarySacrificeTotal),
                        ),
                      ],
                    ),
                  ),
                )),

          if (comparison != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Impact on Take-Home Pay',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _buildRow(
                      'Total gross sacrificed/mo',
                      _currencyFormat.format(totalMonthlySacrifice),
                    ),
                    _buildRow(
                      'Monthly net without sacrifice',
                      _currencyFormat.format(comparison.monthlyNetWithout),
                    ),
                    _buildRow(
                      'Monthly net with sacrifice',
                      _currencyFormat.format(comparison.monthlyNetWith),
                    ),
                    _buildRow(
                      'Actual cost to take-home',
                      _currencyFormat.format(
                        comparison.monthlyNetWithout - comparison.monthlyNetWith,
                      ),
                    ),
                    _buildRow(
                      'Tax/NI saving per month',
                      _currencyFormat.format(
                        totalMonthlySacrifice -
                            (comparison.monthlyNetWithout -
                                comparison.monthlyNetWith),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _SacrificeComparison? _buildComparison({
    required List<IncomeSource> incomeSources,
  }) {
    if (incomeSources.isEmpty) {
      return null;
    }

    double monthlyNetWithout = 0;
    double monthlyNetWith = 0;
    for (final income in incomeSources) {
      monthlyNetWith += income.payBreakdown().monthlyNet;
      monthlyNetWithout += UkTaxCalculator.calculateMonthlyNet(
        annualGross: income.annualGross,
        monthlySalarySacrifice: 0,
        studentLoanPlan: income.studentLoanPlan,
        monthlyTaxableBenefits: income.monthlyTaxableBenefits,
        monthlyNiableBenefits: income.monthlyNiableBenefits,
        monthlyStudentLoanableBenefits: income.monthlyStudentLoanableBenefits,
      ).monthlyNet;
    }

    return _SacrificeComparison(
      monthlyNetWithout: monthlyNetWithout,
      monthlyNetWith: monthlyNetWith,
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SacrificeComparison {
  const _SacrificeComparison({
    required this.monthlyNetWithout,
    required this.monthlyNetWith,
  });

  final double monthlyNetWithout;
  final double monthlyNetWith;
}
