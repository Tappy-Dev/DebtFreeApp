import 'package:debt_free_app/features/simulation/engine/strategies/snowball_strategy.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/projection_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SnowballStrategy', () {
    test('should pay off debts in the correct order', () {
      final debts = <DebtAccount>[
        DebtAccount(balance: 1000, apr: 5, minimumPayment: 50),
        DebtAccount(balance: 500, apr: 3, minimumPayment: 25),
        DebtAccount(balance: 2000, apr: 7, minimumPayment: 100),
      ];

      final strategy = SnowballStrategy();
      final result = strategy.calculate(debts, 200);

      expect(result, isA<ProjectionResult>());
      expect(result.monthlyBreakdown.length, greaterThan(0));
      expect(result.updatedPayoffDate, isNotNull);
    });

    test('should handle zero debts', () {
      final debts = <DebtAccount>[];

      final strategy = SnowballStrategy();
      final result = strategy.calculate(debts, 200);

      expect(result, isA<ProjectionResult>());
      expect(result.monthlyBreakdown, isEmpty);
    });

    test('should not exceed available payment', () {
      final debts = <DebtAccount>[
        DebtAccount(balance: 1000, apr: 5, minimumPayment: 50),
      ];

      final strategy = SnowballStrategy();
      final result = strategy.calculate(debts, 30);

      expect(result.monthlyBreakdown, isNotEmpty);
      expect(result.monthlyBreakdown[0].totalPayment, lessThanOrEqualTo(30));
    });
  });
}
