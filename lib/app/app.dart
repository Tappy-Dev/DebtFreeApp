import 'package:debt_free_app/app/router/app_router.dart';
import 'package:debt_free_app/app/theme/app_theme.dart';
import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/services/subscription_service.dart';
import 'package:debt_free_app/features/subscription/presentation/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DebtFreeApp extends StatefulWidget {
  const DebtFreeApp({super.key});

  @override
  State<DebtFreeApp> createState() => _DebtFreeAppState();
}

class _DebtFreeAppState extends State<DebtFreeApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildAppRouter();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        SubscriptionService.instance,
        SessionFinancialRepository.instance,
      ]),
      builder: (context, _) {
        final sub = SubscriptionService.instance;
        final showPaywall = sub.initialized && !sub.isEntitled;
        final themeMode = SessionFinancialRepository.instance.themeMode;

        return MaterialApp.router(
          title: 'Debt Free',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          routerConfig: _router,
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
