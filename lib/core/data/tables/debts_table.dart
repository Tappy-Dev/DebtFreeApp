import 'package:drift/drift.dart';

class DebtsTable extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get debtType => text().named('debt_type').withDefault(
        const Constant('other'),
      )();

  RealColumn get balance => real()();

  RealColumn get apr => real()();

  RealColumn get minimumPayment => real().named('minimum_payment')();

  TextColumn get payoffDate => text().named('payoff_date').nullable()();

  TextColumn get loanEndDate => text().named('loan_end_date').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
