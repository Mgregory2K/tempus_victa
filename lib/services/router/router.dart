import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:tempus_victa/services/consent/consent.dart';
import 'package:tempus_victa/services/redaction/redaction.dart';

class Policy {
  final bool internetAllowed;
  final bool wifiOnlyForAi;
  final bool syncAllowed;

  Policy(
      {this.internetAllowed = true,
      this.wifiOnlyForAi = false,
      this.syncAllowed = true});
}

class CandidatePlan {
  final String planId;
  final String intent;
  final double confidence;
  final Map<String, dynamic> entities;
  final List<Map<String, dynamic>> actions;
  final List<String> explain;
  final String? provenanceRef;

  CandidatePlan({
    required this.planId,
    required this.intent,
    required this.confidence,
    Map<String, dynamic>? entities,
    List<Map<String, dynamic>>? actions,
    List<String>? explain,
    this.provenanceRef,
  })  : entities = entities ?? {},
        actions = actions ?? [],
        explain = explain ?? [];
}

class DoctrineOutput {
  final String inputId;
  final List<CandidatePlan> candidates;

  DoctrineOutput({required this.inputId, List<CandidatePlan>? candidates})
      : candidates = candidates ?? [];
}

class RouterDecision {
  final String decision; // commit|escalate|ask_user
  final String? itemId;
  final String? reason;

  RouterDecision({required this.decision, this.itemId, this.reason});
}

String _genId(String prefix) {
  final r = Random.secure();
  final bytes = List<int>.generate(12, (_) => r.nextInt(256));
  final token = base64Url.encode(bytes).replaceAll('=', '');
  return '$prefix-$token';
}

/// Simple in-memory store used by Router for persistence in tests.
class LocalStore {
  final Map<String, Map<String, dynamic>> items = {};
  final Map<String, Map<String, dynamic>> provenance = {};
  final String dbPath;
  late final Database _db;

  LocalStore({String? dbPath}) : dbPath = dbPath ?? ':memory:' {
    if (this.dbPath == ':memory:') {
      _db = sqlite3.openInMemory();
    } else {
      final dbFile = File(this.dbPath);
      if (!dbFile.existsSync()) {
        dbFile.parent.createSync(recursive: true);
        dbFile.createSync();
      }
      _db = sqlite3.open(this.dbPath);
    }
    _ensureSchema();
    _loadIntoMemory();
  }

  void _ensureSchema() {
    try {
      _db.execute("PRAGMA journal_mode = WAL;");
      _db.execute("PRAGMA busy_timeout = 5000;");
    } catch (_) {}

    _db.execute('''
      CREATE TABLE IF NOT EXISTS items (
        item_id TEXT PRIMARY KEY,
        type TEXT,
        title TEXT,
        body TEXT,
        status TEXT,
        metadata TEXT,
        created_at TEXT,
        updated_at TEXT,
        source_ref TEXT,
        last_routing TEXT
      );
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS provenance (
        prov_id TEXT PRIMARY KEY,
        input_id TEXT,
        actor TEXT,
        action TEXT,
        payload TEXT,
        explain TEXT,
        timestamp TEXT,
        consent TEXT,
        redacted_payload TEXT,
        redacted_fields TEXT,
        entities TEXT,
        resolved INTEGER DEFAULT 0,
        resolution TEXT
      );
    ''');
    // Ensure DB user_version is set for migrations. Current schema version = 1
    final versionRow = _db.select('PRAGMA user_version');
    int userVer = 0;
    if (versionRow.isNotEmpty) {
      final row = versionRow.first;
      userVer = row['user_version'] as int? ?? 0;
    }
    if (userVer < 1) {
      _db.execute('PRAGMA user_version = 1');
    }
  }

  void _loadIntoMemory() {
    final it = _db.select('SELECT * FROM items');
    for (final row in it) {
      final map = <String, dynamic>{
        'item_id': row['item_id'],
        'type': row['type'],
        'title': row['title'],
        'body': row['body'],
        'status': row['status'],
        'metadata': row['metadata'] != null ? jsonDecode(row['metadata']) : {},
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
        'source_ref': row['source_ref'],
        'last_routing':
            row['last_routing'] != null ? jsonDecode(row['last_routing']) : {}
      };
      items[map['item_id']] = map;
    }
    final pt = _db.select('SELECT * FROM provenance');
    for (final row in pt) {
      final map = <String, dynamic>{
        'prov_id': row['prov_id'],
        'input_id': row['input_id'],
        'actor': row['actor'],
        'action': row['action'],
        'payload': row['payload'] != null ? jsonDecode(row['payload']) : null,
        'explain': row['explain'] != null ? jsonDecode(row['explain']) : null,
        'timestamp': row['timestamp'],
        'consent': row['consent'] != null ? jsonDecode(row['consent']) : null,
        'redacted_payload': row['redacted_payload'] != null
            ? jsonDecode(row['redacted_payload'])
            : null,
        'redacted_fields': row['redacted_fields'] != null
            ? jsonDecode(row['redacted_fields'])
            : null,
        'entities':
            row['entities'] != null ? jsonDecode(row['entities']) : null,
        'resolved': (row['resolved'] as int) == 1,
        'resolution': row['resolution']
      };
      provenance[map['prov_id']] = map;
    }
  }

  String saveItem(Map<String, dynamic> item) {
    final id = item['item_id'] ?? _genId('item');
    item['item_id'] = id;
    item['created_at'] = DateTime.now().toIso8601String();
    item['updated_at'] = DateTime.now().toIso8601String();
    item['metadata'] =
        item['metadata'] != null ? jsonEncode(item['metadata']) : null;
    item['last_routing'] =
        item['last_routing'] != null ? jsonEncode(item['last_routing']) : null;
    final stmt = _db.prepare(
        'INSERT OR REPLACE INTO items (item_id,type,title,body,status,metadata,created_at,updated_at,source_ref,last_routing) VALUES (?,?,?,?,?,?,?,?,?,?)');
    stmt.execute([
      item['item_id'],
      item['type'],
      item['title'],
      item['body'],
      item['status'],
      item['metadata'],
      item['created_at'],
      item['updated_at'],
      item['source_ref'],
      item['last_routing']
    ]);
    stmt.dispose();
    items[id] = Map.from(item);
    return id;
  }

  String saveProvenance(Map<String, dynamic> prov) {
    final id = prov['prov_id'] ?? _genId('prov');
    prov['prov_id'] = id;
    prov['timestamp'] = DateTime.now().toIso8601String();
    final payload =
        prov['payload'] != null ? jsonEncode(prov['payload']) : null;
    final explain =
        prov['explain'] != null ? jsonEncode(prov['explain']) : null;
    final consent =
        prov['consent'] != null ? jsonEncode(prov['consent']) : null;
    final redacted = prov['redacted_payload'] != null
        ? jsonEncode(prov['redacted_payload'])
        : null;
    final redactedFields = prov['redacted_fields'] != null
        ? jsonEncode(prov['redacted_fields'])
        : null;
    final entities =
        prov['entities'] != null ? jsonEncode(prov['entities']) : null;
    final stmt = _db.prepare(
        'INSERT OR REPLACE INTO provenance (prov_id,input_id,actor,action,payload,explain,timestamp,consent,redacted_payload,redacted_fields,entities,resolved,resolution) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)');
    stmt.execute([
      prov['prov_id'],
      prov['input_id'],
      prov['actor'],
      prov['action'],
      payload,
      explain,
      prov['timestamp'],
      consent,
      redacted,
      redactedFields,
      entities,
      prov['resolved'] == true ? 1 : 0,
      prov['resolution']
    ]);
    stmt.dispose();
    provenance[id] = Map.from(prov);
    return id;
  }
}

class Router {
  final double localThreshold;
  final LocalStore store;
  final ConsentManager? consentManager;
  final Redactor? redactor;
  final Policy policy;

  Router(
      {this.localThreshold = 0.7,
      LocalStore? store,
      this.consentManager,
      this.redactor,
      Policy? policy})
      : store = store ?? LocalStore(),
        policy = policy ?? Policy();

  /// Route doctrine output: choose top candidate and either commit locally or escalate.
  RouterDecision route(DoctrineOutput out) {
    if (out.candidates.isEmpty)
      return RouterDecision(decision: 'ask_user', reason: 'no_candidates');
    out.candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    final top = out.candidates.first;

    // Simple rule: if entity priority == urgent, override confidence
    if (top.entities['priority'] == 'urgent') {
      // bump confidence
      final prov = {
        'input_id': out.inputId,
        'actor': 'router',
        'action': 'rule_override',
        'explain': ['priority:urgent -> confidence_override'],
        'candidate': {'plan_id': top.planId}
      };
      store.saveProvenance(prov);
      // commit regardless
      final item = {
        'type': 'task',
        'title': top.entities['title'] ?? top.intent,
        'metadata': top.entities,
        'last_routing': {
          'rule_id': 'rule-urgent',
          'router_decision': 'route_to:inbox:urgent',
          'confidence': top.confidence
        }
      };
      final itemId = store.saveItem(item);
      final provCommit = {
        'input_id': out.inputId,
        'actor': 'router',
        'action': 'commit',
        'candidate': {'plan_id': top.planId, 'confidence': top.confidence},
      };
      final provId = store.saveProvenance(provCommit);
      return RouterDecision(decision: 'commit', itemId: itemId, reason: provId);
    }

    if (top.confidence >= localThreshold) {
      // commit to local store
      final item = {
        'type': 'task',
        'title': top.entities['title'] ?? top.intent,
        'metadata': top.entities,
        'last_routing': {
          'router_decision': 'commit',
          'confidence': top.confidence
        }
      };
      final itemId = store.saveItem(item);
      final prov = {
        'input_id': out.inputId,
        'actor': 'router',
        'action': 'commit',
        'candidate': {'plan_id': top.planId, 'confidence': top.confidence},
      };
      final provId = store.saveProvenance(prov);
      return RouterDecision(decision: 'commit', itemId: itemId, reason: provId);
    }

    // Low confidence -> escalate if policy and consent allow; otherwise ask the user
    if (!policy.internetAllowed) {
      final prov = {
        'input_id': out.inputId,
        'actor': 'router',
        'action': 'internet_blocked',
        'candidate': {'plan_id': top.planId, 'confidence': top.confidence},
      };
      final provId = store.saveProvenance(prov);
      return RouterDecision(decision: 'ask_user', reason: provId);
    }

    // Prefer redacted AI calls when possible
    final consent = consentManager?.getConsent('ai:redacted');

    if (consent != null && consent.granted) {
      // Build redacted payload if redactor available
      Map<String, dynamic> redactedPayload = {};
      List<String> redactedFields = [];
      if (redactor != null) {
        final item = {
          'title': top.entities['title'] ?? top.intent,
          'body': top.entities['body'] ?? top.entities.toString(),
          'metadata': top.entities
        };
        final res = redactor!.redactItem(item);
        redactedPayload = res.payload;
        redactedFields = res.redactedFields;
      } else {
        redactedPayload = {'title': top.entities['title'] ?? top.intent};
      }

      final prov = {
        'input_id': out.inputId,
        'actor': 'router',
        'action': 'escalate',
        'candidate': {'plan_id': top.planId, 'confidence': top.confidence},
        'entities': top.entities,
        'redacted_payload': redactedPayload,
        'redacted_fields': redactedFields,
      };
      final provId = store.saveProvenance(prov);

      return RouterDecision(decision: 'escalate', reason: provId);
    }

    // No consent to escalate -> ask user for clarification
    final prov = {
      'input_id': out.inputId,
      'actor': 'router',
      'action': 'ask_user',
      'candidate': {'plan_id': top.planId, 'confidence': top.confidence},
      'entities': top.entities,
    };
    final provId = store.saveProvenance(prov);

    return RouterDecision(decision: 'ask_user', reason: provId);
  }
}
