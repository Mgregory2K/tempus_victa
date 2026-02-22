import '../../data/models/action_item_model.dart';
import '../../data/repos/actions_repo.dart' as data;

/// Bridge/Signals/legacy callers use this static helper.
///
/// IMPORTANT:
/// - Do not change call sites to keep the app stable.
/// - This wrapper routes all captures into the canonical Actions JSONL store
///   used by the Actions (Tasks) screen.
class ActionsRepo {
  static final data.ActionsRepo _repo = data.ActionsRepo();

  /// Default capture behavior per Conception/Textbook:
  /// - capture first
  /// - route later
  /// So we start as [ActionStatus.inbox].
  static Future<void> addAction({
    required String title,
    String? notes,
    DateTime? dueAt,
    String? sourceSignalId,
    String? source,
  }) async {
    await _repo.add(
      title: title,
      notes: notes,
      dueAt: dueAt,
      sourceSignalId: sourceSignalId,
      source: source,
      status: ActionStatus.inbox,
    );
  }
}
