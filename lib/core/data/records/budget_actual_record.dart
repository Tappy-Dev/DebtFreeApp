import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:drift/drift.dart';

class BudgetActualRecord {
  const BudgetActualRecord({
    required this.id,
    required this.periodId,
    required this.categoryId,
    required this.categoryName,
    required this.categoryType,
    required this.budgeted,
    required this.actual,
    this.debtBalance = 0,
  });

  factory BudgetActualRecord.fromActual(BudgetActual actual) {
    return BudgetActualRecord(
      id: actual.id,
      periodId: actual.periodId,
      categoryId: actual.categoryId,
      categoryName: actual.categoryName,
      categoryType: actual.categoryType.name,
      budgeted: actual.budgeted,
      actual: actual.actual,
      debtBalance: actual.debtBalance,
    );
  }

  factory BudgetActualRecord.fromRow(QueryRow row) {
    return BudgetActualRecord(
      id: row.read<String>('id'),
      periodId: row.read<String>('period_id'),
      categoryId: row.read<String>('category_id'),
      categoryName: row.read<String>('category_name'),
      categoryType: row.read<String>('category_type'),
      budgeted: row.read<double>('budgeted'),
      actual: row.read<double>('actual'),
      debtBalance: row.read<double?>('debt_balance') ?? 0,
    );
  }

  final String id;
  final String periodId;
  final String categoryId;
  final String categoryName;
  final String categoryType;
  final double budgeted;
  final double actual;
  final double debtBalance;

  static ActualCategoryType _parseCategoryType(String value) {
    switch (value) {
      case 'income':
        return ActualCategoryType.income;
      case 'bill':
        return ActualCategoryType.bill;
      case 'debtPayment':
        return ActualCategoryType.debtPayment;
      case 'expense':
      default:
        return ActualCategoryType.expense;
    }
  }

  BudgetActual toBudgetActual() {
    return BudgetActual(
      id: id,
      periodId: periodId,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryType: _parseCategoryType(categoryType),
      budgeted: budgeted,
      actual: actual,
      debtBalance: debtBalance,
    );
  }

  List<Object?> toSqlVariables() {
    return <Object?>[
      id,
      periodId,
      categoryId,
      categoryName,
      categoryType,
      budgeted,
      actual,
      debtBalance,
    ];
  }
}
