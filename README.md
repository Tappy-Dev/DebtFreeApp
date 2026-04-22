# Debt Free App

## Overview
The Debt Free App is designed to help users manage their debts, budget, and financial scenarios effectively. It provides a clean and minimal interface focused on financial clarity and outcome-oriented decision-making.

## Tech Stack
- **Flutter**: Framework for building the app.
- **Riverpod**: State management solution.
- **GoRouter**: For managing app navigation.
- **SQLite**: For local data storage (using Drift or sqflite).
- **flutter_secure_storage**: For secure data storage.
- **fl_chart**: For visualizing financial data.
- **Freezed + json_serializable**: For data modeling and serialization.
- **intl**: For internationalization and date formatting.

## Features
- **Onboarding**: Guides new users through the initial setup.
- **Home Screen**: Displays total debt, debt-free date, interest projections, and recommendations.
- **Debts Management**: Allows users to view and manage their debts.
- **Budgeting**: Users can input and track their income and expenses.
- **Scenario Simulation**: Users can input changes and compare different financial scenarios.
- **Performance Optimization**: Caches baseline projections and debounces inputs for better performance.

## Core Components
- **SummaryCard**: Displays a summary of financial information.
- **DebtCard**: Presents individual debt details.
- **RecommendationCard**: Shows financial recommendations based on user data.
- **MoneyInputSlider**: A slider for inputting monetary values.
- **TimelineChart**: Visualizes financial data over time.
- **ComparisonView**: Compares different financial scenarios.

## Testing
The app includes unit tests for core functionalities such as interest calculations, strategies, and projection logic, as well as widget tests for UI components.

## Getting Started
1. Clone the repository.
2. Run `flutter pub get` to install dependencies.
3. Use `flutter run` to start the application.

## Contribution
Contributions are welcome! Please open an issue or submit a pull request for any enhancements or bug fixes.

## License
This project is licensed under the MIT License. See the LICENSE file for details.