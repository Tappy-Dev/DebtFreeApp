import 'package:debt_free_app/features/simulation/engine/strategies/avalanche_strategy.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvalancheStrategy', () {
    late AvalancheStrategy strategy;

    setUp(() {
      strategy = AvalancheStrategy();
    });

    test('should prioritize debts by highest APR', () {
      final debts = <DebtAccount>[
        DebtAccount(balance: 1000, apr: 20, minimumPayment: 50),
        DebtAccount(balance: 500, apr: 15, minimumPayment: 30),
        DebtAccount(balance: 2000, apr: 10, minimumPayment: 100),
      ];

      final prioritizedDebts = strategy.prioritizeDebts(debts);

      expect(prioritizedDebts[0].apr, greaterThan(prioritizedDebts[1].apr));
      expect(prioritizedDebts[1].apr, greaterThan(prioritizedDebts[2].apr));
    });

    test('should calculate payments correctly', () {
      final debts = <DebtAccount>[
        DebtAccount(balance: 1000, apr: 20, minimumPayment: 50),
        DebtAccount(balance: 500, apr: 15, minimumPayment: 30),
      ];

      final totalPayment = strategy.calculatePayments(debts, 200);

      expect(totalPayment, equals(200));
    });

    test('should allocate extra payments to highest APR debt', () {
      final debts = <DebtAccount>[
        DebtAccount(balance: 1000, apr: 20, minimumPayment: 50),
        DebtAccount(balance: 500, apr: 15, minimumPayment: 30),
      ];

      final result = strategy.allocateExtraPayment(debts, 100);

      expect(result[0].balance, equals(900));
      expect(result[1].balance, equals(500));
    });
  });
}
