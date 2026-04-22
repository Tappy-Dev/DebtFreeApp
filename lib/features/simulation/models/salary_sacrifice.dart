enum TaxBand {
  basicRate,
  higherRate,
}

class SalarySacrifice {
  const SalarySacrifice({
    this.id = '',
    required this.name,
    required this.grossAmount,
    required this.taxBand,
  });

  final String id;
  final String name;

  /// The gross monthly amount sacrificed from pre-tax salary.
  final double grossAmount;

  final TaxBand taxBand;

  /// Tax + NI saved by sacrificing this amount.
  /// Basic rate: 20% income tax + 12% employee NI = 32%
  /// Higher rate: 40% income tax + 2% employee NI = 42%
  double get taxSaving {
    switch (taxBand) {
      case TaxBand.basicRate:
        return grossAmount * 0.32;
      case TaxBand.higherRate:
        return grossAmount * 0.42;
    }
  }

  /// The actual reduction to take-home pay (less than gross due to tax relief).
  double get netCostToTakeHome => grossAmount - taxSaving;

  SalarySacrifice copyWith({
    String? id,
    String? name,
    double? grossAmount,
    TaxBand? taxBand,
  }) {
    return SalarySacrifice(
      id: id ?? this.id,
      name: name ?? this.name,
      grossAmount: grossAmount ?? this.grossAmount,
      taxBand: taxBand ?? this.taxBand,
    );
  }
}
