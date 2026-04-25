import 'package:debt_free_app/features/budget/domain/budget_snapshot.dart';
import 'package:debt_free_app/features/planner/models/planner_event.dart';
import 'package:debt_free_app/features/simulation/models/debt_account.dart';
import 'package:debt_free_app/features/simulation/models/income_source.dart';
import 'package:debt_free_app/features/simulation/models/mortgage.dart';
import 'package:debt_free_app/features/scenarios/domain/scenario_overview.dart';
import 'package:debt_free_app/features/tracking/models/monthly_budget_summary.dart';

class FinancialSummary {
  const FinancialSummary({
    required this.debts,
    required this.incomeSources,
    required this.mortgage,
    this.mortgages = const <Mortgage>[],
    required this.budgetSnapshot,
    this.scenarioOverview,
    this.recentTracking = const <MonthlyBudgetSummary>[],
    this.plannerEvents = const <PlannerEvent>[],
  });

  final List<DebtAccount> debts;
  final List<IncomeSource> incomeSources;
  final Mortgage? mortgage;
  final List<Mortgage> mortgages;
  final BudgetSnapshot budgetSnapshot;
  final ScenarioOverview? scenarioOverview;
  final List<MonthlyBudgetSummary> recentTracking;
  final List<PlannerEvent> plannerEvents;

  bool get hasMinimumData =>
      incomeSources.isNotEmpty &&
      (debts.isNotEmpty ||
          mortgages.isNotEmpty ||
          mortgage != null);

  String toPromptText() {
    final buffer = StringBuffer();

    buffer.writeln('=== MONTHLY BUDGET ===');
    for (final source in incomeSources) {
      final breakdown = source.payBreakdown();
      buffer.writeln('Income source: ${source.name}');
      buffer.writeln(
        '  Annual gross: £${source.annualGross.toStringAsFixed(2)}',
      );
      buffer.writeln(
        '  Monthly tax: £${breakdown.monthlyTax.toStringAsFixed(2)}',
      );
      buffer.writeln(
        '  Monthly NI: £${breakdown.monthlyNI.toStringAsFixed(2)}',
      );
      if (breakdown.monthlyStudentLoan > 0) {
        buffer.writeln(
          '  Monthly student loan: £${breakdown.monthlyStudentLoan.toStringAsFixed(2)}',
        );
      }
      if (source.monthlySalarySacrificeTotal > 0) {
        buffer.writeln(
          '  Monthly salary sacrifice: £${breakdown.monthlySalarySacrifice.toStringAsFixed(2)}',
        );
        if (source.monthlyPensionSacrifice > 0) {
          buffer.writeln(
            '    - Pension: £${source.monthlyPensionSacrifice.toStringAsFixed(2)}',
          );
        }
        if (source.monthlyCarSacrifice > 0) {
          buffer.writeln(
            '    - Car: £${source.monthlyCarSacrifice.toStringAsFixed(2)}',
          );
        }
        if (source.monthlyOtherSacrifice > 0) {
          buffer.writeln(
            '    - Other: £${source.monthlyOtherSacrifice.toStringAsFixed(2)}',
          );
        }
      }
      if (source.monthlyTaxableBenefits > 0) {
        buffer.writeln(
          '  Monthly taxable benefits: £${source.monthlyTaxableBenefits.toStringAsFixed(2)}',
        );
      }
      if (source.monthlyNiableBenefits > 0) {
        buffer.writeln(
          '  Monthly NI-able benefits: £${source.monthlyNiableBenefits.toStringAsFixed(2)}',
        );
      }
      if (source.monthlyStudentLoanableBenefits > 0) {
        buffer.writeln(
          '  Monthly student-loanable benefits: £${source.monthlyStudentLoanableBenefits.toStringAsFixed(2)}',
        );
      }
      buffer.writeln(
        '  Monthly net take-home: £${breakdown.monthlyNet.toStringAsFixed(2)}',
      );
    }
    buffer.writeln(
      'Total monthly net income: £${budgetSnapshot.totalIncome.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Total monthly bills: £${budgetSnapshot.totalBills.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Total monthly expenses: £${budgetSnapshot.totalExpenses.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Total minimum debt payments: £${budgetSnapshot.totalMinimumPayments.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Mortgage payment: £${budgetSnapshot.mortgagePayment.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Salary sacrifice net cost: £${budgetSnapshot.salarySacrificeNetCost.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Remaining cash (post all deductions): £${budgetSnapshot.remainingCash.toStringAsFixed(2)}',
    );

    buffer.writeln();
    buffer.writeln('=== DEBTS ===');
    if (debts.isEmpty) {
      buffer.writeln('No debts recorded.');
    } else {
      for (final debt in debts) {
        buffer.writeln(
          '- ${debt.name}: balance £${debt.balance.toStringAsFixed(2)}, '
          'APR ${debt.apr.toStringAsFixed(1)}%, '
          'minimum payment £${debt.currentMinPayment().toStringAsFixed(2)}/month',
        );
      }
      final totalDebt = debts.fold<double>(
        0,
        (sum, d) => sum + d.balance,
      );
      buffer.writeln(
        'Total debt: £${totalDebt.toStringAsFixed(2)}',
      );
    }

    final effectiveMortgages = mortgages.isNotEmpty
        ? mortgages
        : (mortgage == null ? const <Mortgage>[] : <Mortgage>[mortgage!]);

    buffer.writeln();
    buffer.writeln('=== MORTGAGES ===');
    if (effectiveMortgages.isEmpty) {
      buffer.writeln('No mortgages recorded.');
    } else {
      for (final m in effectiveMortgages) {
        buffer.writeln('- ${m.name}');
        buffer.writeln('  Balance: £${m.balance.toStringAsFixed(2)}');
        buffer.writeln('  Annual rate: ${m.annualRate.toStringAsFixed(2)}%');
        buffer.writeln('  Monthly payment: £${m.monthlyPayment.toStringAsFixed(2)}');
        buffer.writeln('  Remaining term: ${m.remainingTermMonths} months');
        if (m.overpayment > 0) {
          buffer.writeln(
            '  Current overpayment: £${m.overpayment.toStringAsFixed(2)}/month',
          );
        }
      }
      final totalMortgageBalance =
          effectiveMortgages.fold<double>(0, (sum, m) => sum + m.balance);
      buffer.writeln('Total mortgage balance: £${totalMortgageBalance.toStringAsFixed(2)}');
    }

    if (scenarioOverview != null) {
      buffer.writeln();
      buffer.writeln('=== CURRENT SCENARIO ANALYSIS ===');
      final overview = scenarioOverview!;
      buffer.writeln(
        'Baseline payoff date: ${overview.baselinePayoffDateLabel}',
      );
      buffer.writeln(
        'Scenario payoff date: ${overview.scenarioPayoffDateLabel}',
      );
      buffer.writeln(
        'Baseline total interest: £${overview.baselineInterest.toStringAsFixed(2)}',
      );
      buffer.writeln(
        'Scenario total interest: £${overview.scenarioInterest.toStringAsFixed(2)}',
      );
      buffer.writeln('Months saved: ${overview.monthsSaved}');
      buffer.writeln(
        'Interest saved: £${overview.interestSaved.toStringAsFixed(2)}',
      );
      if (overview.hasActiveChanges) {
        buffer.writeln('Active scenario changes:');
        for (final label in overview.activeChangeLabels) {
          buffer.writeln('  - $label');
        }
      }
      buffer.writeln(
        'Affordable: ${overview.isAffordable ? 'Yes' : 'No'}',
      );
    }

    if (recentTracking.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('=== RECENT MONTHLY TRACKING ===');
      for (final month in recentTracking) {
        final label =
            '${_monthName(month.period.month)} ${month.period.year}';
        final status = month.period.isClosed ? 'closed' : 'open';
        buffer.writeln('--- $label ($status) ---');
        buffer.writeln(
          'Income: actual £${month.totalActualIncome.toStringAsFixed(2)} '
          'vs budgeted £${month.totalBudgetedIncome.toStringAsFixed(2)}',
        );
        buffer.writeln(
          'Bills: actual £${month.totalActualBills.toStringAsFixed(2)} '
          'vs budgeted £${month.totalBudgetedBills.toStringAsFixed(2)}',
        );
        buffer.writeln(
          'Expenses: actual £${month.totalActualExpenses.toStringAsFixed(2)} '
          'vs budgeted £${month.totalBudgetedExpenses.toStringAsFixed(2)}',
        );
        buffer.writeln(
          'Extra debt payments: actual £${month.totalActualDebtPayments.toStringAsFixed(2)} '
          'vs budgeted £${month.totalBudgetedDebtPayments.toStringAsFixed(2)}',
        );
        buffer.writeln(
          'Net variance: £${month.netVariance.toStringAsFixed(2)} '
          '(${month.isOverBudget ? 'OVER budget' : 'on track'})',
        );

        // Show per-item detail for items with actuals entered
        final entered = month.actuals.where((a) => a.actual > 0).toList()
          ..sort(
            (a, b) => (b.actual - b.budgeted)
                .abs()
                .compareTo((a.actual - a.budgeted).abs()),
          );
        if (entered.isNotEmpty) {
          for (final a in entered.take(6)) {
            final diff = a.actual - a.budgeted;
            final diffLabel = diff >= 0
                ? '+£${diff.toStringAsFixed(2)}'
                : '-£${diff.abs().toStringAsFixed(2)}';
            buffer.writeln(
              '  ${a.categoryName}: £${a.actual.toStringAsFixed(2)} '
              '(budget £${a.budgeted.toStringAsFixed(2)}, $diffLabel)',
            );
          }
          if (entered.length > 6) {
            buffer.writeln(
              '  ${entered.length - 6} more tracked categories omitted for brevity.',
            );
          }
        }
      }
    }

    if (plannerEvents.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('=== PLANNED WHAT-IF EVENTS ===');
      for (final event in plannerEvents) {
        buffer.writeln(
          '- ${event.title} (${event.typeLabel}): '
          '£${event.amount.toStringAsFixed(2)} '
          '${event.isRecurring ? "recurring from" : "in"} '
          '${event.scheduledLabel}',
        );
        if (event.notes.isNotEmpty) {
          buffer.writeln('  Notes: ${event.notes}');
        }
      }
    }

    return buffer.toString();
  }

  static String _monthName(int month) {
    const names = <String>[
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month];
  }
}
