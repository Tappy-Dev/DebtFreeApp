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

    if (!AmountParser.hasMaxDecimalPlaces(value, 2)) {
      return '$fieldName can have at most 2 decimal places.';
    }

    return null;
  }

  String? validateBalance(String? value) {
    final parsedError = validateMoney(value, 'Balance');
    if (parsedError != null) {
      return parsedError;
    }

    final parsed = AmountParser.tryParse(value)!;
    if (parsed <= 0) {
      return 'Balance must be greater than 0.';
    }

    return null;
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

  String? validateAprForDebtType(String? value, DebtType debtType) {
    if (debtType == DebtType.other) {
      return null;
    }
    return validateApr(value);
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
    int paymentDay = 1,
    MinPaymentType minPaymentType = MinPaymentType.interestPlusPercentage,
    String percentage = '1.0',
    String floor = '25',
    DateTime? startDate,
    DateTime? loanEndDate,
    List<DebtExtraPayment>? extraPayments,
  }) {
    final nameError = validateRequired(name, 'Debt name');
    if (nameError != null) {
      throw ArgumentError(nameError);
    }

    final balanceError = validateBalance(balance);
    if (balanceError != null) {
      throw ArgumentError(balanceError);
    }

    if (debtType != DebtType.other) {
      final aprError = validateApr(apr);
      if (aprError != null) {
        throw ArgumentError(aprError);
      }
    }

    if (debtType == DebtType.other ||
        (debtType != DebtType.loan && minPaymentType == MinPaymentType.fixed)) {
      final minPaymentError = validateMinimumPayment(minimumPayment);
      if (minPaymentError != null) {
        throw ArgumentError(minPaymentError);
      }
    }

    if (debtType != DebtType.loan && minPaymentType != MinPaymentType.fixed) {
      final percentageError = validatePercentage(percentage);
      if (percentageError != null) {
        throw ArgumentError(percentageError);
      }
      final floorError = validateFloor(floor);
      if (floorError != null) {
        throw ArgumentError(floorError);
      }
    }

    if (debtType == DebtType.loan) {
      final loanTermError = validateLoanTerm(
        startDate ?? DateTime.now(),
        loanEndDate,
      );
      if (loanTermError != null) {
        throw ArgumentError(loanTermError);
      }
    }

    final parsedBalance = AmountParser.tryParse(balance)!;
    final parsedApr =
        debtType == DebtType.other ? 0.0 : (AmountParser.tryParse(apr) ?? 0.0);
    final resolvedMinPayment = debtType == DebtType.loan
        ? estimateLoanPayment(
              balance: balance,
              apr: apr,
              startDate: startDate ?? DateTime.now(),
              endDate: loanEndDate,
            ) ??
            0
        : debtType == DebtType.other
            ? (AmountParser.tryParse(minimumPayment) ?? 0)
            : AmountParser.tryParse(minimumPayment) ?? 0;
    final debt = DebtAccount(
      id: debtId == null || debtId.trim().isEmpty ? _buildId(name) : debtId,
      name: name.trim(),
      debtType: debtType,
      balance: parsedBalance,
      apr: parsedApr,
      minimumPayment: resolvedMinPayment,
      paymentDay: paymentDay,
      startDate: startDate,
      loanEndDate: debtType == DebtType.loan ? loanEndDate : null,
      minPaymentRule: MinPaymentRule(
        type: debtType == DebtType.loan || debtType == DebtType.other
            ? MinPaymentType.fixed
            : minPaymentType,
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

    return normalized.isEmpty
        ? 'debt-${DateTime.now().millisecondsSinceEpoch}'
        : normalized;
  }
}
