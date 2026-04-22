import 'package:debt_free_app/core/utils/uk_tax_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UkTaxCalculator', () {
    test('applies taxable benefits to tax only when NI/SL benefits are zero', () {
      final base = UkTaxCalculator.calculateMonthlyNet(
        annualGross: 50000,
        monthlySalarySacrifice: 863.42,
        studentLoanPlan: StudentLoanPlan.plan2,
      );

      final withTaxBenefits = UkTaxCalculator.calculateMonthlyNet(
        annualGross: 50000,
        monthlySalarySacrifice: 863.42,
        monthlyTaxableBenefits: 138.22,
        monthlyNiableBenefits: 0,
        monthlyStudentLoanableBenefits: 0,
        studentLoanPlan: StudentLoanPlan.plan2,
      );

      // Tax should increase with taxable benefits.
      expect(withTaxBenefits.monthlyTax, greaterThan(base.monthlyTax));
      // NI and Student Loan should stay flat when those bases are unchanged.
      expect(withTaxBenefits.monthlyNI, closeTo(base.monthlyNI, 0.01));
      expect(
        withTaxBenefits.monthlyStudentLoan,
        closeTo(base.monthlyStudentLoan, 0.01),
      );
    });

    test('matches payslip pattern with split assessable bases', () {
      final breakdown = UkTaxCalculator.calculateMonthlyNet(
        annualGross: 50000,
        monthlySalarySacrifice: 863.42,
        monthlyTaxableBenefits: 138.22,
        monthlyNiableBenefits: 0,
        monthlyStudentLoanableBenefits: 0,
        studentLoanPlan: StudentLoanPlan.plan2,
      );

      // Expected direction and close values from uploaded payslip.
      expect(breakdown.monthlyTax, closeTo(478.79, 0.5));
      expect(breakdown.monthlyNI, closeTo(180.42, 0.1));
      expect(breakdown.monthlyStudentLoan, closeTo(76.0, 0.1));
      expect(breakdown.monthlyNet, closeTo(2568.0, 2.0));
    });
  });
}
