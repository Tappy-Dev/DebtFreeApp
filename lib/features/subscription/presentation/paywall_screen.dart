import 'package:debt_free_app/core/services/subscription_service.dart';
import 'package:flutter/material.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _annual = true; // Default to annual (best value)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = SubscriptionService.instance;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: sub,
          builder: (context, _) {
            final monthlyPrice = sub.monthlyProduct?.price ?? '£3.99';
            final annualPrice = sub.annualProduct?.price ?? '£39.99';

            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Your Free Trial Has Ended',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Subscribe to continue using Debt Free and keep '
                    'your data, insights, and progress.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Feature list
                  _FeatureRow(
                    icon: Icons.account_balance_wallet_outlined,
                    text: 'Full budget & debt tracking',
                    theme: theme,
                  ),
                  _FeatureRow(
                    icon: Icons.compare_arrows_rounded,
                    text: 'Avalanche & Snowball strategies',
                    theme: theme,
                  ),
                  _FeatureRow(
                    icon: Icons.home_outlined,
                    text: 'Mortgage overpayment analysis',
                    theme: theme,
                  ),
                  _FeatureRow(
                    icon: Icons.psychology_outlined,
                    text: 'AI-powered financial advisor',
                    theme: theme,
                  ),
                  _FeatureRow(
                    icon: Icons.event_note_outlined,
                    text: 'What-if scenario planner',
                    theme: theme,
                  ),
                  const SizedBox(height: 32),

                  // Plan toggle
                  Row(
                    children: [
                      Expanded(
                        child: _PlanCard(
                          label: 'Monthly',
                          price: monthlyPrice,
                          period: '/month',
                          selected: !_annual,
                          onTap: () => setState(() => _annual = false),
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlanCard(
                          label: 'Annual',
                          price: annualPrice,
                          period: '/year',
                          badge: 'Save 17%',
                          selected: _annual,
                          onTap: () => setState(() => _annual = true),
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cancel anytime via Google Play',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Subscribe button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: sub.isStoreAvailable
                          ? () => _handlePurchase(context)
                          : null,
                      child: Text(
                        'Subscribe — ${_annual ? annualPrice : monthlyPrice}${_annual ? '/year' : '/month'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Restore purchases
                  TextButton(
                    onPressed: sub.isStoreAvailable
                        ? () => _handleRestore(context)
                        : null,
                    child: const Text('Restore Purchases'),
                  ),

                  if (!sub.isStoreAvailable) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Store not available on this platform.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handlePurchase(BuildContext context) async {
    final success =
        await SubscriptionService.instance.purchase(annual: _annual);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start purchase. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    await SubscriptionService.instance.restorePurchases();
    if (context.mounted) {
      final sub = SubscriptionService.instance;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sub.isSubscribed
                ? 'Subscription restored!'
                : 'No active subscription found.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.theme,
  });

  final IconData icon;
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            Icons.check_circle,
            size: 18,
            color: Colors.green.shade600,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.price,
    required this.period,
    required this.selected,
    required this.onTap,
    required this.theme,
    this.badge,
  });

  final String label;
  final String price;
  final String period;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    final bgColor = selected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
        : theme.colorScheme.surface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            Text(
              period,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
