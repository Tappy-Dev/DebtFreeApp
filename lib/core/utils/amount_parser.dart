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
}
