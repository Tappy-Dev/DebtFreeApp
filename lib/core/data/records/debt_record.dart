import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:drift/drift.dart';

class DebtRecord {
  const DebtRecord({
    required this.id,
    required this.name,
    this.debtType = 'other',
    required this.balance,
    required this.apr,
    required this.minimumPayment,
    required this.payoffDateIso,
    this.minPaymentType = 'interestPlusPercentage',
    this.minPaymentPercentage = 1.0,
    this.minPaymentFloor = 25.0,
    this.startDateIso,
    this.loanEndDateIso,
    this.originalBalance,
  });

  factory DebtRecord.fromDebt(DebtAccount debt) {
    return DebtRecord(
      id: debt.id,
      name: debt.name,
      debtType: debt.debtType.name,
      balance: debt.balance,
      apr: debt.apr,
      minimumPayment: debt.minimumPayment,
      payoffDateIso: debt.payoffDate?.toIso8601String(),
      minPaymentType: debt.minPaymentRule.type.name,
      minPaymentPercentage: debt.minPaymentRule.percentage,
      minPaymentFloor: debt.minPaymentRule.floor,
      startDateIso: debt.startDate?.toIso8601String(),
      loanEndDateIso: debt.loanEndDate?.toIso8601String(),
      originalBalance: debt.originalBalance,
    );
  }

  factory DebtRecord.fromRow(QueryRow row) {
    return DebtRecord(
      id: row.read<String>(idColumn),
      name: row.read<String>(nameColumn),
      debtType: row.data[debtTypeColumn] as String? ?? 'other',
      balance: row.read<double>(balanceColumn),
      apr: row.read<double>(aprColumn),
      minimumPayment: row.read<double>(minimumPaymentColumn),
      payoffDateIso: row.data[payoffDateColumn] == null
          ? null
          : row.read<String>(payoffDateColumn),
      minPaymentType: row.data[minPaymentTypeColumn] as String? ??
          'interestPlusPercentage',
      minPaymentPercentage:
          (row.data[minPaymentPercentageColumn] as num?)?.toDouble() ?? 1.0,
      minPaymentFloor:
          (row.data[minPaymentFloorColumn] as num?)?.toDouble() ?? 25.0,
      startDateIso: row.data[startDateColumn] as String?,
        loanEndDateIso: row.data[loanEndDateColumn] as String?,
      originalBalance:
          (row.data[originalBalanceColumn] as num?)?.toDouble(),
    );
  }

  static const String idColumn = 'id';
  static const String nameColumn = 'name';
      static const String debtTypeColumn = 'debt_type';
  static const String balanceColumn = 'balance';
  static const String aprColumn = 'apr';
  static const String minimumPaymentColumn = 'minimum_payment';
  static const String payoffDateColumn = 'payoff_date';
  static const String minPaymentTypeColumn = 'min_payment_type';
  static const String minPaymentPercentageColumn = 'min_payment_percentage';
  static const String minPaymentFloorColumn = 'min_payment_floor';
  static const String startDateColumn = 'start_date';
    static const String loanEndDateColumn = 'loan_end_date';
  static const String originalBalanceColumn = 'original_balance';

  static const String selectColumns =
      '$idColumn, $nameColumn, $debtTypeColumn, $balanceColumn, $aprColumn, '
      '$minimumPaymentColumn, $payoffDateColumn, '
      '$minPaymentTypeColumn, $minPaymentPercentageColumn, $minPaymentFloorColumn, '
      '$startDateColumn, $loanEndDateColumn, $originalBalanceColumn';

  static const String insertColumns =
      '($idColumn, $nameColumn, $debtTypeColumn, $balanceColumn, $aprColumn, '
      '$minimumPaymentColumn, $payoffDateColumn, '
      '$minPaymentTypeColumn, $minPaymentPercentageColumn, $minPaymentFloorColumn, '
      '$startDateColumn, $loanEndDateColumn, $originalBalanceColumn)';

  final String id;
  final String name;
    final String debtType;
  final double balance;
  final double apr;
  final double minimumPayment;
  final String? payoffDateIso;
  final String minPaymentType;
  final double minPaymentPercentage;
  final double minPaymentFloor;
  final String? startDateIso;
  final String? loanEndDateIso;
  final double? originalBalance;

  static DebtType _parseDebtType(String value) {
    switch (value) {
      case 'loan':
        return DebtType.loan;
      case 'creditCard':
        return DebtType.creditCard;
      case 'other':
      default:
        return DebtType.other;
    }
  }

  static MinPaymentType _parseMinPaymentType(String value) {
    switch (value) {
      case 'fixed':
        return MinPaymentType.fixed;
      case 'percentageOfBalance':
        return MinPaymentType.percentageOfBalance;
      case 'interestPlusPercentage':
      default:
        return MinPaymentType.interestPlusPercentage;
    }
  }

  DebtAccount toDebtAccount() {
    return DebtAccount(
      id: id,
      name: name,
      debtType: _parseDebtType(debtType),
      balance: balance,
      apr: apr,
      minimumPayment: minimumPayment,
      payoffDate: payoffDateIso == null ? null : DateTime.parse(payoffDateIso!),
      startDate: startDateIso == null ? null : DateTime.parse(startDateIso!),
      loanEndDate:
          loanEndDateIso == null ? null : DateTime.parse(loanEndDateIso!),
      originalBalance: originalBalance,
      minPaymentRule: MinPaymentRule(
        type: _parseMinPaymentType(minPaymentType),
        percentage: minPaymentPercentage,
        floor: minPaymentFloor,
      ),
    );
  }

  List<Object?> toSqlVariables() {
    return <Object?>[
      id,
      name,
      debtType,
      balance,
      apr,
      minimumPayment,
      payoffDateIso,
      minPaymentType,
      minPaymentPercentage,
      minPaymentFloor,
      startDateIso,
      loanEndDateIso,
      originalBalance,
    ];
  }
}
