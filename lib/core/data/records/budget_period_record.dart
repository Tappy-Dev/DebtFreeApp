import 'package:debt_free_app/features/tracking/models/budget_period.dart';
import 'package:drift/drift.dart';

class BudgetPeriodRecord {
  const BudgetPeriodRecord({
    required this.id,
    required this.year,
    required this.month,
    required this.status,
    required this.notes,
    required this.closedAtIso,
    required this.carriedForwardBalance,
  });

  factory BudgetPeriodRecord.fromPeriod(BudgetPeriod period) {
    return BudgetPeriodRecord(
      id: period.id,
      year: period.year,
      month: period.month,
      status: period.status.name,
      notes: period.notes,
      closedAtIso: period.closedAt?.toIso8601String(),
      carriedForwardBalance: period.carriedForwardBalance,
    );
  }

  factory BudgetPeriodRecord.fromRow(QueryRow row) {
    return BudgetPeriodRecord(
      id: row.read<String>('id'),
      year: row.read<int>('year'),
      month: row.read<int>('month'),
      status: row.read<String>('status'),
      notes: row.read<String>('notes'),
      closedAtIso: row.data['closed_at'] as String?,
      carriedForwardBalance: (row.data['carried_forward_balance'] as num? ?? 0).toDouble(),
    );
  }

  final String id;
  final int year;
  final int month;
  final String status;
  final String notes;
  final String? closedAtIso;
  final double carriedForwardBalance;

  BudgetPeriod toBudgetPeriod() {
    return BudgetPeriod(
      id: id,
      year: year,
      month: month,
      status: status == 'closed'
          ? BudgetPeriodStatus.closed
          : BudgetPeriodStatus.open,
      notes: notes,
      closedAt:
          closedAtIso == null ? null : DateTime.parse(closedAtIso!),
      carriedForwardBalance: carriedForwardBalance,
    );
  }

  List<Object?> toSqlVariables() {
    return <Object?>[id, year, month, status, notes, closedAtIso, carriedForwardBalance];
  }
}
