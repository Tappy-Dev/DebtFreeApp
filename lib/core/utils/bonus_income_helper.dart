import 'package:debt_free_app/features/simulation/models/income_source.dart';

const String bonusParentMarker = '__from__';

bool isBonusIncome(IncomeSource source) {
  return source.name.toLowerCase().startsWith('bonus (');
}

String? parentIncomeIdFromBonusId(String bonusIncomeId) {
  final index = bonusIncomeId.lastIndexOf(bonusParentMarker);
  if (index == -1) {
    return null;
  }

  final parentId = bonusIncomeId.substring(index + bonusParentMarker.length);
  if (parentId.isEmpty) {
    return null;
  }
  return parentId;
}

String? parentIncomeNameFromBonusName(String bonusName) {
  final start = bonusName.indexOf('(');
  final end = bonusName.lastIndexOf(')');
  if (start == -1 || end == -1 || end <= start + 1) {
    return null;
  }
  final parentName = bonusName.substring(start + 1, end).trim();
  return parentName.isEmpty ? null : parentName;
}

double resolvedMonthlyIncomeNet(
  IncomeSource source,
  List<IncomeSource> allIncomeSources,
) {
  if (!isBonusIncome(source)) {
    return source.monthlyNetAfterSacrifice();
  }

  final parentId = parentIncomeIdFromBonusId(source.id);
  IncomeSource? parent;
  if (parentId != null) {
    final matching = allIncomeSources.where((item) => item.id == parentId);
    if (matching.isNotEmpty) {
      parent = matching.first;
    }
  }
  if (parent == null) {
    final parentName = parentIncomeNameFromBonusName(source.name);
    if (parentName != null) {
      final matchingByName = allIncomeSources.where(
        (item) => !isBonusIncome(item) && item.name == parentName,
      );
      if (matchingByName.isNotEmpty) {
        parent = matchingByName.first;
      }
    }
  }
  if (parent == null) {
    return source.monthlyNetAfterSacrifice();
  }

  final bonusGross = source.annualGross / 12;
  if (bonusGross <= 0) {
    return 0;
  }

  final baseNet = parent.monthlyNetAfterSacrifice();
  final withBonusNet = parent
      .copyWith(annualGross: parent.annualGross + (bonusGross * 12))
      .monthlyNetAfterSacrifice();

  final bonusNet = withBonusNet - baseNet;
  if (bonusNet <= 0) {
    return 0;
  }
  return bonusNet;
}