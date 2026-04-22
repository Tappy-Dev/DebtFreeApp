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

  Future<String?> getAppStartMonth() async {
    final rows = await _database.customSelect(
      'SELECT value FROM ${DriftSchema.appSettingsTable} WHERE key = ?',
      variables: [Variable<String>(_keyAppStartMonth)],
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.read<String>('value');
  }

  Future<void> setAppStartMonth(String monthKey) async {
    await _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.appSettingsTable} (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [_keyAppStartMonth, monthKey],
    );
  }

  Future<int> getFinancialMonthStartDay() async {
    final rows = await _database.customSelect(
      'SELECT value FROM ${DriftSchema.appSettingsTable} WHERE key = ?',
      variables: [Variable<String>(_keyFinancialMonthStartDay)],
    ).get();
    if (rows.isEmpty) return 1;
    return int.tryParse(rows.first.read<String>('value')) ?? 1;
  }

  Future<void> setFinancialMonthStartDay(int day) async {
    await _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.appSettingsTable} (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [_keyFinancialMonthStartDay, day.clamp(1, 28).toString()],
    );
  }

  Future<bool> getDeveloperModeEnabled() async {
    final rows = await _database.customSelect(
      'SELECT value FROM ${DriftSchema.appSettingsTable} WHERE key = ?',
      variables: [Variable<String>(_keyDeveloperModeEnabled)],
    ).get();
    if (rows.isEmpty) return false;
    return rows.first.read<String>('value') == 'true';
  }

  Future<void> setDeveloperModeEnabled(bool enabled) async {
    await _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.appSettingsTable} (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [_keyDeveloperModeEnabled, enabled ? 'true' : 'false'],
    );
  }

  Future<int> getDeveloperMonthOffset() async {
    final rows = await _database.customSelect(
      'SELECT value FROM ${DriftSchema.appSettingsTable} WHERE key = ?',
      variables: [Variable<String>(_keyDeveloperMonthOffset)],
    ).get();
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first.read<String>('value')) ?? 0;
  }

  Future<void> setDeveloperMonthOffset(int offset) async {
    await _database.customStatement(
      '''
      INSERT INTO ${DriftSchema.appSettingsTable} (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [_keyDeveloperMonthOffset, offset.toString()],
    );
  }
}
