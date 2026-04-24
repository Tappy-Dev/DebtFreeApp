class AmountParser {
  static double? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }

    final normalized = raw
        .trim()
        .replaceAll(',', '')
        .replaceAll('\u00A3', '')
        .replaceAll('%', '')
        .replaceAll(RegExp(r'\s+'), '');

    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  static bool hasMaxDecimalPlaces(String? raw, int maxPlaces) {
    if (raw == null) {
      return true;
    }

    final normalized = raw
        .trim()
        .replaceAll(',', '')
        .replaceAll('\u00A3', '')
        .replaceAll('%', '')
        .replaceAll(RegExp(r'\s+'), '');

    if (normalized.isEmpty) {
      return true;
    }

    final dotIndex = normalized.indexOf('.');
    if (dotIndex < 0) {
      return true;
    }

    final decimals = normalized.length - dotIndex - 1;
    return decimals <= maxPlaces;
  }
}
