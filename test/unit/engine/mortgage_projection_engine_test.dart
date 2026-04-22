import 'package:debt_free_app/features/simulation/engine/mortgage_projection_engine.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/simulation/models/salary_sacrifice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mortgage simulation calculates payoff over term', () {
    const mortgage = Mortgage(
      balance: 100000,
      annualRate: 4.0,
      monthlyPayment: 500,
      remainingTermMonths: 300,
    );

    final result = MortgageProjectionEngine().simulate(mortgage);

    expect(result.monthsToPayoff, greaterThan(0));
    expect(result.totalInterestPaid, greaterThan(0));
    expect(result.monthlyBreakdown, isNotEmpty);
    expect(result.monthlyBreakdown.last.balanceRemaining, 0);
  });

  test('overpayment reduces months and interest', () {
    const mortgage = Mortgage(
      balance: 100000,
      annualRate: 4.0,
      monthlyPayment: 500,
      remainingTermMonths: 300,
    );

    final comparison = MortgageProjectionEngine().compare(
      mortgage,
      overpaymentAmount: 200,
    );

    expect(comparison.monthsSaved, greaterThan(0));
    expect(comparison.interestSaved, greaterThan(0));
    expect(
      comparison.withOverpayment.monthsToPayoff,
      lessThan(comparison.baseline.monthsToPayoff),
    );
  });

  test('zero balance mortgage returns immediately', () {
    const mortgage = Mortgage(
      balance: 0,
      annualRate: 4.0,
      monthlyPayment: 500,
      remainingTermMonths: 300,
    );

    final result = MortgageProjectionEngine().simulate(mortgage);

    expect(result.monthsToPayoff, 0);
    expect(result.totalInterestPaid, 0);
    expect(result.monthlyBreakdown, isEmpty);
  });

  test('salary sacrifice basic rate saves 32%', () {
    // This tests the model, not the engine, but important to validate
    const sacrifice = SalarySacrifice(
      name: 'Pension',
      grossAmount: 200,
      taxBand: TaxBand.basicRate,
    );

    expect(sacrifice.taxSaving, closeTo(64, 0.01)); // 200 * 0.32
    expect(sacrifice.netCostToTakeHome, closeTo(136, 0.01)); // 200 - 64
  });

  test('salary sacrifice higher rate saves 42%', () {
    const sacrifice = SalarySacrifice(
      name: 'Pension',
      grossAmount: 500,
      taxBand: TaxBand.higherRate,
    );

    expect(sacrifice.taxSaving, closeTo(210, 0.01)); // 500 * 0.42
    expect(sacrifice.netCostToTakeHome, closeTo(290, 0.01)); // 500 - 210
  });
}
