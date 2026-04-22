import 'package:debt_free_app/shared/widgets/timeline_chart.dart';

class MortgageDetail {
  const MortgageDetail({
    required this.name,
    required this.balance,
    required this.annualRate,
    required this.monthlyPayment,
    required this.remainingTermMonths,
    required this.payoffDateLabel,
    required this.totalInterest,
    required this.monthsToPayoff,
    required this.chartData,
    required this.overpaymentPayoffDateLabel,
    required this.overpaymentTotalInterest,
    required this.overpaymentMonthsToPayoff,
    required this.overpaymentMonthsSaved,
    required this.overpaymentInterestSaved,
    required this.overpaymentChartData,
  });

  final String name;
  final double balance;
  final double annualRate;
  final double monthlyPayment;
  final int remainingTermMonths;

  // Baseline (standard payments only)
  final String payoffDateLabel;
  final double totalInterest;
  final int monthsToPayoff;
  final List<TimelineDataPoint> chartData;

  // With overpayment
  final String overpaymentPayoffDateLabel;
  final double overpaymentTotalInterest;
  final int overpaymentMonthsToPayoff;
  final int overpaymentMonthsSaved;
  final double overpaymentInterestSaved;
  final List<TimelineDataPoint> overpaymentChartData;
}
