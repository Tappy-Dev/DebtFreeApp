enum ActualCategoryType {
  income,
  expense,
  bill,
  debtPayment,
}

class BudgetActual {
  const BudgetActual({
    required this.id,
    required this.periodId,
    required this.categoryId,
    required this.categoryName,
    required this.categoryType,
    required this.budgeted,
    this.actual = 0,
    this.debtBalance = 0,
  });

  final String id;
  final String periodId;
  final String categoryId;
  final String categoryName;
  final ActualCategoryType categoryType;
  final double budgeted;
  final double actual;

  /// For debtPayment rows: the projected outstanding balance at the START of
  /// this period (after previous months' payments have been applied).
  final double debtBalance;

  double get variance => actual - budgeted;
  bool get isOverBudget =>
      categoryType != ActualCategoryType.income && actual > budgeted;
  bool get isUnderBudget =>
      categoryType != ActualCategoryType.income && actual < budgeted;

  BudgetActual copyWith({double? actual, double? debtBalance}) {
    return BudgetActual(
      id: id,
      periodId: periodId,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryType: categoryType,
      budgeted: budgeted,
      actual: actual ?? this.actual,
      debtBalance: debtBalance ?? this.debtBalance,
    );
  }

  static String buildId(String periodId, String categoryId) =>
      '$periodId:$categoryId';
}
