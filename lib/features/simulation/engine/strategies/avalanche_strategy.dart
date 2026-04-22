import 'dart:math' as math;

import 'package:debt_free_app/features/simulation/models/debt_account.dart';

class AvalancheStrategy {
  List<DebtAccount> prioritizeDebts(List<DebtAccount> debts) {
    final sorted = debts.toList()
      ..sort(
        (DebtAccount a, DebtAccount b) {
          final aprCompare = b.apr.compareTo(a.apr);
          if (aprCompare != 0) {
            return aprCompare;
          }
          return b.balance.compareTo(a.balance);
        },
      );

    return sorted;
  }

  double calculatePayments(List<DebtAccount> debts, double availablePayment) {
    if (debts.isEmpty || availablePayment <= 0) {
      return 0;
    }

    return availablePayment;
  }

  List<DebtAccount> allocateExtraPayment(
    List<DebtAccount> debts,
    double extraPayment,
  ) {
    final prioritized = prioritizeDebts(
      debts.map((DebtAccount debt) => debt.copy()).toList(),
    );
    if (prioritized.isEmpty || extraPayment <= 0) {
      return prioritized;
    }

    prioritized.first.makePayment(
      math.min(extraPayment, prioritized.first.balance),
    );
    return prioritized;
  }
}
