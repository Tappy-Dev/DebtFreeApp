import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:flutter/material.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _repository = SessionFinancialRepository.instance;

  Future<void> _confirmResetApp(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            size: 40, color: theme.colorScheme.error),
        title: const Text('Reset App?'),
        content: const Text(
          'This will permanently delete all your data — budgets, debts, '
          'mortgage, tracking history, planner events, and settings.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _repository.resetAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App has been reset to factory state.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: ListView(
          children: [
            // ── App Info ──
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Icon(Icons.info_outline_rounded,
                  color: theme.colorScheme.primary),
              title: const Text('Debt Free v1.0.0'),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'Budget tracking, debt repayment strategies, mortgage '
                'overpayment analysis, salary sacrifice modelling, what-if '
                'scenario planning, and AI-powered financial advice — all in '
                'one place.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 32, indent: 20, endIndent: 20),
            // ── Data & Privacy ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Text('Data & Privacy',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'All your financial data is stored locally on this device. '
                'When AI Insights is used, a summary of your financial data is '
                'sent to Google Gemini via Firebase to generate advice. No data '
                'is shared otherwise.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, indent: 20, endIndent: 20),
            const SizedBox(height: 16),
            // ── Reset App ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _confirmResetApp(context),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.restart_alt_rounded,
                            size: 20,
                            color: theme.colorScheme.onError,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reset App',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Erase all data and return to factory state',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
