class DriftSchema {
  static const String debtsTable = 'debts';
  static const String incomeSourcesTable = 'income_sources';
  static const String expensesTable = 'expenses';
  static const String scenarioChangesTable = 'scenario_changes';
  static const String scenarioStartMonthColumn = 'start_month';
  static const String scenarioDurationInMonthsColumn = 'duration_in_months';

  static const String createDebtsTable = '''
    CREATE TABLE IF NOT EXISTS debts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      debt_type TEXT NOT NULL DEFAULT 'other',
      balance REAL NOT NULL,
      apr REAL NOT NULL,
      minimum_payment REAL NOT NULL,
      payoff_date TEXT,
      min_payment_type TEXT NOT NULL DEFAULT 'interestPlusPercentage',
      min_payment_percentage REAL NOT NULL DEFAULT 1.0,
      min_payment_floor REAL NOT NULL DEFAULT 25.0,
      start_date TEXT,
      loan_end_date TEXT,
      payment_day INTEGER NOT NULL DEFAULT 1,
      original_balance REAL
    )
  ''';

  static const String addDebtTypeColumn = '''
    ALTER TABLE debts ADD COLUMN debt_type TEXT NOT NULL DEFAULT 'other'
  ''';

  static const String addMinPaymentTypeColumn = '''
    ALTER TABLE debts ADD COLUMN min_payment_type TEXT NOT NULL DEFAULT 'interestPlusPercentage'
  ''';

  static const String addMinPaymentPercentageColumn = '''
    ALTER TABLE debts ADD COLUMN min_payment_percentage REAL NOT NULL DEFAULT 1.0
  ''';

  static const String addMinPaymentFloorColumn = '''
    ALTER TABLE debts ADD COLUMN min_payment_floor REAL NOT NULL DEFAULT 25.0
  ''';

  static const String addStartDateColumn = '''
    ALTER TABLE debts ADD COLUMN start_date TEXT
  ''';

  static const String addLoanEndDateColumn = '''
    ALTER TABLE debts ADD COLUMN loan_end_date TEXT
  ''';

  static const String addOriginalBalanceColumn = '''
    ALTER TABLE debts ADD COLUMN original_balance REAL
  ''';

  static const String addDebtPaymentDayColumn = '''
    ALTER TABLE debts ADD COLUMN payment_day INTEGER NOT NULL DEFAULT 1
  ''';

  static const String debtExtraPaymentsTable = 'debt_extra_payments';

  static const String createDebtExtraPaymentsTable = '''
    CREATE TABLE IF NOT EXISTS debt_extra_payments (
      id TEXT PRIMARY KEY,
      debt_id TEXT NOT NULL,
      amount REAL NOT NULL,
      start_date TEXT NOT NULL,
      end_date TEXT NOT NULL
    )
  ''';

  static const String createIncomeSourcesTable = '''
    CREATE TABLE IF NOT EXISTS income_sources (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      amount REAL NOT NULL,
      annual_gross REAL NOT NULL DEFAULT 0,
      student_loan_plan TEXT NOT NULL DEFAULT 'none',
      monthly_pension_sacrifice REAL NOT NULL DEFAULT 0,
      monthly_car_sacrifice REAL NOT NULL DEFAULT 0,
      monthly_other_sacrifice REAL NOT NULL DEFAULT 0,
      monthly_taxable_benefits REAL NOT NULL DEFAULT 0,
      monthly_niable_benefits REAL NOT NULL DEFAULT 0,
      monthly_student_loanable_benefits REAL NOT NULL DEFAULT 0,
      month_key TEXT NOT NULL DEFAULT ''
    )
  ''';

  static const String addAnnualGrossColumn = '''
    ALTER TABLE income_sources ADD COLUMN annual_gross REAL NOT NULL DEFAULT 0
  ''';

  static const String addStudentLoanPlanColumn = '''
    ALTER TABLE income_sources ADD COLUMN student_loan_plan TEXT NOT NULL DEFAULT 'none'
  ''';

  static const String addMonthlyTaxableBenefitsColumn = '''
    ALTER TABLE income_sources ADD COLUMN monthly_taxable_benefits REAL NOT NULL DEFAULT 0
  ''';

  static const String addMonthlyPensionSacrificeColumn = '''
    ALTER TABLE income_sources ADD COLUMN monthly_pension_sacrifice REAL NOT NULL DEFAULT 0
  ''';

  static const String addMonthlyCarSacrificeColumn = '''
    ALTER TABLE income_sources ADD COLUMN monthly_car_sacrifice REAL NOT NULL DEFAULT 0
  ''';

  static const String addMonthlyOtherSacrificeColumn = '''
    ALTER TABLE income_sources ADD COLUMN monthly_other_sacrifice REAL NOT NULL DEFAULT 0
  ''';

  static const String addMonthlyNiableBenefitsColumn = '''
    ALTER TABLE income_sources ADD COLUMN monthly_niable_benefits REAL NOT NULL DEFAULT 0
  ''';

  static const String addMonthlyStudentLoanableBenefitsColumn = '''
    ALTER TABLE income_sources ADD COLUMN monthly_student_loanable_benefits REAL NOT NULL DEFAULT 0
  ''';

  static const String addMonthKeyToIncomeSources = '''
    ALTER TABLE income_sources ADD COLUMN month_key TEXT NOT NULL DEFAULT ''
  ''';

  static const String addMonthKeyToExpenses = '''
    ALTER TABLE expenses ADD COLUMN month_key TEXT NOT NULL DEFAULT ''
  ''';

  static const String addMonthKeyToBills = '''
    ALTER TABLE bills ADD COLUMN month_key TEXT NOT NULL DEFAULT ''
  ''';

  static const String createExpensesTable = '''
    CREATE TABLE IF NOT EXISTS expenses (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      amount REAL NOT NULL,
      month_key TEXT NOT NULL DEFAULT '',
      is_trackable INTEGER NOT NULL DEFAULT 0,
      category TEXT NOT NULL DEFAULT 'other'
    )
  ''';

  static const String addIsTrackableToExpenses = '''
    ALTER TABLE expenses ADD COLUMN is_trackable INTEGER DEFAULT 0
  ''';

  static const String addCategoryToExpenses = '''
    ALTER TABLE expenses ADD COLUMN category TEXT NOT NULL DEFAULT 'other'
  ''';

  static const String scenarioDebtIdColumn = 'debt_id';

  static const String createScenarioChangesTable = '''
    CREATE TABLE IF NOT EXISTS scenario_changes (
      id TEXT PRIMARY KEY,
      change_type TEXT NOT NULL,
      amount REAL NOT NULL,
      $scenarioStartMonthColumn INTEGER NOT NULL,
      $scenarioDurationInMonthsColumn INTEGER,
      $scenarioDebtIdColumn TEXT
    )
  ''';

  static const String createLegacyScenarioChangesTable = '''
    CREATE TABLE IF NOT EXISTS scenario_changes (
      id TEXT PRIMARY KEY,
      change_type TEXT NOT NULL,
      amount REAL NOT NULL
    )
  ''';

  static const String addScenarioStartMonthColumn = '''
    ALTER TABLE scenario_changes
    ADD COLUMN start_month INTEGER NOT NULL DEFAULT 0
  ''';

  static const String addScenarioDurationInMonthsColumn = '''
    ALTER TABLE scenario_changes
    ADD COLUMN duration_in_months INTEGER
  ''';

  static const String addScenarioDebtIdColumn = '''
    ALTER TABLE scenario_changes
    ADD COLUMN debt_id TEXT
  ''';

  static const String mortgageTable = 'mortgage';

  static const String createMortgageTable = '''
    CREATE TABLE IF NOT EXISTS mortgage (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      balance REAL NOT NULL,
      annual_rate REAL NOT NULL,
      monthly_payment REAL NOT NULL,
      remaining_term_months INTEGER NOT NULL,
      overpayment REAL NOT NULL DEFAULT 0,
      payment_day INTEGER NOT NULL DEFAULT 1,
      deal_end_date INTEGER
    )
  ''';

  static const String addMortgagePaymentDayColumn = '''
    ALTER TABLE mortgage ADD COLUMN payment_day INTEGER NOT NULL DEFAULT 1
  ''';

  static const String addMortgageDealEndDateColumn = '''
    ALTER TABLE mortgage ADD COLUMN deal_end_date INTEGER
  ''';

  static const String salarySacrificesTable = 'salary_sacrifices';

  static const String createSalarySacrificesTable = '''
    CREATE TABLE IF NOT EXISTS salary_sacrifices (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      gross_amount REAL NOT NULL,
      tax_band TEXT NOT NULL
    )
  ''';

  static const String budgetPeriodsTable = 'budget_periods';

  static const String createBudgetPeriodsTable = '''
    CREATE TABLE IF NOT EXISTS budget_periods (
      id TEXT PRIMARY KEY,
      year INTEGER NOT NULL,
      month INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'open',
      notes TEXT NOT NULL DEFAULT '',
      closed_at TEXT,
      carried_forward_balance REAL NOT NULL DEFAULT 0
    )
  ''';

  static const String addCarriedForwardBalanceToBudgetPeriods = '''
    ALTER TABLE budget_periods ADD COLUMN carried_forward_balance REAL NOT NULL DEFAULT 0
  ''';

  static const String budgetActualsTable = 'budget_actuals';

  static const String billsTable = 'bills';

  static const String createBillsTable = '''
    CREATE TABLE IF NOT EXISTS bills (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      amount REAL NOT NULL,
      month_key TEXT NOT NULL DEFAULT '',
      is_subscription INTEGER NOT NULL DEFAULT 0,
      payment_day INTEGER NOT NULL DEFAULT 1,
      category TEXT NOT NULL DEFAULT 'other'
    )
  ''';

  static const String addIsSubscriptionToBills = '''
    ALTER TABLE bills ADD COLUMN is_subscription INTEGER NOT NULL DEFAULT 0
  ''';

  static const String addPaymentDayToBills = '''
    ALTER TABLE bills ADD COLUMN payment_day INTEGER NOT NULL DEFAULT 1
  ''';

  static const String addCategoryToBills = '''
    ALTER TABLE bills ADD COLUMN category TEXT NOT NULL DEFAULT 'other'
  ''';

  static const String createBudgetActualsTable = '''
    CREATE TABLE IF NOT EXISTS budget_actuals (
      id TEXT PRIMARY KEY,
      period_id TEXT NOT NULL,
      category_id TEXT NOT NULL,
      category_name TEXT NOT NULL,
      category_type TEXT NOT NULL,
      budgeted REAL NOT NULL,
      actual REAL NOT NULL DEFAULT 0,
      debt_balance REAL NOT NULL DEFAULT 0
    )
  ''';

  static const String plannerEventsTable = 'planner_events';

  static const String createPlannerEventsTable = '''
    CREATE TABLE IF NOT EXISTS planner_events (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      event_type TEXT NOT NULL,
      amount REAL NOT NULL,
      scheduled_month INTEGER NOT NULL,
      scheduled_year INTEGER NOT NULL,
      is_recurring INTEGER NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT ''
    )
  ''';

  static const String appSettingsTable = 'app_settings';

  static const String createAppSettingsTable = '''
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  static const String addDebtBalanceToActuals = '''
    ALTER TABLE budget_actuals ADD COLUMN debt_balance REAL NOT NULL DEFAULT 0
  ''';

  static const String budgetActualEntriesTable = 'budget_actual_entries';

  static const String createBudgetActualEntriesTable = '''
    CREATE TABLE IF NOT EXISTS budget_actual_entries (
      id TEXT PRIMARY KEY,
      actual_id TEXT NOT NULL,
      reference TEXT NOT NULL DEFAULT '',
      entry_date TEXT NOT NULL,
      amount REAL NOT NULL
    )
  ''';
}
