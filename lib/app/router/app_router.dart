import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/features/budget/presentation/budget_screen.dart';
import 'package:debt_free_app/features/budget/application/budget_item_form_controller.dart';
import 'package:debt_free_app/features/budget/presentation/budget_item_form_screen.dart';
import 'package:debt_free_app/features/debts/presentation/debt_detail_screen.dart';
import 'package:debt_free_app/features/debts/presentation/debt_form_screen.dart';
import 'package:debt_free_app/features/debts/presentation/debt_summary_screen.dart';
import 'package:debt_free_app/features/debts/presentation/debts_screen.dart';
import 'package:debt_free_app/features/home/presentation/home_screen.dart';
import 'package:debt_free_app/features/home/presentation/monthly_summary_screen.dart';
import 'package:debt_free_app/features/mortgage/presentation/mortgage_screen.dart';
import 'package:debt_free_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:debt_free_app/features/onboarding/presentation/welcome_screen.dart';
import 'package:debt_free_app/features/salary_sacrifice/presentation/salary_sacrifice_screen.dart';
import 'package:debt_free_app/features/planner/presentation/planner_screen.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/settings/presentation/settings_screen.dart';
import 'package:debt_free_app/features/settings/presentation/about_screen.dart';
import 'package:debt_free_app/features/settings/presentation/finance_settings_screen.dart';
import 'package:debt_free_app/features/tracking/presentation/monthly_tracking_screen.dart';
import 'package:go_router/go_router.dart';

GoRouter buildAppRouter() {
  return GoRouter(
    redirect: (context, state) {
      final hasSeenWelcome =
          SessionFinancialRepository.instance.hasSeenWelcome;
      if (!hasSeenWelcome && state.matchedLocation != '/welcome') {
        return '/welcome';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/debts',
        builder: (context, state) => const DebtsScreen(),
      ),
      GoRoute(
        path: '/debts/new',
        builder: (context, state) => const DebtFormScreen(),
      ),
      GoRoute(
        path: '/debts/:id/edit',
        builder: (context, state) => DebtFormScreen(
          debtId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/debts/:id',
        builder: (context, state) => DebtDetailScreen(
          debtId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/planner',
        builder: (context, state) => const PlannerScreen(),
      ),
      GoRoute(
        path: '/budget',
        builder: (context, state) => const BudgetScreen(),
      ),
      GoRoute(
        path: '/budget/income/new',
        builder: (context, state) => const BudgetItemFormScreen(
          type: BudgetItemType.income,
        ),
      ),
      GoRoute(
        path: '/budget/income/:id/edit',
        builder: (context, state) => BudgetItemFormScreen(
          type: BudgetItemType.income,
          itemId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/budget/expense/new',
        builder: (context, state) {
          final catName = state.uri.queryParameters['category'];
          final cat = catName != null
              ? ExpenseCategory.fromName(catName)
              : null;
          return BudgetItemFormScreen(
            type: BudgetItemType.expense,
            initialCategory: cat,
          );
        },
      ),
      GoRoute(
        path: '/budget/expense/:id/edit',
        builder: (context, state) => BudgetItemFormScreen(
          type: BudgetItemType.expense,
          itemId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/budget/bill/new',
        builder: (context, state) => const BudgetItemFormScreen(
          type: BudgetItemType.bill,
        ),
      ),
      GoRoute(
        path: '/budget/bill/:id/edit',
        builder: (context, state) => BudgetItemFormScreen(
          type: BudgetItemType.bill,
          itemId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/budget/subscription/new',
        builder: (context, state) => const BudgetItemFormScreen(
          type: BudgetItemType.subscription,
        ),
      ),
      GoRoute(
        path: '/budget/subscription/:id/edit',
        builder: (context, state) => BudgetItemFormScreen(
          type: BudgetItemType.subscription,
          itemId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/finance',
        builder: (context, state) => const FinanceSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/tracking',
        builder: (context, state) => const MonthlyTrackingScreen(),
      ),
      GoRoute(
        path: '/debt-summary',
        builder: (context, state) => const DebtSummaryScreen(),
      ),
      GoRoute(
        path: '/monthly-summary',
        builder: (context, state) => const MonthlySummaryScreen(),
      ),
      GoRoute(
        path: '/mortgage',
        builder: (context, state) => const MortgageScreen(),
      ),
      GoRoute(
        path: '/salary-sacrifice',
        builder: (context, state) => const SalarySacrificeScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
}
