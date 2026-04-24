import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/services/ai_usage_service.dart';
import 'package:debt_free_app/core/services/financial_summary.dart';
import 'package:firebase_ai/firebase_ai.dart';

class AiInsightService {
  AiInsightService();

  static const String _modelName = 'gemini-2.5-flash';
  static const int _scenarioMaxOutputTokens = 900;
  static const int _plannerMaxOutputTokens = 1100;
  static const int _advisorMaxOutputTokens = 1200;

  Future<String> generateInsight(FinancialSummary summary) async {
    final prompt = _buildUserPrompt(summary);
    return _generateContent(
      requestType: AiRequestType.scenario,
      systemPrompt: _systemPrompt,
      prompt: prompt,
      maxOutputTokens: _scenarioMaxOutputTokens,
    );
  }

  static const String _systemPrompt = '''
You are a friendly UK personal finance advisor built into a debt management app.
The user will provide their complete financial summary including debts, mortgage, budget, scenario analysis, and recent monthly tracking data.

Your job is to:
1. Analyse their overall financial position
2. Identify which debts to prioritise and why (avalanche vs snowball trade-offs)
3. Flag any concerning patterns (e.g. high APR debts, tight cash flow, unaffordable scenarios)
4. Suggest concrete, actionable steps they could take
5. If they have a mortgage, comment on whether overpayments make sense vs paying off high-APR debts first
6. If monthly tracking data is provided, analyse their actual spending vs budget — highlight categories where they consistently overspend or underspend, and suggest adjustments
7. Comment on any extra debt payments they have been making and whether they should continue or redirect them

Rules:
- Use GBP (£) throughout
- Be concise — use bullet points and short paragraphs
- Never use markdown tables or pipe-delimited table formatting
- For comparisons, use short bullets with one metric per line
- Keep the full response under 350 words unless a calculation needs more detail
- Be encouraging but honest
- Never recommend specific financial products or providers
- Remind them this is guidance, not regulated financial advice
- Focus on what will save them the most money or reduce risk
''';

  String _buildUserPrompt(FinancialSummary summary) {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    return '''
Today's date is $dateStr.

Please analyse my complete financial situation and give me your best advice on the optimal strategy to become debt-free.

${summary.toPromptText()}

Based on all of this, what should I focus on? What's my best path to becoming debt-free?
''';
  }

  static const String _plannerSystemPrompt = '''
You are a friendly UK personal finance planner built into a debt management app.
The user will provide their complete financial summary and a list of "what-if" events they are considering.

Your job is to:
1. Analyse each what-if event and project its financial impact
2. For pay rises: calculate the new monthly take-home after UK PAYE tax, NI, and any student loan deductions, and show the net monthly increase
3. For one-off expenses: show how it affects their cash flow that month and whether they can absorb it, or if it would set back debt repayment
4. For recurring expense changes: project the ongoing monthly impact
5. For extra debt payments: calculate interest saved and time saved on the targeted debt
6. Consider timing conflicts between events (e.g. a holiday booking the same month as a large bill)
7. Suggest which events to prioritise or defer based on their current financial position
8. Project a revised debt-free timeline incorporating the planned events

Rules:
- Use GBP (£) throughout
- Use UK 2025/26 PAYE tax rates and NI thresholds for salary calculations
- Be concise — use bullet points and short paragraphs
- Never use markdown tables or pipe-delimited table formatting
- Present calculations as simple labelled lines, not columns
- Keep the full response under 450 words unless calculations need more detail
- Be encouraging but honest about trade-offs
- Never recommend specific financial products or providers
- Remind them this is guidance, not regulated financial advice
- If an event would put them in negative cash flow, flag it clearly
''';

  Future<String> generatePlannerInsight(FinancialSummary summary) async {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    final prompt = '''
Today's date is $dateStr.

Please analyse my what-if events and tell me how each one would impact my finances. Project the overall effect on my debt-free timeline.

${summary.toPromptText()}

For each event, break down the financial impact. Then give me an overall assessment of what happens if I go ahead with all of them.
''';

    return _generateContent(
      requestType: AiRequestType.planner,
      systemPrompt: _plannerSystemPrompt,
      prompt: prompt,
      maxOutputTokens: _plannerMaxOutputTokens,
    );
  }

  static String _monthName(int month) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month];
  }

  static const String _advisorSystemPrompt = '''
You are a friendly UK personal finance advisor built into a debt management app.
The user will provide their complete financial summary and ask a specific financial question.

Your job is to:
1. Analyse their data thoroughly in the context of the question asked
2. Provide a clear, direct answer with supporting reasoning
3. Show calculations where relevant (e.g. interest comparisons, monthly cost differences)
4. Give a clear recommendation with pros and cons
5. Suggest concrete next steps

Rules:
- Use GBP (£) throughout
- Use current UK financial rates and thresholds where relevant
- Be concise — use bullet points and short paragraphs
- Never use markdown tables or pipe-delimited table formatting
- If you need comparisons, write them as labelled bullet points instead of columns
- Keep the full response under 500 words unless the user asks for detailed calculations
- Be encouraging but honest about trade-offs
- Never recommend specific financial products or providers
- Remind them this is guidance, not regulated financial advice
- Structure your response with clear headings using markdown
''';

  Future<String> generateAdvisorInsight(
      FinancialSummary summary, String question) async {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    final prompt = '''
Today's date is $dateStr.

Here is my complete financial situation:

${summary.toPromptText()}

My question: $question
''';

    return _generateContent(
      requestType: AiRequestType.advisor,
      systemPrompt: _advisorSystemPrompt,
      prompt: prompt,
      maxOutputTokens: _advisorMaxOutputTokens,
    );
  }

  Future<String> _generateContent({
    required AiRequestType requestType,
    required String systemPrompt,
    required String prompt,
    required int maxOutputTokens,
  }) async {
    final usageService = AiUsageService.instance;
    await usageService.initialize(SessionFinancialRepository.instance.database);
    final snapshot = await usageService.currentSnapshot();
    if (snapshot.limitReached) {
      throw AiInsightException(usageService.usageLimitMessage());
    }

    final model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        maxOutputTokens: maxOutputTokens,
      ),
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.isEmpty) {
        throw AiInsightException('No response received from AI.');
      }
      final normalizedText = _normalizeResponse(text);
      await usageService.recordRequest(
        requestType: requestType,
        systemPrompt: systemPrompt,
        prompt: prompt,
        responseText: normalizedText,
      );
      return normalizedText;
    } on FirebaseAIException catch (e) {
      throw AiInsightException('AI request failed: ${e.message}');
    }
  }

  static String _normalizeResponse(String text) {
    final flattenedTables = _flattenMarkdownTables(text);
    return flattenedTables
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _flattenMarkdownTables(String text) {
    final lines = text.split('\n');
    final output = <String>[];
    var index = 0;

    while (index < lines.length) {
      final line = lines[index];
      if (!_looksLikeTableRow(line)) {
        output.add(line);
        index++;
        continue;
      }

      final block = <String>[];
      while (index < lines.length && _looksLikeTableRow(lines[index])) {
        block.add(lines[index]);
        index++;
      }

      if (!_looksLikeMarkdownTable(block)) {
        output.addAll(block);
        continue;
      }

      output.addAll(_convertTableBlock(block));
    }

    return output.join('\n');
  }

  static bool _looksLikeTableRow(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('|') && trimmed.endsWith('|');
  }

  static bool _looksLikeMarkdownTable(List<String> block) {
    if (block.length < 2) return false;
    final separator = block[1].trim();
    return RegExp(r'^\|?(\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?$')
        .hasMatch(separator);
  }

  static List<String> _convertTableBlock(List<String> block) {
    final headers = _parseTableCells(block.first);
    final rows = block.skip(2).map(_parseTableCells).where((cells) => cells.isNotEmpty);
    final converted = <String>[];

    for (final row in rows) {
      final pairs = <String>[];
      for (var i = 0; i < row.length && i < headers.length; i++) {
        final header = headers[i];
        final value = row[i];
        if (header.isEmpty || value.isEmpty) continue;
        pairs.add('$header: $value');
      }
      if (pairs.isNotEmpty) {
        converted.add('- ${pairs.join('; ')}');
      }
    }

    if (converted.isEmpty) {
      converted.addAll(block);
    }

    return converted;
  }

  static List<String> _parseTableCells(String row) {
    final trimmed = row.trim();
    final withoutEdges = trimmed.replaceFirst(RegExp(r'^\|'), '').replaceFirst(RegExp(r'\|$'), '');
    return withoutEdges
        .split('|')
        .map((cell) => cell.trim())
        .toList(growable: false);
  }
}

class AiInsightException implements Exception {
  const AiInsightException(this.message);

  final String message;

  @override
  String toString() => message;
}
