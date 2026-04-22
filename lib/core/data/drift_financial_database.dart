import 'dart:io';

import 'package:debt_free_app/core/data/daos/app_settings_dao.dart';
import 'package:debt_free_app/core/data/daos/budget_items_dao.dart';
import 'package:debt_free_app/core/data/daos/budget_periods_dao.dart';
import 'package:debt_free_app/core/data/daos/debts_dao.dart';
import 'package:debt_free_app/core/data/daos/mortgage_dao.dart';
import 'package:debt_free_app/core/data/daos/planner_events_dao.dart';
import 'package:debt_free_app/core/data/daos/scenario_changes_dao.dart';
import 'package:debt_free_app/core/data/drift_schema.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

class DriftFinancialDatabase extends GeneratedDatabase {
  DriftFinancialDatabase({
    QueryExecutor? executor,
  }) : super(executor ?? _openConnection());

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}debt_free.sqlite',
      );
      return NativeDatabase(file);
    });
  }

  late final DebtsDao debtsDao = DebtsDao(this);
  late final BudgetItemsDao budgetItemsDao = BudgetItemsDao(this);
  late final ScenarioChangesDao scenarioChangesDao = ScenarioChangesDao(this);
  late final MortgageDao mortgageDao = MortgageDao(this);
  late final BudgetPeriodsDao budgetPeriodsDao = BudgetPeriodsDao(this);
  late final PlannerEventsDao plannerEventsDao = PlannerEventsDao(this);
  late final AppSettingsDao appSettingsDao = AppSettingsDao(this);

  @override
  int get schemaVersion => 18;

  @override
  Iterable<TableInfo> get allTables => const <TableInfo>[];

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await customStatement(DriftSchema.createDebtsTable);
        await customStatement(DriftSchema.createIncomeSourcesTable);
        await customStatement(DriftSchema.createExpensesTable);
        await customStatement(DriftSchema.createScenarioChangesTable);
        await customStatement(DriftSchema.createMortgageTable);
        await customStatement(DriftSchema.createSalarySacrificesTable);
        await customStatement(DriftSchema.createBudgetPeriodsTable);
        await customStatement(DriftSchema.createBudgetActualsTable);
        await customStatement(DriftSchema.createBudgetActualEntriesTable);
        await customStatement(DriftSchema.createBillsTable);
        await customStatement(DriftSchema.createPlannerEventsTable);
        await customStatement(DriftSchema.createAppSettingsTable);
        await customStatement(DriftSchema.createDebtExtraPaymentsTable);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await ensureScenarioChangeScheduleColumns();
        }
        if (from < 3) {
          await customStatement(DriftSchema.createMortgageTable);
          await customStatement(DriftSchema.createSalarySacrificesTable);
        }
        if (from < 4) {
          await customStatement(DriftSchema.addMinPaymentTypeColumn);
          await customStatement(DriftSchema.addMinPaymentPercentageColumn);
          await customStatement(DriftSchema.addMinPaymentFloorColumn);
        }
        if (from < 5) {
          await customStatement(DriftSchema.createBudgetPeriodsTable);
          await customStatement(DriftSchema.createBudgetActualsTable);
        }
        if (from < 6) {
          await customStatement(DriftSchema.addAnnualGrossColumn);
          await customStatement(DriftSchema.addStudentLoanPlanColumn);
        }
        if (from < 7) {
          await customStatement(DriftSchema.createBillsTable);
        }
        if (from < 8) {
          await customStatement(DriftSchema.createPlannerEventsTable);
        }
        if (from < 9) {
          await customStatement(DriftSchema.addMonthKeyToIncomeSources);
          await customStatement(DriftSchema.addMonthKeyToExpenses);
          await customStatement(DriftSchema.addMonthKeyToBills);
        }
        if (from < 10) {
          await customStatement(DriftSchema.createAppSettingsTable);
          await customStatement(DriftSchema.addDebtBalanceToActuals);
        }
        if (from < 11) {
          await customStatement(DriftSchema.addIsTrackableToExpenses);
        }
        if (from < 12) {
          await customStatement(DriftSchema.createBudgetActualEntriesTable);
        }
        if (from < 13) {
          await customStatement(DriftSchema.addScenarioDebtIdColumn);
        }
        if (from < 14) {
          await customStatement(DriftSchema.addStartDateColumn);
        }
        if (from < 15) {
          await customStatement(DriftSchema.addOriginalBalanceColumn);
          await customStatement(DriftSchema.createDebtExtraPaymentsTable);
          // Backfill original_balance with current balance for existing debts
          await customStatement(
            'UPDATE debts SET original_balance = balance WHERE original_balance IS NULL',
          );
        }
        if (from < 16) {
          await customStatement(DriftSchema.addDebtTypeColumn);
          await customStatement(DriftSchema.addLoanEndDateColumn);
        }
        if (from < 17) {
          await customStatement(DriftSchema.addMonthlyTaxableBenefitsColumn);
          await customStatement(DriftSchema.addMonthlyNiableBenefitsColumn);
          await customStatement(
            DriftSchema.addMonthlyStudentLoanableBenefitsColumn,
          );
        }
        if (from < 18) {
          await customStatement(DriftSchema.addMonthlyPensionSacrificeColumn);
          await customStatement(DriftSchema.addMonthlyCarSacrificeColumn);
          await customStatement(DriftSchema.addMonthlyOtherSacrificeColumn);
        }
      },
      beforeOpen: (OpeningDetails details) async {
        await ensureScenarioChangeScheduleColumns();
      },
    );
  }

  Future<void> ensureScenarioChangeScheduleColumns() async {
    final existingColumns = await _loadColumnNames(
      DriftSchema.scenarioChangesTable,
    );
    if (existingColumns.isEmpty) {
      return;
    }

    if (!existingColumns.contains(DriftSchema.scenarioStartMonthColumn)) {
      await customStatement(DriftSchema.addScenarioStartMonthColumn);
    }

    if (!existingColumns.contains(
      DriftSchema.scenarioDurationInMonthsColumn,
    )) {
      await customStatement(DriftSchema.addScenarioDurationInMonthsColumn);
    }
  }

  Future<Set<String>> _loadColumnNames(String tableName) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    return rows
        .map((QueryRow row) => row.read<String>('name'))
        .toSet();
  }
}
