import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

import '../settings/auth_settings.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService I = GoogleAuthService._();

  // NOTE: Scopes can be expanded later as you add Calendar/Gmail integrations.
  // Keep it minimal for now.
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: <String>[
      'email',
      // 'https://www.googleapis.com/auth/calendar.readonly',
      // 'https://www.googleapis.com/auth/gmail.readonly',
    ],
  );

  GoogleSignInAccount? _current;

  GoogleSignInAccount? get currentUser => _current;

  Stream<GoogleSignInAccount?> get onChanged => _gsi.onCurrentUserChanged;

  Future<void> init() async {
    _current = await _gsi.signInSilently();
    if (_current != null) {
      await _persist(_current!);
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    final acct = await _gsi.signIn();
    _current = acct;
    if (acct != null) {
      await _persist(acct);
    }
    return acct;
  }

  Future<void> signOut() async {
    await _gsi.signOut();
    _current = null;
    await AuthSettings.clear();
  }

  Future<void> disconnect() async {
    await _gsi.disconnect();
    _current = null;
    await AuthSettings.clear();
  }

  Future<void> _persist(GoogleSignInAccount acct) async {
    await AuthSettings.setGoogleUser(
      userId: acct.id,
      email: acct.email,
      displayName: acct.displayName,
    );
  }
}
