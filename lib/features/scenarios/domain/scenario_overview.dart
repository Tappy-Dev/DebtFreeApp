class ScenarioOverview {
  const ScenarioOverview({
    required this.incomeIncrease,
    required this.expenseReduction,
    required this.extraPayment,
    required this.startMonth,
    required this.durationInMonths,
    required this.scheduleSummary,
    required this.scheduleWarningMessage,
    required this.hasActiveChanges,
    required this.activeChangeLabels,
    required this.remainingCash,
    required this.availableCashAfterAdjustments,
    required this.cashBufferAfterPlan,
    required this.isAffordable,
    required this.baselinePayoffDateLabel,
    required this.scenarioPayoffDateLabel,
    required this.baselineInterest,
    required this.scenarioInterest,
    required this.interestSaved,
    required this.monthsSaved,
    required this.planSummaryTitle,
    required this.planSummaryMessage,
    required this.guidanceTitle,
    required this.guidanceMessage,
  });

  final double incomeIncrease;
  final double expenseReduction;
  final double extraPayment;
  final int startMonth;
  final int? durationInMonths;
  final String scheduleSummary;
  final String? scheduleWarningMessage;
  final bool hasActiveChanges;
  final List<String> activeChangeLabels;
  final double remainingCash;
  final double availableCashAfterAdjustments;
  final double cashBufferAfterPlan;
  final bool isAffordable;
  final String baselinePayoffDateLabel;
  final String scenarioPayoffDateLabel;
  final double baselineInterest;
  final double scenarioInterest;
  final double interestSaved;
  final int monthsSaved;
  final String planSummaryTitle;
  final String planSummaryMessage;
  final String guidanceTitle;
  final String guidanceMessage;
}
