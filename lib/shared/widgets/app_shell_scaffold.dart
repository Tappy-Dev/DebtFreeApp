import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.title,
    required this.currentIndex,
    required this.body,
    this.appBarActions = const <Widget>[],
  });

  final String title;
  final int currentIndex;
  final Widget body;
  final List<Widget> appBarActions;

  static const List<String> _paths = <String>[
    '/',
    '/debts',
    '/budget',
    '/tracking',
    '/planner',
  ];

  void _showGuide(BuildContext context) {
    if (currentIndex == 0) {
      _showDashboardGuide(context);
      return;
    }
    if (currentIndex == 1) {
      _showDebtsGuide(context);
      return;
    }
    if (currentIndex == 2) {
      _showBudgetGuide(context);
      return;
    }
    if (currentIndex == 3) {
      _showTrackingGuide(context);
      return;
    }
    if (currentIndex == 4) {
      _showPlannerGuide(context);
      return;
    }

    _showGeneralGuide(context);
  }

  void _showDashboardGuide(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.home_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Dashboard Guide')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _guideStep(
                theme,
                '1',
                Icons.rocket_launch_outlined,
                'Use Get Started prompts',
                'Complete setup tasks for income, budget, debts, and finance settings. Each prompt disappears once completed.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '2',
                Icons.account_balance_wallet_outlined,
                'Review Monthly Summary',
                'See remaining money, income, bills, and expenses at a glance for the current period.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '3',
                Icons.trending_down_rounded,
                'Track Debt Summary',
                'Monitor total debt, projected debt-free date, and interest impact month to month.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '4',
                Icons.home_work_outlined,
                'Check Mortgage block (if added)',
                'If you added a mortgage, dashboard shows quick status and links to deeper analysis.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showGeneralGuide(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded,
                color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Expanded(child: Text('How to Use Debt Free')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _guideStep(theme, '1', Icons.account_balance_wallet,
                  'Set up your budget',
                  'Go to the Budget tab and add your income, bills, and expenses. This is the foundation for all calculations.'),
              const SizedBox(height: 16),
              _guideStep(theme, '2', Icons.credit_card,
                  'Add your debts',
                  'Head to the Debts tab and enter each debt with its balance, interest rate, and minimum payment.'),
              const SizedBox(height: 16),
              _guideStep(theme, '3', Icons.home_outlined,
                  'Add your mortgage (optional)',
                  'If you have a mortgage, add it from the Dashboard or Budget screen to model overpayments.'),
              const SizedBox(height: 16),
              _guideStep(theme, '4', Icons.calendar_month,
                  'Track monthly spending',
                  'Use the Tracking tab each month to log actual spending against your budget categories.'),
              const SizedBox(height: 16),
              _guideStep(theme, '5', Icons.lightbulb,
                  'Plan & Simulate',
                  'Visit the Planner tab to explore scenarios — extra payments, debt strategies, and see how changes affect your debt-free date.'),
              const SizedBox(height: 16),
              _guideStep(theme, '6', Icons.settings_outlined,
                  'Customise in Settings',
                  'Adjust your financial month start day, app start month, and other preferences.'),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tip: Keep your budget up to date each month by using the Copy button to carry it forward.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showDebtsGuide(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.credit_card_rounded,
                color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Debts Guide')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _guideStep(
                theme,
                '1',
                Icons.add_card_rounded,
                'Add each debt separately',
                'Create one entry per credit card, loan, or other balance so payoff calculations stay accurate.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '2',
                Icons.percent_rounded,
                'Enter APR and payment details carefully',
                'Use the real APR and minimum payment rule from your statement. Small APR differences can shift projections significantly.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '3',
                Icons.event_available_rounded,
                'Set payment day',
                'Payment day helps align debt cashflow with monthly periods and improves Tracking accuracy.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '4',
                Icons.trending_down_rounded,
                'Use extra payments strategically',
                'Apply extra payments to high-interest debts first to reduce total interest and shorten your debt-free timeline.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '5',
                Icons.analytics_outlined,
                'Review Debt Summary regularly',
                'Track total debt, estimated debt-free date, and monthly movement to see if your plan is improving.',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tip: If a debt payment is too low to cover monthly interest, the balance can grow. The app warns you before saving those values.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showBudgetGuide(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded,
                color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Budget Guide')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _guideStep(
                theme,
                '1',
                Icons.attach_money_rounded,
                'Set up income first',
                'Add your annual gross salary and salary-sacrifice details. This drives your net take-home estimate.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '2',
                Icons.receipt_long_outlined,
                'Add fixed bills and subscriptions',
                'Capture committed monthly outgoings first so remaining budget is realistic before adding flexible spending.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '3',
                Icons.shopping_bag_outlined,
                'Add variable expenses',
                'Use expenses for categories that change month-to-month. Mark items as trackable if you want actual-vs-planned tracking.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '4',
                Icons.home_work_outlined,
                'Include mortgage if relevant',
                'Mortgage payments are included in the monthly budget snapshot and should match your current repayment settings.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '5',
                Icons.calendar_month_rounded,
                'Align with Finance Settings',
                'Budget periods follow your financial month start day. Configure Finance Settings to match your real pay cycle.',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tips_and_updates_outlined,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tip: Keep values realistic with 2 decimal places and update Budget monthly before using Tracking and Planner insights.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showTrackingGuide(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Tracking Guide')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _guideStep(
                theme,
                '1',
                Icons.calendar_today_outlined,
                'Choose the right period',
                'Tracking periods follow your Financial Month Start Day. Confirm the month label before entering actuals.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '2',
                Icons.edit_note_rounded,
                'Enter actual spending',
                'Record what really happened for each trackable category so variance analysis stays meaningful.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '3',
                Icons.compare_arrows_rounded,
                'Review planned vs actual',
                'Use over/under figures to identify drift and improve next month\'s budget quality.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '4',
                Icons.task_alt_rounded,
                'Close month when complete',
                'Close only after entries are final to lock in clean historical reporting.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showPlannerGuide(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Planner Guide')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _guideStep(
                theme,
                '1',
                Icons.auto_graph_rounded,
                'Build realistic scenarios',
                'Test extra payments, payment timing, and strategy changes using values you can actually maintain.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '2',
                Icons.schedule_rounded,
                'Compare debt-free dates',
                'Use timeline outputs to see how each scenario shifts payoff timing and total interest.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '3',
                Icons.savings_outlined,
                'Focus on interest saved',
                'Prioritize plans that meaningfully reduce total interest without breaking monthly cashflow.',
              ),
              const SizedBox(height: 16),
              _guideStep(
                theme,
                '4',
                Icons.rule_rounded,
                'Adopt and review monthly',
                'When choosing a scenario, revisit it each month after Tracking updates to keep assumptions valid.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  static Widget _guideStep(ThemeData theme, String number, IconData icon,
      String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(number,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              )),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          ...appBarActions,
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How to use this page',
            onPressed: () => _showGuide(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.scaffoldBackgroundColor,
                theme.colorScheme.surface.withValues(alpha: 0.65),
              ],
            ),
          ),
          child: body,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (int index) {
          if (index != currentIndex) {
            context.go(_paths[index]);
          }
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_outlined),
            selectedIcon: Icon(Icons.credit_card),
            label: 'Debts',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Tracking',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outlined),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Planner',
          ),
        ],
      ),
    );
  }
}
