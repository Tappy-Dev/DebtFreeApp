import 'package:debt_free_app/core/utils/uk_tax_calculator.dart';

class IncomeSource {
  const IncomeSource({
    this.id = '',
    this.name = '',
    required this.annualGross,
    this.studentLoanPlan = StudentLoanPlan.none,
    this.monthlyPensionSacrifice = 0,
    this.monthlyCarSacrifice = 0,
    this.monthlyOtherSacrifice = 0,
    this.monthlyTaxableBenefits = 0,
    this.monthlyNiableBenefits = 0,
    this.monthlyStudentLoanableBenefits = 0,
    this.overrideMonthlyNet,
    this.monthKey = '',
  });

  final String id;
  final String name;

  /// Annual gross salary before any deductions.
  final double annualGross;

  /// Student loan repayment plan (if any).
  final StudentLoanPlan studentLoanPlan;

  /// Salary sacrifice breakdown by category.
  final double monthlyPensionSacrifice;
  final double monthlyCarSacrifice;
  final double monthlyOtherSacrifice;

  /// Non-cash taxable benefits that affect income tax calculations.
  final double monthlyTaxableBenefits;

  /// Benefits that affect NI calculations.
  final double monthlyNiableBenefits;

  /// Benefits that affect student loan calculations.
  final double monthlyStudentLoanableBenefits;

  double get monthlySalarySacrificeTotal =>
      monthlyPensionSacrifice + monthlyCarSacrifice + monthlyOtherSacrifice;

  /// When set, used directly instead of computing from gross.
  /// This is used internally when salary-sacrifice-adjusted amounts are needed.
  final double? overrideMonthlyNet;

  final String monthKey;

  /// Monthly take-home pay computed from gross, tax, NI, and student loan.
  /// Salary sacrifices are applied from this income's own sacrifice breakdown.
  double get amount => overrideMonthlyNet ??
      UkTaxCalculator.calculateMonthlyNet(
        annualGross: annualGross,
        monthlySalarySacrifice: monthlySalarySacrificeTotal,
        studentLoanPlan: studentLoanPlan,
        monthlyTaxableBenefits: monthlyTaxableBenefits,
        monthlyNiableBenefits: monthlyNiableBenefits,
        monthlyStudentLoanableBenefits: monthlyStudentLoanableBenefits,
      ).monthlyNet;

  /// Monthly net after salary sacrifices are also deducted.
  /// If [totalMonthlySacrifice] is omitted, this income's own sacrifice total
  /// is used.
  double monthlyNetAfterSacrifice([double? totalMonthlySacrifice]) {
    final resolvedSacrifice =
        totalMonthlySacrifice ?? monthlySalarySacrificeTotal;
    if (totalMonthlySacrifice == 0 && overrideMonthlyNet != null) {
      return overrideMonthlyNet!;
    }
    return UkTaxCalculator.calculateMonthlyNet(
      annualGross: annualGross,
      monthlySalarySacrifice: resolvedSacrifice,
      studentLoanPlan: studentLoanPlan,
      monthlyTaxableBenefits: monthlyTaxableBenefits,
      monthlyNiableBenefits: monthlyNiableBenefits,
      monthlyStudentLoanableBenefits: monthlyStudentLoanableBenefits,
    ).monthlyNet;
  }

  /// Full pay breakdown for display purposes.
  PayBreakdown payBreakdown({double? totalMonthlySacrifice}) {
    return UkTaxCalculator.calculateMonthlyNet(
      annualGross: annualGross,
      monthlySalarySacrifice:
          totalMonthlySacrifice ?? monthlySalarySacrificeTotal,
      studentLoanPlan: studentLoanPlan,
      monthlyTaxableBenefits: monthlyTaxableBenefits,
      monthlyNiableBenefits: monthlyNiableBenefits,
      monthlyStudentLoanableBenefits: monthlyStudentLoanableBenefits,
    );
  }

  IncomeSource copyWith({
    String? id,
    String? name,
    double? annualGross,
    StudentLoanPlan? studentLoanPlan,
    double? monthlyPensionSacrifice,
    double? monthlyCarSacrifice,
    double? monthlyOtherSacrifice,
    double? monthlyTaxableBenefits,
    double? monthlyNiableBenefits,
    double? monthlyStudentLoanableBenefits,
    double? overrideMonthlyNet,
    String? monthKey,
  }) {
    return IncomeSource(
      id: id ?? this.id,
      name: name ?? this.name,
      annualGross: annualGross ?? this.annualGross,
      studentLoanPlan: studentLoanPlan ?? this.studentLoanPlan,
        monthlyPensionSacrifice:
          monthlyPensionSacrifice ?? this.monthlyPensionSacrifice,
        monthlyCarSacrifice: monthlyCarSacrifice ?? this.monthlyCarSacrifice,
        monthlyOtherSacrifice:
          monthlyOtherSacrifice ?? this.monthlyOtherSacrifice,
      monthlyTaxableBenefits:
          monthlyTaxableBenefits ?? this.monthlyTaxableBenefits,
      monthlyNiableBenefits: monthlyNiableBenefits ?? this.monthlyNiableBenefits,
      monthlyStudentLoanableBenefits: monthlyStudentLoanableBenefits ??
          this.monthlyStudentLoanableBenefits,
      overrideMonthlyNet: overrideMonthlyNet ?? this.overrideMonthlyNet,
      monthKey: monthKey ?? this.monthKey,
    );
  }
}
