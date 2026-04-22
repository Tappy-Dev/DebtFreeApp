import 'package:debt_free_app/features/simulation/models/salary_sacrifice.dart';
import 'package:drift/drift.dart';

class SalarySacrificeRecord {
  const SalarySacrificeRecord({
    required this.id,
    required this.name,
    required this.grossAmount,
    required this.taxBandName,
  });

  factory SalarySacrificeRecord.fromSacrifice(SalarySacrifice sacrifice) {
    return SalarySacrificeRecord(
      id: sacrifice.id,
      name: sacrifice.name,
      grossAmount: sacrifice.grossAmount,
      taxBandName: sacrifice.taxBand.name,
    );
  }

  factory SalarySacrificeRecord.fromRow(QueryRow row) {
    return SalarySacrificeRecord(
      id: row.read<String>(idColumn),
      name: row.read<String>(nameColumn),
      grossAmount: row.read<double>(grossAmountColumn),
      taxBandName: row.read<String>(taxBandColumn),
    );
  }

  static const String idColumn = 'id';
  static const String nameColumn = 'name';
  static const String grossAmountColumn = 'gross_amount';
  static const String taxBandColumn = 'tax_band';

  static const String selectColumns =
      '$idColumn, $nameColumn, $grossAmountColumn, $taxBandColumn';

  static const String insertColumns =
      '($idColumn, $nameColumn, $grossAmountColumn, $taxBandColumn)';

  final String id;
  final String name;
  final double grossAmount;
  final String taxBandName;

  SalarySacrifice toSalarySacrifice() {
    return SalarySacrifice(
      id: id,
      name: name,
      grossAmount: grossAmount,
      taxBand: TaxBand.values.firstWhere(
        (TaxBand band) => band.name == taxBandName,
        orElse: () => TaxBand.basicRate,
      ),
    );
  }

  List<Object?> toSqlVariables() {
    return <Object?>[
      id,
      name,
      grossAmount,
      taxBandName,
    ];
  }
}
