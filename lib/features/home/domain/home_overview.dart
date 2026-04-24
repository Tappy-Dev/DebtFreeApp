import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/shared/widgets/timeline_chart.dart';

class MonthForecast {
  const MonthForecast({
    required this.label,
    required this.cashLeft,
    required this.debtInterest,
    required this.debtBalance,
    this.mortgageInterest,
  });

  final String label;
  final double cashLeft;
  final double debtInterest;
  final double debtBalance;
  final double? mortgageInterest;
}

class HomeOverview {
  const HomeOverview({
    required this.totalDebt,
    required this.debtFreeDateLabel,
    required this.interestProjection,
    required this.interestSaved,
    required this.monthsSaved,
    required this.nextMonthBalance,
    required this.debtChangeFromPreviousMonth,
    required this.remainingCash,
    required this.availableCashAfterScenario,
    required this.incomeIncrease,
    required this.expenseReduction,
    required this.extraPayment,
    required this.monthlyFlexibilityGain,
    required this.planSummaryTitle,
    required this.planSummaryMessage,
    required this.scheduleSummary,
    required this.scheduleWarningMessage,
    required this.recommendationTitle,
    required this.recommendationMessage,
    required this.debtChartData,
    this.mortgage,
    this.mortgageCount = 0,
    this.mortgagePayoffLabel,
    this.mortgageTotalInterest,
    this.monthlyDebtInterest = 0,
    this.monthlyMortgageInterest,
    this.monthlyForecast = const [],
  });

  final double totalDebt;
  final String debtFreeDateLabel;
  final double interestProjection;
  final double interestSaved;
  final int monthsSaved;
  final double? nextMonthBalance;
  final double debtChangeFromPreviousMonth;
  final double remainingCash;
  final double availableCashAfterScenario;
  final double incomeIncrease;
  final double expenseReduction;
  final double extraPayment;
  final double monthlyFlexibilityGain;
  final String planSummaryTitle;
  final String planSummaryMessage;
  final String scheduleSummary;
  final String? scheduleWarningMessage;
  final String recommendationTitle;
  final String recommendationMessage;
  final List<TimelineDataPoint> debtChartData;
  final Mortgage? mortgage;
  final int mortgageCount;
  final String? mortgagePayoffLabel;
  final double? mortgageTotalInterest;
  final double monthlyDebtInterest;
  final double? monthlyMortgageInterest;
  final List<MonthForecast> monthlyForecast;
}
