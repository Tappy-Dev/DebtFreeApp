import 'package:debt_free_app/core/utils/uk_tax_calculator.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';

class DemoData {
  // ── Debts (from spreadsheet "View" sheet – Apr 2026) ──
  // UK typical: interest + 1% of balance, min £25
  static final List<DebtAccount> debts = <DebtAccount>[
    DebtAccount(
      id: 'fluid',
      name: 'Fluid',
      balance: 1100,
      apr: 29.59,
      minimumPayment: 38.12,
      minPaymentRule: const MinPaymentRule(),
    ),
    DebtAccount(
      id: 'barclays',
      name: 'Barclays',
      balance: 941,
      apr: 29.59,
      minimumPayment: 32.61,
      minPaymentRule: const MinPaymentRule(),
    ),
    DebtAccount(
      id: 'aqua',
      name: 'Aqua',
      balance: 269,
      apr: 39.69,
      minimumPayment: 11.59,
      minPaymentRule: const MinPaymentRule(),
    ),
    DebtAccount(
      id: 'next',
      name: 'Next',
      balance: 614,
      apr: 24.90,
      minimumPayment: 18.88,
      minPaymentRule: const MinPaymentRule(),
    ),
    DebtAccount(
      id: 'paypal',
      name: 'Paypal',
      balance: 363,
      apr: 24.00,
      minimumPayment: 10.89,
      minPaymentRule: const MinPaymentRule(),
    ),
    DebtAccount(
      id: 'bip',
      name: 'BIP',
      balance: 212,
      apr: 54.00,
      minimumPayment: 11.66,
      minPaymentRule: const MinPaymentRule(),
    ),
    DebtAccount(
      id: 'currys',
      name: 'Currys',
      balance: 632,
      apr: 29.00,
      minimumPayment: 21.59,
      minPaymentRule: const MinPaymentRule(),
    ),
    DebtAccount(
      id: 'frasers',
      name: 'Frasers Plus',
      balance: 343,
      apr: 29.00,
      minimumPayment: 11.72,
      minPaymentRule: const MinPaymentRule(),
    ),
  ];

  // ── Income ──
  static final List<IncomeSource> income = <IncomeSource>[
    const IncomeSource(
      id: 'salary',
      name: 'Monthly Pay',
      annualGross: 50000,
      studentLoanPlan: StudentLoanPlan.plan2,
    ),
  ];

  // ── Bills (fixed monthly obligations) ──
  static final List<Expense> bills = <Expense>[
    const Expense(id: 'car', name: 'Car Finance', amount: 405),
    const Expense(id: 'rent', name: 'Rent', amount: 400),
    const Expense(id: 'council-tax', name: 'Council Tax', amount: 115),
    const Expense(id: 'energy', name: 'Octopus (Energy)', amount: 70),
    const Expense(id: 'water', name: 'Water', amount: 38),
    const Expense(id: 'phone', name: 'O2 (Phone)', amount: 20),
    const Expense(id: 'internet', name: 'Internet', amount: 38),
    const Expense(id: 'car-insurance', name: 'Car Insurance', amount: 59),
  ];

  // ── Expenses (variable/discretionary spending) ──
  static final List<Expense> expenses = <Expense>[
    const Expense(id: 'natalia', name: 'Natalia', amount: 200),
    const Expense(id: 'food', name: 'Food', amount: 320),
    const Expense(id: 'fuel', name: 'Fuel', amount: 30),
    const Expense(id: 'gym', name: 'Gym', amount: 29),
    const Expense(id: 'haircut', name: 'Haircut', amount: 30),
  ];

  static final List<ScenarioChange> extraPaymentScenario = <ScenarioChange>[
    const ScenarioChange(
      changeType: ChangeType.extraPayment,
      amount: 150,
    ),
  ];

  // ── Mortgage (tracked separately for overpayment simulation) ──
  static final Mortgage mortgage = Mortgage(
    id: 'mortgage',
    name: 'Mortgage',
    startDate: DateTime(2021, 1, 15),
    originalLoanAmount: 100000,
    mortgageTermMonths: 360,
    annualRate: 4.5,
    monthlyPayment: 442,
  );
}
