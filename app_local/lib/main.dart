import 'package:flutter/widgets.dart';
import 'package:full_jizhang/app.dart';
import 'package:full_jizhang/data/database.dart';
import 'package:full_jizhang/services/local_api.dart';

/// Starts the on-device ledger.
///
/// Opens the SQLite file, wraps it in [LocalApi], and runs [FullJizhangApp].
/// There is no login and no HTTP process. Every rule from `api/internal/app`
/// that this app still enforces lives inside [LocalApi].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // drift file `full_jizhang` — the only copy of the books.
  final db = AppDatabase.defaults();
  final api = LocalApi(db);
  runApp(FullJizhangApp(api: api));
}
