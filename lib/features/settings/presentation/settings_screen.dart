import 'dart:convert';

import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/services/ai_usage_service.dart';
import 'package:debt_free_app/core/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repository = SessionFinancialRepository.instance;
  final _aiUsageService = AiUsageService.instance;

  @override
  void initState() {
    super.initState();
    _aiUsageService.initialize(_repository.database);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            // ── Finance Settings ──
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/settings/finance'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Finance Settings',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              'Budget start month & financial month start day',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── About ──
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/settings/about'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('About',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              'App info & data privacy',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Subscription ──
            ListenableBuilder(
              listenable: SubscriptionService.instance,
              builder: (context, _) {
                final sub = SubscriptionService.instance;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 22,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Subscription',
                              style: theme.textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (sub.isSubscribed)
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 8),
                              const Text('Premium — Active'),
                            ],
                          )
                        else if (sub.isTrialActive) ...[
                          Row(
                            children: [
                              Icon(Icons.timer_outlined,
                                  color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Free Trial — ${sub.trialDaysRemaining} day${sub.trialDaysRemaining == 1 ? '' : 's'} remaining',
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: theme.colorScheme.error, size: 20),
                              const SizedBox(width: 8),
                              const Text('Trial expired'),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (!sub.isSubscribed)
                              FilledButton.icon(
                                onPressed: sub.isStoreAvailable
                                    ? () => sub.purchase()
                                    : null,
                                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                                label: Text(
                                  'From ${sub.monthlyProduct?.price ?? '£3.99'}/month',
                                ),
                              ),
                            if (!sub.isSubscribed)
                              const SizedBox(width: 8),
                            TextButton(
                              onPressed: sub.isStoreAvailable
                                  ? () => sub.restorePurchases()
                                  : null,
                              child: const Text('Restore Purchases'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showFeedbackDialog(context),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.feedback_outlined,
                          size: 20,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submit Bug / Request Feature',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Report an issue or suggest a new feature',
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
            const SizedBox(height: 16),
            // ── Developer Mode ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _repository,
                    SubscriptionService.instance,
                    _aiUsageService,
                  ]),
                  builder: (context, _) {
                    final enabled = _repository.developerModeEnabled;
                    final offset = _repository.developerMonthOffset;
                    final previewDate = _repository.effectiveNow;
                    final previewMonthLabel = DateFormat.yMMMM().format(previewDate);
                    final sub = SubscriptionService.instance;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: [
                            Text(
                              'Developer Mode',
                              style: theme.textTheme.titleLarge,
                            ),
                            const Spacer(),
                            Switch.adaptive(
                              value: enabled,
                              onChanged: (value) async {
                                await _repository.setDeveloperModeEnabled(value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Preview app logic as time moves forward/backward '
                          'without changing your device date.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (enabled) ...[      
                          const SizedBox(height: 16),
                          Text(
                            'Month offset: ${offset >= 0 ? '+' : ''}$offset',
                            style: theme.textTheme.titleSmall,
                          ),
                          Slider(
                            value: offset.toDouble(),
                            min: -12,
                            max: 24,
                            divisions: 36,
                            label: '${offset >= 0 ? '+' : ''}$offset months',
                            onChanged: (value) async {
                              await _repository
                                  .setDeveloperMonthOffset(value.round());
                            },
                          ),
                          Text(
                            'Preview date: ${DateFormat.yMMMd().format(previewDate)} '
                            '($previewMonthLabel)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () async {
                                await _repository.setDeveloperMonthOffset(0);
                              },
                              child: const Text('Reset Offset'),
                            ),
                          ),
                          const Divider(height: 24),
                          Text(
                            'Access state',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<DeveloperAccessScenario>(
                            initialValue: sub.developerAccessScenario,
                            decoration: const InputDecoration(
                              labelText: 'Subscription / trial state',
                              border: OutlineInputBorder(),
                            ),
                            items: DeveloperAccessScenario.values
                                .map(
                                  (scenario) => DropdownMenuItem<DeveloperAccessScenario>(
                                    value: scenario,
                                    child: Text(
                                      _developerAccessScenarioLabel(scenario),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) async {
                              if (value == null) return;
                              await sub.setDeveloperAccessScenario(value);
                              await _aiUsageService.refresh();
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _developerAccessScenarioDescription(
                              sub.developerAccessScenario,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await sub.setDeveloperAccessScenario(
                                  DeveloperAccessScenario.activeTrial,
                                );
                                await _aiUsageService.setTrialUsageExhausted();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Trial exhausted simulated (3/3 prompts)'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18),
                              label: const Text('Simulate trial exhausted'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _aiUsageService.resetAllUsage();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('AI usage counters reset'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Reset AI usage counters'),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFeedbackDialog(BuildContext context) async {
    const _typeBug = 'bug';
    const _typeFeature = 'feature';
    String selectedType = _typeBug;

    final titleController = TextEditingController();
    final stepsController = TextEditingController();
    final expectedController = TextEditingController();
    final actualController = TextEditingController();
    final featureDescController = TextEditingController();
    final useCaseController = TextEditingController();
    String severity = 'Medium';
    String priority = 'Important';
    final theme = Theme.of(context);

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isBug = selectedType == _typeBug;
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isBug ? Icons.bug_report_outlined : Icons.lightbulb_outline_rounded,
                  size: 22,
                  color: isBug ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text('Submit Feedback'),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Type toggle ──
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: _typeBug,
                          label: Text('Bug Report'),
                          icon: Icon(Icons.bug_report_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: _typeFeature,
                          label: Text('Feature Request'),
                          icon: Icon(Icons.lightbulb_outline_rounded, size: 18),
                        ),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (v) =>
                          setDialogState(() => selectedType = v.first),
                    ),
                    const SizedBox(height: 20),
                    // ── Title / Summary ──
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: isBug ? 'Summary' : 'Feature Title',
                        hintText: isBug
                            ? 'e.g. Budget totals wrong after copying month'
                            : 'e.g. Export budgets to CSV',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isBug) ...[
                      // ── Steps to reproduce ──
                      TextField(
                        controller: stepsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Steps to Reproduce',
                          hintText:
                              '1. Go to Budget\n2. Copy month\n3. Totals show incorrectly',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Expected ──
                      TextField(
                        controller: expectedController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Expected Behaviour',
                          hintText: 'What should have happened?',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Actual ──
                      TextField(
                        controller: actualController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Actual Behaviour',
                          hintText: 'What actually happened?',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Severity ──
                      DropdownButtonFormField<String>(
                        value: severity,
                        decoration: const InputDecoration(
                          labelText: 'Severity',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Low', child: Text('Low — minor cosmetic issue')),
                          DropdownMenuItem(value: 'Medium', child: Text('Medium — noticeable but workaround exists')),
                          DropdownMenuItem(value: 'High', child: Text('High — major functionality broken')),
                          DropdownMenuItem(value: 'Critical', child: Text('Critical — app crashes / data loss')),
                        ],
                        onChanged: (v) => setDialogState(() => severity = v!),
                      ),
                    ] else ...[
                      // ── Feature description ──
                      TextField(
                        controller: featureDescController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe what this feature would do.',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Use case ──
                      TextField(
                        controller: useCaseController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Why does this matter?',
                          hintText:
                              'How would this help you or other users?',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Priority ──
                      DropdownButtonFormField<String>(
                        value: priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Nice to have', child: Text('Nice to have')),
                          DropdownMenuItem(value: 'Important', child: Text('Important')),
                          DropdownMenuItem(value: 'Critical', child: Text('Critical to my workflow')),
                        ],
                        onChanged: (v) => setDialogState(() => priority = v!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );

    if (submitted != true || !mounted) return;

    final isBug = selectedType == _typeBug;
    try {
      final body = isBug
          ? {
              '_subject': '[Bug — $severity] ${titleController.text.trim()}',
              'type': 'Bug Report',
              'summary': titleController.text.trim(),
              'steps_to_reproduce': stepsController.text.trim().isEmpty
                  ? '(not provided)'
                  : stepsController.text.trim(),
              'expected_behaviour': expectedController.text.trim().isEmpty
                  ? '(not provided)'
                  : expectedController.text.trim(),
              'actual_behaviour': actualController.text.trim().isEmpty
                  ? '(not provided)'
                  : actualController.text.trim(),
              'severity': severity,
              'app_version': 'Debt Free v1.0.0',
              'platform': 'Windows',
              'date': DateFormat.yMMMd().format(DateTime.now()),
            }
          : {
              '_subject': '[Feature — $priority] ${titleController.text.trim()}',
              'type': 'Feature Request',
              'title': titleController.text.trim(),
              'description': featureDescController.text.trim().isEmpty
                  ? '(not provided)'
                  : featureDescController.text.trim(),
              'why_it_matters': useCaseController.text.trim().isEmpty
                  ? '(not provided)'
                  : useCaseController.text.trim(),
              'priority': priority,
              'app_version': 'Debt Free v1.0.0',
              'platform': 'Windows',
              'date': DateFormat.yMMMd().format(DateTime.now()),
            };

      final response = await http.post(
        Uri.parse('https://formspree.io/f/xnjlvrjq'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isBug ? 'Bug report submitted — thank you!' : 'Feature request submitted — thank you!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to submit (${response.statusCode}). Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not connect. Check your internet and try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatCompact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }
}

class _AiUsageMetric extends StatelessWidget {
  const _AiUsageMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _AiUsageChip extends StatelessWidget {
  const _AiUsageChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _developerAccessScenarioLabel(DeveloperAccessScenario scenario) {
  switch (scenario) {
    case DeveloperAccessScenario.live:
      return 'Live app behaviour';
    case DeveloperAccessScenario.activeTrial:
      return 'Force active trial';
    case DeveloperAccessScenario.trialEndingToday:
      return 'Force last trial day';
    case DeveloperAccessScenario.trialExpired:
      return 'Force trial expired';
    case DeveloperAccessScenario.premium:
      return 'Force premium active';
  }
}

String _developerAccessScenarioDescription(DeveloperAccessScenario scenario) {
  switch (scenario) {
    case DeveloperAccessScenario.live:
      return 'Use the real entitlement state, plus any developer month offset already applied.';
    case DeveloperAccessScenario.activeTrial:
      return 'Pretend the user is mid-trial and still fully entitled.';
    case DeveloperAccessScenario.trialEndingToday:
      return 'Pretend the user is on the final day of their 3-day trial.';
    case DeveloperAccessScenario.trialExpired:
      return 'Pretend the trial has ended so paywall, limits, and expiry messaging can be tested.';
    case DeveloperAccessScenario.premium:
      return 'Pretend the user has an active Premium subscription.';
  }
}
