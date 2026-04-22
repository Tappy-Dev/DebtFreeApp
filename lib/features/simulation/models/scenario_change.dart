enum ChangeType {
  increaseIncome,
  reduceExpenses,
  extraPayment,
}

class ScenarioChange {
  const ScenarioChange({
    required this.changeType,
    required this.amount,
    this.startMonth = 0,
    this.durationInMonths,
    this.debtId,
  });

  final ChangeType changeType;
  final double amount;
  final int startMonth;
  final int? durationInMonths;
  final String? debtId;

  bool appliesToMonth(int monthIndex) {
    if (monthIndex < startMonth) {
      return false;
    }

    if (durationInMonths == null) {
      return true;
    }

    return monthIndex < startMonth + durationInMonths!;
  }
}
