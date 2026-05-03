import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:drift/drift.dart';

class MortgageRecord {
  const MortgageRecord({
    required this.id,
    required this.name,
    required this.startDate,
    required this.originalLoanAmount,
    required this.mortgageTermMonths,
    required this.annualRate,
    required this.monthlyPayment,
    required this.overpayment,
    this.overpaymentStartDateIso,
    required this.paymentDay,
    this.dealEndDateMs,
    required this.ownershipType,
    required this.repaymentType,
    required this.ownedSharePercent,
    required this.monthlyRent,
    required this.monthlyServiceCharge,
    required this.monthlyGroundRent,
  });

  factory MortgageRecord.fromMortgage(Mortgage mortgage) {
    return MortgageRecord(
      id: mortgage.id,
      name: mortgage.name,
      startDate: mortgage.startDate,
      originalLoanAmount: mortgage.originalLoanAmount,
      mortgageTermMonths: mortgage.mortgageTermMonths,
      annualRate: mortgage.annualRate,
      monthlyPayment: mortgage.monthlyPayment,
      overpayment: mortgage.overpayment,
      overpaymentStartDateIso:
          mortgage.overpaymentStartDate?.toIso8601String(),
      paymentDay: mortgage.paymentDay,
      dealEndDateMs: mortgage.dealEndDate?.millisecondsSinceEpoch,
      ownershipType: mortgage.ownershipType.name,
      repaymentType: mortgage.repaymentType.name,
      ownedSharePercent: mortgage.ownedSharePercent,
      monthlyRent: mortgage.monthlyRent,
      monthlyServiceCharge: mortgage.monthlyServiceCharge,
      monthlyGroundRent: mortgage.monthlyGroundRent,
    );
  }

  factory MortgageRecord.fromRow(QueryRow row) {
    final dealEndMs = row.readNullable<int>(dealEndDateColumn);
    final ownershipType = row.readNullable<String>(ownershipTypeColumn) ??
        MortgageOwnershipType.standard.name;
    final repaymentType = row.readNullable<String>(repaymentTypeColumn) ??
        MortgageRepaymentType.repayment.name;
    final startDateStr = row.readNullable<String>(startDateColumn);
    return MortgageRecord(
      id: row.read<String>(idColumn),
      name: row.read<String>(nameColumn),
      startDate: startDateStr != null ? DateTime.parse(startDateStr) : DateTime(2024, 1, 1),
      originalLoanAmount: row.readNullable<double>(originalLoanAmountColumn) ?? 0,
      mortgageTermMonths: row.readNullable<int>(mortgageTermMonthsColumn) ?? 360,
      annualRate: row.read<double>(annualRateColumn),
      monthlyPayment: row.read<double>(monthlyPaymentColumn),
      overpayment: row.read<double>(overpaymentColumn),
      overpaymentStartDateIso:
          row.readNullable<String>(overpaymentStartDateColumn),
      paymentDay: row.read<int>(paymentDayColumn),
      dealEndDateMs: dealEndMs,
      ownershipType: ownershipType,
      repaymentType: repaymentType,
      ownedSharePercent:
          row.readNullable<double>(ownedSharePercentColumn) ?? 100,
      monthlyRent: row.readNullable<double>(monthlyRentColumn) ?? 0,
      monthlyServiceCharge:
          row.readNullable<double>(monthlyServiceChargeColumn) ?? 0,
      monthlyGroundRent: row.readNullable<double>(monthlyGroundRentColumn) ?? 0,
    );
  }

  static const String idColumn = 'id';
  static const String nameColumn = 'name';
  static const String balanceColumn = 'balance';
  static const String startDateColumn = 'start_date';
  static const String originalLoanAmountColumn = 'original_loan_amount';
  static const String remainingTermMonthsLegacyColumn = 'remaining_term_months';
  static const String mortgageTermMonthsColumn = 'mortgage_term_months';
  static const String annualRateColumn = 'annual_rate';
  static const String monthlyPaymentColumn = 'monthly_payment';
  static const String overpaymentColumn = 'overpayment';
  static const String overpaymentStartDateColumn = 'overpayment_start_date';
  static const String paymentDayColumn = 'payment_day';
  static const String dealEndDateColumn = 'deal_end_date';
  static const String ownershipTypeColumn = 'ownership_type';
  static const String repaymentTypeColumn = 'repayment_type';
  static const String ownedSharePercentColumn = 'owned_share_percent';
  static const String monthlyRentColumn = 'monthly_rent';
  static const String monthlyServiceChargeColumn = 'monthly_service_charge';
  static const String monthlyGroundRentColumn = 'monthly_ground_rent';

  static const String selectColumns =
      '$idColumn, $nameColumn, $startDateColumn, $originalLoanAmountColumn, '
      '$mortgageTermMonthsColumn, $annualRateColumn, '
      '$monthlyPaymentColumn, $overpaymentColumn, $overpaymentStartDateColumn, '
      '$paymentDayColumn, $dealEndDateColumn, $ownershipTypeColumn, '
      '$repaymentTypeColumn, $ownedSharePercentColumn, $monthlyRentColumn, '
      '$monthlyServiceChargeColumn, $monthlyGroundRentColumn';

  static const String insertColumns =
      '($idColumn, $nameColumn, $balanceColumn, $startDateColumn, $originalLoanAmountColumn, '
      '$remainingTermMonthsLegacyColumn, $mortgageTermMonthsColumn, $annualRateColumn, '
      '$monthlyPaymentColumn, $overpaymentColumn, $overpaymentStartDateColumn, '
      '$paymentDayColumn, $dealEndDateColumn, $ownershipTypeColumn, '
      '$repaymentTypeColumn, $ownedSharePercentColumn, $monthlyRentColumn, '
      '$monthlyServiceChargeColumn, $monthlyGroundRentColumn)';

  final String id;
  final String name;
  final DateTime startDate;
  final double originalLoanAmount;
  final int mortgageTermMonths;
  final double annualRate;
  final double monthlyPayment;
  final double overpayment;
  final String? overpaymentStartDateIso;
  final int paymentDay;
  final int? dealEndDateMs;
  final String ownershipType;
  final String repaymentType;
  final double ownedSharePercent;
  final double monthlyRent;
  final double monthlyServiceCharge;
  final double monthlyGroundRent;

  Mortgage toMortgage() {
    return Mortgage(
      id: id,
      name: name,
      startDate: startDate,
      originalLoanAmount: originalLoanAmount,
      mortgageTermMonths: mortgageTermMonths,
      annualRate: annualRate,
      monthlyPayment: monthlyPayment,
      overpayment: overpayment,
      overpaymentStartDate: overpaymentStartDateIso != null
          ? DateTime.parse(overpaymentStartDateIso!)
          : null,
      paymentDay: paymentDay,
      dealEndDate: dealEndDateMs != null
          ? DateTime.fromMillisecondsSinceEpoch(dealEndDateMs!)
          : null,
      ownershipType: MortgageOwnershipType.values.firstWhere(
        (value) => value.name == ownershipType,
        orElse: () => MortgageOwnershipType.standard,
      ),
      repaymentType: MortgageRepaymentType.values.firstWhere(
        (value) => value.name == repaymentType,
        orElse: () => MortgageRepaymentType.repayment,
      ),
      ownedSharePercent: ownedSharePercent,
      monthlyRent: monthlyRent,
      monthlyServiceCharge: monthlyServiceCharge,
      monthlyGroundRent: monthlyGroundRent,
    );
  }

  List<Object?> toSqlVariables() {
    return <Object?>[
      id,
      name,
      // Legacy persistence fields kept for compatibility with older local DBs.
      originalLoanAmount,
      startDate.toIso8601String(),
      originalLoanAmount,
      mortgageTermMonths,
      mortgageTermMonths,
      annualRate,
      monthlyPayment,
      overpayment,
      overpaymentStartDateIso,
      paymentDay,
      dealEndDateMs,
      ownershipType,
      repaymentType,
      ownedSharePercent,
      monthlyRent,
      monthlyServiceCharge,
      monthlyGroundRent,
    ];
  }
}
