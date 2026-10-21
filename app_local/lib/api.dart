import 'package:full_jizhang/models/ledger.dart';

// Ledger surface shared by pages. The cloud app talks HTTP; this package's
// implementation is [LocalApi] in services/local_api.dart, which ports
// api/internal/app without sessions. Login, register, logout, and password
// are absent on purpose.

/// Error raised by the ledger. [status] matches the Go HTTP status
/// (`400` validation, `409` conflict, `422` 「修改後持倉會變負數」).
class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// On-device ledger surface used by pages.
///
/// Method names match the cloud HTTP client, minus login, register, logout,
/// and password. [createEntry] and [createTrade] take an idempotency key
/// the way `api/internal/app/app.go` `idempotency` reads `Idempotency-Key`.
/// [exportBook] / [importBook] speak the JSON shape of `backup.go`.
abstract class ApiClient {
  Future<List<Book>> listBooks();

  Future<Book> createBook({required String name});

  Future<Book> patchBook({
    required String id,
    required String name,
    required int version,
  });

  Future<Book> archiveBook(String id);

  Future<Book> unarchiveBook(String id);

  Future<void> deleteBook(String id);

  Future<Book> selectBook(String id);

  Future<Map<String, dynamic>> exportBook(String id);

  Future<Book> importBook({
    required String id,
    required Map<String, dynamic> payload,
  });

  Future<List<Account>> listAccounts(String bookId);

  Future<Account> createAccount({
    required String bookId,
    required String name,
    required String type,
  });

  Future<Account> patchAccount({
    required String id,
    required String name,
    required int version,
  });

  Future<void> archiveAccount(String id);

  Future<void> deleteAccount(String id);

  Future<List<Category>> listCategories(String bookId);

  Future<Category> createCategory({
    required String bookId,
    required String name,
    required String kind,
  });

  Future<Category> patchCategory({
    required String id,
    required String name,
    required int version,
  });

  Future<void> archiveCategory(String id);

  Future<void> deleteCategory(String id);

  Future<List<Entry>> listEntries({
    required String bookId,
    String? date,
    String? from,
    String? to,
    String? accountId,
    String? categoryId,
  });

  Future<Entry> createEntry({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  });

  /// Updates one income, expense, or transfer.
  ///
  /// Rule: `opening_balance` cannot be changed. The resulting date cannot be
  /// before the book's opening date (不能記開帳日之前的帳). A version mismatch
  /// is 「資料已被更新，請重抓再送」. The write and a full holding replay run
  /// in one transaction; 「修改後持倉會變負數」 leaves the row unchanged.
  /// Cash balances are not stored — they are summed from the updated rows.
  Future<Entry> patchEntry({
    required String id,
    required Map<String, dynamic> body,
  });

  /// Soft-deletes one entry, then replays holdings in the same transaction.
  ///
  /// Rule: `opening_balance` cannot be deleted (開帳分錄不能刪). A replay
  /// that would make any holding negative throws 「修改後持倉會變負數」 and
  /// the delete is rolled back.
  Future<void> deleteEntry({required String id, required int version});

  Future<List<DailyPoint>> statsDaily({
    required String bookId,
    required String from,
    required String to,
  });

  Future<StatsSummary> statsSummary({required String bookId, String? month});

  Future<List<CategoryAmount>> statsByCategory({
    required String bookId,
    String? month,
  });

  Future<List<Position>> listPositions(String bookId);

  Future<QuoteRefresh> refreshQuotes(String bookId);

  Future<Map<String, dynamic>> createTrade({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  });

  /// Live trades in date order, plus symbol fields for the ledger.
  ///
  /// `transfer_in` stays in the list so callers can follow `pair_id`.
  /// The 帳本 hides that leg and shows the `transfer_out` once.
  Future<List<Map<String, dynamic>>> listTrades(String bookId);

  /// Updates a buy, sell, airdrop, or both legs of a transfer, then replays.
  ///
  /// Rule: `opening` lots cannot be changed here. The new date cannot be
  /// before the opening date. Holdings are rebuilt from opening lots and
  /// every live trade in time order (moving-average cost). A negative
  /// quantity at any point throws 「修改後持倉會變負數」 and the transaction
  /// rolls back, so the trade and the positions stay as they were.
  Future<Map<String, dynamic>> patchTrade({
    required String id,
    required Map<String, dynamic> body,
  });

  /// Soft-deletes a trade, or both legs of a transfer, then replays.
  ///
  /// Rule: `opening` lots cannot be deleted. The same negative-holding
  /// check as [patchTrade] runs inside the transaction. A matching
  /// 搬倉手續費 expense is removed with the transfer so cash is recomputed.
  Future<void> deleteTrade({required String id, required int version});

  Future<OpeningSnapshot> getOpening(String bookId);

  Future<OpeningSnapshot> putOpening({
    required String bookId,
    required Map<String, dynamic> body,
  });

  void close() {}
}
