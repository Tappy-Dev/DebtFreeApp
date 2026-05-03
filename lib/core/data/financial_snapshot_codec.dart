import 'dart:convert';

import 'package:debt_free_app/core/utils/uk_tax_calculator.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/expense.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/simulation/models/scenario_change.dart';

class FinancialSnapshot {
  const FinancialSnapshot({
    required this.debts,
    required this.income,
    required this.expenses,
    this.bills = const <Expense>[],
    required this.scenarioChanges,
    this.mortgage,
  });

  final List<DebtAccount> debts;
  final List<IncomeSource> income;
  final List<Expense> expenses;
  final List<Expense> bills;
  final List<ScenarioChange> scenarioChanges;
  final Mortgage? mortgage;
}

class FinancialSnapshotCodec {
  static String encode(FinancialSnapshot snapshot) {
    return jsonEncode(
      <String, dynamic>{
        'debts': snapshot.debts.map(_debtToJson).toList(growable: false),
        'income': snapshot.income.map(_incomeToJson).toList(growable: false),
        'expenses':
            snapshot.expenses.map(_expenseToJson).toList(growable: false),
        'bills': snapshot.bills.map(_expenseToJson).toList(growable: false),
        'scenarioChanges': snapshot.scenarioChanges
            .map(_scenarioChangeToJson)
            .toList(growable: false),
        if (snapshot.mortgage != null)
          'mortgage': _mortgageToJson(snapshot.mortgage!),
      },
    );
  }

  static FinancialSnapshot decode(String raw) {
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;

    return FinancialSnapshot(
      debts: ((json['debts'] as List<dynamic>? ?? const <dynamic>[]))
          .map((dynamic item) => _debtFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      income: ((json['income'] as List<dynamic>? ?? const <dynamic>[]))
          .map((dynamic item) => _incomeFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      expenses: ((json['expenses'] as List<dynamic>? ?? const <dynamic>[]))
          .map((dynamic item) => _expenseFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      bills: ((json['bills'] as List<dynamic>? ?? const <dynamic>[]))
          .map((dynamic item) => _expenseFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      scenarioChanges:
          ((json['scenarioChanges'] as List<dynamic>? ?? const <dynamic>[]))
              .map(
                (dynamic item) =>
                    _scenarioChangeFromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false),
      mortgage: json['mortgage'] == null
          ? null
          : _mortgageFromJson(json['mortgage'] as Map<String, dynamic>),
    );
  }

  static Map<String, dynamic> _debtToJson(DebtAccount debt) {
    return <String, dynamic>{
      'id': debt.id,
      'name': debt.name,
      'debtType': debt.debtType.name,
      'balance': debt.balance,
      'apr': debt.apr,
      'minimumPayment': debt.minimumPayment,
      'payoffDate': debt.payoffDate?.toIso8601String(),
      'minPaymentType': debt.minPaymentRule.type.name,
      'minPaymentPercentage': debt.minPaymentRule.percentage,
      'minPaymentFloor': debt.minPaymentRule.floor,
      'startDate': debt.startDate?.toIso8601String(),
      'loanEndDate': debt.loanEndDate?.toIso8601String(),
      'originalBalance': debt.originalBalance,
    };
  }

  static DebtAccount _debtFromJson(Map<String, dynamic> json) {
    return DebtAccount(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      debtType: _parseDebtType(json['debtType'] as String?),
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      apr: (json['apr'] as num?)?.toDouble() ?? 0,
      minimumPayment: (json['minimumPayment'] as num?)?.toDouble() ?? 0,
      payoffDate: json['payoffDate'] == null
          ? null
          : DateTime.parse(json['payoffDate'] as String),
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      loanEndDate: json['loanEndDate'] == null
          ? null
          : DateTime.parse(json['loanEndDate'] as String),
      originalBalance: (json['originalBalance'] as num?)?.toDouble(),
      minPaymentRule: MinPaymentRule(
        type: _parseMinPaymentType(json['minPaymentType'] as String?),
        percentage: (json['minPaymentPercentage'] as num?)?.toDouble() ?? 1.0,
        floor: (json['minPaymentFloor'] as num?)?.toDouble() ?? 25.0,
      ),
    );
  }

  static DebtType _parseDebtType(String? value) {
    switch (value) {
      case 'loan':
        return DebtType.loan;
      case 'creditCard':
        return DebtType.creditCard;
      case 'other':
      default:
        return DebtType.other;
    }
  }

  static MinPaymentType _parseMinPaymentType(String? value) {
    switch (value) {
      case 'fixed':
        return MinPaymentType.fixed;
      case 'percentageOfBalance':
        return MinPaymentType.percentageOfBalance;
      case 'interestPlusPercentage':
      default:
        return MinPaymentType.interestPlusPercentage;
    }
  }

  static Map<String, dynamic> _incomeToJson(IncomeSource income) {
    return <String, dynamic>{
      'id': income.id,
      'name': income.name,
      'annualGross': income.annualGross,
      'studentLoanPlan': income.studentLoanPlan.name,
      'monthlyPensionSacrifice': income.monthlyPensionSacrifice,
      'monthlyCarSacrifice': income.monthlyCarSacrifice,
      'monthlyOtherSacrifice': income.monthlyOtherSacrifice,
      'monthlyTaxableBenefits': income.monthlyTaxableBenefits,
      'monthlyNiableBenefits': income.monthlyNiableBenefits,
      'monthlyStudentLoanableBenefits': income.monthlyStudentLoanableBenefits,
    };
  }

  static IncomeSource _incomeFromJson(Map<String, dynamic> json) {
    final planName = json['studentLoanPlan'] as String? ?? 'none';
    final plan = StudentLoanPlan.values.firstWhere(
      (StudentLoanPlan p) => p.name == planName,
      orElse: () => StudentLoanPlan.none,
    );
    return IncomeSource(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      annualGross: (json['annualGross'] as num?)?.toDouble() ??
          ((json['amount'] as num?)?.toDouble() ?? 0) * 12,
      studentLoanPlan: plan,
      monthlyPensionSacrifice:
          (json['monthlyPensionSacrifice'] as num?)?.toDouble() ?? 0,
      monthlyCarSacrifice:
          (json['monthlyCarSacrifice'] as num?)?.toDouble() ?? 0,
      monthlyOtherSacrifice:
          (json['monthlyOtherSacrifice'] as num?)?.toDouble() ?? 0,
      monthlyTaxableBenefits:
          (json['monthlyTaxableBenefits'] as num?)?.toDouble() ?? 0,
      monthlyNiableBenefits:
          (json['monthlyNiableBenefits'] as num?)?.toDouble() ?? 0,
      monthlyStudentLoanableBenefits:
          (json['monthlyStudentLoanableBenefits'] as num?)?.toDouble() ?? 0,
    );
  }

  static Map<String, dynamic> _expenseToJson(Expense expense) {
    return <String, dynamic>{
      'id': expense.id,
      'name': expense.name,
      'amount': expense.amount,
    };
  }

  static Expense _expenseFromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  static Map<String, dynamic> _scenarioChangeToJson(ScenarioChange change) {
    return <String, dynamic>{
      'changeType': change.changeType.name,
      'amount': change.amount,
      'startMonth': change.startMonth,
      'durationInMonths': change.durationInMonths,
      'debtId': change.debtId,
    };
  }

  static ScenarioChange _scenarioChangeFromJson(Map<String, dynamic> json) {
    return ScenarioChange(
      changeType: ChangeType.values.firstWhere(
        (ChangeType type) => type.name == json['changeType'],
        orElse: () => ChangeType.extraPayment,
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      startMonth: (json['startMonth'] as num?)?.toInt() ?? 0,
      durationInMonths: (json['durationInMonths'] as num?)?.toInt(),
      debtId: json['debtId'] as String?,
    );
  }

  static Map<String, dynamic> _mortgageToJson(Mortgage mortgage) {
    return <String, dynamic>{
      'id': mortgage.id,
      'name': mortgage.name,
      'startDateMs': mortgage.startDate.millisecondsSinceEpoch,
      'originalLoanAmount': mortgage.originalLoanAmount,
      'mortgageTermMonths': mortgage.mortgageTermMonths,
      'annualRate': mortgage.annualRate,
      'monthlyPayment': mortgage.monthlyPayment,
      'overpayment': mortgage.overpayment,
      'overpaymentStartDateMs':
          mortgage.overpaymentStartDate?.millisecondsSinceEpoch,
      'paymentDay': mortgage.paymentDay,
      'dealEndDateMs': mortgage.dealEndDate?.millisecondsSinceEpoch,
      'ownershipType': mortgage.ownershipType.name,
      'repaymentType': mortgage.repaymentType.name,
      'ownedSharePercent': mortgage.ownedSharePercent,
      'monthlyRent': mortgage.monthlyRent,
      'monthlyServiceCharge': mortgage.monthlyServiceCharge,
      'monthlyGroundRent': mortgage.monthlyGroundRent,
    };
  }

  static Mortgage _mortgageFromJson(Map<String, dynamic> json) {
    return Mortgage(
      id: json['id'] as String? ?? 'mortgage',
      name: json['name'] as String? ?? 'Mortgage',
      startDate: (json['startDateMs'] as num?) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['startDateMs'] as num).toInt(),
            )
          : DateTime(2024, 1, 1),
      originalLoanAmount:
          (json['originalLoanAmount'] as num?)?.toDouble() ?? 0,
      mortgageTermMonths:
          (json['mortgageTermMonths'] as num?)?.toInt() ?? 360,
      annualRate: (json['annualRate'] as num?)?.toDouble() ?? 0,
      monthlyPayment: (json['monthlyPayment'] as num?)?.toDouble() ?? 0,
      overpayment: (json['overpayment'] as num?)?.toDouble() ?? 0,
      overpaymentStartDate: (json['overpaymentStartDateMs'] as num?) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['overpaymentStartDateMs'] as num).toInt(),
            )
          : null,
      paymentDay: (json['paymentDay'] as num?)?.toInt() ?? 1,
      dealEndDate: (json['dealEndDateMs'] as num?) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['dealEndDateMs'] as num).toInt(),
            )
          : null,
      ownershipType: MortgageOwnershipType.values.firstWhere(
        (type) => type.name == json['ownershipType'],
        orElse: () => MortgageOwnershipType.standard,
      ),
      repaymentType: MortgageRepaymentType.values.firstWhere(
        (type) => type.name == json['repaymentType'],
        orElse: () => MortgageRepaymentType.repayment,
      ),
      ownedSharePercent: (json['ownedSharePercent'] as num?)?.toDouble() ?? 100,
      monthlyRent: (json['monthlyRent'] as num?)?.toDouble() ?? 0,
      monthlyServiceCharge:
          (json['monthlyServiceCharge'] as num?)?.toDouble() ?? 0,
      monthlyGroundRent: (json['monthlyGroundRent'] as num?)?.toDouble() ?? 0,
    );
  }
}
