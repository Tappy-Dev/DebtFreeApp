import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/core/data/financial_repository_extensions.dart';
import 'package:debt_free_app/core/utils/amount_parser.dart';
import 'package:debt_free_app/features/scenarios/domain/active_scenario_plan.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';

class ScenarioBuilderController {
  ScenarioBuilderController(this._repository);

  final FinancialRepository _repository;

  String? validateIncomeIncrease(String? value) {
    return _validateOptionalNonNegativeAmount(
      value: value,
      emptyMessage: 'Income increase is required.',
      invalidMessage: 'Income increase must be a valid amount.',
    );
  }

  String? validateExpenseReduction(String? value) {
    return _validateOptionalNonNegativeAmount(
      value: value,
      emptyMessage: 'Expense reduction is required.',
      invalidMessage: 'Expense reduction must be a valid amount.',
    );
  }

  String? validateExtraPayment(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Extra payment is required.';
    }

    final parsed = AmountParser.tryParse(value);
    if (parsed == null || parsed < 0) {
      return 'Extra payment must be a valid amount.';
    }

    return null;
  }

  String? validateStandaloneExtraPayment(String? value) {
    final basicValidation = validateExtraPayment(value);
    if (basicValidation != null) {
      return basicValidation;
    }

    final parsed = AmountParser.tryParse(value)!;

    final remainingCash = _remainingCash();
    final availableCash = remainingCash < 0 ? 0 : remainingCash;
    if (availableCash == 0 && parsed > 0) {
      return 'No free monthly cash is available for extra payments right now.';
    }

    if (parsed > availableCash) {
      return 'Extra payment exceeds available monthly cash.';
    }

    return null;
  }

  String? validateStartMonth(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return 'Start month must be a whole number of 0 or more.';
    }

    return null;
  }

  String? validateDurationInMonths(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return 'Duration must be a whole number above 0.';
    }

    return null;
  }

  String? validateScenarioPlan({
    required String extraPayment,
    required String incomeIncrease,
    required String expenseReduction,
  }) {
    final parsedExtraPayment = AmountParser.tryParse(extraPayment);
    final parsedIncomeIncrease = AmountParser.tryParse(incomeIncrease);
    final parsedExpenseReduction = AmountParser.tryParse(expenseReduction);

    if (parsedExtraPayment == null ||
        parsedIncomeIncrease == null ||
        parsedExpenseReduction == null) {
      return 'Scenario amounts must be valid.';
    }

    final availableCash = _remainingCash() + parsedIncomeIncrease + parsedExpenseReduction;
    final safeAvailableCash = availableCash < 0 ? 0 : availableCash;

    if (safeAvailableCash == 0 && parsedExtraPayment > 0) {
      return 'No free monthly cash is available for extra payments right now.';
    }

    if (parsedExtraPayment > safeAvailableCash) {
      return 'Extra payment exceeds available monthly cash after your scenario changes.';
    }

    return null;
  }

  double currentIncomeIncrease() {
    return _currentAmount(ChangeType.increaseIncome);
  }

  double currentExpenseReduction() {
    return _currentAmount(ChangeType.reduceExpenses);
  }

  double currentExtraPayment() {
    return _currentAmount(ChangeType.extraPayment);
  }

  int currentStartMonth() {
    return _currentPlan().startMonth;
  }

  int? currentDurationInMonths() {
    return _currentPlan().durationInMonths;
  }

  void saveExtraPayment(String value) {
    saveScenarioPlan(
      extraPayment: value,
      incomeIncrease: '0',
      expenseReduction: '0',
      startMonth: '0',
      durationInMonths: '',
    );
  }

  void clearScenarioPlan() {
    // Preserve per-debt extra payments, only clear global scenario entries
    final perDebtExtras = _repository.getScenarioChanges()
        .where((c) => c.changeType == ChangeType.extraPayment && c.debtId != null)
        .toList();
    _repository.saveScenarioChanges(perDebtExtras);
  }

  void normalizeCurrentPlan() {
    final perDebtExtras = _repository.getScenarioChanges()
        .where((c) => c.changeType == ChangeType.extraPayment && c.debtId != null)
        .toList();
    _repository.saveScenarioChanges([
      ..._currentPlan().toChanges(),
      ...perDebtExtras,
    ]);
  }

  void removeChange(ChangeType type) {
    final updatedPlan = _currentPlan().removeType(type);
    // Preserve per-debt extra payments when removing from scenarios
    final perDebtExtras = _repository.getScenarioChanges()
        .where((c) => c.changeType == ChangeType.extraPayment && c.debtId != null)
        .toList();
    _repository.saveScenarioChanges([
      ...updatedPlan.toChanges(),
      ...perDebtExtras,
    ]);
  }

  void saveScenarioPlan({
    required String extraPayment,
    required String incomeIncrease,
    required String expenseReduction,
    required String startMonth,
    required String durationInMonths,
  }) {
    final plan = ActiveScenarioPlan(
      incomeIncrease: AmountParser.tryParse(incomeIncrease) ?? 0,
      expenseReduction: AmountParser.tryParse(expenseReduction) ?? 0,
      extraPayment: AmountParser.tryParse(extraPayment) ?? 0,
      startMonth: _parseStartMonth(startMonth),
      durationInMonths: _parseDurationInMonths(durationInMonths),
    );

    // Preserve per-debt extra payments
    final perDebtExtras = _repository.getScenarioChanges()
        .where((c) => c.changeType == ChangeType.extraPayment && c.debtId != null)
        .toList();
    _repository.saveScenarioChanges([
      ...plan.toChanges(),
      ...perDebtExtras,
    ]);
  }

  double _currentAmount(ChangeType type) {
    return _currentPlan().amountFor(type);
  }

  String? _validateOptionalNonNegativeAmount({
    required String? value,
    required String emptyMessage,
    required String invalidMessage,
  }) {
    if (value == null || value.trim().isEmpty) {
      return emptyMessage;
    }

    final parsed = AmountParser.tryParse(value);
    if (parsed == null || parsed < 0) {
      return invalidMessage;
    }

    return null;
  }

  double _remainingCash() {
    final incomeSources = _repository.getAdjustedIncomeSources();
    final totalIncome = incomeSources.fold<double>(
      0,
      (double sum, item) => sum + item.amount,
    );
    final totalExpenses = _repository
        .getExpenses()
        .fold<double>(0, (double sum, item) => sum + item.amount);
    final totalBills = _repository
        .getBills()
        .fold<double>(0, (double sum, item) => sum + item.amount);
    final totalMinimumPayments = _repository
        .getDebts()
        .fold<double>(0, (double sum, item) => sum + item.currentMinPayment());
    final mortgagePayment = _repository
      .getMortgages()
      .fold<double>(0, (double sum, m) => sum + m.totalMonthlyPayment);

    return totalIncome -
        totalBills -
        totalExpenses -
        totalMinimumPayments -
        mortgagePayment;
  }

  int _parseStartMonth(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 0;
    }

    return int.tryParse(trimmed) ?? 0;
  }

  int? _parseDurationInMonths(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return int.tryParse(trimmed);
  }

  ActiveScenarioPlan _currentPlan() {
    return _repository.getActiveScenarioPlan();
  }
}
