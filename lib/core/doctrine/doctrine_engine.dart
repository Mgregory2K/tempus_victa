import 'dart:math';

import '../../services/ai/ai_settings_store.dart';
import '../../services/ai/openai_client.dart';
import '../../services/web/web_search_client.dart';
import '../twin_plus/shaper.dart';
import '../twin_plus/twin_event.dart';
import '../twin_plus/twin_plus_kernel.dart';
import '../twin_plus/router.dart';

import 'doctrine_models.dart';
import 'doctrine_result.dart';

/// Canonical executor for Local → Internet → AI.
///
/// Twin+ decides the *plan* (RoutePlan). DoctrineEngine executes it deterministically.
/// No UI should call OpenAI or WebSearchClient directly once wired.
class DoctrineEngine {
  final TwinPlusKernel kernel;
  final WebSearchClient web;

  DoctrineEngine({
    required this.kernel,
    WebSearchClient? webClient,
  }) : web = webClient ?? WebSearchClient();

  Future<DoctrineResult> execute(DoctrineRequest req) async {
    final sw = Stopwatch()..start();
    final debugTrace = <String>[];

    final intent = req.toQueryIntent();
    final plan = kernel.router.route(intent);

    if (req.devMode) {
      debugTrace.add('surface=${intent.surface}');
      debugTrace.add('decisionId=${plan.decisionId}');
      debugTrace.add('strategy=${plan.strategy}');
      debugTrace.add('verifiabilityW=${plan.verifiabilityW.toStringAsFixed(1)}');
      debugTrace.add('timeSensitivityW=${plan.timeSensitivityW.toStringAsFixed(1)}');
      debugTrace.add('aiAllowed=${plan.aiAllowed}');
      debugTrace.add('aiProvider=${plan.aiProvider}');
      debugTrace.add('budgetTokensMax=${plan.budgetTokensMax}');
      if (plan.reasonCodes.isNotEmpty) {
        debugTrace.add('reasonCodes=' + plan.reasonCodes.join(','));
      }
    }

    kernel.observe(
      TwinEvent.routeChosen(
        surface: intent.surface,
        decisionId: plan.decisionId,
        strategy: plan.strategy,
        verifiabilityW: plan.verifiabilityW,
        timeSensitivityW: plan.timeSensitivityW,
        aiAllowed: plan.aiAllowed,
        provider: plan.aiProvider,
      ),
    );

    // NOTE: Local resolver is intentionally minimal right now.
    // Local-first behavior is preserved by the plan + future resolvers. Today we guarantee never-zero-results.
    String answerText = '';
    final webResults = <DoctrineWebResult>[];
    final fallbackLinks = <String>[];

    // Execute web if strategy includes it or verifiability is non-trivial.
    final needsWeb = plan.strategy.contains('web') || plan.verifiabilityW >= 0.5;
    WebSearchResponse? webResp;
    if (needsWeb) {
      final webSw = Stopwatch()..start();
      webResp = await web.search(intent.queryText, maxLinks: 6);
      webSw.stop();
      if (req.devMode) {
        debugTrace.add('web.ok=${webResp.ok}');
        debugTrace.add('web.links=${webResp.links.length}');
        if (webResp.error != null) debugTrace.add('web.error=${webResp.error}');
        debugTrace.add('web.ms=${webSw.elapsedMilliseconds}');
      }
      if (webResp.ok && webResp.links.isNotEmpty) {
        for (final l in webResp.links) {
          webResults.add(
            DoctrineWebResult(
              title: l.title,
              snippet: l.snippet,
              url: l.url,
              domain: l.domain,
            ),
          );
        }
        kernel.observe(TwinEvent.sourceUsed(surface: intent.surface, decisionId: plan.decisionId, source: 'web'));
      } else {
        // Always provide fallback links when web yields nothing or errors.
        fallbackLinks.addAll(_fallbackLinks(intent.queryText));
        if (req.devMode) debugTrace.add('web.fallbackLinks=${fallbackLinks.length}');
      }
    }

    final aiAllowed = plan.aiAllowed && (plan.aiProvider != 'none');

    // Build inspectable context lines (no hallucinated citations).
    final contextLines = <String>[];
    if (webResults.isNotEmpty) {
      contextLines.add('WEB RESULTS (may be incomplete):');
      for (final r in webResults.take(5)) {
        contextLines.add('- ${r.title}: ${r.snippet} (${r.url})');
      }
    }

    final aiInstructions = _aiInstructionsForSurface(intent.surface);

    if (aiAllowed && plan.strategy.contains('llm')) {
      final settings = await AiSettingsStore.load();
      if (settings.enabled && settings.apiKey != null && settings.model != null) {
        try {
          final client = OpenAiClient(apiKey: settings.apiKey!, model: settings.model!);
          final input = [
            if (contextLines.isNotEmpty) ...contextLines,
            '',
            'USER:',
            intent.queryText,
          ].join('\n');

          final maxTokens = max(120, plan.budgetTokensMax);
          final aiSw = Stopwatch()..start();
          final resp = await client.respondText(
            input: input,
            instructions: aiInstructions,
            maxOutputTokens: maxTokens,
          );
          aiSw.stop();
          answerText = resp.text.trim();
          if (req.devMode) {
            debugTrace.add('ai.used=true');
            debugTrace.add('ai.ms=${aiSw.elapsedMilliseconds}');
          }
          if (answerText.isNotEmpty) {
            kernel.observe(TwinEvent.sourceUsed(surface: intent.surface, decisionId: plan.decisionId, source: 'ai_openai'));
          }
        } catch (e) {
          // Deterministic fallback: if AI fails, rely on web/fallback.
          answerText = '';
          if (req.devMode) debugTrace.add('ai.error=$e');
        }
      }
    }

    if (answerText.isEmpty) {
      // If AI disabled or empty, provide a deterministic response from web or fallback.
      if (webResults.isNotEmpty) {
        answerText = _synthesizeFromWeb(webResults);
      } else {
        if (fallbackLinks.isEmpty) fallbackLinks.addAll(_fallbackLinks(intent.queryText));
        answerText = 'No direct results returned. Try one of these links:';
      }
    }

    // Shape output (Tiny/Short/etc). TwinShaper keeps your global tone rules.
    final shaped = kernel.shaper.shape(
      OutputIntent(
        surface: intent.surface,
        purpose: 'inform',
        draftText: answerText,
      ),
    );

    kernel.observe(
      TwinEvent.actionPerformed(
        surface: intent.surface,
        actor: TwinActor.system,
        action: 'result_shown',
        meta: {'decisionId': plan.decisionId},
      ),
    );

    sw.stop();
    if (req.devMode) debugTrace.add('total.ms=${sw.elapsedMilliseconds}');

    return DoctrineResult(
      decisionId: plan.decisionId,
      text: shaped.text,
      webResults: webResults,
      fallbackLinks: fallbackLinks,
      reasonCodes: plan.reasonCodes,
      debugTrace: req.devMode ? debugTrace : const <String>[],
    );
  }

  static String _aiInstructionsForSurface(String surface) {
    // Keep this minimal and deterministic. TwinShaper does final shaping anyway.
    if (surface == 'ready_room') {
      return 'Answer concisely. Use bullets when appropriate. If you are unsure, say so.';
    }
    return 'Be concise and helpful.';
  }

  static String _synthesizeFromWeb(List<DoctrineWebResult> results) {
    final lines = <String>['Top web hits:'];
    for (final r in results.take(4)) {
      final s = r.snippet.trim();
      lines.add('- ${r.title}${s.isNotEmpty ? ": $s" : ""}');
    }
    return lines.join('\n');
  }

  static List<String> _fallbackLinks(String q) {
    final encoded = Uri.encodeComponent(q);
    return <String>[
      'https://duckduckgo.com/?q=$encoded',
      'https://www.google.com/search?q=$encoded',
    ];
  }
}
