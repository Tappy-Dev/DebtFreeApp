import 'package:debt_free_app/core/services/financial_summary.dart';
import 'package:firebase_ai/firebase_ai.dart';

class AiInsightService {
  AiInsightService();

  static const String _modelName = 'gemini-2.5-flash';

  Future<String> generateInsight(FinancialSummary summary) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 65536,
      ),
      systemInstruction: Content.system(_systemPrompt),
    );

    final prompt = _buildUserPrompt(summary);

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.isEmpty) {
        throw AiInsightException('No response received from AI.');
      }
      return text;
    } on FirebaseAIException catch (e) {
      throw AiInsightException('AI request failed: ${e.message}');
    }
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
- Be encouraging but honest about trade-offs
- Never recommend specific financial products or providers
- Remind them this is guidance, not regulated financial advice
- If an event would put them in negative cash flow, flag it clearly
''';

  Future<String> generatePlannerInsight(FinancialSummary summary) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 65536,
      ),
      systemInstruction: Content.system(_plannerSystemPrompt),
    );

    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    final prompt = '''
Today's date is $dateStr.

Please analyse my what-if events and tell me how each one would impact my finances. Project the overall effect on my debt-free timeline.

${summary.toPromptText()}

For each event, break down the financial impact. Then give me an overall assessment of what happens if I go ahead with all of them.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.isEmpty) {
        throw AiInsightException('No response received from AI.');
      }
      return text;
    } on FirebaseAIException catch (e) {
      throw AiInsightException('AI request failed: ${e.message}');
    }
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
- Be concise — use bullet points, tables and short paragraphs
- Be encouraging but honest about trade-offs
- Never recommend specific financial products or providers
- Remind them this is guidance, not regulated financial advice
- Structure your response with clear headings using markdown
''';

  Future<String> generateAdvisorInsight(
      FinancialSummary summary, String question) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 65536,
      ),
      systemInstruction: Content.system(_advisorSystemPrompt),
    );

    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    final prompt = '''
Today's date is $dateStr.

Here is my complete financial situation:

${summary.toPromptText()}

My question: $question
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.isEmpty) {
        throw AiInsightException('No response received from AI.');
      }
      return text;
    } on FirebaseAIException catch (e) {
      throw AiInsightException('AI request failed: ${e.message}');
    }
  }
}

class AiInsightException implements Exception {
  const AiInsightException(this.message);

  final String message;

  @override
  String toString() => message;
}
