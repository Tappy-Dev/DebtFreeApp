import 'package:debt_free_app/core/data/financial_snapshot_codec.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FinancialSnapshotCodec round-trips snapshot data', () {
    const income = <IncomeSource>[
      IncomeSource(id: 'salary', name: 'Salary', annualGross: 38400, overrideMonthlyNet: 3200),
    ];
    const expenses = <Expense>[
      Expense(id: 'rent', name: 'Rent', amount: 1200),
    ];
    const changes = <ScenarioChange>[
      ScenarioChange(changeType: ChangeType.extraPayment, amount: 200),
    ];
    final debts = <DebtAccount>[
      DebtAccount(
        id: 'card-1',
        name: 'Card',
        balance: 1500,
        apr: 19.9,
        minimumPayment: 60,
        payoffDate: DateTime(2027, 1, 31),
      ),
    ];

    final encoded = FinancialSnapshotCodec.encode(
      FinancialSnapshot(
        debts: debts,
        income: income,
        expenses: expenses,
        scenarioChanges: changes,
      ),
    );
    final decoded = FinancialSnapshotCodec.decode(encoded);

    expect(decoded.debts, hasLength(1));
    expect(decoded.debts.first.name, 'Card');
    expect(decoded.debts.first.minimumPayment, 60);
    expect(decoded.income.first.annualGross, 38400);
    expect(decoded.expenses.first.name, 'Rent');
    expect(decoded.scenarioChanges.first.amount, 200);
  });
}
