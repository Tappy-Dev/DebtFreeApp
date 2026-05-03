import 'package:debt_free_app/core/data/daos/budget_items_dao.dart';
import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BudgetItemsDao upserts, loads, and deletes budget items', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final dao = BudgetItemsDao(database);

    await dao.upsertIncomeSource(
      const IncomeSource(
        id: 'salary',
        name: 'Salary',
        annualGross: 38400,
        overrideMonthlyNet: 3200,
      ),
    );
    await dao.upsertExpense(
      const Expense(
        id: 'rent',
        name: 'Rent',
        amount: 1200,
      ),
    );

    final incomeSources = await dao.loadIncomeSources();
    final expenses = await dao.loadExpenses();

    expect(incomeSources, hasLength(1));
    expect(incomeSources.first.id, 'salary');
    expect(incomeSources.first.annualGross, 38400);
    expect(expenses, hasLength(1));
    expect(expenses.first.id, 'rent');
    expect(expenses.first.amount, 1200);

    await dao.deleteIncomeSource('salary');
    await dao.deleteExpense('rent');

    expect(await dao.loadIncomeSources(), isEmpty);
    expect(await dao.loadExpenses(), isEmpty);
  });

  test('BudgetItemsDao updates an existing income source', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final dao = BudgetItemsDao(database);

    await dao.upsertIncomeSource(
      const IncomeSource(
        id: 'salary',
        name: 'Salary',
        annualGross: 38400,
        overrideMonthlyNet: 3200,
      ),
    );
    await dao.upsertIncomeSource(
      const IncomeSource(
        id: 'salary',
        name: 'Updated Salary',
        annualGross: 42000,
        overrideMonthlyNet: 3500,
      ),
    );

    final incomeSources = await dao.loadIncomeSources();

    expect(incomeSources, hasLength(1));
    expect(incomeSources.single.name, 'Updated Salary');
    expect(incomeSources.single.annualGross, 42000);
  });
}
