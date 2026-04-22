import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebtAccount', () {
    test('should create a DebtAccount with correct values', () {
      final debtAccount = DebtAccount(
        id: '1',
        name: 'Credit Card',
        balance: 1000.0,
        apr: 15.0,
        minimumPayment: 100.0,
        payoffDate: DateTime(2025, 12, 31),
      );

      expect(debtAccount.id, '1');
      expect(debtAccount.name, 'Credit Card');
      expect(debtAccount.balance, 1000.0);
      expect(debtAccount.apr, 15.0);
      expect(debtAccount.minimumPayment, 100.0);
      expect(debtAccount.payoffDate, DateTime(2025, 12, 31));
    });

    test('should calculate the correct interest for a month', () {
      final debtAccount = DebtAccount(
        id: '1',
        name: 'Credit Card',
        balance: 1000.0,
        apr: 15.0,
        minimumPayment: 100.0,
      );

      final interest = debtAccount.calculateMonthlyInterest();

      expect(interest, 12.5);
    });

    test('should update balance after payment', () {
      final debtAccount = DebtAccount(
        id: '1',
        name: 'Credit Card',
        balance: 1000.0,
        apr: 15.0,
        minimumPayment: 100.0,
      );

      debtAccount.makePayment(100.0);

      expect(debtAccount.balance, 900.0);
    });

    test('should calculate amortized payment for loan debts', () {
      final debtAccount = DebtAccount(
        id: 'loan-1',
        name: 'Car Loan',
        debtType: DebtType.loan,
        balance: 12000.0,
        originalBalance: 12000.0,
        apr: 6.0,
        minimumPayment: 0,
        startDate: DateTime(2026, 4),
        loanEndDate: DateTime(2029, 3),
      );

      expect(debtAccount.currentMinPayment(), closeTo(365.08, 0.02));
    });
  });
}
