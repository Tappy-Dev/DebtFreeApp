import 'package:debt_free_app/app/router/app_router.dart';
import 'package:debt_free_app/app/theme/app_theme.dart';
import 'package:debt_free_app/core/services/subscription_service.dart';
import 'package:debt_free_app/features/subscription/presentation/paywall_screen.dart';
import 'package:flutter/material.dart';

class DebtFreeApp extends StatelessWidget {
  const DebtFreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SubscriptionService.instance,
      builder: (context, _) {
        final sub = SubscriptionService.instance;
        final showPaywall = sub.initialized && !sub.isEntitled;

        return MaterialApp.router(
          title: 'Debt Free',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: buildAppRouter(),
          builder: (context, child) {
            if (showPaywall) {
              return const PaywallScreen();
            }
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
