/// UK PAYE tax, National Insurance, and Student Loan calculator.
///
/// Uses 2025/26 tax year rates. Salary sacrifices are deducted from gross
/// before tax/NI/student-loan calculations (they reduce taxable income).
class UkTaxCalculator {
  const UkTaxCalculator._();

  // ── 2025/26 Income Tax thresholds (annual) ──
  static const double personalAllowance = 12570;
  static const double basicRateLimit = 50270; // up to this amount
  static const double higherRateLimit = 125140; // up to this amount
  // Above higherRateLimit → additional rate

  // ── Income Tax rates ──
  static const double basicRate = 0.20;
  static const double higherRate = 0.40;
  static const double additionalRate = 0.45;

  // Personal allowance taper: reduced by £1 for every £2 over £100,000
  static const double allowanceTaperThreshold = 100000;

  // ── Class 1 Employee NI (2025/26) ──
  static const double niPrimaryThresholdAnnual = 12570; // £242/week × 52
  static const double niUpperEarningsLimitAnnual = 50270; // £967/week × 52
  static const double niMainRate = 0.08; // 8% between PT and UEL
  static const double niUpperRate = 0.02; // 2% above UEL

  // ── Student Loan thresholds (2025/26 from GOV.UK) ──
  // Monthly thresholds are published by SLC and used by employers.
  static const double plan1Threshold = 26900;
  static const double plan2Threshold = 29385;
  static const double plan4Threshold = 33795;
  static const double plan5Threshold = 25000;
  static const double postgraduateThreshold = 21000;

  // Monthly thresholds (as published by SLC)
  static const double plan1MonthlyThreshold = 2241;
  static const double plan2MonthlyThreshold = 2448;
  static const double plan4MonthlyThreshold = 2816;
  static const double plan5MonthlyThreshold = 2083;
  static const double postgraduateMonthlyThreshold = 1750;

  static const double studentLoanRate = 0.09;
  static const double postgraduateRate = 0.06;

  /// Calculates annual income tax on [taxableIncome] (after personal allowance).
  static double calculateIncomeTax(double grossAnnual) {
    if (grossAnnual <= 0) return 0;

    // Adjusted personal allowance (tapered above £100k)
    double allowance = personalAllowance;
    if (grossAnnual > allowanceTaperThreshold) {
      final reduction = (grossAnnual - allowanceTaperThreshold) / 2;
      allowance = (personalAllowance - reduction).clamp(0.0, personalAllowance);
    }

    final taxable = (grossAnnual - allowance).clamp(0.0, double.infinity);
    if (taxable <= 0) return 0;

    double tax = 0;

    // Basic rate band: allowance → basicRateLimit
    final basicBand = (basicRateLimit - allowance).clamp(0.0, double.infinity);
    final basicTaxable = taxable.clamp(0.0, basicBand);
    tax += basicTaxable * basicRate;

    // Higher rate band: basicRateLimit → higherRateLimit
    final double higherBand = higherRateLimit - basicRateLimit;
    final higherTaxable = (taxable - basicBand).clamp(0.0, higherBand);
    tax += higherTaxable * higherRate;

    // Additional rate: above higherRateLimit
    final additionalTaxable =
        (taxable - basicBand - higherBand).clamp(0.0, double.infinity);
    tax += additionalTaxable * additionalRate;

    return tax;
  }

  /// Calculates annual Class 1 Employee National Insurance.
  static double calculateEmployeeNI(double grossAnnual) {
    if (grossAnnual <= niPrimaryThresholdAnnual) return 0;

    double ni = 0;

    // Main rate: PT → UEL
    final double mainBand = niUpperEarningsLimitAnnual - niPrimaryThresholdAnnual;
    final mainEarnings =
        (grossAnnual - niPrimaryThresholdAnnual).clamp(0.0, mainBand);
    ni += mainEarnings * niMainRate;

    // Upper rate: above UEL
    final upperEarnings =
        (grossAnnual - niUpperEarningsLimitAnnual).clamp(0.0, double.infinity);
    ni += upperEarnings * niUpperRate;

    return ni;
  }

  /// Calculates annual student loan repayment for the given [plan].
  /// Uses monthly threshold with floor rounding per-month (matching PAYE).
  static double calculateStudentLoan(
    double grossAnnual,
    StudentLoanPlan plan,
  ) {
    final monthlyThreshold = _studentLoanMonthlyThreshold(plan);
    final rate = plan == StudentLoanPlan.postgraduate
        ? postgraduateRate
        : studentLoanRate;

    final monthlyGross = grossAnnual / 12;
    final monthlyRepayable =
        (monthlyGross - monthlyThreshold).clamp(0.0, double.infinity);
    final monthlyRepayment = (monthlyRepayable * rate).floorToDouble();
    return monthlyRepayment * 12;
  }

  static double _studentLoanMonthlyThreshold(StudentLoanPlan plan) {
    switch (plan) {
      case StudentLoanPlan.plan1:
        return plan1MonthlyThreshold;
      case StudentLoanPlan.plan2:
        return plan2MonthlyThreshold;
      case StudentLoanPlan.plan4:
        return plan4MonthlyThreshold;
      case StudentLoanPlan.plan5:
        return plan5MonthlyThreshold;
      case StudentLoanPlan.postgraduate:
        return postgraduateMonthlyThreshold;
      case StudentLoanPlan.none:
        return double.infinity;
    }
  }

  /// Computes a full pay breakdown from annual gross salary.
  ///
  /// [annualGross] — the contractual annual salary before any deductions.
  /// [monthlySalarySacrifice] — total gross salary sacrifice per month
  ///   (pension, EV scheme, cycle-to-work, etc.). These reduce taxable pay.
  /// [monthlyTaxableBenefits] — non-cash taxable benefits (e.g. medical, fuel
  ///   benefit) that increase income tax assessable pay.
  /// [monthlyNiableBenefits] — benefits that increase NI assessable pay.
  /// [monthlyStudentLoanableBenefits] — benefits that increase student-loan
  ///   assessable pay.
  /// [studentLoanPlan] — which student loan plan (if any).
  static PayBreakdown calculateMonthlyNet({
    required double annualGross,
    double monthlySalarySacrifice = 0,
    double monthlyTaxableBenefits = 0,
    double monthlyNiableBenefits = 0,
    double monthlyStudentLoanableBenefits = 0,
    StudentLoanPlan studentLoanPlan = StudentLoanPlan.none,
  }) {
    final annualSacrifice = monthlySalarySacrifice * 12;
    final double annualCashAfterSacrifice =
        (annualGross - annualSacrifice).clamp(0.0, double.infinity);
    final double annualTaxAssessableIncome =
        (annualCashAfterSacrifice + (monthlyTaxableBenefits * 12))
            .clamp(0.0, double.infinity);
    final double annualNiAssessableIncome =
        (annualCashAfterSacrifice + (monthlyNiableBenefits * 12))
            .clamp(0.0, double.infinity);
    final double annualStudentLoanAssessableIncome =
        (annualCashAfterSacrifice + (monthlyStudentLoanableBenefits * 12))
            .clamp(0.0, double.infinity);

    final annualTax = calculateIncomeTax(annualTaxAssessableIncome);
    final annualNI = calculateEmployeeNI(annualNiAssessableIncome);
    final annualStudentLoan = studentLoanPlan == StudentLoanPlan.none
        ? 0.0
        : calculateStudentLoan(
            annualStudentLoanAssessableIncome,
            studentLoanPlan,
          );

    final annualNet =
        annualCashAfterSacrifice - annualTax - annualNI - annualStudentLoan;

    return PayBreakdown(
      annualGross: annualGross,
      annualSalarySacrifice: annualSacrifice,
      annualTaxableIncome: annualTaxAssessableIncome,
      annualNiAssessableIncome: annualNiAssessableIncome,
      annualStudentLoanAssessableIncome: annualStudentLoanAssessableIncome,
      annualTax: annualTax,
      annualNI: annualNI,
      annualStudentLoan: annualStudentLoan,
      annualNet: annualNet,
      monthlyGross: annualGross / 12,
      monthlySalarySacrifice: monthlySalarySacrifice,
      monthlyTaxableBenefits: monthlyTaxableBenefits,
      monthlyNiableBenefits: monthlyNiableBenefits,
      monthlyStudentLoanableBenefits: monthlyStudentLoanableBenefits,
      monthlyTax: annualTax / 12,
      monthlyNI: annualNI / 12,
      monthlyStudentLoan: annualStudentLoan / 12,
      monthlyNet: annualNet / 12,
    );
  }
}

enum StudentLoanPlan {
  none,
  plan1,
  plan2,
  plan4,
  plan5,
  postgraduate,
}

class PayBreakdown {
  const PayBreakdown({
    required this.annualGross,
    required this.annualSalarySacrifice,
    required this.annualTaxableIncome,
    required this.annualNiAssessableIncome,
    required this.annualStudentLoanAssessableIncome,
    required this.annualTax,
    required this.annualNI,
    required this.annualStudentLoan,
    required this.annualNet,
    required this.monthlyGross,
    required this.monthlySalarySacrifice,
    required this.monthlyTaxableBenefits,
    required this.monthlyNiableBenefits,
    required this.monthlyStudentLoanableBenefits,
    required this.monthlyTax,
    required this.monthlyNI,
    required this.monthlyStudentLoan,
    required this.monthlyNet,
  });

  final double annualGross;
  final double annualSalarySacrifice;
  final double annualTaxableIncome;
  final double annualNiAssessableIncome;
  final double annualStudentLoanAssessableIncome;
  final double annualTax;
  final double annualNI;
  final double annualStudentLoan;
  final double annualNet;

  final double monthlyGross;
  final double monthlySalarySacrifice;
  final double monthlyTaxableBenefits;
  final double monthlyNiableBenefits;
  final double monthlyStudentLoanableBenefits;
  final double monthlyTax;
  final double monthlyNI;
  final double monthlyStudentLoan;
  final double monthlyNet;
}
