import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:drift/drift.dart';

class AppSettingsDao {
  const AppSettingsDao(this._database);

  final DriftFinancialDatabase _database;

  static const String _keyAppStartMonth = 'app_start_month';
  static const String _keyFinancialMonthStartDay = 'financial_month_start_day';
  static const String _keyDeveloperModeEnabled = 'developer_mode_enabled';
  static const String _keyDeveloperMonthOffset = 'developer_month_offset';
  static const String _keyDeveloperAccessScenario = 'developer_access_scenario';

  Future<String?> getStringSetting(String key) async {
    final rows = await _database.customSelect(
      'SELECT value FROM ${DriftSchema.appSettingsTable} WHERE key = ?',
      variables: [Variable<String>(key)],
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.read<String>('value');
  }

  Future<void> setStringSetting(String key, String value) async {
    await _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.appSettingsTable} (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [key, value],
    );
  }

  Future<int> getIntSetting(String key, {int defaultValue = 0}) async {
    final value = await getStringSetting(key);
    return int.tryParse(value ?? '') ?? defaultValue;
  }

  Future<void> setIntSetting(String key, int value) async {
    await setStringSetting(key, value.toString());
  }

  Future<String?> getAppStartMonth() async {
    return getStringSetting(_keyAppStartMonth);
  }

  Future<void> setAppStartMonth(String monthKey) async {
    await setStringSetting(_keyAppStartMonth, monthKey);
  }

  Future<int> getFinancialMonthStartDay() async {
    return getIntSetting(_keyFinancialMonthStartDay, defaultValue: 1);
  }

  Future<void> setFinancialMonthStartDay(int day) async {
    await setIntSetting(_keyFinancialMonthStartDay, day.clamp(1, 28));
  }

  Future<bool> getDeveloperModeEnabled() async {
    return (await getStringSetting(_keyDeveloperModeEnabled)) == 'true';
  }

  Future<void> setDeveloperModeEnabled(bool enabled) async {
    await setStringSetting(_keyDeveloperModeEnabled, enabled ? 'true' : 'false');
  }

  Future<int> getDeveloperMonthOffset() async {
    return getIntSetting(_keyDeveloperMonthOffset);
  }

  Future<void> setDeveloperMonthOffset(int offset) async {
    await setIntSetting(_keyDeveloperMonthOffset, offset);
  }

  Future<String?> getDeveloperAccessScenario() async {
    return getStringSetting(_keyDeveloperAccessScenario);
  }

  Future<void> setDeveloperAccessScenario(String scenario) async {
    await setStringSetting(_keyDeveloperAccessScenario, scenario);
  }
}
