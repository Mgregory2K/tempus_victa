// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


class CommandRoute {
  final String kind; // task|project|reminder|unknown
  final String payload;

  CommandRoute(this.kind, this.payload);
}

class CommandRouter {
  static CommandRoute route(String text) {
    final t = text.trim();
    final lower = t.toLowerCase();

    String stripPrefix(String p) {
      final idx = lower.indexOf(p);
      if (idx == 0) {
        return t.substring(p.length).trim();
      }
      return t;
    }

    if (lower.startsWith('create a task')) {
      return CommandRoute('task', stripPrefix('create a task'));
    }
    if (lower.startsWith('create task')) {
      return CommandRoute('task', stripPrefix('create task'));
    }
    if (lower.startsWith('create a project')) {
      return CommandRoute('project', stripPrefix('create a project'));
    }
    if (lower.startsWith('create project')) {
      return CommandRoute('project', stripPrefix('create project'));
    }
    if (lower.startsWith('create a reminder')) {
      return CommandRoute('reminder', stripPrefix('create a reminder'));
    }
    if (lower.startsWith('create reminder')) {
      return CommandRoute('reminder', stripPrefix('create reminder'));
    }
    return CommandRoute('unknown', t);
  }
}
