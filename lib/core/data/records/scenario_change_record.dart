import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:drift/drift.dart';

class ScenarioChangeRecord {
  const ScenarioChangeRecord({
    required this.id,
    required this.changeTypeName,
    required this.amount,
    required this.startMonth,
    required this.durationInMonths,
    this.debtId,
  });

  factory ScenarioChangeRecord.fromChange({
    required String id,
    required ScenarioChange change,
  }) {
    return ScenarioChangeRecord(
      id: id,
      changeTypeName: change.changeType.name,
      amount: change.amount,
      startMonth: change.startMonth,
      durationInMonths: change.durationInMonths,
      debtId: change.debtId,
    );
  }

  factory ScenarioChangeRecord.fromRow(QueryRow row) {
    return ScenarioChangeRecord(
      id: row.read<String>(idColumn),
      changeTypeName: row.read<String>(changeTypeColumn),
      amount: row.read<double>(amountColumn),
      startMonth: row.read<int>(startMonthColumn),
      durationInMonths: row.data[durationInMonthsColumn] == null
          ? null
          : row.read<int>(durationInMonthsColumn),
      debtId: row.data[debtIdColumn] as String?,
    );
  }

  static const String idColumn = 'id';
  static const String changeTypeColumn = 'change_type';
  static const String amountColumn = 'amount';
  static const String startMonthColumn = 'start_month';
  static const String durationInMonthsColumn = 'duration_in_months';
  static const String debtIdColumn = 'debt_id';

  static const String selectColumns =
      '$idColumn, $changeTypeColumn, $amountColumn, $startMonthColumn, '
      '$durationInMonthsColumn, $debtIdColumn';

  static const String insertColumns =
      '($idColumn, $changeTypeColumn, $amountColumn, $startMonthColumn, '
      '$durationInMonthsColumn, $debtIdColumn)';

  final String id;
  final String changeTypeName;
  final double amount;
  final int startMonth;
  final int? durationInMonths;
  final String? debtId;

  ScenarioChange toScenarioChange() {
    return ScenarioChange(
      changeType: ChangeType.values.firstWhere(
        (type) => type.name == changeTypeName,
        orElse: () => ChangeType.extraPayment,
      ),
      amount: amount,
      startMonth: startMonth,
      durationInMonths: durationInMonths,
      debtId: debtId,
    );
  }

  List<Object?> toSqlVariables() {
    return <Object?>[
      id,
      changeTypeName,
      amount,
      startMonth,
      durationInMonths,
      debtId,
    ];
  }
}
