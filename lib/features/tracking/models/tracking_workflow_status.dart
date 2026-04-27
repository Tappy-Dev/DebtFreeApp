import 'package:debt_free_app/core/utils/financial_month.dart';
import 'package:debt_free_app/features/tracking/models/monthly_budget_summary.dart';

enum TrackingWorkflowStage {
  gettingStarted,
  inProgress,
  readyToClose,
  overdue,
  closed,
}

class TrackingWorkflowStatus {
  const TrackingWorkflowStatus({
    required this.stage,
    required this.title,
    required this.message,
    required this.trackableStartedCount,
    required this.trackableTotalCount,
    required this.extraExpenseCount,
    required this.daysUntilPeriodEnd,
    required this.canCloseMonth,
  });

  final TrackingWorkflowStage stage;
  final String title;
  final String message;
  final int trackableStartedCount;
  final int trackableTotalCount;
  final int extraExpenseCount;
  final int daysUntilPeriodEnd;
  final bool canCloseMonth;

  bool get isActionable => stage != TrackingWorkflowStage.closed;

  /// Whether this status warrants showing a reminder card on the dashboard.
  /// Hide it when tracking is simply in progress and the user has already
  /// logged at least one item — no need to keep nudging them.
  bool get showOnDashboard =>
      stage != TrackingWorkflowStage.inProgress || trackableStartedCount == 0;
}

TrackingWorkflowStatus buildTrackingWorkflowStatus({
  required MonthlyBudgetSummary summary,
  required DateTime now,
  required int financialMonthStartDay,
  required bool isCurrentPeriod,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final periodEnd = FinancialMonth.endDate(
    summary.period.year,
    summary.period.month,
    financialMonthStartDay,
  );
  final normalizedEnd = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);
  final daysUntilEnd = normalizedEnd.difference(today).inDays;
  final trackableStartedCount = summary.trackableExpenseActuals
      .where((actual) => actual.actual > 0)
      .length;
  final trackableTotalCount = summary.trackableExpenseActuals.length;
  final extraExpenseCount = summary.extraExpenseActuals
      .where((actual) => actual.actual > 0)
      .length;

  if (summary.period.isClosed) {
    return TrackingWorkflowStatus(
      stage: TrackingWorkflowStage.closed,
      title: 'Month closed',
      message: 'This period is locked and up to date.',
      trackableStartedCount: trackableStartedCount,
      trackableTotalCount: trackableTotalCount,
      extraExpenseCount: extraExpenseCount,
      daysUntilPeriodEnd: daysUntilEnd,
      canCloseMonth: false,
    );
  }

  if (!isCurrentPeriod) {
    return TrackingWorkflowStatus(
      stage: TrackingWorkflowStage.overdue,
      title: 'Past month still open',
      message: 'Review this older period and close it so your monthly results stay locked.',
      trackableStartedCount: trackableStartedCount,
      trackableTotalCount: trackableTotalCount,
      extraExpenseCount: extraExpenseCount,
      daysUntilPeriodEnd: daysUntilEnd,
      canCloseMonth: true,
    );
  }

  if (!summary.hasAnyActuals) {
    return TrackingWorkflowStatus(
      stage: TrackingWorkflowStage.gettingStarted,
      title: 'Start tracking this month',
      message: daysUntilEnd <= 3
          ? 'This period ends soon. Add your first actuals now so you can review and close the month on time.'
          : 'No actuals recorded yet. Start with trackable spending, extra expenses, or extra income.',
      trackableStartedCount: trackableStartedCount,
      trackableTotalCount: trackableTotalCount,
      extraExpenseCount: extraExpenseCount,
      daysUntilPeriodEnd: daysUntilEnd,
      canCloseMonth: false,
    );
  }

  if (daysUntilEnd < 0) {
    return TrackingWorkflowStatus(
      stage: TrackingWorkflowStage.overdue,
      title: 'Close last month',
      message: 'This period has ended. Review the numbers and close the month to lock in your results.',
      trackableStartedCount: trackableStartedCount,
      trackableTotalCount: trackableTotalCount,
      extraExpenseCount: extraExpenseCount,
      daysUntilPeriodEnd: daysUntilEnd,
      canCloseMonth: true,
    );
  }

  if (daysUntilEnd <= 3) {
    return TrackingWorkflowStatus(
      stage: TrackingWorkflowStage.readyToClose,
      title: 'Wrap up this month',
      message: 'You are near the end of the period. Review missing actuals, check overspend, and close the month when ready.',
      trackableStartedCount: trackableStartedCount,
      trackableTotalCount: trackableTotalCount,
      extraExpenseCount: extraExpenseCount,
      daysUntilPeriodEnd: daysUntilEnd,
      canCloseMonth: true,
    );
  }

  return TrackingWorkflowStatus(
    stage: TrackingWorkflowStage.inProgress,
    title: 'Tracking in progress',
    message: 'You have logged $trackableStartedCount of $trackableTotalCount trackable categories and $extraExpenseCount extra expense${extraExpenseCount == 1 ? '' : 's'} so far.',
    trackableStartedCount: trackableStartedCount,
    trackableTotalCount: trackableTotalCount,
    extraExpenseCount: extraExpenseCount,
    daysUntilPeriodEnd: daysUntilEnd,
    canCloseMonth: false,
  );
}