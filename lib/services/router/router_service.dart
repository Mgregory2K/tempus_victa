import 'package:tempus_victa/services/router/router.dart';
import 'package:tempus_victa/services/consent/consent.dart';
import 'package:tempus_victa/services/redaction/redaction.dart';
import 'package:tempus_victa/services/db/db_provider.dart';

/// Singleton service to initialize and provide Router and its backing store.
class RouterService {
  Router? router;
  LocalStore? store;
  ConsentManager? consentManager;
  Redactor? redactor;

  RouterService._private();
  static final RouterService instance = RouterService._private();

  Future<void> init({String? dbPath}) async {
    final path = dbPath ?? 'build/local_store.db';
    await DatabaseProvider.init(dbPath: path);
    // Create consent manager and store using shared DB instance
    final db = DatabaseProvider.instance;
    consentManager = ConsentManager(dbPath: path, db: db);
    redactor = Redactor();
    store = LocalStore(dbPath: path, db: db);
    router = Router(
        store: store, consentManager: consentManager, redactor: redactor);
  }
}
