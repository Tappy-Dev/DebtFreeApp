import 'package:debt_free_app/core/data/financial_repository.dart';
import 'package:debt_free_app/core/utils/amount_parser.dart';
import 'package:debt_free_app/core/utils/uk_tax_calculator.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';

enum BudgetItemType {
  income,
  expense,
  bill,
  subscription,
}

class BudgetItemFormController {
  BudgetItemFormController(this._repository);

  final FinancialRepository _repository;

  String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }

    return null;
  }

  String? validateAmount(String? value, String fieldName) {
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

    if (parsed == 0) {
      return '$fieldName must be greater than 0.';
    }

    return null;
  }

  void saveItem({
    required BudgetItemType type,
    String? itemId,
    required String name,
    required String amount,
    bool trackable = false,
    int? paymentDay,
  }) {
    final nameError = validateRequired(name, 'Name');
    if (nameError != null) {
      throw ArgumentError(nameError);
    }
    final amountError = validateAmount(amount, 'Amount');
    if (amountError != null) {
      throw ArgumentError(amountError);
    }

    final monthKey = _repository.activeBudgetMonth;
    final id = itemId == null || itemId.trim().isEmpty
        ? _buildId(type, name, monthKey)
        : itemId;
    final parsedAmount = AmountParser.tryParse(amount)!;
    final trimmedName = name.trim();

    if (type == BudgetItemType.income) {
      _repository.saveIncomeSource(
        IncomeSource(
          id: id,
          name: trimmedName,
          annualGross: parsedAmount,
          monthKey: monthKey,
        ),
      );
      return;
    }

    if (type == BudgetItemType.bill) {
      _repository.saveBill(
        Expense(
          id: id,
          name: trimmedName,
          amount: parsedAmount,
          monthKey: monthKey,
          paymentDay: paymentDay ?? 1,
        ),
      );
      return;
    }

    if (type == BudgetItemType.subscription) {
      _repository.saveBill(
        Expense(
          id: id,
          name: trimmedName,
          amount: parsedAmount,
          monthKey: monthKey,
          isSubscription: true,
          paymentDay: paymentDay ?? 1,
        ),
      );
      return;
    }

    _repository.saveExpense(
      Expense(
        id: id,
        name: trimmedName,
        amount: parsedAmount,
        monthKey: monthKey,
        trackable: trackable,
      ),
    );
  }

  void saveIncomeItem({
    String? itemId,
    required String name,
    required String annualGross,
    required StudentLoanPlan studentLoanPlan,
    String monthlyPensionSacrifice = '0',
    String monthlyCarSacrifice = '0',
    String monthlyOtherSacrifice = '0',
    String monthlyTaxableBenefits = '0',
    String monthlyNiableBenefits = '0',
    String monthlyStudentLoanableBenefits = '0',
  }) {
    final nameError = validateRequired(name, 'Income name');
    if (nameError != null) {
      throw ArgumentError(nameError);
    }
    final grossError = validateAmount(annualGross, 'Annual gross salary');
    if (grossError != null) {
      throw ArgumentError(grossError);
    }

    final pensionError =
        validateNonNegativeMoney(monthlyPensionSacrifice, 'Pension sacrifice');
    if (pensionError != null) {
      throw ArgumentError(pensionError);
    }
    final carError =
        validateNonNegativeMoney(monthlyCarSacrifice, 'Car sacrifice');
    if (carError != null) {
      throw ArgumentError(carError);
    }
    final otherError =
        validateNonNegativeMoney(monthlyOtherSacrifice, 'Other sacrifice');
    if (otherError != null) {
      throw ArgumentError(otherError);
    }
    final taxableError =
        validateNonNegativeMoney(monthlyTaxableBenefits, 'Taxable benefits');
    if (taxableError != null) {
      throw ArgumentError(taxableError);
    }
    final niableError =
        validateNonNegativeMoney(monthlyNiableBenefits, 'NI-able benefits');
    if (niableError != null) {
      throw ArgumentError(niableError);
    }
    final loanableError = validateNonNegativeMoney(
      monthlyStudentLoanableBenefits,
      'Student-loanable benefits',
    );
    if (loanableError != null) {
      throw ArgumentError(loanableError);
    }

    final sacrificeError = validateSalarySacrificeTotal(
      annualGross: annualGross,
      monthlyPensionSacrifice: monthlyPensionSacrifice,
      monthlyCarSacrifice: monthlyCarSacrifice,
      monthlyOtherSacrifice: monthlyOtherSacrifice,
    );
    if (sacrificeError != null) {
      throw ArgumentError(sacrificeError);
    }

    final monthKey = _repository.activeBudgetMonth;
    final id = itemId == null || itemId.trim().isEmpty
        ? _buildId(BudgetItemType.income, name, monthKey)
        : itemId;
    final parsedGross = AmountParser.tryParse(annualGross)!;
    final parsedPensionSacrifice =
        AmountParser.tryParse(monthlyPensionSacrifice) ?? 0;
    final parsedCarSacrifice = AmountParser.tryParse(monthlyCarSacrifice) ?? 0;
    final parsedOtherSacrifice =
        AmountParser.tryParse(monthlyOtherSacrifice) ?? 0;
    final parsedTaxableBenefits =
        AmountParser.tryParse(monthlyTaxableBenefits) ?? 0;
    final parsedNiableBenefits =
        AmountParser.tryParse(monthlyNiableBenefits) ?? 0;
    final parsedStudentLoanableBenefits =
        AmountParser.tryParse(monthlyStudentLoanableBenefits) ?? 0;
    final trimmedName = name.trim();

    _repository.saveIncomeSource(
      IncomeSource(
        id: id,
        name: trimmedName,
        annualGross: parsedGross,
        studentLoanPlan: studentLoanPlan,
        monthlyPensionSacrifice: parsedPensionSacrifice,
        monthlyCarSacrifice: parsedCarSacrifice,
        monthlyOtherSacrifice: parsedOtherSacrifice,
        monthlyTaxableBenefits: parsedTaxableBenefits,
        monthlyNiableBenefits: parsedNiableBenefits,
        monthlyStudentLoanableBenefits: parsedStudentLoanableBenefits,
        monthKey: monthKey,
      ),
    );
  }

  String? validateNonNegativeMoney(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return null;
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

  String? validateSalarySacrificeTotal({
    required String annualGross,
    required String monthlyPensionSacrifice,
    required String monthlyCarSacrifice,
    required String monthlyOtherSacrifice,
  }) {
    final parsedGross = AmountParser.tryParse(annualGross);
    if (parsedGross == null || parsedGross <= 0) {
      return null;
    }

    final totalSacrifice =
        (AmountParser.tryParse(monthlyPensionSacrifice) ?? 0) +
            (AmountParser.tryParse(monthlyCarSacrifice) ?? 0) +
            (AmountParser.tryParse(monthlyOtherSacrifice) ?? 0);

    final grossMonthly = parsedGross / 12;
    if (totalSacrifice > grossMonthly) {
      return 'Total salary sacrifice cannot exceed gross monthly pay.';
    }

    return null;
  }

  String _buildId(BudgetItemType type, String name, String monthKey) {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    final prefix = type == BudgetItemType.income
        ? 'income'
        : type == BudgetItemType.bill
            ? 'bill'
            : type == BudgetItemType.subscription
                ? 'subscription'
                : 'expense';
    return normalized.isEmpty
        ? '$monthKey-$prefix-${DateTime.now().millisecondsSinceEpoch}'
        : '$monthKey-$prefix-$normalized';
  }
}
