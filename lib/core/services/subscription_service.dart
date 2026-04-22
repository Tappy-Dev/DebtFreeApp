import 'dart:async';
import 'dart:io';

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

  bool _isAvailable = false;
  bool _subscribed = false;
  bool _trialActive = false;
  bool _trialExpired = false;
  DateTime? _trialStartDate;
  ProductDetails? _monthlyProduct;
  ProductDetails? _annualProduct;
  bool _initialized = false;

  bool get isEntitled => _subscribed || _trialActive;
  bool get isSubscribed => _subscribed;
  bool get isTrialActive => _trialActive;
  bool get isTrialExpired => _trialExpired;
  bool get isStoreAvailable => _isAvailable;
  DateTime? get trialStartDate => _trialStartDate;
  ProductDetails? get monthlyProduct => _monthlyProduct;
  ProductDetails? get annualProduct => _annualProduct;
  bool get initialized => _initialized;

  int get trialDaysRemaining {
    if (_trialStartDate == null) return trialDays;
    final elapsed = DateTime.now().difference(_trialStartDate!).inDays;
    return (trialDays - elapsed).clamp(0, trialDays);
  }

  Future<void> initialize(DriftFinancialDatabase database) async {
    if (_initialized) return;

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
      _trialStartDate = DateTime.now();
      await database.customStatement(
        '''
        INSERT INTO ${DriftSchema.appSettingsTable} (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
        ''',
        [_keyTrialStart, _trialStartDate!.toIso8601String()],
      );
    }

    _updateTrialStatus();

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

  void _updateTrialStatus() {
    if (_trialStartDate == null) {
      _trialActive = false;
      _trialExpired = false;
      return;
    }
    final elapsed = DateTime.now().difference(_trialStartDate!).inDays;
    _trialActive = elapsed < trialDays;
    _trialExpired = elapsed >= trialDays && !_subscribed;
  }

  static const _productIds = {monthlyProductId, annualProductId};

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (_productIds.contains(purchase.productID)) {
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            _subscribed = true;
            _updateTrialStatus();
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
    super.dispose();
  }
}
