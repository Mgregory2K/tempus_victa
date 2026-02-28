// Simple redaction library prototype for Tempus Victa
import 'dart:convert';

class RedactionResult {
  final Map<String, dynamic> payload;
  final List<String> redactedFields;
  RedactionResult(this.payload, this.redactedFields);
}

class Redactor {
  // Basic regexes for emails, phones, and urls
  static final RegExp _emailRe =
      RegExp(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b");
  static final RegExp _phoneRe = RegExp(r"\+?\d[\d\-\s()]{6,}\d");
  static final RegExp _urlRe = RegExp(r"https?://[\S]+|www\.[\S]+");

  /// Produce a redacted version of [item]. Returns redacted payload and list of redacted fields.
  RedactionResult redactItem(Map<String, dynamic> item,
      {bool redactAttachments = true}) {
    final redacted = Map<String, dynamic>.from(item);
    final redactedFields = <String>[];

    void _redactField(String key) {
      if (redacted.containsKey(key)) {
        redacted[key] = _redactValue(redacted[key]);
        redactedFields.add(key);
      }
    }

    // Common text fields
    for (final key in ['raw', 'body', 'description', 'notes']) {
      if (redacted.containsKey(key) && redacted[key] is String) {
        final s = redacted[key] as String;
        final r = _redactText(s);
        if (r != s) {
          redacted[key] = r;
          redactedFields.add(key);
        }
      }
    }

    // Attachments
    if (redactAttachments) {
      if (redacted.containsKey('attachments')) {
        redacted['attachments'] = '[REDACTED_ATTACHMENT]';
        redactedFields.add('attachments');
      }
    }

    // Scan top-level values for PII in strings
    for (final entry
        in List<MapEntry<String, dynamic>>.from(redacted.entries)) {
      final k = entry.key;
      final v = entry.value;
      if (v is String) {
        final r = _redactText(v);
        if (r != v) {
          redacted[k] = r;
          if (!redactedFields.contains(k)) redactedFields.add(k);
        }
      }
    }

    // Add provenance of redaction
    redacted['_redaction'] = {
      'redacted_fields': redactedFields,
      'redacted_at': DateTime.now().toIso8601String()
    };

    return RedactionResult(redacted, redactedFields);
  }

  dynamic _redactValue(dynamic v) {
    if (v is String) return _redactText(v);
    if (v is List) return v.map(_redactValue).toList();
    if (v is Map) return v.map((k, val) => MapEntry(k, _redactValue(val)));
    return '[REDACTED]';
  }

  String _redactText(String s) {
    var out = s;
    var changed = false;

    // emails
    if (_emailRe.hasMatch(out)) {
      out = out.replaceAllMapped(
          _emailRe, (m) => _tokenize('email', m.group(0)!));
      changed = true;
    }

    // phones
    if (_phoneRe.hasMatch(out)) {
      out = out.replaceAllMapped(
          _phoneRe, (m) => _tokenize('phone', m.group(0)!));
      changed = true;
    }

    // urls
    if (_urlRe.hasMatch(out)) {
      out = out.replaceAllMapped(_urlRe, (m) => '[REDACTED_URL]');
      changed = true;
    }

    return changed ? out : s;
  }

  // Deterministic opaque token (simple base64 of input truncated)
  String _tokenize(String kind, String original) {
    final bytes = utf8.encode(original);
    final token = base64Url.encode(bytes).replaceAll('=', '');
    final short = token.length > 8 ? token.substring(0, 8) : token;
    return '<REDACTED_${kind}_$short>';
  }
}
