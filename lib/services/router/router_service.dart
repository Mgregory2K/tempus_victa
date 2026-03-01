import 'router.dart';
import '../consent/consent.dart';
import '../redaction/redaction.dart';
import '../db/db_provider.dart';

/// Singleton service to initialize and provide Router and its backing store.
class RouterService {
  Router? router;
  LocalStore? store;
  ConsentManager? consentManager;
  Redactor? redactor;

  RouterService._private();
  static final RouterService instance = RouterService._private();

  Future<void> init({String? dbPath}) async {
    await DatabaseProvider.init(dbPath: dbPath);
    // Create consent manager and store using shared DB instance
    final db = DatabaseProvider.instance;
    final path = DatabaseProvider.dbPath;
    consentManager = ConsentManager(dbPath: path, db: db);
    redactor = Redactor();
    store = LocalStore(dbPath: path, db: db);
    router = Router(store: store, consentManager: consentManager, redactor: redactor);
  }
}
