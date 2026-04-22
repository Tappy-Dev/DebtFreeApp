import 'package:debt_free_app/features/simulation/engine/projection_engine.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectionEngine', () {
    late ProjectionEngine projectionEngine;

    setUp(() {
      projectionEngine = ProjectionEngine();
    });

    test('should calculate cash flow projection correctly', () {
      final debts = <DebtAccount>[
        DebtAccount(
          id: '1',
          name: 'Card',
          balance: 1200,
          apr: 12,
          minimumPayment: 100,
        ),
      ];
      final incomeSources = <IncomeSource>[
        const IncomeSource(annualGross: 19200, overrideMonthlyNet: 1600),
      ];
      final expenses = <Expense>[
        const Expense(amount: 1450),
      ];
      final scenarioChanges = <ScenarioChange>[
        const ScenarioChange(
          changeType: ChangeType.increaseIncome,
          amount: 200,
        ),
      ];

      final result = projectionEngine.simulate(
        debts,
        incomeSources,
        expenses,
        scenarioChanges,
      );

      expect(result.monthlyBreakdown, isNotEmpty);
      expect(result.totalInterestSaved, greaterThan(0));
      expect(result.updatedPayoffDate, isNotNull);
    });

    test('should handle zero APR correctly', () {
      final debts = <DebtAccount>[
        DebtAccount(
          id: '1',
          name: 'Card',
          balance: 1000,
          apr: 0,
          minimumPayment: 100,
        ),
      ];
      final incomeSources = <IncomeSource>[
        const IncomeSource(annualGross: 19200, overrideMonthlyNet: 1600),
      ];
      final expenses = <Expense>[
        const Expense(amount: 1450),
      ];

      final result = projectionEngine.simulate(
        debts,
        incomeSources,
        expenses,
        const <ScenarioChange>[],
      );

      expect(result.monthlyBreakdown, isNotEmpty);
      expect(result.totalInterestPaid, equals(0));
      expect(result.totalInterestSaved, equals(0));
      expect(result.updatedPayoffDate, isNotNull);
    });

    test('should handle overpayment greater than balance', () {
      final debts = <DebtAccount>[
        DebtAccount(
          id: '1',
          name: 'Card',
          balance: 400,
          apr: 5,
          minimumPayment: 100,
        ),
      ];
      final incomeSources = <IncomeSource>[
        const IncomeSource(annualGross: 13200, overrideMonthlyNet: 1100),
      ];
      final expenses = <Expense>[
        const Expense(amount: 1000),
      ];
      final scenarioChanges = <ScenarioChange>[
        const ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 500,
        ),
      ];

      final result = projectionEngine.simulate(
        debts,
        incomeSources,
        expenses,
        scenarioChanges,
      );

      expect(result.monthlyBreakdown, isNotEmpty);
      expect(result.totalInterestSaved, greaterThanOrEqualTo(0));
      expect(result.updatedPayoffDate, isNotNull);
    });

    test('should not pay more than available monthly funds without scenario help', () {
      final debts = <DebtAccount>[
        DebtAccount(
          id: '1',
          name: 'Card',
          balance: 1000,
          apr: 12,
          minimumPayment: 150,
        ),
      ];
      final incomeSources = <IncomeSource>[
        const IncomeSource(annualGross: 1200, overrideMonthlyNet: 100),
      ];
      final expenses = <Expense>[
        const Expense(amount: 20),
      ];

      final result = projectionEngine.simulate(
        debts,
        incomeSources,
        expenses,
        const <ScenarioChange>[],
        maxMonths: 1,
      );

      expect(result.monthlyBreakdown, hasLength(1));
      expect(result.monthlyBreakdown.first.totalPayment, lessThanOrEqualTo(80));
    });

    test('should apply delayed extra payment only after its start month', () {
      final debts = <DebtAccount>[
        DebtAccount(
          id: '1',
          name: 'Card',
          balance: 1000,
          apr: 0,
          minimumPayment: 50,
        ),
      ];
      final incomeSources = <IncomeSource>[
        const IncomeSource(annualGross: 1200, overrideMonthlyNet: 100),
      ];
      final expenses = <Expense>[];
      final scenarioChanges = <ScenarioChange>[
        const ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 100,
          startMonth: 1,
        ),
      ];

      final result = projectionEngine.simulate(
        debts,
        incomeSources,
        expenses,
        scenarioChanges,
        maxMonths: 2,
      );

      expect(result.monthlyBreakdown, hasLength(2));
      expect(result.monthlyBreakdown[0].totalPayment, 100);
      expect(result.monthlyBreakdown[1].totalPayment, 200);
    });

    test('should stop applying a temporary scenario after its duration ends', () {
      final debts = <DebtAccount>[
        DebtAccount(
          id: '1',
          name: 'Card',
          balance: 1000,
          apr: 0,
          minimumPayment: 50,
        ),
      ];
      final incomeSources = <IncomeSource>[
        const IncomeSource(annualGross: 1200, overrideMonthlyNet: 100),
      ];
      final expenses = <Expense>[];
      final scenarioChanges = <ScenarioChange>[
        const ScenarioChange(
          changeType: ChangeType.extraPayment,
          amount: 50,
          durationInMonths: 1,
        ),
      ];

      final result = projectionEngine.simulate(
        debts,
        incomeSources,
        expenses,
        scenarioChanges,
        maxMonths: 2,
      );

      expect(result.monthlyBreakdown, hasLength(2));
      expect(result.monthlyBreakdown[0].totalPayment, 150);
      expect(result.monthlyBreakdown[1].totalPayment, 100);
    });
  });
}
