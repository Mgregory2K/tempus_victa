class AppCapability {
  final String id;
  final String title;

  /// Where the user can find it (tab / screen / button path).
  final String where;

  /// What it is / what it does (short).
  final String summary;

  /// How to use it (short bullets as plain text).
  final List<String> howTo;

  /// Keywords / synonyms for matching user phrasing.
  final List<String> keywords;

  /// Optional navigation hint (e.g., tab index).
  final int? tabIndex;

  const AppCapability({
    required this.id,
    required this.title,
    required this.where,
    required this.summary,
    required this.howTo,
    required this.keywords,
    this.tabIndex,
  });
}

/// Self-documenting registry.
/// This is NOT hardwiring questions; it is the app describing itself.
/// As new features are added, add one entry here per feature.
class AppCapabilities {
  static const List<AppCapability> all = <AppCapability>[
    AppCapability(
      id: 'ready_room',
      title: 'Ready Room',
      where: 'Bottom tab: Ready Room',
      summary:
          'The command interface and routing layer. It routes Local → Trusted → Web → AI (if enabled).',
      howTo: <String>[
        'Type a question or command in the input bar.',
        'Toggle Web or AI using the icons in the top bar.',
        'Use it to navigate modules, create items, and ask for help.',
      ],
      keywords: <String>[
        'ready room',
        'router',
        'command',
        'chat',
        'help',
        'protocol',
        'ai',
        'web',
        'local first',
        'local-first',
      ],
      tabIndex: 0,
    ),
    AppCapability(
      id: 'signal_bay',
      title: 'Signal Bay',
      where: 'Bottom tab: Signal Bay',
      summary:
          'A triage surface for actionable signals (not noise). Lets you mark important vs ignore.',
      howTo: <String>[
        'Open Signal Bay to see signals ranked by relevance.',
        'Use overrides (important/noise) to teach the system.',
      ],
      keywords: <String>[
        'signal bay',
        'signals',
        'signal',
        'triage',
        'notification',
        'alerts',
        'important',
        'noise',
      ],
      tabIndex: 1,
    ),
    AppCapability(
      id: 'corkboard',
      title: 'Corkboard',
      where: 'Bottom tab: Corkboard',
      summary: 'A visual corkboard for quick capture and organization.',
      howTo: <String>[
        'Add a note to the corkboard.',
        'Reposition and manage items.',
        'Convert items into Actions when needed.',
      ],
      keywords: <String>[
        'corkboard',
        'notes',
        'sticky note',
        'capture',
        'board',
        'post-it',
      ],
      tabIndex: 2,
    ),
    AppCapability(
      id: 'quote_board',
      title: 'Quote Board',
      where: 'Bottom tab: Quote Board',
      summary: 'A lightweight place to capture and search quotes.',
      howTo: <String>[
        'Add a quote manually.',
        'Search your saved quotes.',
      ],
      keywords: <String>[
        'quote board',
        'quotes',
        'quote',
        'save quote',
        'capture quote',
      ],
      tabIndex: 4,
    ),
    AppCapability(
      id: 'actions',
      title: 'Actions',
      where: 'Bottom tab: Actions',
      summary: 'Your task/action list and action sheets.',
      howTo: <String>[
        'Add actions you need to do.',
        'Mark complete or manage details.',
      ],
      keywords: <String>[
        'actions',
        'tasks',
        'to-do',
        'todo',
        'action list',
      ],
      tabIndex: 5,
    ),
    AppCapability(
      id: 'settings',
      title: 'Settings',
      where:
          'AI/Web toggles are in Ready Room (top bar icons). Other settings are stored locally.',
      summary:
          'Configuration: AI enablement, web enablement, and API key storage.',
      howTo: <String>[
        'Enable/disable Web using the Wi-Fi icon in Ready Room.',
        'Enable/disable AI using the robot icon in Ready Room.',
        'Store your API key using the AI settings flow (local-only).',
      ],
      keywords: <String>[
        'settings',
        'configuration',
        'config',
        'preferences',
        'api key',
        'openai key',
        'key',
        'token',
        'model',
        'enable ai',
        'enable web',
        'toggle',
      ],
      tabIndex: null,
    ),
  ];
}
