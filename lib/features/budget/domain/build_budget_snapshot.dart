import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/core/data/financial_repository_extensions.dart';
import 'package:debt_free_app/core/utils/bonus_income_helper.dart';
import 'package:debt_free_app/features/budget/domain/budget_snapshot.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';

class BuildBudgetSnapshot {
  const BuildBudgetSnapshot(this._repository);

  final FinancialRepository _repository;

  BudgetSnapshot call() {
    final income = _repository.getIncomeSources();
    final adjustedIncome = _repository.getAdjustedIncomeSources();
    final bills = _repository.getBills();
    final subscriptions = _repository.getSubscriptions();
    final expenses = _repository.getExpenses();
    final debts = _repository.getDebts();
    final mortgages = _repository.getMortgages();
    // Monthly net income computed from gross salary minus tax/NI/student loan
    // AND salary sacrifices (which reduce taxable income).
    final totalIncome = adjustedIncome.fold<double>(
      0,
      (double sum, item) => sum + item.amount,
    );
    final totalBills = bills.fold<double>(
      0,
      (double sum, item) => sum + item.amount,
    );
    final totalSubscriptions = subscriptions.fold<double>(
      0,
      (double sum, item) => sum + item.amount,
    );
    final totalSavings = expenses
        .where((e) => e.category == ExpenseCategory.savings)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final totalExpenses = expenses.fold<double>(
      0,
      (double sum, item) => sum + item.amount,
    ) - totalSavings;
    final totalMinimumPayments = debts.fold<double>(
      0,
      (double sum, item) => sum + item.currentMinPayment(),
    );
    final mortgagePayment = mortgages.fold<double>(
      0,
      (sum, mortgage) => sum + mortgage.totalMonthlyPayment,
    );

    // True take-home impact of salary sacrifice (not gross sacrificed amount).
    final salarySacrificeNetCost = income.fold<double>(
      0,
      (double sum, item) =>
        isBonusIncome(item)
          ? sum
          :
          sum +
          (item.payBreakdown(totalMonthlySacrifice: 0).monthlyNet -
              item.payBreakdown().monthlyNet),
    );

    return BudgetSnapshot(
      totalIncome: totalIncome,
      totalBills: totalBills,
      totalSubscriptions: totalSubscriptions,
      totalExpenses: totalExpenses,
      totalSavings: totalSavings,
      totalMinimumPayments: totalMinimumPayments,
      mortgagePayment: mortgagePayment,
      salarySacrificeNetCost: salarySacrificeNetCost,
      remainingCash: totalIncome -
          totalBills -
          totalSubscriptions -
          totalExpenses -
          totalSavings -
          totalMinimumPayments -
          mortgagePayment,
    );
  }
}
