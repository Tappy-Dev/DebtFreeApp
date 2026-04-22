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
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          ...appBarActions,
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How to use',
            onPressed: () => _showGuide(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: body,
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
