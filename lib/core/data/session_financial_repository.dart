import 'dart:async';

import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/core/sample/demo_data.dart';
import 'package:debt_free_app/core/utils/financial_month.dart';
import 'package:debt_free_app/features/planner/models/planner_event.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual.dart';
import 'package:debt_free_app/features/tracking/models/budget_actual_entry.dart';
import 'package:debt_free_app/features/tracking/models/budget_period.dart';
import 'package:flutter/foundation.dart';

class SessionFinancialRepository extends ChangeNotifier
    implements FinancialRepository {
  SessionFinancialRepository._internal({
    DriftFinancialDatabase? database,
    bool seedDemoData = false,
  })  : _database = database ?? DriftFinancialDatabase(),
        _seedDemoData = seedDemoData;

  factory SessionFinancialRepository.test({
    required DriftFinancialDatabase database,
    bool seedDemoData = false,
  }) {
    return SessionFinancialRepository._internal(
      database: database,
      seedDemoData: seedDemoData,
    );
  }

  static final SessionFinancialRepository instance =
      SessionFinancialRepository._internal();

  final DriftFinancialDatabase _database;
  final bool _seedDemoData;

  DriftFinancialDatabase get database => _database;

  final List<DebtAccount> _debts = <DebtAccount>[];
  final Map<String, List<IncomeSource>> _incomeByMonth =
      <String, List<IncomeSource>>{};
  final Map<String, List<Expense>> _expensesByMonth =
      <String, List<Expense>>{};
  final Map<String, List<Expense>> _billsByMonth = <String, List<Expense>>{};
  String _activeBudgetMonth = _currentMonthKey();
  final List<ScenarioChange> _scenarioChanges = <ScenarioChange>[];
  final List<Mortgage> _mortgages = <Mortgage>[];
  final List<PlannerEvent> _plannerEvents = <PlannerEvent>[];
  String? _appStartMonth;
  int _financialMonthStartDay = 1;
  bool _developerModeEnabled = false;
  int _developerMonthOffset = 0;
  final Set<String> _closedMonthKeys = <String>{};
  Future<void> _pendingWrite = Future<void>.value();

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String currentMonthKeyWithStartDay() {
    return FinancialMonth.monthKeyFor(effectiveNow, _financialMonthStartDay);
  }

  DateTime get effectiveNow {
    if (!_developerModeEnabled || _developerMonthOffset == 0) {
      return DateTime.now();
    }
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month + _developerMonthOffset,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  bool get developerModeEnabled => _developerModeEnabled;

  int get developerMonthOffset => _developerMonthOffset;

  Future<void> setDeveloperModeEnabled(bool enabled) async {
    _developerModeEnabled = enabled;
    if (!enabled) {
      _developerMonthOffset = 0;
      await _database.appSettingsDao.setDeveloperMonthOffset(0);
    }
    _activeBudgetMonth = currentMonthKeyWithStartDay();
    notifyListeners();
    await _database.appSettingsDao.setDeveloperModeEnabled(enabled);
  }

  Future<void> setDeveloperMonthOffset(int offset) async {
    _developerMonthOffset = offset;
    _activeBudgetMonth = currentMonthKeyWithStartDay();
    notifyListeners();
    await _database.appSettingsDao.setDeveloperMonthOffset(offset);
  }

  int get financialMonthStartDay => _financialMonthStartDay;

  Future<void> setFinancialMonthStartDay(int day) async {
    _financialMonthStartDay = day.clamp(1, 28);
    _activeBudgetMonth = currentMonthKeyWithStartDay();
    notifyListeners();
    await _database.appSettingsDao.setFinancialMonthStartDay(_financialMonthStartDay);
  }

  // ── Budget month navigation ──

  String get activeBudgetMonth => _activeBudgetMonth;

  bool isMonthClosed(String monthKey) => _closedMonthKeys.contains(monthKey);

  void setActiveBudgetMonth(String monthKey) {
    _activeBudgetMonth = monthKey;
    notifyListeners();
  }

  List<String> get availableBudgetMonths {
    final keys = <String>{
      ..._incomeByMonth.keys,
      ..._expensesByMonth.keys,
      ..._billsByMonth.keys,
    }.toList()
      ..sort();
    return keys;
  }

  List<IncomeSource> getIncomeSourcesForMonth(String monthKey) {
    return List<IncomeSource>.unmodifiable(
      _incomeByMonth[monthKey] ?? const <IncomeSource>[],
    );
  }

  List<Expense> getExpensesForMonth(String monthKey) {
    return List<Expense>.unmodifiable(
      _expensesByMonth[monthKey] ?? const <Expense>[],
    );
  }

  List<Expense> getBillsForMonth(String monthKey) {
    return List<Expense>.unmodifiable(
      _billsByMonth[monthKey] ?? const <Expense>[],
    );
  }

  // ── App settings ──

  @override
  String? get appStartMonth => _appStartMonth;

  @override
  Future<void> setAppStartMonth(String monthKey) async {
    _appStartMonth = monthKey.isEmpty ? null : monthKey;
    notifyListeners();
    if (monthKey.isEmpty) {
      // Store empty string to indicate "cleared"
      await _database.appSettingsDao.setAppStartMonth('');
    } else {
      await _database.appSettingsDao.setAppStartMonth(monthKey);
    }
  }

  Future<void> copyBudgetMonth(
    String fromMonthKey,
    String toMonthKey,
  ) async {
    final income = getIncomeSourcesForMonth(fromMonthKey);
    final expenses = getExpensesForMonth(fromMonthKey);
    final bills = getBillsForMonth(fromMonthKey);

    for (final item in income) {
      final newId = _monthlyId('income', item.name, toMonthKey);
      saveIncomeSource(item.copyWith(id: newId, monthKey: toMonthKey));
    }
    for (final item in expenses) {
      final newId = _monthlyId('expense', item.name, toMonthKey);
      saveExpense(item.copyWith(id: newId, monthKey: toMonthKey));
    }
    for (final item in bills) {
      final newId = _monthlyId('bill', item.name, toMonthKey);
      saveBill(item.copyWith(id: newId, monthKey: toMonthKey));
    }
    _activeBudgetMonth = toMonthKey;
    notifyListeners();
  }

  static String _monthlyId(String type, String name, String monthKey) {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty
        ? '$monthKey-$type-${DateTime.now().millisecondsSinceEpoch}'
        : '$monthKey-$type-$normalized';
  }

  Future<void> clearBudgetMonth(String monthKey) async {
    await waitForPendingWrites();
    await _database.budgetItemsDao.clearMonth(monthKey);
    // Remove in-memory items for this month
    _incomeByMonth.remove(monthKey);
    _expensesByMonth.remove(monthKey);
    _billsByMonth.remove(monthKey);
    notifyListeners();
  }

  Future<void> resetAll() async {
    await waitForPendingWrites();
    await _database.customStatement('DELETE FROM debts');
    await _database.customStatement('DELETE FROM debt_extra_payments');
    await _database.customStatement('DELETE FROM debt_extra_payments');
    await _database.customStatement('DELETE FROM income_sources');
    await _database.customStatement('DELETE FROM expenses');
    await _database.customStatement('DELETE FROM bills');
    await _database.customStatement('DELETE FROM scenario_changes');
    await _database.customStatement('DELETE FROM mortgage');
    await _database.customStatement('DELETE FROM budget_periods');
    await _database.customStatement('DELETE FROM budget_actuals');
    await _database.customStatement('DELETE FROM budget_actual_entries');
    await _database.customStatement('DELETE FROM planner_events');
    await _database.customStatement('DELETE FROM app_settings');

    _debts.clear();
    _incomeByMonth.clear();
    _expensesByMonth.clear();
    _billsByMonth.clear();
    _scenarioChanges.clear();
    _mortgages.clear();
    _plannerEvents.clear();
    _closedMonthKeys.clear();
    _appStartMonth = null;
    _financialMonthStartDay = 1;
    _developerModeEnabled = false;
    _developerMonthOffset = 0;
    _activeBudgetMonth = _currentMonthKey();

    notifyListeners();
  }

  Future<void> hydrate() async {
    await waitForPendingWrites();

    final loadedDebts = await _database.debtsDao.loadAll();
    final loadedIncome = await _database.budgetItemsDao.loadIncomeSources();
    final loadedExpenses = await _database.budgetItemsDao.loadExpenses();
    final loadedBills = await _database.budgetItemsDao.loadBills();
    final loadedScenarioChanges = await _database.scenarioChangesDao.loadAll();

    final loadedMortgages = await _database.mortgageDao.loadAll();

    final loadedPlannerEvents = await _database.plannerEventsDao.loadAll();
    final loadedAppStartMonth = await _database.appSettingsDao.getAppStartMonth();
    final loadedFinancialMonthStartDay =
        await _database.appSettingsDao.getFinancialMonthStartDay();
    final loadedDeveloperModeEnabled =
      await _database.appSettingsDao.getDeveloperModeEnabled();
    final loadedDeveloperMonthOffset =
      await _database.appSettingsDao.getDeveloperMonthOffset();

    // Apply financial month setting early so currentMonthKeyWithStartDay()
    // is correct for the rest of hydrate().
    _financialMonthStartDay = loadedFinancialMonthStartDay;
    _appStartMonth = (loadedAppStartMonth?.isEmpty ?? true)
        ? null
        : loadedAppStartMonth;
    _developerModeEnabled = loadedDeveloperModeEnabled;
    _developerMonthOffset = loadedDeveloperModeEnabled
      ? loadedDeveloperMonthOffset
      : 0;

    if (_seedDemoData &&
        loadedDebts.isEmpty &&
        loadedIncome.isEmpty &&
        loadedExpenses.isEmpty &&
        loadedScenarioChanges.isEmpty) {
      _debts
        ..clear()
        ..addAll(DemoData.debts.map((DebtAccount debt) => debt.copy()));
      final currentMonth = _currentMonthKey();
      _incomeByMonth[currentMonth] = DemoData.income
          .map((i) => i.copyWith(monthKey: currentMonth))
          .toList();
      _expensesByMonth[currentMonth] = DemoData.expenses
          .map((e) => e.copyWith(monthKey: currentMonth))
          .toList();
      _billsByMonth[currentMonth] = DemoData.bills
          .map((b) => b.copyWith(monthKey: currentMonth))
          .toList();
      _activeBudgetMonth = currentMonth;
      _scenarioChanges
        ..clear()
        ..addAll(DemoData.extraPaymentScenario);
      _mortgages
        ..clear()
        ..add(DemoData.mortgage);
      await _persistAll();
      notifyListeners();
      return;
    }

    // Group loaded items by month_key; migrate legacy items (month_key='')
    // to the current month.
    final currentMonth = currentMonthKeyWithStartDay();
    _incomeByMonth.clear();
    _expensesByMonth.clear();
    _billsByMonth.clear();

    for (final item in loadedIncome) {
      final key = item.monthKey.isEmpty ? currentMonth : item.monthKey;
      _incomeByMonth.putIfAbsent(key, () => []).add(
            item.monthKey.isEmpty ? item.copyWith(monthKey: key) : item,
          );
      if (item.monthKey.isEmpty) {
        _scheduleWrite(() => _database.budgetItemsDao
            .upsertIncomeSource(item.copyWith(monthKey: key)));
      }
    }
    for (final item in loadedExpenses) {
      final key = item.monthKey.isEmpty ? currentMonth : item.monthKey;
      _expensesByMonth.putIfAbsent(key, () => []).add(
            item.monthKey.isEmpty ? item.copyWith(monthKey: key) : item,
          );
      if (item.monthKey.isEmpty) {
        _scheduleWrite(() => _database.budgetItemsDao
            .upsertExpense(item.copyWith(monthKey: key)));
      }
    }
    for (final item in loadedBills) {
      final key = item.monthKey.isEmpty ? currentMonth : item.monthKey;
      _billsByMonth.putIfAbsent(key, () => []).add(
            item.monthKey.isEmpty ? item.copyWith(monthKey: key) : item,
          );
      if (item.monthKey.isEmpty) {
        _scheduleWrite(
            () => _database.budgetItemsDao.upsertBill(item.copyWith(monthKey: key)));
      }
    }

    // Default to current month (falls back to latest available month if empty)
    final allMonths = availableBudgetMonths;
    if (allMonths.isNotEmpty && !_incomeByMonth.containsKey(currentMonth) &&
        !_expensesByMonth.containsKey(currentMonth) &&
        !_billsByMonth.containsKey(currentMonth)) {
      _activeBudgetMonth = allMonths.last;
    } else {
      _activeBudgetMonth = currentMonth;
    }

    _debts
      ..clear()
      ..addAll(loadedDebts.map((DebtAccount debt) => debt.copy()));
    _scenarioChanges
      ..clear()
      ..addAll(loadedScenarioChanges);
    _mortgages
      ..clear()
      ..addAll(loadedMortgages);
    _plannerEvents
      ..clear()
      ..addAll(loadedPlannerEvents);

    // Cache closed month keys
    _closedMonthKeys.clear();
    final allPeriods = await _database.budgetPeriodsDao.loadAllPeriods();
    for (final p in allPeriods) {
      if (p.isClosed) _closedMonthKeys.add(p.id);
    }

    notifyListeners();
  }

  @override
  List<DebtAccount> getDebts() {
    return _debts.map((DebtAccount debt) => debt.copy()).toList(growable: false);
  }

  @override
  List<IncomeSource> getIncomeSources() {
    return List<IncomeSource>.unmodifiable(
      _incomeByMonth[_activeBudgetMonth] ?? const <IncomeSource>[],
    );
  }

  @override
  List<Expense> getExpenses() {
    return List<Expense>.unmodifiable(
      _expensesByMonth[_activeBudgetMonth] ?? const <Expense>[],
    );
  }

  @override
  List<ScenarioChange> getScenarioChanges() {
    return List<ScenarioChange>.unmodifiable(_scenarioChanges);
  }

  @override
  void saveDebt(DebtAccount debtAccount) {
    final index =
        _debts.indexWhere((DebtAccount debt) => debt.id == debtAccount.id);
    if (index == -1) {
      _debts.add(debtAccount.copy());
      notifyListeners();
      _scheduleWrite(() => _database.debtsDao.upsert(debtAccount.copy()));
      return;
    }

    _debts[index] = debtAccount.copy();
    notifyListeners();
    _scheduleWrite(() => _database.debtsDao.upsert(debtAccount.copy()));
  }

  @override
  void deleteDebt(String debtId) {
    _debts.removeWhere((DebtAccount debt) => debt.id == debtId);
    notifyListeners();
   

  void saveDebtExtraPayment(DebtExtraPayment extra) {
    final debtIndex = _debts.indexWhere((d) => d.id == extra.debtId);
    if (debtIndex == -1) return;
    final debt = _debts[debtIndex];
    final extras = List<DebtExtraPayment>.from(debt.extraPayments);
    final eIdx = extras.indexWhere((e) => e.id == extra.id);
    if (eIdx == -1) {
      extras.add(extra);
    } else {
      extras[eIdx] = extra;
    }
    _debts[debtIndex] = DebtAccount(
      id: debt.id,
      name: debt.name,
      debtType: debt.debtType,
      balance: debt.balance,
      apr: debt.apr,
      minimumPayment: debt.minimumPayment,
      payoffDate: debt.payoffDate,
      startDate: debt.startDate,
      loanEndDate: debt.loanEndDate,
      minPaymentRule: debt.minPaymentRule,
      originalBalance: debt.originalBalance,
      extraPayments: extras,
    );
    notifyListeners();
    _scheduleWrite(() => _database.debtsDao.upsertExtraPayment(extra));
  }

  void deleteDebtExtraPayment(String extraId, String debtId) {
    final debtIndex = _debts.indexWhere((d) => d.id == debtId);
    if (debtIndex != -1) {
      final debt = _debts[debtIndex];
      final extras = debt.extraPayments.where((e) => e.id != extraId).toList();
      _debts[debtIndex] = DebtAccount(
        id: debt.id,
        name: debt.name,
        debtType: debt.debtType,
        balance: debt.balance,
        apr: debt.apr,
        minimumPayment: debt.minimumPayment,
        payoffDate: debt.payoffDate,
        startDate: debt.startDate,
        loanEndDate: debt.loanEndDate,
        minPaymentRule: debt.minPaymentRule,
        originalBalance: debt.originalBalance,
        extraPayments: extras,
      );
    }
    notifyListeners();
    _scheduleWrite(() => _database.debtsDao.deleteExtraPayment(extraId));
  } _scheduleWrite(() => _database.debtsDao.deleteById(debtId));
  }

  void saveDebtExtraPayment(DebtExtraPayment extra) {
    final debtIndex = _debts.indexWhere((d) => d.id == extra.debtId);
    if (debtIndex == -1) return;
    final debt = _debts[debtIndex];
    final extras = List<DebtExtraPayment>.from(debt.extraPayments);
    final eIdx = extras.indexWhere((e) => e.id == extra.id);
    if (eIdx == -1) {
      extras.add(extra);
    } else {
      extras[eIdx] = extra;
    }
    _debts[debtIndex] = DebtAccount(
      id: debt.id,
      name: debt.name,
      debtType: debt.debtType,
      balance: debt.balance,
      apr: debt.apr,
      minimumPayment: debt.minimumPayment,
      payoffDate: debt.payoffDate,
      startDate: debt.startDate,
      loanEndDate: debt.loanEndDate,
      minPaymentRule: debt.minPaymentRule,
      originalBalance: debt.originalBalance,
      extraPayments: extras,
    );
    notifyListeners();
    _scheduleWrite(() => _database.debtsDao.upsertExtraPayment(extra));
  }

  void deleteDebtExtraPayment(String extraId, String debtId) {
    final debtIndex = _debts.indexWhere((d) => d.id == debtId);
    if (debtIndex != -1) {
      final debt = _debts[debtIndex];
      final extras = debt.extraPayments.where((e) => e.id != extraId).toList();
      _debts[debtIndex] = DebtAccount(
        id: debt.id,
        name: debt.name,
        debtType: debt.debtType,
        balance: debt.balance,
        apr: debt.apr,
        minimumPayment: debt.minimumPayment,
        payoffDate: debt.payoffDate,
        startDate: debt.startDate,
        loanEndDate: debt.loanEndDate,
        minPaymentRule: debt.minPaymentRule,
        originalBalance: debt.originalBalance,
        extraPayments: extras,
      );
    }
    notifyListeners();
    _scheduleWrite(() => _database.debtsDao.deleteExtraPayment(extraId));
  }

  @override
  void saveIncomeSource(IncomeSource incomeSource) {
    final monthKey = incomeSource.monthKey.isEmpty
        ? _activeBudgetMonth
        : incomeSource.monthKey;
    final item = monthKey == incomeSource.monthKey
        ? incomeSource
        : incomeSource.copyWith(monthKey: monthKey);
    final list = _incomeByMonth.putIfAbsent(monthKey, () => []);
    final index = list.indexWhere((i) => i.id == item.id);
    if (index == -1) {
      list.add(item);
    } else {
      list[index] = item;
    }
    notifyListeners();
    _scheduleWrite(() => _database.budgetItemsDao.upsertIncomeSource(item));
  }

  @override
  void deleteIncomeSource(String incomeSourceId) {
    for (final list in _incomeByMonth.values) {
      list.removeWhere((i) => i.id == incomeSourceId);
    }
    notifyListeners();
    _scheduleWrite(
      () => _database.budgetItemsDao.deleteIncomeSource(incomeSourceId),
    );
  }

  @override
  void saveExpense(Expense expense) {
    final monthKey =
        expense.monthKey.isEmpty ? _activeBudgetMonth : expense.monthKey;
    final item = monthKey == expense.monthKey
        ? expense
        : expense.copyWith(monthKey: monthKey);
    final list = _expensesByMonth.putIfAbsent(monthKey, () => []);
    final index = list.indexWhere((e) => e.id == item.id);
    if (index == -1) {
      list.add(item);
    } else {
      list[index] = item;
    }
    notifyListeners();
    _scheduleWrite(() => _database.budgetItemsDao.upsertExpense(item));
  }

  @override
  void deleteExpense(String expenseId) {
    for (final list in _expensesByMonth.values) {
      list.removeWhere((e) => e.id == expenseId);
    }
    notifyListeners();
    _scheduleWrite(() => _database.budgetItemsDao.deleteExpense(expenseId));
  }

  @override
  List<Expense> getBills() {
    final all = _billsByMonth[_activeBudgetMonth] ?? const <Expense>[];
    return List<Expense>.unmodifiable(
      all.where((b) => !b.isSubscription),
    );
  }

  @override
  List<Expense> getSubscriptions() {
    final all = _billsByMonth[_activeBudgetMonth] ?? const <Expense>[];
    return List<Expense>.unmodifiable(
      all.where((b) => b.isSubscription),
    );
  }

  @override
  void saveBill(Expense bill) {
    final monthKey = bill.monthKey.isEmpty ? _activeBudgetMonth : bill.monthKey;
    final item =
        monthKey == bill.monthKey ? bill : bill.copyWith(monthKey: monthKey);
    final list = _billsByMonth.putIfAbsent(monthKey, () => []);
    final index = list.indexWhere((b) => b.id == item.id);
    if (index == -1) {
      list.add(item);
    } else {
      list[index] = item;
    }
    notifyListeners();
    _scheduleWrite(() => _database.budgetItemsDao.upsertBill(item));
  }

  @override
  void deleteBill(String billId) {
    for (final list in _billsByMonth.values) {
      list.removeWhere((b) => b.id == billId);
    }
    notifyListeners();
    _scheduleWrite(() => _database.budgetItemsDao.deleteBill(billId));
  }

  @override
  void saveScenarioChanges(List<ScenarioChange> scenarioChanges) {
    _scenarioChanges
      ..clear()
      ..addAll(scenarioChanges);
    notifyListeners();
    _scheduleWrite(
      () => _database.scenarioChangesDao.replaceAll(_scenarioChanges),
    );
  }

  @override
  Mortgage? getMortgage() {
    if (_mortgages.isEmpty) {
      return null;
    }
    return _mortgages.first;
  }

  @override
  List<Mortgage> getMortgages() {
    return List<Mortgage>.unmodifiable(_mortgages);
  }

  @override
  void saveMortgage(Mortgage mortgage) {
    final index = _mortgages.indexWhere((m) => m.id == mortgage.id);
    if (index == -1) {
      _mortgages.add(mortgage);
    } else {
      _mortgages[index] = mortgage;
    }
    notifyListeners();
    _scheduleWrite(() => _database.mortgageDao.upsert(mortgage));
  }

  @override
  void deleteMortgage() {
    _mortgages.clear();
    notifyListeners();
    _scheduleWrite(() => _database.mortgageDao.deleteAll());
  }

  @override
  void deleteMortgageById(String mortgageId) {
    _mortgages.removeWhere((m) => m.id == mortgageId);
    notifyListeners();
    _scheduleWrite(() => _database.mortgageDao.deleteById(mortgageId));
  }

  // ── Planner events ──

  List<PlannerEvent> getPlannerEvents() {
    return List<PlannerEvent>.unmodifiable(_plannerEvents);
  }

  void savePlannerEvent(PlannerEvent event) {
    final index =
        _plannerEvents.indexWhere((PlannerEvent e) => e.id == event.id);
    if (index == -1) {
      _plannerEvents.add(event);
    } else {
      _plannerEvents[index] = event;
    }
    notifyListeners();
    _scheduleWrite(() => _database.plannerEventsDao.upsert(event));
  }

  void deletePlannerEvent(String id) {
    _plannerEvents.removeWhere((PlannerEvent e) => e.id == id);
    notifyListeners();
    _scheduleWrite(() => _database.plannerEventsDao.deleteById(id));
  }

  // ── Budget tracking ──

  @override
  Future<List<BudgetPeriod>> getBudgetPeriods() {
    return _database.budgetPeriodsDao.loadAllPeriods();
  }

  @override
  Future<BudgetPeriod?> getBudgetPeriod(String periodId) {
    return _database.budgetPeriodsDao.loadPeriod(periodId);
  }

  @override
  Future<void> saveBudgetPeriod(BudgetPeriod period) async {
    await _database.budgetPeriodsDao.upsertPeriod(period);
    if (period.isClosed) {
      _closedMonthKeys.add(period.id);
    } else {
      _closedMonthKeys.remove(period.id);
    }
    notifyListeners();
  }

  @override
  Future<List<BudgetActual>> getBudgetActuals(String periodId) {
    return _database.budgetPeriodsDao.loadActualsForPeriod(periodId);
  }

  @override
  Future<void> saveBudgetActual(BudgetActual actual) async {
    await _database.budgetPeriodsDao.upsertActual(actual);
    notifyListeners();
  }

  @override
  Future<void> saveBudgetActuals(List<BudgetActual> actuals) async {
    await _database.budgetPeriodsDao.upsertAllActuals(actuals);
    notifyListeners();
  }

  @override
  Future<void> deleteBudgetActual(String actualId) async {
    await _database.budgetPeriodsDao.deleteActual(actualId);
    notifyListeners();
  }

  @override
  Future<void> deleteSeededBudgetActuals(String periodId) async {
    await _database.budgetPeriodsDao.deleteSeededBudgetActuals(periodId);
  }

  @override
  Future<List<BudgetActualEntry>> getBudgetActualEntries(
      String periodId) {
    return _database.budgetPeriodsDao.loadEntriesForPeriod(periodId);
  }

  @override
  Future<void> saveBudgetActualEntry(BudgetActualEntry entry) async {
    await _database.budgetPeriodsDao.upsertEntry(entry);
    notifyListeners();
  }

  @override
  Future<void> deleteBudgetActualEntry(String entryId) async {
    await _database.budgetPeriodsDao.deleteEntry(entryId);
    notifyListeners();
  }

  Future<void> waitForPendingWrites() {
    return _pendingWrite;
  }

  Future<void> _persistAll() async {
    for (final debt in _debts) {
      await _database.debtsDao.upsert(debt);
    }
    for (final entry in _incomeByMonth.entries) {
      for (final item in entry.value) {
        final withMonth = item.monthKey.isEmpty
            ? item.copyWith(monthKey: entry.key)
            : item;
        await _database.budgetItemsDao.upsertIncomeSource(withMonth);
      }
    }
    for (final entry in _expensesByMonth.entries) {
      for (final item in entry.value) {
        final withMonth =
            item.monthKey.isEmpty ? item.copyWith(monthKey: entry.key) : item;
        await _database.budgetItemsDao.upsertExpense(withMonth);
      }
    }
    for (final entry in _billsByMonth.entries) {
      for (final item in entry.value) {
        final withMonth =
            item.monthKey.isEmpty ? item.copyWith(monthKey: entry.key) : item;
        await _database.budgetItemsDao.upsertBill(withMonth);
      }
    }
    await _database.scenarioChangesDao.replaceAll(_scenarioChanges);
    for (final mortgage in _mortgages) {
      await _database.mortgageDao.upsert(mortgage);
    }
  }

  void _scheduleWrite(Future<void> Function() action) {
    final nextWrite = _pendingWrite.catchError((Object _, StackTrace __) {
      // Keep later writes running even if an earlier one fails.
    }).then((_) => action());
    _pendingWrite = nextWrite;
  }
}
