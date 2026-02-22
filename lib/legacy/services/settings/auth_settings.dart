import '../../providers/db_provider.dart';

/// Stores *non-sensitive* auth state for convenience (display, routing).
/// OAuth tokens are held by the platform plugin; do not store tokens here.
class AuthSettings {
  static const _kProvider = 'auth.provider'; // google|none
  static const _kEmail = 'auth.email';
  static const _kDisplayName = 'auth.display_name';
  static const _kUserId = 'auth.user_id';

  static Future<String?> getProvider() => DbProvider.db.getMeta(_kProvider);
  static Future<String?> getEmail() => DbProvider.db.getMeta(_kEmail);
  static Future<String?> getDisplayName() => DbProvider.db.getMeta(_kDisplayName);
  static Future<String?> getUserId() => DbProvider.db.getMeta(_kUserId);

  static Future<void> clear() async {
    await DbProvider.db.setMeta(_kProvider, '');
    await DbProvider.db.setMeta(_kEmail, '');
    await DbProvider.db.setMeta(_kDisplayName, '');
    await DbProvider.db.setMeta(_kUserId, '');
  }

  static Future<void> setGoogleUser({
    required String userId,
    required String? email,
    required String? displayName,
  }) async {
    await DbProvider.db.setMeta(_kProvider, 'google');
    await DbProvider.db.setMeta(_kUserId, userId);
    await DbProvider.db.setMeta(_kEmail, email ?? '');
    await DbProvider.db.setMeta(_kDisplayName, displayName ?? '');
  }
}
