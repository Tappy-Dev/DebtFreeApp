import 'package:debt_free_app/features/simulation/models/scenario_change.dart';

class ActiveScenarioPlan {
  const ActiveScenarioPlan({
    required this.incomeIncrease,
    required this.expenseReduction,
    required this.extraPayment,
    required this.startMonth,
    required this.durationInMonths,
    this.scheduleIsConsistent = true,
  });

  factory ActiveScenarioPlan.empty() {
    return const ActiveScenarioPlan(
      incomeIncrease: 0,
      expenseReduction: 0,
      extraPayment: 0,
      startMonth: 0,
      durationInMonths: null,
    );
  }

  factory ActiveScenarioPlan.fromChanges(List<ScenarioChange> changes) {
    if (changes.isEmpty) {
      return ActiveScenarioPlan.empty();
    }

    final orderedChanges = changes.toList()
      ..sort((ScenarioChange a, ScenarioChange b) {
        final startCompare = a.startMonth.compareTo(b.startMonth);
        if (startCompare != 0) {
          return startCompare;
        }

        final aDuration = a.durationInMonths ?? 1 << 30;
        final bDuration = b.durationInMonths ?? 1 << 30;
        return aDuration.compareTo(bDuration);
      });
    final first = orderedChanges.first;
    final scheduleIsConsistent = orderedChanges.every(
      (ScenarioChange change) =>
          change.startMonth == first.startMonth &&
          change.durationInMonths == first.durationInMonths,
    );
    double incomeIncrease = 0;
    double expenseReduction = 0;
    double extraPayment = 0;

    for (final change in changes) {
      switch (change.changeType) {
        case ChangeType.increaseIncome:
          incomeIncrease += change.amount;
        case ChangeType.reduceExpenses:
          expenseReduction += change.amount;
        case ChangeType.extraPayment:
          // Only count global extra payments (no debtId) in scenario plan
          if (change.debtId == null) {
            extraPayment += change.amount;
          }
      }
    }

    return ActiveScenarioPlan(
      incomeIncrease: incomeIncrease,
      expenseReduction: expenseReduction,
      extraPayment: extraPayment,
      startMonth: first.startMonth,
      durationInMonths: first.durationInMonths,
      scheduleIsConsistent: scheduleIsConsistent,
    );
  }

  final double incomeIncrease;
  final double expenseReduction;
  final double extraPayment;
  final int startMonth;
  final int? durationInMonths;
  final bool scheduleIsConsistent;

  bool get hasChanges =>
      incomeIncrease > 0 || expenseReduction > 0 || extraPayment > 0;
  bool get hasMixedSchedules => !scheduleIsConsistent;

  double amountFor(ChangeType type) {
    switch (type) {
      case ChangeType.increaseIncome:
        return incomeIncrease;
      case ChangeType.reduceExpenses:
        return expenseReduction;
      case ChangeType.extraPayment:
        return extraPayment;
    }
  }

  ActiveScenarioPlan removeType(ChangeType type) {
    switch (type) {
      case ChangeType.increaseIncome:
        return copyWith(incomeIncrease: 0);
      case ChangeType.reduceExpenses:
        return copyWith(expenseReduction: 0);
      case ChangeType.extraPayment:
        return copyWith(extraPayment: 0);
    }
  }

  List<ScenarioChange> toChanges() {
    if (!hasChanges) {
      return const <ScenarioChange>[];
    }

    final changes = <ScenarioChange>[];
    _appendChange(
      changes: changes,
      type: ChangeType.increaseIncome,
      amount: incomeIncrease,
    );
    _appendChange(
      changes: changes,
      type: ChangeType.reduceExpenses,
      amount: expenseReduction,
    );
    _appendChange(
      changes: changes,
      type: ChangeType.extraPayment,
      amount: extraPayment,
    );
    return changes;
  }

  ActiveScenarioPlan copyWith({
    double? incomeIncrease,
    double? expenseReduction,
    double? extraPayment,
    int? startMonth,
    Object? durationInMonths = _unset,
  }) {
    return ActiveScenarioPlan(
      incomeIncrease: incomeIncrease ?? this.incomeIncrease,
      expenseReduction: expenseReduction ?? this.expenseReduction,
      extraPayment: extraPayment ?? this.extraPayment,
      startMonth: startMonth ?? this.startMonth,
      durationInMonths: identical(durationInMonths, _unset)
          ? this.durationInMonths
          : durationInMonths as int?,
      scheduleIsConsistent: true,
    );
  }

  void _appendChange({
    required List<ScenarioChange> changes,
    required ChangeType type,
    required double amount,
  }) {
    if (amount <= 0) {
      return;
    }

    changes.add(
      ScenarioChange(
        changeType: type,
        amount: amount,
        startMonth: startMonth,
        durationInMonths: durationInMonths,
      ),
    );
  }

  static const Object _unset = Object();
}
