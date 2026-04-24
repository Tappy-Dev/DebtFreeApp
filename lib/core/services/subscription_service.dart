import 'dart:async';
import 'dart:io';

import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Manages subscription state, trial period, and Google Play purchases.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._internal();

  static final SubscriptionService instance = SubscriptionService._internal();

  static const String monthlyProductId = 'debt_free_premium_monthly';
  static const String annualProductId = 'debt_free_premium_annual';
  static const int trialDays = 3;

  static const String _keyTrialStart = 'trial_start_date';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  DriftFinancialDatabase? _database;

  bool _isAvailable = false;
  bool _subscribed = false;
  DateTime? _trialStartDate;
  ProductDetails? _monthlyProduct;
  ProductDetails? _annualProduct;
  bool _initialized = false;
  DeveloperAccessScenario _developerAccessScenario =
      DeveloperAccessScenario.live;
  bool _lastDeveloperModeEnabled = false;
  int _lastDeveloperMonthOffset = 0;

  bool get isEntitled => isSubscribed || isTrialActive;
  bool get isSubscribed {
    switch (_activeDeveloperScenario) {
      case DeveloperAccessScenario.live:
        return _subscribed;
      case DeveloperAccessScenario.premium:
        return true;
      case DeveloperAccessScenario.activeTrial:
      case DeveloperAccessScenario.trialEndingToday:
      case DeveloperAccessScenario.trialExpired:
        return false;
    }
  }

  bool get isTrialActive {
    switch (_activeDeveloperScenario) {
      case DeveloperAccessScenario.live:
        final startDate = _trialStartDate;
        if (startDate == null || _subscribed) return false;
        return _referenceNow.difference(startDate).inDays < trialDays;
      case DeveloperAccessScenario.activeTrial:
      case DeveloperAccessScenario.trialEndingToday:
        return true;
      case DeveloperAccessScenario.trialExpired:
      case DeveloperAccessScenario.premium:
        return false;
    }
  }

  bool get isTrialExpired {
    switch (_activeDeveloperScenario) {
      case DeveloperAccessScenario.live:
        final startDate = _trialStartDate;
        if (startDate == null || _subscribed) return false;
        return _referenceNow.difference(startDate).inDays >= trialDays;
      case DeveloperAccessScenario.trialExpired:
        return true;
      case DeveloperAccessScenario.activeTrial:
      case DeveloperAccessScenario.trialEndingToday:
      case DeveloperAccessScenario.premium:
        return false;
    }
  }

  bool get isStoreAvailable => _isAvailable;
  DateTime? get trialStartDate {
    switch (_activeDeveloperScenario) {
      case DeveloperAccessScenario.live:
        return _trialStartDate;
      case DeveloperAccessScenario.activeTrial:
        return _referenceNow.subtract(const Duration(days: 1));
      case DeveloperAccessScenario.trialEndingToday:
        return _referenceNow.subtract(Duration(days: trialDays - 1));
      case DeveloperAccessScenario.trialExpired:
        return _referenceNow.subtract(Duration(days: trialDays));
      case DeveloperAccessScenario.premium:
        return _trialStartDate;
    }
  }

  ProductDetails? get monthlyProduct => _monthlyProduct;
  ProductDetails? get annualProduct => _annualProduct;
  bool get initialized => _initialized;
  DeveloperAccessScenario get developerAccessScenario => _developerAccessScenario;

  int get trialDaysRemaining {
    if (isSubscribed) return 0;
    final startDate = trialStartDate;
    if (startDate == null) return trialDays;
    final elapsed = _referenceNow.difference(startDate).inDays;
    return (trialDays - elapsed).clamp(0, trialDays);
  }

  DateTime get _referenceNow => SessionFinancialRepository.instance.effectiveNow;

  DeveloperAccessScenario get _activeDeveloperScenario {
    if (!SessionFinancialRepository.instance.developerModeEnabled) {
      return DeveloperAccessScenario.live;
    }
    return _developerAccessScenario;
  }

  Future<void> initialize(DriftFinancialDatabase database) async {
    if (_initialized) return;
    _database = database;

    final repo = SessionFinancialRepository.instance;
    _lastDeveloperModeEnabled = repo.developerModeEnabled;
    _lastDeveloperMonthOffset = repo.developerMonthOffset;
    repo.addListener(_handleDeveloperContextChanged);

    final storedScenario =
        await database.appSettingsDao.getDeveloperAccessScenario();
    _developerAccessScenario = DeveloperAccessScenarioX.fromStorageValue(
      storedScenario,
    );

    // Load trial start date from DB
    final rows = await database.customSelect(
      'SELECT value FROM ${DriftSchema.appSettingsTable} WHERE key = ?',
      variables: [Variable<String>(_keyTrialStart)],
    ).get();

    if (rows.isNotEmpty) {
      final stored = rows.first.read<String>('value');
      _trialStartDate = DateTime.tryParse(stored);
    }

    // Start trial on first launch
    if (_trialStartDate == null) {
      _trialStartDate = _referenceNow;
      await database.customStatement(
        '''
        INSERT INTO ${DriftSchema.appSettingsTable} (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
        ''',
        [_keyTrialStart, _trialStartDate!.toIso8601String()],
      );
    }

    // Initialize store (only on Android/iOS)
    if (Platform.isAndroid || Platform.isIOS) {
      _isAvailable = await _iap.isAvailable();
      if (_isAvailable) {
        _purchaseSubscription = _iap.purchaseStream.listen(
          _onPurchaseUpdate,
          onError: (error) {
            debugPrint('Purchase stream error: $error');
          },
        );

        // Load product details
        final response = await _iap.queryProductDetails(
          {monthlyProductId, annualProductId},
        );
        for (final p in response.productDetails) {
          if (p.id == monthlyProductId) _monthlyProduct = p;
          if (p.id == annualProductId) _annualProduct = p;
        }

        // Check existing purchases
        await _iap.restorePurchases();
      }
    } else {
      // On desktop (Windows/macOS/Linux), store is unavailable.
      // Bypass paywall for development builds.
      _isAvailable = false;
      _subscribed = true; // Desktop always entitled
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> setDeveloperAccessScenario(
    DeveloperAccessScenario scenario,
  ) async {
    _developerAccessScenario = scenario;
    await _database?.appSettingsDao
        .setDeveloperAccessScenario(scenario.storageValue);
    notifyListeners();
  }

  void _handleDeveloperContextChanged() {
    final repo = SessionFinancialRepository.instance;
    final changed = _lastDeveloperModeEnabled != repo.developerModeEnabled ||
        _lastDeveloperMonthOffset != repo.developerMonthOffset;
    if (!changed) return;
    _lastDeveloperModeEnabled = repo.developerModeEnabled;
    _lastDeveloperMonthOffset = repo.developerMonthOffset;
    notifyListeners();
  }

  static const _productIds = {monthlyProductId, annualProductId};

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (_productIds.contains(purchase.productID)) {
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            _subscribed = true;
            notifyListeners();
            if (purchase.pendingCompletePurchase) {
              _iap.completePurchase(purchase);
            }
            break;
          case PurchaseStatus.error:
            debugPrint('Purchase error: ${purchase.error}');
            break;
          case PurchaseStatus.canceled:
            break;
          case PurchaseStatus.pending:
            break;
        }
      }
    }
  }

  Future<bool> purchase({bool annual = false}) async {
    final product = annual ? _annualProduct : _monthlyProduct;
    if (product == null || !_isAvailable) return false;
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    if (_isAvailable) {
      await _iap.restorePurchases();
    }
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    SessionFinancialRepository.instance.removeListener(_handleDeveloperContextChanged);
    super.dispose();
  }
}

enum DeveloperAccessScenario {
  live('live'),
  activeTrial('active-trial'),
  trialEndingToday('trial-ending-today'),
  trialExpired('trial-expired'),
  premium('premium');

  const DeveloperAccessScenario(this.storageValue);

  final String storageValue;
}

extension DeveloperAccessScenarioX on DeveloperAccessScenario {
  static DeveloperAccessScenario fromStorageValue(String? value) {
    for (final scenario in DeveloperAccessScenario.values) {
      if (scenario.storageValue == value) return scenario;
    }
    return DeveloperAccessScenario.live;
  }
}
