import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:drift/drift.dart';

class MortgageRecord {
  const MortgageRecord({
    required this.id,
    required this.name,
    required this.balance,
    required this.annualRate,
    required this.monthlyPayment,
    required this.remainingTermMonths,
    required this.overpayment,
  });

  factory MortgageRecord.fromMortgage(Mortgage mortgage) {
    return MortgageRecord(
      id: mortgage.id,
      name: mortgage.name,
      balance: mortgage.balance,
      annualRate: mortgage.annualRate,
      monthlyPayment: mortgage.monthlyPayment,
      remainingTermMonths: mortgage.remainingTermMonths,
      overpayment: mortgage.overpayment,
    );
  }

  factory MortgageRecord.fromRow(QueryRow row) {
    return MortgageRecord(
      id: row.read<String>(idColumn),
      name: row.read<String>(nameColumn),
      balance: row.read<double>(balanceColumn),
      annualRate: row.read<double>(annualRateColumn),
      monthlyPayment: row.read<double>(monthlyPaymentColumn),
      remainingTermMonths: row.read<int>(remainingTermMonthsColumn),
      overpayment: row.read<double>(overpaymentColumn),
    );
  }

  static const String idColumn = 'id';
  static const String nameColumn = 'name';
  static const String balanceColumn = 'balance';
  static const String annualRateColumn = 'annual_rate';
  static const String monthlyPaymentColumn = 'monthly_payment';
  static const String remainingTermMonthsColumn = 'remaining_term_months';
  static const String overpaymentColumn = 'overpayment';

  static const String selectColumns =
      '$idColumn, $nameColumn, $balanceColumn, $annualRateColumn, '
      '$monthlyPaymentColumn, $remainingTermMonthsColumn, $overpaymentColumn';

  static const String insertColumns =
      '($idColumn, $nameColumn, $balanceColumn, $annualRateColumn, '
      '$monthlyPaymentColumn, $remainingTermMonthsColumn, $overpaymentColumn)';

  final String id;
  final String name;
  final double balance;
  final double annualRate;
  final double monthlyPayment;
  final int remainingTermMonths;
  final double overpayment;

  Mortgage toMortgage() {
    return Mortgage(
      id: id,
      name: name,
      balance: balance,
      annualRate: annualRate,
      monthlyPayment: monthlyPayment,
      remainingTermMonths: remainingTermMonths,
      overpayment: overpayment,
    );
  }

  List<Object?> toSqlVariables() {
    return <Object?>[
      id,
      name,
      balance,
      annualRate,
      monthlyPayment,
      remainingTermMonths,
      overpayment,
    ];
  }
}
