class BudgetSnapshot {
  const BudgetSnapshot({
    required this.totalIncome,
    required this.totalBills,
    required this.totalExpenses,
    required this.totalMinimumPayments,
    required this.mortgagePayment,
    required this.salarySacrificeNetCost,
    required this.remainingCash,
  });

  final double totalIncome;
  final double totalBills;
  final double totalExpenses;
  final double totalMinimumPayments;
  final double mortgagePayment;
  final double salarySacrificeNetCost;
  final double remainingCash;
}
