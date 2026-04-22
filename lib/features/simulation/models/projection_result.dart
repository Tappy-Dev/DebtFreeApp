class ProjectionMonth {
  const ProjectionMonth({
    required this.monthIndex,
    required this.month,
    required this.totalDebtRemaining,
    required this.totalInterest,
    required this.totalPayment,
    required this.remainingCash,
  });

  final int monthIndex;
  final DateTime month;
  final double totalDebtRemaining;
  final double totalInterest;
  final double totalPayment;
  final double remainingCash;
}

class ProjectionResult {
  const ProjectionResult({
    required this.monthlyBreakdown,
    required this.totalInterestPaid,
    required this.totalInterestSaved,
    required this.updatedPayoffDate,
    required this.monthsSaved,
  });

  final List<ProjectionMonth> monthlyBreakdown;
  final double totalInterestPaid;
  final double totalInterestSaved;
  final DateTime? updatedPayoffDate;
  final int monthsSaved;

  ProjectionResult copyWith({
    List<ProjectionMonth>? monthlyBreakdown,
    double? totalInterestPaid,
    double? totalInterestSaved,
    DateTime? updatedPayoffDate,
    int? monthsSaved,
  }) {
    return ProjectionResult(
      monthlyBreakdown: monthlyBreakdown ?? this.monthlyBreakdown,
      totalInterestPaid: totalInterestPaid ?? this.totalInterestPaid,
      totalInterestSaved: totalInterestSaved ?? this.totalInterestSaved,
      updatedPayoffDate: updatedPayoffDate ?? this.updatedPayoffDate,
      monthsSaved: monthsSaved ?? this.monthsSaved,
    );
  }
}
