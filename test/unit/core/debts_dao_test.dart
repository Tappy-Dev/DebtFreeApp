import 'package:debt_free_app/core/data/daos/debts_dao.dart';
import 'package:debt_free_app/core/data/drift_financial_database.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DebtsDao upserts and reads debts', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final dao = DebtsDao(database);

    await dao.upsert(
      DebtAccount(
        id: 'card-1',
        name: 'Credit Card',
        balance: 2000,
        apr: 18.9,
        minimumPayment: 75,
      ),
    );

    final debts = await dao.loadAll();

    expect(debts, hasLength(1));
    expect(debts.first.id, 'card-1');
    expect(debts.first.name, 'Credit Card');
    expect(debts.first.minimumPayment, 75);
  });

  test('DebtsDao updates an existing debt record', () async {
    final database = DriftFinancialDatabase(
      executor: NativeDatabase.memory(),
    );
    final dao = DebtsDao(database);
    final updatedPayoffDate = DateTime(2027, 6);

    await dao.upsert(
      DebtAccount(
        id: 'card-1',
        name: 'Credit Card',
        balance: 2000,
        apr: 18.9,
        minimumPayment: 75,
      ),
    );
    await dao.upsert(
      DebtAccount(
        id: 'card-1',
        name: 'Updated Card',
        balance: 1500,
        apr: 16.5,
        minimumPayment: 90,
        payoffDate: updatedPayoffDate,
      ),
    );

    final debts = await dao.loadAll();

    expect(debts, hasLength(1));
    expect(debts.single.name, 'Updated Card');
    expect(debts.single.balance, 1500);
    expect(debts.single.apr, 16.5);
    expect(debts.single.minimumPayment, 90);
    expect(debts.single.payoffDate, updatedPayoffDate);
  });
}
