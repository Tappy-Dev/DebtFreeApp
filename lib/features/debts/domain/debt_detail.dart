import 'package:debt_free_app/shared/widgets/timeline_chart.dart';

class DebtDetail {
  const DebtDetail({
    required this.debtName,
    required this.balance,
    required this.apr,
    required this.minimumPayment,
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

  final String debtName;
  final double balance;
  final double apr;
  final double minimumPayment;
  final String payoffDateLabel;
  final double totalInterest;
  final int monthsToPayoff;
  final List<TimelineDataPoint> chartData;
  final String overpaymentPayoffDateLabel;
  final double overpaymentTotalInterest;
  final int overpaymentMonthsToPayoff;
  final int overpaymentMonthsSaved;
  final double overpaymentInterestSaved;
  final List<TimelineDataPoint> overpaymentChartData;
}
