// lib/services/trust/trusted_sources_store.dart
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../providers/db_provider.dart';

/// Local-first Trusted Sources store.
///
/// - Loads a seed JSON from assets (assets/sources_of_truth.json)
/// - Sanitizes domains (porn/illegal/onion) into quarantine
/// - Stores ACTIVE and QUARANTINE into Drift
/// - Enforces cap sizes (approx bytes)
/// - Provides fast weight lookup for web results
class TrustedSourcesStore {
  static const String assetPath = 'assets/sources_of_truth.json';

  // Caps (approximate; enforced by per-row bytesEstimate)
  static const int activeCapBytes = 1 * 1024 * 1024; // 1 MB
  static const int quarantineCapBytes = 5 * 1024 * 1024; // 5 MB

  static const String _metaVersionKey = 'trust.sources.version';
  static const int _version = 1;

  static bool _bootstrapped = false;

  static Future<void> ensureLoaded() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    // If DB already has entries and version matches, skip.
    final v = await DbProvider.db.getMeta(_metaVersionKey);
    if (v == _version.toString()) return;

    await _ingestFromAsset();
    await DbProvider.db.setMeta(_metaVersionKey, _version.toString());
  }

  static Future<void> _ingestFromAsset() async {
    String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (_) {
      // Seed file missing; keep app functional.
      return;
    }

    final decoded = jsonDecode(raw);
    final domains = <Map<String, dynamic>>[];

    if (decoded is Map && decoded['domains'] is List) {
      for (final d in (decoded['domains'] as List)) {
        if (d is Map) domains.add(d.cast<String, dynamic>());
      }
    } else if (decoded is List) {
      // allow list-only format: [{domain, trust, ...}, ...]
      for (final d in decoded) {
        if (d is Map) domains.add(d.cast<String, dynamic>());
      }
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    for (final d in domains) {
      final domainRaw = (d['domain'] ?? d['url'] ?? '').toString().trim();
      final domain = _normalizeDomain(domainRaw);
      if (domain.isEmpty) continue;

      final trust = _clamp01(_asDouble(d['trust'], fallback: 0.55));
      final bias = _clamp01(_asDouble(d['biasRisk'], fallback: 0.25));
      final cat = (d['category'] ?? '').toString().trim();

      final reason = _quarantineReason(domain);
      final bytes = _estimateBytes(domain: domain, category: cat, reason: reason);

      if (reason != null) {
        await DbProvider.db.upsertQuarantinedSource(
          domain: domain,
          reason: reason,
          originalTrust: trust,
          originalBiasRisk: bias,
          originalCategory: cat,
          insertedAt: now,
          bytesEstimate: bytes,
        );
        continue;
      }

      await DbProvider.db.upsertActiveSource(
        domain: domain,
        baseTrust: trust,
        biasRisk: bias,
        category: cat,
        insertedAt: now,
        bytesEstimate: bytes,
      );
    }

    await enforceCaps();
  }

  static Future<void> enforceCaps() async {
    await _capActive();
    await _capQuarantine();
  }

  static Future<void> _capActive() async {
    final total = await DbProvider.db.sumActiveBytes();
    if (total <= activeCapBytes) return;

    // Keep best sources; move overflow to quarantine with reason cap_overflow
    final all = await DbProvider.db.listActiveSourcesForCapping();
    var running = 0;
    for (final s in all) {
      running += s.bytesEstimate;
      if (running <= activeCapBytes) continue;

      await DbProvider.db.moveActiveToQuarantine(
        domain: s.domain,
        reason: 'cap_overflow',
      );
    }
  }

  static Future<void> _capQuarantine() async {
    final total = await DbProvider.db.sumQuarantineBytes();
    if (total <= quarantineCapBytes) return;

    // Delete oldest first when quarantine exceeds cap.
    final all = await DbProvider.db.listQuarantineForCappingOldestFirst();
    var running = 0;
    for (final q in all) {
      running += q.bytesEstimate;
      if (running <= quarantineCapBytes) continue;
      await DbProvider.db.deleteQuarantined(domain: q.domain);
    }
  }

  /// Returns 0.0-1.0 weight for a given url.
  /// If no record, returns null.
  static Future<double?> weightForUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    final d = _extractDomain(url);
    if (d.isEmpty) return null;
    final row = await DbProvider.db.getActiveSource(d);
    if (row == null) return null;

    // Weighting: base trust + reinforcement, mild bias penalty.
    final base = row.baseTrust;
    final reinf = row.reinforcement;
    final biasPenalty = (row.biasRisk * 0.10);
    final w = (base * 0.70) + (reinf.clamp(0.0, 1.0) * 0.25) - biasPenalty;
    return w.clamp(0.0, 1.0);
  }

  static Future<void> reinforceDomain(String url, {double delta = 0.06}) async {
    final d = _extractDomain(url);
    if (d.isEmpty) return;
    await DbProvider.db.bumpActiveSource(domain: d, reinforcementDelta: delta);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static double _asDouble(dynamic v, {required double fallback}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    return double.tryParse(s) ?? fallback;
  }

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  static String _normalizeDomain(String input) {
    var d = input.trim().toLowerCase();
    if (d.isEmpty) return '';
    d = d.replaceAll(RegExp(r'^https?://'), '');
    d = d.replaceAll(RegExp(r'^www\.'), '');
    d = d.split('/').first;
    d = d.split('?').first;
    d = d.split('#').first;
    // strip port
    d = d.split(':').first;
    // basic sanity
    if (!d.contains('.')) return '';
    if (d.length > 253) return '';
    return d;
  }

  static String _extractDomain(String url) {
    try {
      final u = Uri.parse(url);
      final host = (u.host.isNotEmpty) ? u.host : url;
      return _normalizeDomain(host);
    } catch (_) {
      return _normalizeDomain(url);
    }
  }

  static String? _quarantineReason(String domain) {
    final d = domain.toLowerCase();
    if (d.endsWith('.onion')) return 'onion';

    // Porn/explicit keywords
    const porn = [
      'porn',
      'xxx',
      'sex',
      'escort',
      'xnxx',
      'xvideos',
      'redtube',
      'youporn',
      'onlyfans',
      'brazzers',
      'pornhub',
    ];
    for (final k in porn) {
      if (d.contains(k)) return 'porn_keyword';
    }

    // Illegal-ish keywords (lightweight; can evolve)
    const illegal = [
      'pirate',
      'torrents',
      'crack',
      'warez',
      'keygen',
      'hacking',
      'guns',
      'drugs',
    ];
    for (final k in illegal) {
      if (d.contains(k)) return 'illegal_keyword';
    }

    // Suspicious TLDs (very conservative; not ideological)
    const badTlds = ['xxx', 'porn'];
    final tld = d.split('.').last;
    if (badTlds.contains(tld)) return 'porn_tld';

    return null;
  }

  static int _estimateBytes({required String domain, required String category, required String? reason}) {
    // Rough estimate: UTF-16 in Dart, but DB stores UTF-8-ish; we just need stable cap behavior.
    final base = domain.length + category.length + (reason?.length ?? 0);
    // add overhead per row
    return (base * 2) + 80;
  }
}
