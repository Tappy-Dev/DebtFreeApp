import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/core/utils/amount_parser.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';

class DebtFormController {
  DebtFormController(this._repository);

  final FinancialRepository _repository;

  String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }

    return null;
  }

  String? validateMoney(String? value, String fieldName) {
    final requiredError = validateRequired(value, fieldName);
    if (requiredError != null) {
      return requiredError;
    }

    final parsed = AmountParser.tryParse(value);
    if (parsed == null || parsed < 0) {
      return '$fieldName must be a valid amount.';
    }

    return null;
  }

  String? validateBalance(String? value) {
    return validateMoney(value, 'Balance');
  }

  String? validateApr(String? value) {
    final parsedError = validateMoney(value, 'APR');
    if (parsedError != null) {
      return parsedError;
    }

    final parsed = AmountParser.tryParse(value)!;
    if (parsed > 100) {
      return 'APR must be 100 or less.';
    }

    return null;
  }

  String? validateMinimumPayment(String? value) {
    final parsedError = validateMoney(value, 'Minimum payment');
    if (parsedError != null) {
      return parsedError;
    }

    final parsed = AmountParser.tryParse(value)!;
    if (parsed <= 0) {
      return 'Minimum payment must be greater than 0.';
    }

    return null;
  }

  String? validatePercentage(String? value) {
    final parsedError = validateMoney(value, 'Percentage');
    if (parsedError != null) {
      return parsedError;
    }

    final parsed = AmountParser.tryParse(value)!;
    if (parsed <= 0 || parsed > 100) {
      return 'Percentage must be between 0 and 100.';
    }

    return null;
  }

  String? validateFloor(String? value) {
    final parsedError = validateMoney(value, 'Minimum floor');
    if (parsedError != null) {
      return parsedError;
    }

    return null;
  }

  String? validateLoanTerm(DateTime startDate, DateTime? endDate) {
    if (endDate == null) {
      return 'Loan end date is required.';
    }

    final months = DebtAccount.loanTermInMonths(
      startDate: startDate,
      endDate: endDate,
    );
    if (months <= 0) {
      return 'Loan end date must be the same month or later.';
    }

    return null;
  }

  double? estimateLoanPayment({
    required String balance,
    required String apr,
    required DateTime startDate,
    required DateTime? endDate,
  }) {
    final parsedBalance = AmountParser.tryParse(balance);
    final parsedApr = AmountParser.tryParse(apr);
    if (parsedBalance == null || parsedBalance <= 0 || parsedApr == null) {
      return null;
    }

    if (validateLoanTerm(startDate, endDate) != null) {
      return null;
    }

    return DebtAccount.calculateAmortizedPayment(
      principal: parsedBalance,
      apr: parsedApr,
      startDate: startDate,
      endDate: endDate!,
    );
  }

  DebtAccount saveDebt({
    String? debtId,
    required String name,
    DebtType debtType = DebtType.creditCard,
    required String balance,
    required String apr,
    required String minimumPayment,
    MinPaymentType minPaymentType = MinPaymentType.interestPlusPercentage,
    String percentage = '1.0',
    String floor = '25',
    DateTime? startDate,
    DateTime? loanEndDate,
    List<DebtExtraPayment>? extraPayments,
  }) {
    final parsedBalance = AmountParser.tryParse(balance)!;
    final parsedApr = AmountParser.tryParse(apr)!;
    final resolvedMinPayment = debtType == DebtType.loan
        ? estimateLoanPayment(
              balance: balance,
              apr: apr,
              startDate: startDate ?? DateTime.now(),
              endDate: loanEndDate,
            ) ??
            0
        : AmountParser.tryParse(minimumPayment) ?? 0;
    final debt = DebtAccount(
      id: debtId == null || debtId.trim().isEmpty ? _buildId(name) : debtId,
      name: name.trim(),
      debtType: debtType,
      balance: parsedBalance,
      apr: parsedApr,
      minimumPayment: resolvedMinPayment,
      startDate: startDate,
      loanEndDate: debtType == DebtType.loan ? loanEndDate : null,
      minPaymentRule: MinPaymentRule(
        type: debtType == DebtType.loan ? MinPaymentType.fixed : minPaymentType,
        percentage: AmountParser.tryParse(percentage) ?? 1.0,
        floor: AmountParser.tryParse(floor) ?? 25.0,
      ),
      originalBalance: parsedBalance,
      extraPayments: extraPayments ?? const [],
    );

    _repository.saveDebt(debt);
    return debt;
  }

  String _buildId(String name) {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    return normalized.isEmpty ? 'debt-${DateTime.now().millisecondsSinceEpoch}' : normalized;
  }
}
