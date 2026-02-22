import '../ai/ai_settings.dart';
import '../ai/openai_client.dart';
import '../trust/trusted_sources_store.dart';
import '../app_knowledge/app_knowledge.dart';
import '../app_knowledge/local_command_resolver.dart';
import '../app_knowledge/local_action_resolver.dart';
import 'research_settings.dart';
import 'web_search_duckduckgo.dart';

enum RouteStage { local, trusted, web, ai, error }

class RouterItem {
  final RouteStage stage;
  final String title;
  final String body;
  final String? url;

  const RouterItem({
    required this.stage,
    required this.title,
    required this.body,
    this.url,
  });
}

class RouterResult {
  final List<RouterItem> items;
  const RouterResult(this.items);
}

class IntelligenceRouter {
  const IntelligenceRouter();

  /// Canonical pipeline: Local → Trusted → Web → AI (if enabled)
  Future<RouterResult> route(String input) async {
    final q = input.trim();
    if (q.isEmpty) return const RouterResult([]);

    // 0) LOCAL: ACTION CREATION (add action / todo / remind me)
    final actionItems = await LocalActionResolver.tryCreateAction(q);
    if (actionItems != null && actionItems.isNotEmpty) {
      return RouterResult(actionItems);
    }

    // 1) LOCAL COMMANDS (navigation/actions)
    final cmd = await LocalCommandResolver.tryResolve(q);
    if (cmd != null) {
      return RouterResult([
        RouterItem(
          stage: RouteStage.local,
          title: cmd.title,
          body: cmd.body,
          url: cmd.actionUrl, // app://...
        ),
      ]);
    }

    // 2) APP KNOWLEDGE (local-first self-help)
    final help = AppKnowledge.tryAnswer(q);
    if (help != null) {
      return RouterResult([
        RouterItem(
          stage: RouteStage.local,
          title: 'Help',
          body: help,
        ),
      ]);
    }

    final out = <RouterItem>[];

    // 3) LOCAL (stub for now)
    out.add(const RouterItem(
      stage: RouteStage.local,
      title: 'Local',
      body: 'No local command match yet.',
    ));

    // Ensure trusted cache loaded
    try {
      await TrustedSourcesStore.ensureLoaded();
    } catch (_) {}

    // 4) WEB (if enabled)
    final webEnabled = await ResearchSettings.getWebEnabled();
    if (webEnabled) {
      final results = await DuckDuckGoSearch.search(q);
      if (results.isEmpty) {
        out.add(const RouterItem(
          stage: RouteStage.web,
          title: 'Web',
          body: 'No results.',
        ));
      } else {
        for (final r in results.take(6)) {
          out.add(RouterItem(
            stage: RouteStage.web,
            title: r.title.isEmpty ? 'Result' : r.title,
            body: r.snippet.isEmpty ? '—' : r.snippet,
            url: r.url,
          ));
        }
      }
    } else {
      out.add(const RouterItem(
        stage: RouteStage.web,
        title: 'Web',
        body: 'Web is OFF.',
      ));
    }

    // 5) AI (only if enabled)
    final aiEnabled = await AiSettings.getEnabled();
    if (aiEnabled) {
      final r = await OpenAiClient.tryAssistDetailed(
        prompt: q,
        systemHint:
            'You are Tempus Victa Ready Room. Short, correct, local-first. '
            'Never mention search engines. Never output raw JSON.',
      );

      if (r.ok) {
        out.add(RouterItem(
          stage: RouteStage.ai,
          title: 'AI',
          body: r.text!.trim(),
        ));
      } else {
        out.add(RouterItem(
          stage: RouteStage.ai,
          title: 'AI',
          body: r.error ?? 'AI failed.',
        ));
      }
    } else {
      out.add(const RouterItem(
        stage: RouteStage.ai,
        title: 'AI',
        body: 'AI is OFF.',
      ));
    }

    return RouterResult(out);
  }
}
