// SQLite-backed Consent manager for Tempus Victa
import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

class ConsentRecord {
  final String consentId;
  final String scope; // e.g., ai:full, ai:redacted, sync:full, telemetry:usage
  bool granted;
  final String grantedAt;
  final String via;
  final String? notes;

  ConsentRecord({
    required this.consentId,
    required this.scope,
    required this.granted,
    required this.grantedAt,
    required this.via,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'consent_id': consentId,
        'scope': scope,
        'granted': granted,
        'granted_at': grantedAt,
        'via': via,
        'notes': notes,
      };
}

class ConsentManager {
  final Map<String, ConsentRecord> _store = {};
  final String? dbPath;
  final String? storagePath; // backward-compat JSON path
  late final Database? _db;

  ConsentManager({String? dbPath, String? storagePath})
      : dbPath = dbPath ??
            (storagePath != null && !storagePath.endsWith('.json')
                ? storagePath
                : 'build/local_store.db'),
        storagePath = storagePath {
    // If caller explicitly passed a JSON storage path, use legacy JSON mode.
    if (storagePath != null && storagePath.endsWith('.json')) {
      _db = null;
      _loadJson(storagePath);
      return;
    }
    final f = File(this.dbPath!);
    if (!f.existsSync()) {
      f.parent.createSync(recursive: true);
      f.createSync();
    }
    _db = sqlite3.open(this.dbPath!);
    _ensurePragmas();
    _ensureSchema();
    _load();
  }

  void _ensurePragmas() {
    try {
      _db?.execute("PRAGMA journal_mode = WAL;");
      _db?.execute("PRAGMA busy_timeout = 5000;");
    } catch (e) {
      // ignore
    }
  }

  void _ensureSchema() {
    _db?.execute('''
      CREATE TABLE IF NOT EXISTS consents (
        scope TEXT PRIMARY KEY,
        consent_id TEXT,
        granted INTEGER,
        granted_at TEXT,
        via TEXT,
        notes TEXT,
        meta TEXT
      );
    ''');
  }

  void _loadJson(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return;
      final text = f.readAsStringSync();
      final data = jsonDecode(text) as Map<String, dynamic>;
      data.forEach((scope, v) {
        final m = v as Map<String, dynamic>;
        final rec = ConsentRecord(
          consentId: m['consent_id'] ?? 'consent:$scope',
          scope: scope,
          granted: m['granted'] == true,
          grantedAt: m['granted_at'] ?? DateTime.now().toIso8601String(),
          via: m['via'] ?? 'loaded',
          notes: m['notes'],
        );
        _store[scope] = rec;
      });
    } catch (e) {
      // ignore
    }
  }

  void _load() {
    try {
      final rows = _db!.select(
          'SELECT scope,consent_id,granted,granted_at,via,notes,meta FROM consents');
      for (final r in rows) {
        final scope = r['scope'] as String;
        final rec = ConsentRecord(
          consentId: r['consent_id'] as String? ?? 'consent:$scope',
          scope: scope,
          granted: (r['granted'] as int) == 1,
          grantedAt:
              r['granted_at'] as String? ?? DateTime.now().toIso8601String(),
          via: r['via'] as String? ?? 'loaded',
          notes: r['notes'] as String?,
        );
        _store[scope] = rec;
      }
    } catch (e) {
      // ignore load errors
    }
  }

  ConsentRecord grant(
      {required String scope,
      required String via,
      String? notes,
      Map<String, dynamic>? meta}) {
    final id = 'consent:${scope}:${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();
    if (storagePath != null && storagePath!.endsWith('.json')) {
      // Legacy JSON mode
      try {
        final f = File(storagePath!);
        final Map<String, dynamic> data = f.existsSync()
            ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
            : {};
        data[scope] = {
          'consent_id': id,
          'scope': scope,
          'granted': true,
          'granted_at': now,
          'via': via,
          'notes': notes,
          'meta': meta
        };
        if (!f.existsSync()) f.createSync(recursive: true);
        f.writeAsStringSync(jsonEncode(data));
      } catch (e) {
        // ignore
      }
    } else {
      final stmt = _db!.prepare(
          'INSERT OR REPLACE INTO consents (scope,consent_id,granted,granted_at,via,notes,meta) VALUES (?,?,?,?,?,?,?)');
      stmt.execute([
        scope,
        id,
        1,
        now,
        via,
        notes,
        meta != null ? jsonEncode(meta) : null
      ]);
      stmt.dispose();
    }
    final rec = ConsentRecord(
      consentId: id,
      scope: scope,
      granted: true,
      grantedAt: now,
      via: via,
      notes: notes,
    );
    _store[scope] = rec;
    return rec;
  }

  ConsentRecord? getConsent(String scope) => _store[scope];

  ConsentRecord? revoke(String scope, {String? via}) {
    final rec = _store[scope];
    if (rec != null) {
      rec.granted = false;
      if (storagePath != null && storagePath!.endsWith('.json')) {
        try {
          final f = File(storagePath!);
          final Map<String, dynamic> data = f.existsSync()
              ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
              : {};
          data[scope] = {
            'consent_id': rec.consentId,
            'scope': scope,
            'granted': false,
            'granted_at': DateTime.now().toIso8601String(),
            'via': via ?? 'revoke',
            'notes': rec.notes,
            'meta': null
          };
          if (!f.existsSync()) f.createSync(recursive: true);
          f.writeAsStringSync(jsonEncode(data));
        } catch (e) {
          // ignore
        }
      } else {
        final stmt = _db!.prepare(
            'INSERT OR REPLACE INTO consents (scope,consent_id,granted,granted_at,via,notes,meta) VALUES (?,?,?,?,?,?,?)');
        stmt.execute([
          scope,
          rec.consentId,
          0,
          DateTime.now().toIso8601String(),
          via ?? 'revoke',
          rec.notes,
          null
        ]);
        stmt.dispose();
      }
      _store[scope] = rec;
    }
    return rec;
  }

  List<ConsentRecord> listConsents() =>
      List.unmodifiable(_store.values.toList());
}
