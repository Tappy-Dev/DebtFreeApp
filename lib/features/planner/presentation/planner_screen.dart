import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/services/financial_summary.dart';
import 'package:debt_free_app/core/utils/amount_parser.dart';
import 'package:debt_free_app/features/budget/domain/build_budget_snapshot.dart';
import 'package:debt_free_app/features/planner/models/planner_event.dart';
import 'package:debt_free_app/features/planner/presentation/advisor_result_screen.dart';
import 'package:debt_free_app/features/tracking/domain/build_monthly_budget_summary.dart';
import 'package:debt_free_app/features/tracking/models/monthly_budget_summary.dart';
import 'package:debt_free_app/shared/widgets/app_shell_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  static const int _maxTrackingLookbackMonths = 12;

  final SessionFinancialRepository _repository =
      SessionFinancialRepository.instance;



  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repository,
      builder: (BuildContext context, Widget? child) {
        final events = _repository.getPlannerEvents();

        return AppShellScaffold(
          title: 'Planner',
          currentIndex: 4,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              // ── What-If Events (inactive — kept for future use) ──
              // Card(
              //   child: Padding(
              //     padding: const EdgeInsets.all(20),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: <Widget>[
              //         Row(
              //           children: [
              //             Expanded(
              //               child: Text(
              //                 'What-If Events',
              //                 style: Theme.of(context).textTheme.titleLarge,
              //               ),
              //             ),
              //             FilledButton.icon(
              //               onPressed: _addEvent,
              //               icon: const Icon(Icons.add, size: 18),
              //               label: const Text('Add Event'),
              //             ),
              //           ],
              //         ),
              //         if (events.isEmpty) ...[
              //           const SizedBox(height: 16),
              //           Text(
              //             'No events yet. Add a what-if event to see how it impacts your finances.',
              //             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              //                   color: Theme.of(context).colorScheme.outline,
              //                 ),
              //           ),
              //         ] else ...[
              //           const SizedBox(height: 12),
              //           ...events.map((e) => _buildEventTile(e)),
              //         ],
              //       ],
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 16),

              // ── Analyse with AI (inactive — kept for future use) ──
              // FilledButton.icon(
              //   onPressed: events.isEmpty || !_hasAiData ? null : _analyseWithAi,
              //   icon: const Icon(Icons.auto_awesome, size: 18),
              //   label: const Text('Analyse with AI'),
              // ),
              // const SizedBox(height: 24),
              // Divider(color: Theme.of(context).colorScheme.outlineVariant),
              // const SizedBox(height: 16),

              // ── AI Advisor Section ──
              _buildAdvisorSection(context),
            ],
          ),
        );
      },
    );
  }

  static const List<_AdvisorPrompt> _advisorPrompts = [
    _AdvisorPrompt(
      id: 'repayment_strategy',
      icon: Icons.format_list_numbered_rounded,
      title: 'Suggest Repayment Strategy',
      subtitle: 'Which debts should I tackle first?',
      question:
          'Based on my actual debt balances, interest rates, and available cash, recommend the order I should pay off my debts. '
          'For each debt, explain why it should be tackled at that priority. '
          'Give me a clear ranked list and tell me how much extra I should throw at the top-priority debt each month.',
    ),
    _AdvisorPrompt(
      id: 'mortgage_vs_debt',
      icon: Icons.home_outlined,
      title: 'Overpay mortgage or pay off debts first?',
      subtitle: 'Where does my extra money have the most impact?',
      question:
          'Given my mortgage rate, balance, and term alongside my other debts — where would extra money have the most impact? '
          'Compare the interest savings of mortgage overpayments vs directing that money at my highest-APR debts. '
          'Show me the numbers for both approaches.',
    ),
    _AdvisorPrompt(
      id: 'afford_large_purchase',
      icon: Icons.shopping_cart_outlined,
      title: 'Can I afford a large purchase right now?',
      subtitle: 'Impact of a big spend on my debt-free plan',
      question:
          'Looking at my current cash flow, debts, and remaining budget — could I comfortably absorb a large one-off purchase (e.g. £500-£2000) without derailing my debt repayment? '
          'How many months would it set back my debt-free date? '
          'What is the maximum I could spend without significant impact?',
    ),
    _AdvisorPrompt(
      id: 'how_am_i_doing',
      icon: Icons.query_stats_rounded,
      title: 'How am I doing?',
      subtitle: 'Progress summary, streaks, and watch-outs',
      question:
          'How am I doing overall? Give me a clear summary report using my latest tracking trends, '
          'including spending pattern changes, whether I stayed within available money, and the strongest habit streaks. '
          'Call out my wins, watch-outs, and short actions for the next 7 days.',
    ),
    _AdvisorPrompt(
      id: 'emergency_fund',
      icon: Icons.savings_outlined,
      title: 'Should I build an emergency fund first?',
      subtitle: 'Emergency savings vs paying off debt',
      question:
          'I have debts to pay off but no emergency fund. Should I prioritise building a 3-month emergency fund before attacking my debts, '
          'or should I focus on debt repayment first? '
          'Consider my interest rates, monthly surplus, and the risk of not having a buffer. '
          'Give me a clear recommendation with a suggested split of any monthly surplus.',
    ),
    _AdvisorPrompt(
      id: 'overspending',
      icon: Icons.trending_up_rounded,
      title: 'Where am I overspending?',
      subtitle: 'Spot budget categories going over each month',
      question:
          'Looking at my tracked actuals vs budgeted amounts — which expense categories am I consistently overspending on? '
          'Rank them by total overspend. For each one, suggest a realistic action to bring it back in line. '
          'Also highlight any categories where I am significantly underspending that could free up extra money for debt repayment.',
    ),
    _AdvisorPrompt(
      id: 'income_change',
      icon: Icons.swap_vert_rounded,
      title: 'What if my income changed?',
      subtitle: 'Impact of a pay rise, cut, or job loss on my plan',
      question:
          'How would a change in my income affect my debt-free date and monthly budget? '
          'Show me three scenarios: a 10% pay rise, a 10% pay cut, and losing my income entirely for 3 months. '
          'For each scenario, tell me which debts are at risk, how many months it shifts my debt-free date, and what I should do first.',
    ),
    _AdvisorPrompt(
      id: 'salary_sacrifice',
      icon: Icons.work_outline_rounded,
      title: 'Is my salary sacrifice worth it?',
      subtitle: 'Pension contributions vs paying off debt',
      question:
          'Given my current salary sacrifice pension contributions, debt balances, and interest rates — am I better off increasing pension contributions or directing that money at my debts? '
          'Compare the long-term benefit of extra pension growth against the guaranteed interest saving of paying down debt faster. '
          'Factor in any employer matching and give me a clear recommendation.',
    ),
  ];

  Widget _buildAdvisorSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.psychology_outlined,
                size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('AI Budget Assistant',
                style: theme.textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Ask AI to analyse your budget and answer specific questions.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Text(
          'For informational purposes only. Not regulated financial advice.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),

        if (!_hasAiData)
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add income and at least one debt to unlock AI insights.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          )
        else ...[
          // Prompt cards
          for (final prompt in _advisorPrompts) ...[
            _buildPromptCard(context, prompt),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _buildPromptCard(BuildContext context, _AdvisorPrompt prompt) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openAdvisorResult(prompt),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(prompt.icon, size: 20,
                    color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prompt.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 2),
                    Text(prompt.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasAiData =>
      _repository.getIncomeSources().isNotEmpty &&
      (_repository.getDebts().isNotEmpty ||
          _repository.getMortgages().isNotEmpty ||
          _repository.getMortgage() != null);

  Future<void> _openAdvisorResult(_AdvisorPrompt prompt) async {
    final summary = await _buildFinancialSummary();
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdvisorResultScreen(
          title: prompt.title,
          question: prompt.question,
          summary: summary,
        ),
      ),
    );
  }

  Future<FinancialSummary> _buildFinancialSummary() async {
    final snapshot = BuildBudgetSnapshot(_repository)();
    final recentTracking = await _loadRecentTracking();
    return FinancialSummary(
      debts: _repository.getDebts(),
      incomeSources: _repository.getIncomeSources(),
      mortgage: _repository.getMortgage(),
      mortgages: _repository.getMortgages(),
      budgetSnapshot: snapshot,
      recentTracking: recentTracking,
      plannerEvents: _repository.getPlannerEvents(),
    );
  }

  Future<List<MonthlyBudgetSummary>> _loadRecentTracking() async {
    final builder = BuildMonthlyBudgetSummary(_repository);
    final now = DateTime.now();
    final recentTracking = <MonthlyBudgetSummary>[];
    for (int i = 0; i < _maxTrackingLookbackMonths; i++) {
      final date = DateTime(now.year, now.month - i);
      final summary = await builder.call(
        year: date.year,
        month: date.month,
      );
      if (summary.actuals.any((a) => a.actual > 0)) {
        recentTracking.add(summary);
      }
    }
    return recentTracking;
  }

  Widget _buildEventTile(PlannerEvent event) {
    final isExpense = event.type == PlannerEventType.oneOffExpense ||
        event.type == PlannerEventType.recurringExpenseChange;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isExpense
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          _iconForType(event.type),
          color: isExpense
              ? Theme.of(context).colorScheme.onErrorContainer
              : Theme.of(context).colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(event.title),
      subtitle: Text(
        '${event.typeLabel} · £${event.amount.toStringAsFixed(2)} · ${event.scheduledLabel}'
        '${event.isRecurring ? ' · Recurring' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _editEvent(event),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _confirmDeleteEvent(event),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(PlannerEventType type) {
    switch (type) {
      case PlannerEventType.payRise:
        return Icons.trending_up;
      case PlannerEventType.oneOffExpense:
        return Icons.shopping_bag_outlined;
      case PlannerEventType.oneOffIncome:
        return Icons.savings_outlined;
      case PlannerEventType.recurringExpenseChange:
        return Icons.repeat;
      case PlannerEventType.extraDebtPayment:
        return Icons.payment;
    }
  }

  Future<void> _addEvent() async {
    final event = await _showEventDialog();
    if (event != null) {
      _repository.savePlannerEvent(event);
    }
  }

  Future<void> _editEvent(PlannerEvent existing) async {
    final event = await _showEventDialog(existing: existing);
    if (event != null) {
      _repository.savePlannerEvent(event);
    }
  }

  Future<void> _confirmDeleteEvent(PlannerEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _repository.deletePlannerEvent(event.id);
    }
  }

  Future<PlannerEvent?> _showEventDialog({PlannerEvent? existing}) {
    return showDialog<PlannerEvent>(
      context: context,
      builder: (context) => _EventDialog(
        existing: existing,
        labelForType: _labelForType,
        amountLabel: _amountLabel,
      ),
    );
  }

  String _labelForType(PlannerEventType type) {
    switch (type) {
      case PlannerEventType.payRise:
        return 'Pay Rise';
      case PlannerEventType.oneOffExpense:
        return 'One-off Expense';
      case PlannerEventType.oneOffIncome:
        return 'One-off Income';
      case PlannerEventType.recurringExpenseChange:
        return 'Recurring Expense Change';
      case PlannerEventType.extraDebtPayment:
        return 'Extra Debt Payment';
    }
  }

  String _amountLabel(PlannerEventType type) {
    switch (type) {
      case PlannerEventType.payRise:
        return 'New annual gross salary';
      case PlannerEventType.oneOffExpense:
        return 'Amount';
      case PlannerEventType.oneOffIncome:
        return 'Amount';
      case PlannerEventType.recurringExpenseChange:
        return 'Monthly amount change';
      case PlannerEventType.extraDebtPayment:
        return 'Payment amount';
    }
  }

  Future<void> _analyseWithAi() async {
    final summary = await _buildFinancialSummary();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdvisorResultScreen(
          title: 'What-If Event Analysis',
          question: '',
          summary: summary,
          usePlannerPrompt: true,
        ),
      ),
    );
  }
}

class _EventDialog extends StatefulWidget {
  final PlannerEvent? existing;
  final String Function(PlannerEventType) labelForType;
  final String Function(PlannerEventType) amountLabel;

  const _EventDialog({
    this.existing,
    required this.labelForType,
    required this.amountLabel,
  });

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late PlannerEventType _selectedType;
  late int _selectedMonth;
  late int _selectedYear;
  late bool _isRecurring;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _selectedType = existing?.type ?? PlannerEventType.payRise;
    _selectedMonth = existing?.scheduledMonth ?? DateTime.now().month;
    _selectedYear = existing?.scheduledYear ?? DateTime.now().year;
    _isRecurring = existing?.isRecurring ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Event' : 'Add What-If Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Pay rise, Holiday booking',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PlannerEventType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: PlannerEventType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(widget.labelForType(type)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedType = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: widget.amountLabel(_selectedType),
                prefixText: '£',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (i) {
                      final m = i + 1;
                      return DropdownMenuItem(
                        value: m,
                        child: Text(DateFormat.MMM().format(DateTime(2000, m))),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedMonth = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(5, (i) {
                      final y = DateTime.now().year + i;
                      return DropdownMenuItem(
                          value: y, child: Text(y.toString()));
                    }),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedYear = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recurring'),
              subtitle: const Text(
                'Applies every month from this date onwards',
              ),
              value: _isRecurring,
              onChanged: (value) => setState(() => _isRecurring = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Extra context for AI analysis',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            final amount = AmountParser.tryParse(_amountController.text);
            if (title.isEmpty || amount == null || amount <= 0) return;
            final event = PlannerEvent(
              id: widget.existing?.id ??
                  'planner-${DateTime.now().millisecondsSinceEpoch}',
              title: title,
              type: _selectedType,
              amount: amount,
              scheduledMonth: _selectedMonth,
              scheduledYear: _selectedYear,
              isRecurring: _isRecurring,
              notes: _notesController.text.trim(),
            );
            Navigator.pop(context, event);
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _AdvisorPrompt {
  const _AdvisorPrompt({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.question,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final String question;
}
