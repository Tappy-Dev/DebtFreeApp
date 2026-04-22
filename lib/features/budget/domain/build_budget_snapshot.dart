import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/features/budget/domain/budget_snapshot.dart';

class BuildBudgetSnapshot {
  const BuildBudgetSnapshot(this._repository);

  final FinancialRepository _repository;

  BudgetSnapshot call() {
    final income = _repository.getIncomeSources();
    final bills = _repository.getBills();
    final expenses = _repository.getExpenses();
    final debts = _repository.getDebts();
    final mortgage = _repository.getMortgage();
    // Monthly net income computed from gross salary minus tax/NI/student loan
    // AND salary sacrifices (which reduce taxable income).
    final totalIncome = income.fold<double>(
      0,
      (double sum, item) => sum + item.monthlyNetAfterSacrifice(),
    );
    final totalBills = bills.fold<double>(
      0,
      (double sum, item) => sum + item.amount,
    );
    final totalExpenses = expenses.fold<double>(
      0,
      (double sum, item) => sum + item.amount,
    );
    final totalMinimumPayments = debts.fold<double>(
      0,
      (double sum, item) => sum + item.currentMinPayment(),
    );
    final mortgagePayment = mortgage?.totalMonthlyPayment ?? 0;

    // True take-home impact of salary sacrifice (not gross sacrificed amount).
    final salarySacrificeNetCost = income.fold<double>(
      0,
      (double sum, item) =>
          sum +
          (item.payBreakdown(totalMonthlySacrifice: 0).monthlyNet -
              item.payBreakdown().monthlyNet),
    );

    return BudgetSnapshot(
      totalIncome: totalIncome,
      totalBills: totalBills,
      totalExpenses: totalExpenses,
      totalMinimumPayments: totalMinimumPayments,
      mortgagePayment: mortgagePayment,
      salarySacrificeNetCost: salarySacrificeNetCost,
      remainingCash: totalIncome -
          totalBills -
          totalExpenses -
          totalMinimumPayments -
          mortgagePayment,
    );
  }
}
