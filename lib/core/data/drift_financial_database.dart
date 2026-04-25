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
  int get schemaVersion => 23;

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
          await _ensureColumnExists(
            DriftSchema.debtsTable,
            'min_payment_type',
            DriftSchema.addMinPaymentTypeColumn,
          );
          await _ensureColumnExists(
            DriftSchema.debtsTable,
            'min_payment_percentage',
            DriftSchema.addMinPaymentPercentageColumn,
          );
          await _ensureColumnExists(
            DriftSchema.debtsTable,
            'min_payment_floor',
            DriftSchema.addMinPaymentFloorColumn,
          );
        }
        if (from < 5) {
          await customStatement(DriftSchema.createBudgetPeriodsTable);
          await customStatement(DriftSchema.createBudgetActualsTable);
        }
        if (from < 6) {
          await _ensureColumnExists(
            DriftSchema.incomeSourcesTable,
            'annual_gross',
            DriftSchema.addAnnualGrossColumn,
          );
          await _ensureColumnExists(
            DriftSchema.incomeSourcesTable,
            'student_loan_plan',
            DriftSchema.addStudentLoanPlanColumn,
          );
        }
        if (from < 7) {
          await customStatement(DriftSchema.createBillsTable);
        }
        if (from < 8) {
          await customStatement(DriftSchema.createPlannerEventsTable);
        }
        if (from < 9) {
          await _ensureColumnExists(
            DriftSchema.incomeSourcesTable,
            'month_key',
            DriftSchema.addMonthKeyToIncomeSources,
          );
          await _ensureColumnExists(
            DriftSchema.expensesTable,
            'month_key',
            DriftSchema.addMonthKeyToExpenses,
          );
          await _ensureColumnExists(
            DriftSchema.billsTable,
            'month_key',
            DriftSchema.addMonthKeyToBills,
          );
        }
        if (from < 10) {
          await customStatement(DriftSchema.createAppSettingsTable);
          await _ensureColumnExists(
            DriftSchema.budgetActualsTable,
            'debt_balance',
            DriftSchema.addDebtBalanceToActuals,
          );
        }
        if (from < 11) {
          await _ensureColumnExists(
            DriftSchema.expensesTable,
            'is_trackable',
            DriftSchema.addIsTrackableToExpenses,
          );
        }
        if (from < 12) {
          await customStatement(DriftSchema.createBudgetActualEntriesTable);
        }
        if (from < 13) {
          await _ensureColumnExists(
            DriftSchema.scenarioChangesTable,
            DriftSchema.scenarioDebtIdColumn,
            DriftSchema.addScenarioDebtIdColumn,
          );
        }
        if (from < 14) {
          await _ensureColumnExists(
            DriftSchema.debtsTable,
            'start_date',
            DriftSchema.addStartDateColumn,
          );
        }
        if (from < 15) {
          await _ensureColumnExists(
            DriftSchema.debtsTable,
            'original_balance',
            DriftSchema.addOriginalBalanceColumn,
          );
          await customStatement(DriftSchema.createDebtExtraPaymentsTable);
          // Backfill original_balance with current balance for existing debts
          await customStatement(
            'UPDATE debts SET original_balance = balance WHERE original_balance IS NULL',
          );
        }
        if (from < 16) {
          await _ensureColumnExists(
            DriftSchema.debtsTable,
            'debt_type',
            DriftSchema.addDebtTypeColumn,
          );
          await _ensureColumnExists(
            DriftSchema.debtsTable,
            'loan_end_date',
            DriftSchema.addLoanEndDateColumn,
          );
        }
        if (from < 17) {
          await _ensureColumnExists(
            DriftSchema.incomeSourcesTable,
            'monthly_taxable_benefits',
            DriftSchema.addMonthlyTaxableBenefitsColumn,
          );
          await _ensureColumnExists(
            DriftSchema.incomeSourcesTable,
            'monthly_niable_benefits',
            DriftSchema.addMonthlyNiableBenefitsColumn,
          );
          await _ensureColumnExists(
            DriftSchema.incomeSourcesTable,
            'monthly_student_loanable_benefits',
            DriftSchema.addMonthlyStudentLoanableBenefitsColumn,
          );
        }
        if (from < 18) {
          await _ensureColumnExists(
            DriftSchema.incomeSourcesTable,
            'monthly_pension_sacrifice',
            DriftSchema.addMonthlyPensionSacrificeColumn,
          );
          await _ensureColumnExists(
            DriftSchema.incomeSourcesTable,
            'monthly_car_sacrifice',
            DriftSchema.addMonthlyCarSacrificeColumn,
          );
          await _ensureColumnExists(
            DriftSchema.incomeSourcesTable,
            'monthly_other_sacrifice',
            DriftSchema.addMonthlyOtherSacrificeColumn,
          );
        }
        if (from < 19) {
          await _ensureColumnExists(
            DriftSchema.billsTable,
            'is_subscription',
            DriftSchema.addIsSubscriptionToBills,
          );
        }
        if (from < 20) {
          await _ensureColumnExists(
            DriftSchema.debtsTable,
            'payment_day',
            DriftSchema.addDebtPaymentDayColumn,
          );
          await _ensureColumnExists(
            DriftSchema.billsTable,
            'payment_day',
            DriftSchema.addPaymentDayToBills,
          );
          await _ensureColumnExists(
            DriftSchema.mortgageTable,
            'payment_day',
            DriftSchema.addMortgagePaymentDayColumn,
          );
        }
        if (from < 21) {
          await _ensureColumnExists(
            DriftSchema.expensesTable,
            'category',
            DriftSchema.addCategoryToExpenses,
          );
        }
        if (from < 22) {
          await _ensureColumnExists(
            DriftSchema.billsTable,
            'category',
            DriftSchema.addCategoryToBills,
          );
        }
        if (from < 23) {
          await _ensureColumnExists(
            DriftSchema.mortgageTable,
            'deal_end_date',
            DriftSchema.addMortgageDealEndDateColumn,
          );
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
    return rows.map((QueryRow row) => row.read<String>('name')).toSet();
  }

  Future<void> _ensureColumnExists(
    String tableName,
    String columnName,
    String statement,
  ) async {
    final columns = await _loadColumnNames(tableName);
    if (columns.isEmpty || columns.contains(columnName)) {
      return;
    }
    await customStatement(statement);
  }
}
