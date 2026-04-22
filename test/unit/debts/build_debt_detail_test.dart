import 'package:debt_free_app/features/debts/domain/build_debt_detail.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BuildDebtDetail computes baseline payoff for a single debt', () {
    final detail = BuildDebtDetail()(
      debt: DebtAccount(
        id: 'card-1',
        name: 'Credit Card',
        balance: 1200,
        apr: 18,
        minimumPayment: 100,
      ),
    );

    expect(detail.debtName, 'Credit Card');
    expect(detail.balance, 1200);
    expect(detail.apr, 18);
    expect(detail.minimumPayment, 100);
    expect(detail.monthsToPayoff, greaterThan(0));
    expect(detail.totalInterest, greaterThan(0));
    expect(detail.chartData, isNotEmpty);
    expect(detail.payoffDateLabel, isNotEmpty);
  });

  test('BuildDebtDetail shows savings with extra payment', () {
    final detail = BuildDebtDetail()(
      debt: DebtAccount(
        id: 'card-1',
        name: 'Credit Card',
        balance: 1200,
        apr: 18,
        minimumPayment: 100,
      ),
      extraPayment: 100,
    );

    expect(detail.overpaymentMonthsToPayoff, lessThan(detail.monthsToPayoff));
    expect(
      detail.overpaymentTotalInterest,
      lessThan(detail.totalInterest),
    );
    expect(detail.overpaymentMonthsSaved, greaterThan(0));
    expect(detail.overpaymentInterestSaved, greaterThan(0));
    expect(detail.overpaymentChartData, isNotEmpty);
    expect(
      detail.overpaymentChartData.length,
      lessThan(detail.chartData.length),
    );
  });

  test('BuildDebtDetail handles zero APR debt', () {
    final detail = BuildDebtDetail()(
      debt: DebtAccount(
        id: 'loan-1',
        name: 'Interest-Free Loan',
        balance: 500,
        apr: 0,
        minimumPayment: 100,
      ),
    );

    expect(detail.totalInterest, 0);
    expect(detail.monthsToPayoff, 5);
    expect(detail.chartData, hasLength(6)); // initial + 5 months
  });

  test('BuildDebtDetail handles already paid off debt', () {
    final detail = BuildDebtDetail()(
      debt: DebtAccount(
        id: 'paid',
        name: 'Paid Off',
        balance: 0,
        apr: 15,
        minimumPayment: 100,
      ),
    );

    expect(detail.monthsToPayoff, 0);
    expect(detail.totalInterest, 0);
    expect(detail.payoffDateLabel, 'Already paid off');
  });

  test('BuildDebtDetail handles overpayment greater than balance', () {
    final detail = BuildDebtDetail()(
      debt: DebtAccount(
        id: 'small',
        name: 'Small Debt',
        balance: 50,
        apr: 10,
        minimumPayment: 25,
      ),
      extraPayment: 500,
    );

    expect(detail.overpaymentMonthsToPayoff, 1);
    expect(detail.overpaymentInterestSaved, greaterThanOrEqualTo(0));
  });
}
