import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/services/ai_usage_service.dart';
import 'package:debt_free_app/core/services/financial_summary.dart';
import 'package:firebase_ai/firebase_ai.dart';

class AiInsightService {
  AiInsightService();

  static const String _modelName = 'gemini-2.5-flash';
  static const int _scenarioMaxOutputTokens = 4096;
  static const int _plannerMaxOutputTokens = 4096;
  static const int _advisorMaxOutputTokens = 4096;

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
UK personal finance advisor in a debt management app.

Analyse: debt prioritisation (avalanche vs snowball), cash flow risks, high-APR flags, mortgage overpayment vs debt payoff trade-off, tracking vs budget variances, extra payments direction.
note: remainingCash is already net of all obligations — do NOT subtract debt payments again.

Rules: £GBP; bullet points + short paragraphs; no markdown tables; under 350 words; honest + encouraging; no specific products; end with a one-line disclaimer that this is guidance, not regulated financial advice.
''';

  String _buildUserPrompt(FinancialSummary summary) {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    return '''
Date: $dateStr

${summary.toPromptText()}
What is my optimal strategy to become debt-free?
''';
  }

  static const String _plannerSystemPrompt = '''
UK personal finance planner in a debt management app.

For each what-if event: project financial impact; for pay rises use UK 2025/26 PAYE/NI rates and show net monthly change; for one-offs show cash flow impact that month; flag timing conflicts; suggest priority or deferral; project revised debt-free timeline.
note: remainingCash is already net of all obligations — do NOT subtract debt payments again.

Rules: £GBP; bullet points + labelled lines (no columns/tables); under 450 words; flag negative cash flow clearly; no specific products; end with a one-line disclaimer that this is guidance, not regulated financial advice.
''';

  Future<String> generatePlannerInsight(FinancialSummary summary) async {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    final prompt = '''
Date: $dateStr

${summary.toPromptText()}
Analyse each what-if event. Then give an overall assessment and revised debt-free timeline.
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
UK personal finance advisor in a debt management app.

Answer the user's question concisely. Give a direct answer, key reasoning, a clear recommendation, and 2-3 concrete next steps.
note: remainingCash is already net of all obligations — do NOT subtract debt payments again.

STRICT FORMAT RULES:
- Use £GBP. Use markdown headings (##) and bullet points only. No tables.
- DO NOT show step-by-step calculations or estimate remaining terms per debt — use the figures provided.
- Maximum 350 words. If you exceed this, you will be cut off mid-sentence. Stay well under it.
- No specific product recommendations.
- End with one short italic disclaimer line: this is guidance, not regulated financial advice.
''';

  Future<String> generateAdvisorInsight(
      FinancialSummary summary, String question) async {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    final prompt = '''
Date: $dateStr

${summary.toPromptText()}
$question
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
      // Detect mid-sentence truncation caused by hitting the token limit.
      final candidate = response.candidates.isNotEmpty ? response.candidates.first : null;
      final wasMaxTokens = candidate?.finishReason == FinishReason.maxTokens;
      final trimmed = text.trimRight();
      final endsAbruptly = wasMaxTokens ||
          (!trimmed.endsWith('.') &&
           !trimmed.endsWith('!') &&
           !trimmed.endsWith('?') &&
           !trimmed.endsWith('*') &&
           !trimmed.endsWith(')'));
      final responseText = endsAbruptly
          ? '$trimmed\n\n---\n*Response may have been cut short. Try retrying for a complete answer.*'
          : trimmed;
      final normalizedText = _normalizeResponse(responseText);
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
