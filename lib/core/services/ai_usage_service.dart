import 'dart:convert';
import 'dart:math' as math;

import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/services/subscription_service.dart';
import 'package:flutter/foundation.dart';

class AiUsageService extends ChangeNotifier {
  AiUsageService._internal();

  static final AiUsageService instance = AiUsageService._internal();

  static const int freeTrialRequestLimit = 3;
  static const int premiumMonthlyRequestLimit = 150;

  static const String _keyUsageMonth = 'ai_usage_month';
  static const String _keyRequestCount = 'ai_usage_request_count';
  static const String _keyInputTokens = 'ai_usage_input_tokens';
  static const String _keyOutputTokens = 'ai_usage_output_tokens';
  static const String _keyRequestBreakdown = 'ai_usage_request_breakdown';
  static const String _keyTrialRequestCount = 'ai_trial_request_count';
  static const String _keyTrialInputTokens = 'ai_trial_input_tokens';
  static const String _keyTrialOutputTokens = 'ai_trial_output_tokens';
  static const String _keyTrialRequestBreakdown = 'ai_trial_request_breakdown';

  DriftFinancialDatabase? _database;
  AiUsageSnapshot _snapshot = const AiUsageSnapshot.empty();

  AiUsageSnapshot get snapshot => _snapshot;

  Future<void> initialize(DriftFinancialDatabase database) async {
    _database = database;
    await refresh();
  }

  Future<void> refresh() async {
    final database = _database;
    if (database == null) return;

    final sub = SubscriptionService.instance;
    final isPremium = sub.isSubscribed;
    final isTrialExpired = sub.isTrialExpired;

    if (isPremium) {
      // Monthly counter — reset when month changes
      final monthKey = _currentMonthKey();
      final storedMonth =
          await database.appSettingsDao.getStringSetting(_keyUsageMonth);
      if (storedMonth != monthKey) {
        await database.appSettingsDao.setStringSetting(_keyUsageMonth, monthKey);
        await database.appSettingsDao.setIntSetting(_keyRequestCount, 0);
        await database.appSettingsDao.setIntSetting(_keyInputTokens, 0);
        await database.appSettingsDao.setIntSetting(_keyOutputTokens, 0);
        await database.appSettingsDao.setStringSetting(
          _keyRequestBreakdown,
          jsonEncode(<String, int>{}),
        );
      }
      final requestCount =
          await database.appSettingsDao.getIntSetting(_keyRequestCount);
      final inputTokens =
          await database.appSettingsDao.getIntSetting(_keyInputTokens);
      final outputTokens =
          await database.appSettingsDao.getIntSetting(_keyOutputTokens);
      final breakdownJson =
          await database.appSettingsDao.getStringSetting(_keyRequestBreakdown);
      _snapshot = AiUsageSnapshot(
        monthKey: _currentMonthKey(),
        requestCount: requestCount,
        estimatedInputTokens: inputTokens,
        estimatedOutputTokens: outputTokens,
        requestBreakdown: _decodeBreakdown(breakdownJson),
        requestLimit: premiumMonthlyRequestLimit,
        isPremium: true,
        isTrialExpired: false,
      );
    } else {
      // Trial or expired — lifetime counter, never resets
      final trialCount =
          await database.appSettingsDao.getIntSetting(_keyTrialRequestCount);
      final inputTokens =
          await database.appSettingsDao.getIntSetting(_keyTrialInputTokens);
      final outputTokens =
          await database.appSettingsDao.getIntSetting(_keyTrialOutputTokens);
      final breakdownJson = await database.appSettingsDao
          .getStringSetting(_keyTrialRequestBreakdown);
      // If trial expired, limit = 0 so limitReached is always true
      final limit = isTrialExpired ? 0 : freeTrialRequestLimit;
      _snapshot = AiUsageSnapshot(
        monthKey: _currentMonthKey(),
        requestCount: trialCount,
        estimatedInputTokens: inputTokens,
        estimatedOutputTokens: outputTokens,
        requestBreakdown: _decodeBreakdown(breakdownJson),
        requestLimit: limit,
        isPremium: false,
        isTrialExpired: isTrialExpired,
      );
    }
    notifyListeners();
  }

  Future<AiUsageSnapshot> recordRequest({
    required AiRequestType requestType,
    required String systemPrompt,
    required String prompt,
    required String responseText,
  }) async {
    final database = _database;
    if (database == null) return _snapshot;

    await refresh();
    final nextRequestCount = _snapshot.requestCount + 1;
    final nextInputTokens = _snapshot.estimatedInputTokens +
        estimateTokens(systemPrompt) +
        estimateTokens(prompt);
    final nextOutputTokens =
        _snapshot.estimatedOutputTokens + estimateTokens(responseText);
    final nextBreakdown = Map<String, int>.from(_snapshot.requestBreakdown);
    nextBreakdown.update(requestType.storageKey, (value) => value + 1,
        ifAbsent: () => 1);

    final isPremium = _snapshot.isPremium;
    if (isPremium) {
      await database.appSettingsDao.setIntSetting(_keyRequestCount, nextRequestCount);
      await database.appSettingsDao.setIntSetting(_keyInputTokens, nextInputTokens);
      await database.appSettingsDao.setIntSetting(_keyOutputTokens, nextOutputTokens);
      await database.appSettingsDao.setStringSetting(
        _keyRequestBreakdown,
        jsonEncode(nextBreakdown),
      );
    } else {
      await database.appSettingsDao.setIntSetting(_keyTrialRequestCount, nextRequestCount);
      await database.appSettingsDao.setIntSetting(_keyTrialInputTokens, nextInputTokens);
      await database.appSettingsDao.setIntSetting(_keyTrialOutputTokens, nextOutputTokens);
      await database.appSettingsDao.setStringSetting(
        _keyTrialRequestBreakdown,
        jsonEncode(nextBreakdown),
      );
    }

    _snapshot = _snapshot.copyWith(
      requestCount: nextRequestCount,
      estimatedInputTokens: nextInputTokens,
      estimatedOutputTokens: nextOutputTokens,
      requestBreakdown: nextBreakdown,
    );
    notifyListeners();
    return _snapshot;
  }

  Future<AiUsageSnapshot> currentSnapshot() async {
    await refresh();
    return _snapshot;
  }

  Future<void> resetAllUsage() async {
    final database = _database;
    if (database == null) return;

    await database.appSettingsDao.setStringSetting(
      _keyUsageMonth,
      _currentMonthKey(),
    );
    await database.appSettingsDao.setIntSetting(_keyRequestCount, 0);
    await database.appSettingsDao.setIntSetting(_keyInputTokens, 0);
    await database.appSettingsDao.setIntSetting(_keyOutputTokens, 0);
    await database.appSettingsDao.setStringSetting(
      _keyRequestBreakdown,
      jsonEncode(<String, int>{}),
    );

    await database.appSettingsDao.setIntSetting(_keyTrialRequestCount, 0);
    await database.appSettingsDao.setIntSetting(_keyTrialInputTokens, 0);
    await database.appSettingsDao.setIntSetting(_keyTrialOutputTokens, 0);
    await database.appSettingsDao.setStringSetting(
      _keyTrialRequestBreakdown,
      jsonEncode(<String, int>{}),
    );

    await refresh();
  }

  Future<void> setTrialUsageExhausted() async {
    final database = _database;
    if (database == null) return;

    await database.appSettingsDao.setIntSetting(
      _keyTrialRequestCount,
      freeTrialRequestLimit,
    );
    await database.appSettingsDao.setStringSetting(
      _keyTrialRequestBreakdown,
      jsonEncode(<String, int>{'advisor': freeTrialRequestLimit}),
    );

    await refresh();
  }

  String usageLimitMessage() {
    if (_snapshot.isTrialExpired) {
      return 'Your free trial has ended. Subscribe to Premium to unlock AI insights — up to 150 prompts per month.';
    }
    if (!_snapshot.isPremium) {
      return 'You\'ve used all ${freeTrialRequestLimit} trial AI prompts. '
          'Subscribe to Premium for up to 150 AI insights per month.';
    }
    return 'Premium AI limit reached for ${_snapshot.monthLabel}. '
        'You have used ${_snapshot.requestCount}/${_snapshot.requestLimit} '
        'requests this month.';
  }

  static int estimateTokens(String text) {
    if (text.trim().isEmpty) return 0;
    return math.max(1, (text.length / 4).ceil());
  }

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static Map<String, int> _decodeBreakdown(String? jsonText) {
    if (jsonText == null || jsonText.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return <String, int>{};
      return decoded.map<String, int>((key, value) =>
          MapEntry<String, int>(key, value is int ? value : int.tryParse('$value') ?? 0));
    } catch (_) {
      return <String, int>{};
    }
  }
}

enum AiRequestType {
  scenario('scenario'),
  planner('planner'),
  advisor('advisor');

  const AiRequestType(this.storageKey);

  final String storageKey;
}

class AiUsageSnapshot {
  const AiUsageSnapshot({
    required this.monthKey,
    required this.requestCount,
    required this.estimatedInputTokens,
    required this.estimatedOutputTokens,
    required this.requestBreakdown,
    required this.requestLimit,
    required this.isPremium,
    required this.isTrialExpired,
  });

  const AiUsageSnapshot.empty()
      : monthKey = '',
        requestCount = 0,
        estimatedInputTokens = 0,
        estimatedOutputTokens = 0,
        requestBreakdown = const <String, int>{},
        requestLimit = AiUsageService.freeTrialRequestLimit,
        isPremium = false,
        isTrialExpired = false;

  final String monthKey;
  final int requestCount;
  final int estimatedInputTokens;
  final int estimatedOutputTokens;
  final Map<String, int> requestBreakdown;
  final int requestLimit;
  final bool isPremium;
  final bool isTrialExpired;

  bool get isTrialUser => !isPremium && !isTrialExpired;
  int get requestsRemaining => math.max(0, requestLimit - requestCount);
  bool get limitReached => isTrialExpired || requestCount >= requestLimit;

  String get monthLabel {
    if (monthKey.length != 7 || !monthKey.contains('-')) return 'this month';
    final parts = monthKey.split('-');
    const names = <String>[
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return 'this month';
    }
    return '${names[month]} $year';
  }

  AiUsageSnapshot copyWith({
    String? monthKey,
    int? requestCount,
    int? estimatedInputTokens,
    int? estimatedOutputTokens,
    Map<String, int>? requestBreakdown,
    int? requestLimit,
    bool? isPremium,
    bool? isTrialExpired,
  }) {
    return AiUsageSnapshot(
      monthKey: monthKey ?? this.monthKey,
      requestCount: requestCount ?? this.requestCount,
      estimatedInputTokens: estimatedInputTokens ?? this.estimatedInputTokens,
      estimatedOutputTokens: estimatedOutputTokens ?? this.estimatedOutputTokens,
      requestBreakdown: requestBreakdown ?? this.requestBreakdown,
      requestLimit: requestLimit ?? this.requestLimit,
      isPremium: isPremium ?? this.isPremium,
      isTrialExpired: isTrialExpired ?? this.isTrialExpired,
    );
  }
}
