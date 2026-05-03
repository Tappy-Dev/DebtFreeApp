import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/core/utils/bonus_income_helper.dart';
import 'package:debt_free_app/features/scenarios/domain/active_scenario_plan.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';

extension FinancialRepositoryScenarioPlan on FinancialRepository {
  ActiveScenarioPlan getActiveScenarioPlan() {
    return ActiveScenarioPlan.fromChanges(getScenarioChanges());
  }

  /// Returns income sources with their monthly net pay computed including
  /// salary sacrifice deductions (which reduce taxable income).
  List<IncomeSource> getAdjustedIncomeSources() {
    final incomeSources = getIncomeSources();
    return incomeSources.map((IncomeSource s) {
      final adjustedNet = resolvedMonthlyIncomeNet(s, incomeSources);
      return s.copyWith(overrideMonthlyNet: adjustedNet);
    }).toList();
  }

  /// Returns the expenses and bills list augmented with mortgage payment so the
  /// projection engine accounts for all outgoings.
  ///
  /// Salary sacrifices are NOT included here because they are already
  /// deducted from the computed monthly net income (pre-tax).
  List<Expense> getAllOutgoings() {
    final outgoings = getExpenses().toList();
    outgoings.addAll(getBills());
    outgoings.addAll(getSubscriptions());
    for (final mortgage in getMortgages()) {
      outgoings.add(Expense(
        id: '_mortgage_${mortgage.id}',
        name: mortgage.name,
        amount: mortgage.totalMonthlyHousingCost,
      ));
    }
    return outgoings;
  }
}
