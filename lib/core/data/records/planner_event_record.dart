import 'package:debt_free_app/features/planner/models/planner_event.dart';
import 'package:drift/drift.dart';

class PlannerEventRecord {
  const PlannerEventRecord({
    required this.id,
    required this.title,
    required this.eventType,
    required this.amount,
    required this.scheduledMonth,
    required this.scheduledYear,
    required this.isRecurring,
    required this.notes,
  });

  factory PlannerEventRecord.fromEvent(PlannerEvent event) {
    return PlannerEventRecord(
      id: event.id,
      title: event.title,
      eventType: event.type.name,
      amount: event.amount,
      scheduledMonth: event.scheduledMonth,
      scheduledYear: event.scheduledYear,
      isRecurring: event.isRecurring,
      notes: event.notes,
    );
  }

  factory PlannerEventRecord.fromRow(QueryRow row) {
    return PlannerEventRecord(
      id: row.read<String>('id'),
      title: row.read<String>('title'),
      eventType: row.read<String>('event_type'),
      amount: row.read<double>('amount'),
      scheduledMonth: row.read<int>('scheduled_month'),
      scheduledYear: row.read<int>('scheduled_year'),
      isRecurring: row.read<int>('is_recurring') == 1,
      notes: row.read<String>('notes'),
    );
  }

  final String id;
  final String title;
  final String eventType;
  final double amount;
  final int scheduledMonth;
  final int scheduledYear;
  final bool isRecurring;
  final String notes;

  PlannerEvent toEvent() {
    return PlannerEvent(
      id: id,
      title: title,
      type: PlannerEventType.values.firstWhere(
        (t) => t.name == eventType,
        orElse: () => PlannerEventType.oneOffExpense,
      ),
      amount: amount,
      scheduledMonth: scheduledMonth,
      scheduledYear: scheduledYear,
      isRecurring: isRecurring,
      notes: notes,
    );
  }

  List<Object?> toSqlVariables() {
    return <Object?>[
      id,
      title,
      eventType,
      amount,
      scheduledMonth,
      scheduledYear,
      isRecurring ? 1 : 0,
      notes,
    ];
  }
}
