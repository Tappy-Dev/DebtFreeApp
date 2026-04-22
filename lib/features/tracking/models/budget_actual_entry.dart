class BudgetActualEntry {
  const BudgetActualEntry({
    required this.id,
    required this.actualId,
    required this.reference,
    required this.date,
    required this.amount,
  });

  final String id;
  final String actualId;
  final String reference;
  final DateTime date;
  final double amount;

  BudgetActualEntry copyWith({
    String? reference,
    DateTime? date,
    double? amount,
  }) {
    return BudgetActualEntry(
      id: id,
      actualId: actualId,
      reference: reference ?? this.reference,
      date: date ?? this.date,
      amount: amount ?? this.amount,
    );
  }

  static String buildId(String actualId, int timestamp) =>
      '$actualId:entry:$timestamp';
}
