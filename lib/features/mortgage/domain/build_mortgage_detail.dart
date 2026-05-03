import 'package:debt_free_app/features/mortgage/domain/mortgage_detail.dart';
import 'package:debt_free_app/features/simulation/engine/mortgage_projection_engine.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/shared/widgets/timeline_chart.dart';
import 'package:intl/intl.dart';

class BuildMortgageDetail {
  MortgageDetail call({
    required Mortgage mortgage,
    double extraOverpayment = 0,
    DateTime? overpaymentStartDate,
    DateTime? referenceDate,
  }) {
    final engine = MortgageProjectionEngine();
    final startDate = referenceDate ?? DateTime.now();

    final baseline = engine.simulate(
      mortgage.copyWith(overpayment: 0),
      startDate: startDate,
    );
    final withOverpayment = engine.simulate(
      mortgage.copyWith(overpayment: 0),
      extraMonthlyOverpayment: extraOverpayment,
      overpaymentStartDate: overpaymentStartDate ?? mortgage.overpaymentStartDate,
      startDate: startDate,
    );

    final monthsSaved = baseline.monthsToPayoff - withOverpayment.monthsToPayoff;
    final interestSaved =
        baseline.totalInterestPaid - withOverpayment.totalInterestPaid;

    return MortgageDetail(
      name: mortgage.name,
      balance: mortgage.balance,
      annualRate: mortgage.annualRate,
      monthlyPayment: mortgage.monthlyPayment,
      remainingTermMonths: mortgage.remainingTermMonths,
      payoffDateLabel: _formatDate(baseline.payoffDate),
      totalInterest: baseline.totalInterestPaid,
      monthsToPayoff: baseline.monthsToPayoff,
      chartData: _buildChartData(baseline),
      overpaymentPayoffDateLabel: _formatDate(withOverpayment.payoffDate),
      overpaymentTotalInterest: withOverpayment.totalInterestPaid,
      overpaymentMonthsToPayoff: withOverpayment.monthsToPayoff,
      overpaymentMonthsSaved: monthsSaved < 0 ? 0 : monthsSaved,
      overpaymentInterestSaved: interestSaved < 0 ? 0 : interestSaved,
      overpaymentChartData: _buildChartData(withOverpayment),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat.yMMM().format(date);
  }

  List<TimelineDataPoint> _buildChartData(MortgageProjectionResult result) {
    final monthFormat = DateFormat('MMM yy');

    // Sample at most 24 points to keep the chart readable.
    final breakdown = result.monthlyBreakdown;
    if (breakdown.isEmpty) return const <TimelineDataPoint>[];

    final step = (breakdown.length / 24).ceil().clamp(1, breakdown.length);
    final points = <TimelineDataPoint>[];
    for (int i = 0; i < breakdown.length; i += step) {
      final m = breakdown[i];
      points.add(TimelineDataPoint(
        label: monthFormat.format(m.month),
        value: m.balanceRemaining,
      ));
    }
    // Always include the last point.
    if (points.isEmpty || points.last.value != breakdown.last.balanceRemaining) {
      points.add(TimelineDataPoint(
        label: monthFormat.format(breakdown.last.month),
        value: breakdown.last.balanceRemaining,
      ));
    }
    return points;
  }
}
