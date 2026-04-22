import 'package:debt_free_app/core/utils/uk_tax_calculator.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:drift/drift.dart';

class BudgetItemRecord {
  const BudgetItemRecord({
    required this.id,
    required this.name,
    required this.amount,
    this.annualGross = 0,
    this.studentLoanPlan = 'none',
    this.monthlyPensionSacrifice = 0,
    this.monthlyCarSacrifice = 0,
    this.monthlyOtherSacrifice = 0,
    this.monthlyTaxableBenefits = 0,
    this.monthlyNiableBenefits = 0,
    this.monthlyStudentLoanableBenefits = 0,
    this.monthKey = '',
    this.trackable = false,
  });

  factory BudgetItemRecord.fromIncomeSource(IncomeSource incomeSource) {
    return BudgetItemRecord(
      id: incomeSource.id,
      name: incomeSource.name,
      amount: incomeSource.amount,
      annualGross: incomeSource.annualGross,
      studentLoanPlan: incomeSource.studentLoanPlan.name,
      monthlyPensionSacrifice: incomeSource.monthlyPensionSacrifice,
      monthlyCarSacrifice: incomeSource.monthlyCarSacrifice,
      monthlyOtherSacrifice: incomeSource.monthlyOtherSacrifice,
      monthlyTaxableBenefits: incomeSource.monthlyTaxableBenefits,
      monthlyNiableBenefits: incomeSource.monthlyNiableBenefits,
      monthlyStudentLoanableBenefits: incomeSource.monthlyStudentLoanableBenefits,
      monthKey: incomeSource.monthKey,
    );
  }

  factory BudgetItemRecord.fromExpense(Expense expense) {
    return BudgetItemRecord(
      id: expense.id,
      name: expense.name,
      amount: expense.amount,
      monthKey: expense.monthKey,
      trackable: expense.trackable,
    );
  }

  factory BudgetItemRecord.fromRow(QueryRow row) {
    return BudgetItemRecord(
      id: row.read<String>(idColumn),
      name: row.read<String>(nameColumn),
      amount: row.read<double>(amountColumn),
      monthKey: row.read<String>(monthKeyColumn),
    );
  }

  factory BudgetItemRecord.expenseFromRow(QueryRow row) {
    return BudgetItemRecord(
      id: row.read<String>(idColumn),
      name: row.read<String>(nameColumn),
      amount: row.read<double>(amountColumn),
      monthKey: row.read<String>(monthKeyColumn),
      trackable: (row.read<int?>('is_trackable') ?? 0) == 1,
    );
  }

  factory BudgetItemRecord.incomeFromRow(QueryRow row) {
    return BudgetItemRecord(
      id: row.read<String>(idColumn),
      name: row.read<String>(nameColumn),
      amount: row.read<double>(amountColumn),
      annualGross: row.read<double>(annualGrossColumn),
      studentLoanPlan: row.read<String>(studentLoanPlanColumn),
        monthlyPensionSacrifice:
          (row.data[monthlyPensionSacrificeColumn] as num?)?.toDouble() ?? 0,
        monthlyCarSacrifice:
          (row.data[monthlyCarSacrificeColumn] as num?)?.toDouble() ?? 0,
        monthlyOtherSacrifice:
          (row.data[monthlyOtherSacrificeColumn] as num?)?.toDouble() ?? 0,
        monthlyTaxableBenefits:
          (row.data[monthlyTaxableBenefitsColumn] as num?)?.toDouble() ?? 0,
        monthlyNiableBenefits:
          (row.data[monthlyNiableBenefitsColumn] as num?)?.toDouble() ?? 0,
        monthlyStudentLoanableBenefits:
          (row.data[monthlyStudentLoanableBenefitsColumn] as num?)?.toDouble() ??
            0,
      monthKey: row.read<String>(monthKeyColumn),
    );
  }

  static const String idColumn = 'id';
  static const String nameColumn = 'name';
  static const String amountColumn = 'amount';
  static const String annualGrossColumn = 'annual_gross';
  static const String studentLoanPlanColumn = 'student_loan_plan';
    static const String monthlyPensionSacrificeColumn =
      'monthly_pension_sacrifice';
    static const String monthlyCarSacrificeColumn = 'monthly_car_sacrifice';
    static const String monthlyOtherSacrificeColumn =
      'monthly_other_sacrifice';
    static const String monthlyTaxableBenefitsColumn =
      'monthly_taxable_benefits';
    static const String monthlyNiableBenefitsColumn =
      'monthly_niable_benefits';
    static const String monthlyStudentLoanableBenefitsColumn =
      'monthly_student_loanable_benefits';
  static const String monthKeyColumn = 'month_key';

  static const String selectColumns =
      '$idColumn, $nameColumn, $amountColumn, $monthKeyColumn';
  static const String selectExpenseColumns =
      '$idColumn, $nameColumn, $amountColumn, $monthKeyColumn, is_trackable';
  static const String selectIncomeColumns =
      '$idColumn, $nameColumn, $amountColumn, $annualGrossColumn, '
      '$studentLoanPlanColumn, $monthlyPensionSacrificeColumn, '
      '$monthlyCarSacrificeColumn, $monthlyOtherSacrificeColumn, '
      '$monthlyTaxableBenefitsColumn, '
      '$monthlyNiableBenefitsColumn, $monthlyStudentLoanableBenefitsColumn, '
      '$monthKeyColumn';
  static const String insertColumns =
      '($idColumn, $nameColumn, $amountColumn, $monthKeyColumn, is_trackable)';
  static const String insertIncomeColumns =
      '($idColumn, $nameColumn, $amountColumn, $annualGrossColumn, '
      '$studentLoanPlanColumn, $monthlyPensionSacrificeColumn, '
      '$monthlyCarSacrificeColumn, $monthlyOtherSacrificeColumn, '
      '$monthlyTaxableBenefitsColumn, '
      '$monthlyNiableBenefitsColumn, $monthlyStudentLoanableBenefitsColumn, '
      '$monthKeyColumn)';

  final String id;
  final String name;
  final double amount;
  final double annualGross;
  final String studentLoanPlan;
  final double monthlyPensionSacrifice;
  final double monthlyCarSacrifice;
  final double monthlyOtherSacrifice;
  final double monthlyTaxableBenefits;
  final double monthlyNiableBenefits;
  final double monthlyStudentLoanableBenefits;
  final String monthKey;
  final bool trackable;

  IncomeSource toIncomeSource() {
    // If annualGross is set use it; otherwise fall back to legacy monthly amount
    final effectiveAnnualGross = annualGross > 0 ? annualGross : amount * 12;
    final plan = StudentLoanPlan.values.firstWhere(
      (StudentLoanPlan p) => p.name == studentLoanPlan,
      orElse: () => StudentLoanPlan.none,
    );
    return IncomeSource(
      id: id,
      name: name,
      annualGross: effectiveAnnualGross,
      studentLoanPlan: plan,
      monthlyPensionSacrifice: monthlyPensionSacrifice,
      monthlyCarSacrifice: monthlyCarSacrifice,
      monthlyOtherSacrifice: monthlyOtherSacrifice,
      monthlyTaxableBenefits: monthlyTaxableBenefits,
      monthlyNiableBenefits: monthlyNiableBenefits,
      monthlyStudentLoanableBenefits: monthlyStudentLoanableBenefits,
      monthKey: monthKey,
    );
  }

  Expense toExpense() {
    return Expense(
      id: id,
      name: name,
      amount: amount,
      monthKey: monthKey,
      trackable: trackable,
    );
  }

  List<Object?> toSqlVariables() {
    return <Object?>[
      id,
      name,
      amount,
      monthKey,
      trackable ? 1 : 0,
    ];
  }

  List<Object?> toIncomeSqlVariables() {
    return <Object?>[
      id,
      name,
      amount,
      annualGross,
      studentLoanPlan,
      monthlyPensionSacrifice,
      monthlyCarSacrifice,
      monthlyOtherSacrifice,
      monthlyTaxableBenefits,
      monthlyNiableBenefits,
      monthlyStudentLoanableBenefits,
      monthKey,
    ];
  }
}
