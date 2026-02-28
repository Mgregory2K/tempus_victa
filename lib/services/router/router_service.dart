import 'package:tempus_victa/services/router/router.dart';
import 'package:tempus_victa/services/consent/consent.dart';
import 'package:tempus_victa/services/redaction/redaction.dart';

/// Singleton service to initialize and provide Router and its backing store.
class RouterService {
  Router? router;
  LocalStore? store;
  ConsentManager? consentManager;
  Redactor? redactor;

  RouterService._private();
  static final RouterService instance = RouterService._private();

  void init({String? dbPath}) {
    final path = dbPath ?? 'build/local_store.db';
    // Create consent manager (uses same DB path by default)
    consentManager = ConsentManager(dbPath: path);
    redactor = Redactor();
    store = LocalStore(dbPath: path);
    router = Router(
        store: store, consentManager: consentManager, redactor: redactor);
  }
}
