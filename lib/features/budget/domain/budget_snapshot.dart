class BudgetSnapshot {
  const BudgetSnapshot({
    required this.totalIncome,
    required this.totalBills,
    required this.totalSubscriptions,
    required this.totalExpenses,
    required this.totalSavings,
    required this.totalMinimumPayments,
    required this.mortgagePayment,
    required this.salarySacrificeNetCost,
    required this.remainingCash,
    this.totalRecurringExtraDebtPayments = 0,
  });

  final double totalIncome;
  final double totalBills;
  final double totalSubscriptions;
  /// Expenses excluding savings pots.
  final double totalExpenses;
  /// Monthly amount earmarked for savings pots.
  final double totalSavings;
  final double totalMinimumPayments;
  final double mortgagePayment;
  final double salarySacrificeNetCost;
  final double remainingCash;
  /// Sum of active recurring extra debt payments set via the debt slider.
  final double totalRecurringExtraDebtPayments;
}
