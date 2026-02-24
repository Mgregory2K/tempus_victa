import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Local-first store for Sources of Truth.
///
/// - Seeded from a bundled snapshot (see [_seedJson]).
/// - Lives in app documents directory so it can grow over time.
/// - Not AI-dependent.
class SourcesOfTruthStore {
  // Keep this list bounded. It's a hint list, not an ever-growing archive.
  static const int maxDomains = 250;
  static const int maxEvents = 600;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/tempus/sources');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return File('${folder.path}/sources_of_truth.json');
  }

  static Future<void> ensureSeeded() async {
    final f = await _file();
    if (await f.exists()) return;
    await f.writeAsString(_seedJson, flush: true);
  }

  static Future<Map<String, dynamic>> load() async {
    final f = await _file();
    if (!await f.exists()) {
      await ensureSeeded();
    }
    final raw = await f.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return <String, dynamic>{'version': 1, 'domains': <dynamic>[]};
  }

  static Future<void> save(Map<String, dynamic> data) async {
    final f = await _file();
    final pruned = _prune(data);
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(pruned), flush: true);
  }

  static Future<void> upsertDomain(Map<String, dynamic> domainEntry) async {
    await ensureSeeded();
    final data = await load();
    final list = (data['domains'] is List) ? (data['domains'] as List) : <dynamic>[];
    final domain = _normalizeDomain((domainEntry['domain'] ?? '').toString());
    if (domain.isEmpty) return;

    int idx = -1;
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is Map && _normalizeDomain('${item['domain'] ?? ''}') == domain) {
        idx = i;
        break;
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    if (idx >= 0) {
      final existing = (list[idx] is Map) ? (list[idx] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final merged = <String, dynamic>{...existing, ...domainEntry, 'domain': domain};
      // Preserve usage counters unless explicitly provided.
      merged['uses'] = domainEntry.containsKey('uses') ? domainEntry['uses'] : (existing['uses'] ?? 0);
      merged['lastUsedAtUtc'] = domainEntry.containsKey('lastUsedAtUtc')
          ? domainEntry['lastUsedAtUtc']
          : (existing['lastUsedAtUtc'] ?? existing['updatedAtUtc']);
      merged['createdAtUtc'] = existing['createdAtUtc'] ?? now;
      merged['updatedAtUtc'] = now;
      list[idx] = merged;
    } else {
      list.insert(0, {
        ...domainEntry,
        'domain': domain,
        'uses': domainEntry['uses'] ?? 0,
        'createdAtUtc': now,
        'updatedAtUtc': now,
        'lastUsedAtUtc': domainEntry['lastUsedAtUtc'] ?? now,
      });
    }

    data['domains'] = list;
    data['generatedAtUtc'] = DateTime.now().toUtc().toIso8601String();
    await save(data);
  }

  /// Bookkeeping: call when a domain is shown to the user.
  static Future<void> markDomainUsed(String domain, {int bump = 1}) async {
    final d = _normalizeDomain(domain);
    if (d.isEmpty) return;

    final data = await load();
    final list = (data['domains'] is List) ? (data['domains'] as List) : <dynamic>[];
    int idx = -1;
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is Map && _normalizeDomain('${item['domain'] ?? ''}') == d) {
        idx = i;
        break;
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    if (idx >= 0) {
      final existing = (list[idx] is Map) ? (list[idx] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final uses = (existing['uses'] is num) ? (existing['uses'] as num).toInt() : int.tryParse('${existing['uses']}') ?? 0;
      list[idx] = {
        ...existing,
        'domain': d,
        'uses': uses + bump,
        'lastUsedAtUtc': now,
        'updatedAtUtc': now,
      };
    } else {
      list.insert(0, {
        'domain': d,
        'trust': 0.5,
        'notes': 'Observed from web results',
        'uses': bump,
        'createdAtUtc': now,
        'updatedAtUtc': now,
        'lastUsedAtUtc': now,
      });
    }

    data['domains'] = list;
    data['generatedAtUtc'] = now;
    await save(data);
  }

  static Future<Set<String>> trustedDomains({double minTrust = 0.75}) async {
    final data = await load();
    final list = (data['domains'] is List) ? (data['domains'] as List) : const [];
    final out = <String>{};
    for (final e in list) {
      if (e is! Map) continue;
      final m = e.cast<String, dynamic>();
      final trust = (m['trust'] is num) ? (m['trust'] as num).toDouble() : double.tryParse('${m['trust']}') ?? 0.0;
      if (trust < minTrust) continue;
      final dom = _normalizeDomain('${m['domain'] ?? ''}');
      if (dom.isNotEmpty) out.add(dom);
    }
    return out;
  }

  static Map<String, dynamic> _prune(Map<String, dynamic> data) {
    // Domains: keep most-used, then most-recent.
    final domains = (data['domains'] is List) ? [...(data['domains'] as List)] : <dynamic>[];
    domains.sort((a, b) {
      if (a is! Map || b is! Map) return 0;
      final am = a.cast<String, dynamic>();
      final bm = b.cast<String, dynamic>();
      final au = (am['uses'] is num) ? (am['uses'] as num).toInt() : int.tryParse('${am['uses']}') ?? 0;
      final bu = (bm['uses'] is num) ? (bm['uses'] as num).toInt() : int.tryParse('${bm['uses']}') ?? 0;
      if (au != bu) return bu.compareTo(au);
      final al = (am['lastUsedAtUtc'] ?? am['updatedAtUtc'] ?? am['createdAtUtc'] ?? '').toString();
      final bl = (bm['lastUsedAtUtc'] ?? bm['updatedAtUtc'] ?? bm['createdAtUtc'] ?? '').toString();
      return bl.compareTo(al);
    });
    if (domains.length > maxDomains) domains.removeRange(maxDomains, domains.length);
    data['domains'] = domains;

    // Events: keep most-recent.
    final events = (data['events'] is List) ? [...(data['events'] as List)] : <dynamic>[];
    events.sort((a, b) {
      if (a is! Map || b is! Map) return 0;
      final am = a.cast<String, dynamic>();
      final bm = b.cast<String, dynamic>();
      final al = (am['updatedAtUtc'] ?? am['createdAtUtc'] ?? '').toString();
      final bl = (bm['updatedAtUtc'] ?? bm['createdAtUtc'] ?? '').toString();
      return bl.compareTo(al);
    });
    if (events.length > maxEvents) events.removeRange(maxEvents, events.length);
    data['events'] = events;

    return data;
  }

  static String _normalizeDomain(String d) {
    var s = d.trim().toLowerCase();
    if (s.startsWith('http://')) s = s.substring(7);
    if (s.startsWith('https://')) s = s.substring(8);
    if (s.startsWith('www.')) s = s.substring(4);
    final slash = s.indexOf('/');
    if (slash >= 0) s = s.substring(0, slash);
    return s;
  }
}

const String _seedJson = r'''{
"version": 1,
"generatedAtUtc": "2026-02-18T14:52:00Z",
"domains": [
{
"domain": "congress.gov",
"trust": 0.95,
"category": "government",
"biasRisk": 0.1,
"primaryUse": "US legislation",
"notes": "Bills, laws, and congressional records"
},
{
"domain": "govinfo.gov",
"trust": 0.95,
"category": "government",
"biasRisk": 0.1,
"primaryUse": "US official publications",
"notes": "Statutes, CFR, and official documents"
},
{
"domain": "supremecourt.gov",
"trust": 0.95,
"category": "government",
"biasRisk": 0.1,
"primaryUse": "US Supreme Court",
"notes": "Opinions, orders, and rules"
},
{
"domain": "uscourts.gov",
"trust": 0.93,
"category": "government",
"biasRisk": 0.1,
"primaryUse": "US federal judiciary",
"notes": "Court info and resources"
},
{
"domain": "sec.gov",
"trust": 0.96,
"category": "government",
"biasRisk": 0.15,
"primaryUse": "Securities filings",
"notes": "EDGAR filings, rules, enforcement"
},
{
"domain": "census.gov",
"trust": 0.96,
"category": "government",
"biasRisk": 0.05,
"primaryUse": "Demographic/economic stats",
"notes": "Official census and surveys"
},
{
"domain": "bls.gov",
"trust": 0.96,
"category": "government",
"biasRisk": 0.05,
"primaryUse": "Labor statistics",
"notes": "Employment, CPI, methodology"
},
{
"domain": "bea.gov",
"trust": 0.95,
"category": "government",
"biasRisk": 0.05,
"primaryUse": "National accounts",
"notes": "GDP, trade, and accounts data"
},
{
"domain": "federalreserve.gov",
"trust": 0.96,
"category": "government",
"biasRisk": 0.1,
"primaryUse": "Monetary policy",
"notes": "Fed releases, data, research"
},
{
"domain": "stlouisfed.org",
"trust": 0.9,
"category": "financial",
"biasRisk": 0.1,
"primaryUse": "Economic data",
"notes": "FRED data portal and research"
},
{
"domain": "irs.gov",
"trust": 0.95,
"category": "government",
"biasRisk": 0.15,
"primaryUse": "Tax guidance",
"notes": "Forms and official instructions"
},
{
"domain": "uspto.gov",
"trust": 0.94,
"category": "government",
"biasRisk": 0.1,
"primaryUse": "Patents/trademarks",
"notes": "USPTO databases and guidance"
},
{
"domain": "cdc.gov",
"trust": 0.97,
"category": "health",
"biasRisk": 0.1,
"primaryUse": "Public health guidance",
"notes": "Disease info, surveillance, advisories"
},
{
"domain": "nih.gov",
"trust": 0.97,
"category": "health",
"biasRisk": 0.05,
"primaryUse": "Biomedical research",
"notes": "NIH programs and research resources"
},
{
"domain": "fda.gov",
"trust": 0.97,
"category": "health",
"biasRisk": 0.1,
"primaryUse": "Drug/device regulation",
"notes": "Approvals, safety alerts, labeling"
},
{
"domain": "cisa.gov",
"trust": 0.96,
"category": "government",
"biasRisk": 0.1,
"primaryUse": "Cyber advisories",
"notes": "Vuln alerts and security guidance"
},
{
"domain": "nist.gov",
"trust": 0.98,
"category": "standards",
"biasRisk": 0.05,
"primaryUse": "Cyber/measurement standards",
"notes": "NIST frameworks and publications"
},
{
"domain": "noaa.gov",
"trust": 0.96,
"category": "government",
"biasRisk": 0.05,
"primaryUse": "Weather/climate data",
"notes": "Forecasts, climate datasets"
},
{
"domain": "nasa.gov",
"trust": 0.96,
"category": "government",
"biasRisk": 0.05,
"primaryUse": "Science/space data",
"notes": "Mission data and publications"
},
{
"domain": "mit.edu",
"trust": 0.88,
"category": "academic",
"biasRisk": 0.15,
"primaryUse": "Technical research",
"notes": "University labs and publications"
},
{
"domain": "stanford.edu",
"trust": 0.88,
"category": "academic",
"biasRisk": 0.15,
"primaryUse": "Technical research",
"notes": "University labs and publications"
},
{
"domain": "harvard.edu",
"trust": 0.88,
"category": "academic",
"biasRisk": 0.15,
"primaryUse": "Academic research",
"notes": "Research outputs and references"
},
{
"domain": "berkeley.edu",
"trust": 0.88,
"category": "academic",
"biasRisk": 0.15,
"primaryUse": "Academic research",
"notes": "Research outputs and references"
},
{
"domain": "cmu.edu",
"trust": 0.88,
"category": "academic",
"biasRisk": 0.1,
"primaryUse": "Computer science research",
"notes": "Reports and datasets"
},
{
"domain": "cornell.edu",
"trust": 0.86,
"category": "academic",
"biasRisk": 0.1,
"primaryUse": "Academic + legal resources",
"notes": "University research and archives"
},
{
"domain": "iso.org",
"trust": 0.93,
"category": "standards",
"biasRisk": 0.05,
"primaryUse": "International standards",
"notes": "ISO standards catalog and guidance"
},
{
"domain": "iec.ch",
"trust": 0.92,
"category": "standards",
"biasRisk": 0.05,
"primaryUse": "Electrical standards",
"notes": "IEC standards and publications"
},
{
"domain": "itu.int",
"trust": 0.9,
"category": "standards",
"biasRisk": 0.05,
"primaryUse": "Telecom standards",
"notes": "ITU recommendations and reports"
},
{
"domain": "ieee.org",
"trust": 0.88,
"category": "standards",
"biasRisk": 0.1,
"primaryUse": "Engineering standards",
"notes": "Standards and proceedings"
},
{
"domain": "ietf.org",
"trust": 0.95,
"category": "standards",
"biasRisk": 0.05,
"primaryUse": "Internet standards",
"notes": "Working groups and drafts"
},
{
"domain": "rfc-editor.org",
"trust": 0.95,
"category": "standards",
"biasRisk": 0.05,
"primaryUse": "RFC canonical text",
"notes": "RFC publication source"
},
{
"domain": "w3.org",
"trust": 0.94,
"category": "standards",
"biasRisk": 0.05,
"primaryUse": "Web standards",
"notes": "Specs and recommendations"
},
{
"domain": "iana.org",
"trust": 0.93,
"category": "standards",
"biasRisk": 0.05,
"primaryUse": "Protocol registries",
"notes": "Numbers, registries, assignments"
},
{
"domain": "cve.org",
"trust": 0.92,
"category": "standards",
"biasRisk": 0.05,
"primaryUse": "Vulnerability identifiers",
"notes": "CVE program and IDs"
},
{
"domain": "mitre.org",
"trust": 0.9,
"category": "standards",
"biasRisk": 0.1,
"primaryUse": "ATT&CK knowledge base",
"notes": "Threat frameworks and research"
},
{
"domain": "cisecurity.org",
"trust": 0.85,
"category": "standards",
"biasRisk": 0.1,
"primaryUse": "Security benchmarks",
"notes": "CIS controls and benchmarks"
},
{
"domain": "owasp.org",
"trust": 0.85,
"category": "standards",
"biasRisk": 0.1,
"primaryUse": "AppSec guidance",
"notes": "Top risks and testing guides"
},
{
"domain": "pcisecuritystandards.org",
"trust": 0.9,
"category": "standards",
"biasRisk": 0.05,
"primaryUse": "Payment security standards",
"notes": "PCI DSS and related standards"
},
{
"domain": "arxiv.org",
"trust": 0.8,
"category": "research",
"biasRisk": 0.1,
"primaryUse": "Preprints",
"notes": "Research preprint repository"
},
{
"domain": "nature.com",
"trust": 0.78,
"category": "research",
"biasRisk": 0.15,
"primaryUse": "Journals",
"notes": "Peer-reviewed research publisher"
},
{
"domain": "science.org",
"trust": 0.8,
"category": "research",
"biasRisk": 0.15,
"primaryUse": "Journals",
"notes": "AAAS news and journals"
},
{
"domain": "rand.org",
"trust": 0.82,
"category": "research",
"biasRisk": 0.35,
"primaryUse": "Policy research",
"notes": "Reports and analyses"
},
{
"domain": "pewresearch.org",
"trust": 0.85,
"category": "research",
"biasRisk": 0.25,
"primaryUse": "Survey research",
"notes": "Methodology-led public datasets"
},
{
"domain": "ourworldindata.org",
"trust": 0.72,
"category": "research",
"biasRisk": 0.25,
"primaryUse": "Curated datasets",
"notes": "Global data with sources"
},
{
"domain": "cochranelibrary.com",
"trust": 0.85,
"category": "health",
"biasRisk": 0.1,
"primaryUse": "Evidence reviews",
"notes": "Systematic reviews and meta-analyses"
},
{
"domain": "nejm.org",
"trust": 0.85,
"category": "health",
"biasRisk": 0.1,
"primaryUse": "Medical journal",
"notes": "Peer-reviewed clinical research"
},
{
"domain": "thelancet.com",
"trust": 0.82,
"category": "health",
"biasRisk": 0.15,
"primaryUse": "Medical journal",
"notes": "Peer-reviewed clinical research"
},
{
"domain": "wikipedia.org",
"trust": 0.65,
"category": "encyclopedic",
"biasRisk": 0.25,
"primaryUse": "General reference",
"notes": "Useful overview; verify citations"
},
{
"domain": "britannica.com",
"trust": 0.75,
"category": "encyclopedic",
"biasRisk": 0.15,
"primaryUse": "Encyclopedia",
"notes": "Edited reference articles"
},
{
"domain": "reuters.com",
"trust": 0.82,
"category": "journalism",
"biasRisk": 0.2,
"primaryUse": "Breaking news",
"notes": "Wire reporting and updates"
},
{
"domain": "apnews.com",
"trust": 0.8,
"category": "journalism",
"biasRisk": 0.2,
"primaryUse": "Breaking news",
"notes": "Associated Press reporting"
},
{
"domain": "bbc.com",
"trust": 0.78,
"category": "journalism",
"biasRisk": 0.25,
"primaryUse": "International news",
"notes": "Broad reporting and explainers"
},
{
"domain": "wsj.com",
"trust": 0.78,
"category": "journalism",
"biasRisk": 0.25,
"primaryUse": "Business news",
"notes": "Market and business reporting"
},
{
"domain": "ft.com",
"trust": 0.78,
"category": "journalism",
"biasRisk": 0.25,
"primaryUse": "Financial news",
"notes": "Business reporting and analysis"
},
{
"domain": "bloomberg.com",
"trust": 0.78,
"category": "journalism",
"biasRisk": 0.25,
"primaryUse": "Markets news",
"notes": "Business and market coverage"
},
{
"domain": "propublica.org",
"trust": 0.78,
"category": "journalism",
"biasRisk": 0.35,
"primaryUse": "Investigations",
"notes": "Investigative journalism and datasets"
},
{
"domain": "github.com",
"trust": 0.55,
"category": "community",
"biasRisk": 0.2,
"primaryUse": "Source code",
"notes": "Repo docs; verify maintainers"
},
{
"domain": "stackoverflow.com",
"trust": 0.45,
"category": "community",
"biasRisk": 0.25,
"primaryUse": "Q&A",
"notes": "Practical answers; not authoritative"
},
{
"domain": "serverfault.com",
"trust": 0.45,
"category": "community",
"biasRisk": 0.25,
"primaryUse": "Sysadmin Q&A",
"notes": "Operations troubleshooting discussion"
},
{
"domain": "reddit.com",
"trust": 0.3,
"category": "community",
"biasRisk": 0.45,
"primaryUse": "Discussion threads",
"notes": "High noise; good for leads only"
},
{
"domain": "imf.org",
"trust": 0.9,
"category": "financial",
"biasRisk": 0.15,
"primaryUse": "Macro data",
"notes": "IMF datasets and reports"
},
{
"domain": "worldbank.org",
"trust": 0.89,
"category": "financial",
"biasRisk": 0.15,
"primaryUse": "Development data",
"notes": "World Bank datasets and reports"
},
{
"domain": "oecd.org",
"trust": 0.88,
"category": "financial",
"biasRisk": 0.15,
"primaryUse": "Economic indicators",
"notes": "OECD data and analysis"
},
{
"domain": "bis.org",
"trust": 0.9,
"category": "financial",
"biasRisk": 0.1,
"primaryUse": "Banking statistics",
"notes": "BIS research and statistics"
},
{
"domain": "morningstar.com",
"trust": 0.8,
"category": "financial",
"biasRisk": 0.2,
"primaryUse": "Fund data",
"notes": "Mutual fund/ETF research and data"
},
{
"domain": "who.int",
"trust": 0.93,
"category": "health",
"biasRisk": 0.15,
"primaryUse": "Global health",
"notes": "WHO guidance and statistics"
},
{
"domain": "mayoclinic.org",
"trust": 0.8,
"category": "health",
"biasRisk": 0.1,
"primaryUse": "Clinical reference",
"notes": "Patient-oriented medical guidance"
},
{
"domain": "clevelandclinic.org",
"trust": 0.8,
"category": "health",
"biasRisk": 0.1,
"primaryUse": "Clinical reference",
"notes": "Patient-oriented medical guidance"
},
{
"domain": "pubmed.ncbi.nlm.nih.gov",
"trust": 0.92,
"category": "health",
"biasRisk": 0.05,
"primaryUse": "Literature index",
"notes": "Search biomedical abstracts and links"
},
{
"domain": "law.cornell.edu",
"trust": 0.8,
"category": "legal",
"biasRisk": 0.1,
"primaryUse": "US law reference",
"notes": "LII statutes, CFR, case summaries"
},
{
"domain": "loc.gov",
"trust": 0.9,
"category": "legal",
"biasRisk": 0.1,
"primaryUse": "Library of Congress",
"notes": "Legal and historical archives"
},
{
"domain": "justice.gov",
"trust": 0.92,
"category": "government",
"biasRisk": 0.25,
"primaryUse": "DOJ resources",
"notes": "Enforcement actions and guidance"
},
{
"domain": "europa.eu",
"trust": 0.9,
"category": "government",
"biasRisk": 0.2,
"primaryUse": "EU policy",
"notes": "EU law and policy portal"
},
{
"domain": "eur-lex.europa.eu",
"trust": 0.92,
"category": "legal",
"biasRisk": 0.2,
"primaryUse": "EU law",
"notes": "Official EU law texts"
},
{
"domain": "justia.com",
"trust": 0.65,
"category": "legal",
"biasRisk": 0.2,
"primaryUse": "Legal portal",
"notes": "Secondary legal references"
},
{
"domain": "lexisnexis.com",
"trust": 0.78,
"category": "legal",
"biasRisk": 0.2,
"primaryUse": "Legal research",
"notes": "Commercial legal database"
},
{
"domain": "westlaw.com",
"trust": 0.78,
"category": "legal",
"biasRisk": 0.2,
"primaryUse": "Legal research",
"notes": "Commercial legal database"
},
{
"domain": "openai.com",
"trust": 0.88,
"category": "vendor-docs",
"biasRisk": 0.2,
"primaryUse": "AI APIs",
"notes": "OpenAI product and API documentation"
},
{
"domain": "microsoft.com",
"trust": 0.88,
"category": "vendor-docs",
"biasRisk": 0.2,
"primaryUse": "Cloud/OS docs",
"notes": "Microsoft product docs and advisories"
},
{
"domain": "learn.microsoft.com",
"trust": 0.9,
"category": "vendor-docs",
"biasRisk": 0.15,
"primaryUse": "Cloud/OS docs",
"notes": "Microsoft Learn technical documentation"
},
{
"domain": "developer.apple.com",
"trust": 0.9,
"category": "vendor-docs",
"biasRisk": 0.1,
"primaryUse": "Platform docs",
"notes": "Apple developer documentation"
},
{
"domain": "cloud.google.com",
"trust": 0.86,
"category": "vendor-docs",
"biasRisk": 0.2,
"primaryUse": "Cloud docs",
"notes": "Google Cloud technical documentation"
},
{
"domain": "oracle.com",
"trust": 0.84,
"category": "vendor-docs",
"biasRisk": 0.2,
"primaryUse": "Enterprise docs",
"notes": "Oracle product documentation"
},
{
"domain": "redhat.com",
"trust": 0.86,
"category": "vendor-docs",
"biasRisk": 0.15,
"primaryUse": "Linux/platform docs",
"notes": "Red Hat product documentation"
},
{
"domain": "canonical.com",
"trust": 0.82,
"category": "vendor-docs",
"biasRisk": 0.15,
"primaryUse": "Linux/platform docs",
"notes": "Ubuntu and Canonical docs"
},
{
"domain": "debian.org",
"trust": 0.84,
"category": "vendor-docs",
"biasRisk": 0.1,
"primaryUse": "OS docs",
"notes": "Debian project documentation"
},
{
"domain": "kernel.org",
"trust": 0.86,
"category": "vendor-docs",
"biasRisk": 0.05,
"primaryUse": "Kernel docs",
"notes": "Linux kernel releases and docs"
},
{
"domain": "python.org",
"trust": 0.86,
"category": "vendor-docs",
"biasRisk": 0.05,
"primaryUse": "Language docs",
"notes": "Python language reference"
},
{
"domain": "nodejs.org",
"trust": 0.84,
"category": "vendor-docs",
"biasRisk": 0.05,
"primaryUse": "Runtime docs",
"notes": "Node.js documentation"
},
{
"domain": "flutter.dev",
"trust": 0.85,
"category": "vendor-docs",
"biasRisk": 0.05,
"primaryUse": "Framework docs",
"notes": "Flutter documentation"
},
{
"domain": "dart.dev",
"trust": 0.85,
"category": "vendor-docs",
"biasRisk": 0.05,
"primaryUse": "Language docs",
"notes": "Dart language documentation"
},
{
"domain": "kubernetes.io",
"trust": 0.86,
"category": "vendor-docs",
"biasRisk": 0.1,
"primaryUse": "Orchestration docs",
"notes": "Kubernetes documentation"
},
{
"domain": "docker.com",
"trust": 0.82,
"category": "vendor-docs",
"biasRisk": 0.15,
"primaryUse": "Container docs",
"notes": "Docker documentation and releases"
},
{
"domain": "nginx.org",
"trust": 0.82,
"category": "vendor-docs",
"biasRisk": 0.1,
"primaryUse": "Web server docs",
"notes": "NGINX documentation"
},
{
"domain": "postgresql.org",
"trust": 0.86,
"category": "vendor-docs",
"biasRisk": 0.05,
"primaryUse": "Database docs",
"notes": "PostgreSQL documentation"
},
{
"domain": "mysql.com",
"trust": 0.82,
"category": "vendor-docs",
"biasRisk": 0.15,
"primaryUse": "Database docs",
"notes": "MySQL documentation"
},
{
"domain": "sqlite.org",
"trust": 0.86,
"category": "vendor-docs",
"biasRisk": 0.05,
"primaryUse": "Database docs",
"notes": "SQLite documentation"
},
{
"domain": "cisco.com",
"trust": 0.85,
"category": "vendor-docs",
"biasRisk": 0.2,
"primaryUse": "Networking docs",
"notes": "Cisco product documentation"
},
{
"domain": "juniper.net",
"trust": 0.84,
"category": "vendor-docs",
"biasRisk": 0.2,
"primaryUse": "Networking docs",
"notes": "Juniper product documentation"
},
{
"domain": "arista.com",
"trust": 0.83,
"category": "vendor-docs",
"biasRisk": 0.15,
"primaryUse": "Networking docs",
"notes": "Arista product documentation"
}
]
}
''';
