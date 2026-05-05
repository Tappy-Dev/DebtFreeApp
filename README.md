# Debt Free

Debt Free is a Flutter app for planning debt payoff, budgeting monthly cash flow, modelling mortgage overpayments, and testing future financial scenarios.

Current app version: `1.0.5+6`

## What it does

- Tracks debts, balances, APR, and minimum payments
- Projects payoff dates and total interest using Avalanche and Snowball strategies
- Builds monthly budgets with income, bills, expenses, and subscriptions
- Models mortgage balances, overpayments, and shared ownership housing costs
- Simulates future scenario changes such as pay rises, extra payments, and one-off costs
- Supports salary sacrifice modelling for UK-style take-home pay analysis
- Offers optional AI-powered financial guidance and an optional subscription flow

## Product focus

- UK-oriented money flows and terminology
- Local-first storage with no mandatory account
- Clear payoff timelines and scenario comparison
- Fast iteration on planning, budgeting, and repayment decisions

## Tech stack

- Flutter
- Riverpod
- GoRouter
- Drift / SQLite
- Firebase Core
- Firebase AI
- In-app purchases
- fl_chart
- intl

## Project structure

- `lib/app`: app bootstrap, routing, theming
- `lib/core`: repository, services, data access, shared financial logic
- `lib/features`: budgeting, debts, home, mortgage, planner, scenarios, tracking, settings, subscription
- `lib/shared`: reusable widgets and UI helpers
- `test`: unit and widget coverage

## Getting started

1. Install Flutter and a supported Android toolchain.
2. Clone the repository.
3. Run `flutter pub get`.
4. Run `flutter run` for local development.

For Android release builds:

1. Ensure signing config is present.
2. Run `flutter build appbundle --release`.
3. Upload the generated `.aab` from `build/app/outputs/bundle/release/`.

## Notes

- Financial projections are calculator-style estimates and depend on the values entered.
- Mortgage calculations assume the entered loan amount reflects the current outstanding balance unless the user is modelling a brand-new mortgage.
- AI features are optional and only used when the user explicitly requests analysis.