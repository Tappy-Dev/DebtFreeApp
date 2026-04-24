import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/services/ai_insight_service.dart';
import 'package:debt_free_app/core/services/financial_summary.dart';
import 'package:debt_free_app/features/budget/domain/build_budget_snapshot.dart';
import 'package:debt_free_app/features/scenarios/application/scenario_builder_controller.dart';
import 'package:debt_free_app/features/scenarios/domain/build_scenario_overview.dart';
import 'package:debt_free_app/features/scenarios/domain/scenario_overview.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/features/tracking/domain/build_monthly_budget_summary.dart';
import 'package:debt_free_app/features/tracking/models/monthly_budget_summary.dart';
import 'package:debt_free_app/shared/widgets/app_shell_scaffold.dart';
import 'package:debt_free_app/shared/widgets/comparison_bars_card.dart';
import 'package:flutter/material.dart';

class ScenariosScreen extends StatefulWidget {
  const ScenariosScreen({
    super.key,
    this.repository,
  });

  final SessionFinancialRepository? repository;

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen> {
  late final SessionFinancialRepository _repository;
  late final ScenarioBuilderController _controller;
  late final TextEditingController _incomeIncreaseController;
  late final TextEditingController _expenseReductionController;
  late final TextEditingController _extraPaymentController;
  late final TextEditingController _startMonthController;
  late final TextEditingController _durationInMonthsController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _planError;
  final AiInsightService _aiService = AiInsightService();
  String? _aiInsight;
  bool _aiLoading = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SessionFinancialRepository.instance;
    _controller = ScenarioBuilderController(_repository);
    _incomeIncreaseController = TextEditingController(
      text: _formatScenarioAmount(_controller.currentIncomeIncrease()),
    );
    _expenseReductionController = TextEditingController(
      text: _formatScenarioAmount(_controller.currentExpenseReduction()),
    );
    _extraPaymentController = TextEditingController(
      text: _formatScenarioAmount(_controller.currentExtraPayment()),
    );
    _startMonthController = TextEditingController(
      text: _controller.currentStartMonth().toString(),
    );
    _durationInMonthsController = TextEditingController(
      text: _formatDuration(_controller.currentDurationInMonths()),
    );
    _repository.addListener(_syncScenarioFields);
  }

  @override
  void dispose() {
    _repository.removeListener(_syncScenarioFields);
    _incomeIncreaseController.dispose();
    _expenseReductionController.dispose();
    _extraPaymentController.dispose();
    _startMonthController.dispose();
    _durationInMonthsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repository,
      builder: (BuildContext context, Widget? child) {
        final overview = BuildScenarioOverview(
          repository: _repository,
        )();

        return AppShellScaffold(
          title: 'Scenarios',
          currentIndex: 4,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Core Feature',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'What happens if I earn more, spend less, or pay extra each month?',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Baseline room for extra payments: \u00A3${overview.remainingCash.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _incomeIncreaseController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Extra monthly income',
                            border: OutlineInputBorder(),
                            prefixText: '\u00A3',
                          ),
                          validator: _controller.validateIncomeIncrease,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _expenseReductionController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Monthly expense reduction',
                            border: OutlineInputBorder(),
                            prefixText: '\u00A3',
                          ),
                          validator: _controller.validateExpenseReduction,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _extraPaymentController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Extra monthly payment',
                            border: OutlineInputBorder(),
                            prefixText: '\u00A3',
                          ),
                          validator: _controller.validateStandaloneExtraPayment,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _startMonthController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Start after this many months',
                            border: OutlineInputBorder(),
                          ),
                          validator: _controller.validateStartMonth,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _durationInMonthsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Duration in months (optional)',
                            border: OutlineInputBorder(),
                          ),
                          validator: _controller.validateDurationInMonths,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _applyScenario,
                          child: const Text('Apply scenario'),
                        ),
                        if (overview.hasActiveChanges) ...<Widget>[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _clearScenario,
                            child: const Text('Clear scenario'),
                          ),
                        ],
                        if (_planError != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            _planError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ComparisonBarsCard(
                title: 'Interest Comparison',
                baselineLabel: 'Baseline interest',
                baselineValue: overview.baselineInterest,
                scenarioLabel: 'Scenario interest',
                scenarioValue: overview.scenarioInterest,
                valuePrefix: '\u00A3',
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        overview.guidanceTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        overview.planSummaryTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(overview.planSummaryMessage),
                      const SizedBox(height: 12),
                      Text(overview.scheduleSummary),
                      if (overview.scheduleWarningMessage != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          overview.scheduleWarningMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _normalizeSchedule,
                          child: const Text('Normalize schedule'),
                        ),
                      ],
                      if (overview.activeChangeLabels.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          'Current adjustments',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (overview.incomeIncrease > 0)
                          _AdjustmentRow(
                            label:
                                'Extra monthly income: \u00A3${overview.incomeIncrease.toStringAsFixed(2)}',
                            removeLabel: 'Remove income boost',
                            onRemove: () => _removeAdjustment(
                              ChangeType.increaseIncome,
                            ),
                          ),
                        if (overview.expenseReduction > 0)
                          _AdjustmentRow(
                            label:
                                'Monthly expense reduction: \u00A3${overview.expenseReduction.toStringAsFixed(2)}',
                            removeLabel: 'Remove expense cut',
                            onRemove: () => _removeAdjustment(
                              ChangeType.reduceExpenses,
                            ),
                          ),
                        if (overview.extraPayment > 0)
                          _AdjustmentRow(
                            label:
                                'Extra debt payment: \u00A3${overview.extraPayment.toStringAsFixed(2)}',
                            removeLabel: 'Remove extra payment',
                            onRemove: () => _removeAdjustment(
                              ChangeType.extraPayment,
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Text(overview.guidanceMessage),
                      const SizedBox(height: 12),
                      Text(
                        'Income boost in this plan: \u00A3${overview.incomeIncrease.toStringAsFixed(2)}',
                      ),
                      Text(
                        'Expense cut in this plan: \u00A3${overview.expenseReduction.toStringAsFixed(2)}',
                      ),
                      Text(
                        'Available room after plan changes: \u00A3${overview.availableCashAfterAdjustments.toStringAsFixed(2)}',
                      ),
                      Text(
                        'Cash buffer after planned extra payment: \u00A3${overview.cashBufferAfterPlan.toStringAsFixed(2)}',
                      ),
                      Text(
                        'Scenario affordability: ${overview.isAffordable ? 'Within budget' : 'Over budget'}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _AiInsightsCard(
                insight: _aiInsight,
                isLoading: _aiLoading,
                error: _aiError,
                onGenerate: () => _generateAiInsight(overview),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Comparison',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Baseline payoff date: ${overview.baselinePayoffDateLabel}',
                      ),
                      Text(
                        'Scenario payoff date: ${overview.scenarioPayoffDateLabel}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Baseline interest: \u00A3${overview.baselineInterest.toStringAsFixed(2)}',
                      ),
                      Text(
                        'Scenario interest: \u00A3${overview.scenarioInterest.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      Text('Months saved: ${overview.monthsSaved}'),
                      Text(
                        'Interest saved: \u00A3${overview.interestSaved.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyScenario() {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _planError = null;
      });
      return;
    }

    final planError = _controller.validateScenarioPlan(
      extraPayment: _extraPaymentController.text,
      incomeIncrease: _incomeIncreaseController.text,
      expenseReduction: _expenseReductionController.text,
    );
    if (planError != null) {
      setState(() {
        _planError = planError;
      });
      return;
    }

    _controller.saveScenarioPlan(
      extraPayment: _extraPaymentController.text,
      incomeIncrease: _incomeIncreaseController.text,
      expenseReduction: _expenseReductionController.text,
      startMonth: _startMonthController.text,
      durationInMonths: _durationInMonthsController.text,
    );
    setState(() {
      _planError = null;
    });
    _showSnackBar('Scenario updated.');
  }

  void _clearScenario() {
    _controller.clearScenarioPlan();
    setState(() {
      _planError = null;
    });
    _showSnackBar('Scenario cleared.');
  }

  Future<void> _generateAiInsight(ScenarioOverview overview) async {
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });

    try {
      final budgetSnapshot = BuildBudgetSnapshot(_repository)();

      // Load the last 3 months of tracking data for the AI
      final trackingBuilder = BuildMonthlyBudgetSummary(_repository);
      final now = DateTime.now();
      final recentTracking = <MonthlyBudgetSummary>[];
      for (int i = 0; i < 3; i++) {
        final date = DateTime(now.year, now.month - i);
        final summary = await trackingBuilder(
          year: date.year,
          month: date.month,
        );
        // Only include months with at least one actual entered
        if (summary.actuals.any((a) => a.actual > 0)) {
          recentTracking.add(summary);
        }
      }

      final summary = FinancialSummary(
        debts: _repository.getDebts(),
        incomeSources: _repository.getIncomeSources(),
        mortgage: _repository.getMortgage(),
        mortgages: _repository.getMortgages(),
        budgetSnapshot: budgetSnapshot,
        scenarioOverview: overview,
        recentTracking: recentTracking,
      );
      final insight = await _aiService.generateInsight(summary);
      if (mounted) {
        setState(() {
          _aiInsight = insight;
          _aiLoading = false;
        });
      }
    } on AiInsightException catch (e) {
      if (mounted) {
        setState(() {
          _aiError = e.message;
          _aiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError = 'Something went wrong. Please try again.';
          _aiLoading = false;
        });
      }
    }
  }

  void _removeAdjustment(ChangeType type) {
    _controller.removeChange(type);
    setState(() {
      _planError = null;
    });
    _showSnackBar('Scenario adjustment removed.');
  }

  void _normalizeSchedule() {
    _controller.normalizeCurrentPlan();
    setState(() {
      _planError = null;
    });
    _showSnackBar('Scenario schedule normalized.');
  }

  void _syncScenarioFields() {
    _syncField(
      controller: _incomeIncreaseController,
      amount: _controller.currentIncomeIncrease(),
    );
    _syncField(
      controller: _expenseReductionController,
      amount: _controller.currentExpenseReduction(),
    );
    _syncField(
      controller: _extraPaymentController,
      amount: _controller.currentExtraPayment(),
    );
    _syncIntegerField(
      controller: _startMonthController,
      value: _controller.currentStartMonth(),
    );
    _syncOptionalIntegerField(
      controller: _durationInMonthsController,
      value: _controller.currentDurationInMonths(),
    );
  }

  void _syncField({
    required TextEditingController controller,
    required double amount,
  }) {
    final formattedValue = _formatScenarioAmount(amount);
    if (controller.text == formattedValue) {
      return;
    }

    controller.value = TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }

  String _formatScenarioAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }

    return amount.toStringAsFixed(2);
  }

  String _formatDuration(int? value) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  void _syncIntegerField({
    required TextEditingController controller,
    required int value,
  }) {
    final formattedValue = value.toString();
    if (controller.text == formattedValue) {
      return;
    }

    controller.value = TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }

  void _syncOptionalIntegerField({
    required TextEditingController controller,
    required int? value,
  }) {
    final formattedValue = _formatDuration(value);
    if (controller.text == formattedValue) {
      return;
    }

    controller.value = TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({
    required this.label,
    required this.removeLabel,
    required this.onRemove,
  });

  final String label;
  final String removeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text('- $label'),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onRemove,
            child: Text(removeLabel),
          ),
        ],
      ),
    );
  }
}

class _AiInsightsCard extends StatelessWidget {
  const _AiInsightsCard({
    required this.insight,
    required this.isLoading,
    required this.error,
    required this.onGenerate,
  });

  final String? insight;
  final bool isLoading;
  final String? error;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Insights',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Get personalised advice based on your complete financial picture — '
              'debts, mortgage, budget, and current scenario.',
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: <Widget>[
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Analysing your finances...'),
                    ],
                  ),
                ),
              )
            else ...<Widget>[
              FilledButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  insight == null ? 'Generate insights' : 'Refresh insights',
                ),
              ),
              if (error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (insight != null) ...<Widget>[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                SelectableText(insight!),
                const SizedBox(height: 12),
                Text(
                  'This is AI-generated guidance, not regulated financial advice.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
