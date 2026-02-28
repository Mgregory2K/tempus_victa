import 'package:tempus_victa/services/router/router.dart';

/// Manager to list and resolve `ask_user` provenance entries produced by Router.
class AskUserManager {
  final LocalStore store;
  AskUserManager(this.store);

  List<Map<String, dynamic>> listPending() {
    return store.provenance.values
        .where((p) => p['action'] == 'ask_user' && (p['resolved'] != true))
        .toList();
  }

  /// Accept the asked action: commit item using entities in the provenance.
  String? accept(String provId, {Map<String, dynamic>? overrides}) {
    final prov = store.provenance[provId];
    if (prov == null) return null;
    final entities = prov['entities'] as Map<String, dynamic>? ?? {};
    final title = overrides != null && overrides.containsKey('title')
        ? overrides['title']
        : (entities['title'] ?? entities['text'] ?? 'unspecified');
    final metadata = <String, dynamic>{};
    metadata.addAll(entities);
    if (overrides != null && overrides.containsKey('metadata')) {
      final oMeta = overrides['metadata'] as Map<String, dynamic>?;
      if (oMeta != null) metadata.addAll(oMeta);
    }

    final item = {
      'type': 'task',
      'title': title,
      'metadata': metadata,
      'last_routing': {'router_decision': 'commit_via_user', 'prov_id': provId}
    };
    final itemId = store.saveItem(item);
    final provCommit = {
      'input_id': prov['input_id'],
      'actor': 'user',
      'action': 'commit_via_user',
      'candidate': prov['candidate'],
      'entities': entities,
      'overrides': overrides,
    };
    final provIdNew = store.saveProvenance(provCommit);
    // mark original provenance resolved
    prov['resolved'] = true;
    prov['resolution'] = 'accepted';
    store.provenance[provId] = prov;
    return provIdNew;
  }

  /// Reject the asked action.
  bool reject(String provId) {
    final prov = store.provenance[provId];
    if (prov == null) return false;
    prov['resolved'] = true;
    prov['resolution'] = 'rejected';
    store.provenance[provId] = prov;
    final provReject = {
      'input_id': prov['input_id'],
      'actor': 'user',
      'action': 'reject_via_user',
      'candidate': prov['candidate'],
    };
    store.saveProvenance(provReject);
    return true;
  }
}
