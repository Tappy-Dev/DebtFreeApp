import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/core/utils/financial_month.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';

Future<BudgetPeriod?> findOldestOverdueOpenPeriod({
  required FinancialRepository repository,
  required DateTime now,
  required int financialMonthStartDay,
  String? excludePeriodId,
}) async {
  final today = DateTime(now.year, now.month, now.day);
  final periods = await repository.getBudgetPeriods();

  final overdueOpen = periods.where((period) {
    if (!period.isOpen) return false;
    if (excludePeriodId != null && period.id == excludePeriodId) return false;
    final periodEnd = FinancialMonth.endDate(
      period.year,
      period.month,
      financialMonthStartDay,
    );
    final normalizedEnd = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);
    return normalizedEnd.isBefore(today);
  }).toList()
    ..sort((a, b) {
      final yearCompare = a.year.compareTo(b.year);
      if (yearCompare != 0) return yearCompare;
      return a.month.compareTo(b.month);
    });

  return overdueOpen.isEmpty ? null : overdueOpen.first;
}
