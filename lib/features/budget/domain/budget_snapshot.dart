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
}
