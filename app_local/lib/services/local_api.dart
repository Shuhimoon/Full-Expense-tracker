import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/data/database.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/services/apple_pay_link.dart';
import 'package:full_jizhang/services/money.dart';
import 'package:full_jizhang/services/opening.dart';
import 'package:full_jizhang/services/quotes.dart';

// On-device port of api/internal/app. Pages call this through [ApiClient].
//
// Rules that matter, and the Go handler they follow:
// - Book creation stores today's date in Asia/Taipei (`books.go`
//   `handleBooksCreate`: `(now() AT TIME ZONE 'Asia/Taipei')::date`).
// - Entries and trades dated before that day are rejected with
//   「不能記開帳日之前的帳」 (`entries.go`, `trades.go`).
// - A later opening date is rejected when a non-opening entry or trade is
//   earlier (`opening.go` `handleOpeningPut`).
// - PUT opening replays opening lots and later trades in time order, with
//   moving-average cost, inside one transaction. 「修改後持倉會變負數」 aborts
//   the transaction (`opening.go` `applyOpening` / `rebuildPositions`).
// - Net worth is cash (credit cards inverted) plus position market value,
//   with unquoted lots marked at cost (`stats.go`).
// - Export JSON matches `backup.go` `exportBook`. Import replaces the book
//   in one transaction and remaps transfer `pair_id`.
// - Idempotency keys replay a stored POST body (`app.go` `idempotency`).
// - Entry and trade edits and deletes recompute holdings by replaying
//   opening lots and live trades in time order inside one transaction.
//   「修改後持倉會變負數」 rolls that transaction back.
// - Apple Pay URLs are previews until the user confirms. Import keys and
//   merchant/card mappings are written only then.
// - Quotes try the public sources in `quotes.go`, then keep the old price
//   or a manual USD/TWD of 32.

/// SQLite implementation of [ApiClient].
///
/// [_clock] is injected by tests that need a fixed Taipei day. Production
/// uses [DateTime.now].
class LocalApi implements ApiClient {
  LocalApi(
    this.db, {
    QuoteClient? quotes,
    this._clock,
  }) : quotes = quotes ?? QuoteClient();

  final AppDatabase db;
  final QuoteClient quotes;
  final DateTime Function()? _clock;

  DateTime _now() => _clock?.call() ?? DateTime.now();

  /// Calendar day in Asia/Taipei (UTC+8), not the device zone.
  /// This is the opening-date default and the default entry/trade date.
  String _today() => taipeiToday(_now());

  String _ts() => nowIso(_now());

  // Quote cooldown, port of quotes.go lastAttempt / lastFail (5 minutes).
  final Map<String, DateTime> _lastAttempt = {};
  final Map<String, List<String>> _lastFail = {};

  /// True when this FX or symbol key was tried in the last five minutes.
  bool _recentlyAttempted(String key) {
    final t = _lastAttempt[key];
    return t != null && _now().difference(t) < const Duration(minutes: 5);
  }

  void _markAttempt(String key) => _lastAttempt[key] = _now();

  Future<BookRow> _loadBook(String id) async {
    final row = await (db.select(
      db.books,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    if (row == null) throw ApiException('找不到帳本', status: 404);
    return row;
  }

  /// Archived books reject writes with 409 「帳本已封存，不能寫入」 (`app.go`).
  void _rejectArchived(BookRow b) {
    if (b.archivedAt != null && b.archivedAt!.isNotEmpty) {
      throw ApiException('帳本已封存，不能寫入', status: 409);
    }
  }

  Book _toBook(BookRow b) => Book(
    id: b.id,
    name: b.name,
    archivedAt: b.archivedAt,
    baseCurrency: b.baseCurrency,
    openingDate: b.openingDate,
    timezone: b.timezone,
    costMethod: b.costMethod,
    version: b.version,
    createdAt: b.createdAt,
  );

  Category _toCat(CategoryRow c) => Category(
    id: c.id,
    bookId: c.bookId,
    name: c.name,
    kind: c.kind,
    isSystem: c.isSystem,
    archivedAt: c.archivedAt,
    sort: c.sort,
    version: c.version,
  );

  Entry _toEntry(EntryRow e) => Entry(
    id: e.id,
    bookId: e.bookId,
    date: e.date,
    type: e.type,
    amount: e.amount,
    accountId: e.accountId,
    toAccountId: e.toAccountId,
    categoryId: e.categoryId,
    note: e.note,
    createdAt: e.createdAt,
    version: e.version,
  );

  @override
  /// All books, active ones first. Ports `books.go` `handleBooksList`.
  Future<List<Book>> listBooks() async {
    final rows = await (db.select(db.books)..orderBy([
          (b) => OrderingTerm(
            expression: b.archivedAt,
            mode: OrderingMode.asc,
            nulls: NullsOrder.first,
          ),
          (b) => OrderingTerm(expression: b.createdAt),
        ]))
        .get();
    return [for (final r in rows) _toBook(r)];
  }

  @override
  /// Creates a book. Empty name becomes 「生活」.
  ///
  /// Opening date is the creation day in Asia/Taipei ([_today]), one date
  /// per book, matching `books.go` `handleBooksCreate`. The book can be
  /// used immediately; opening cash and lots are optional (`opening.go` no
  /// longer has a lock). A duplicate active name is 409 「已有同名帳本」.
  /// Categories are the system seeds. `last_book_id` is set only when unset.
  Future<Book> createBook({required String name}) async {
    name = name.trim();
    if (name.isEmpty) name = '生活';
    final id = newId();
    final ts = _ts();
    // Default opening day: the Taipei calendar date of this insert.
    final opening = _today();
    try {
      await db.transaction(() async {
        await db
            .into(db.books)
            .insert(
              BooksCompanion.insert(
                id: id,
                name: name,
                openingDate: Value(opening),
                createdAt: ts,
              ),
            );
        await _seedCategories(id);
        final last = await _pref('last_book_id');
        if (last == null || last.isEmpty) {
          await _setPref('last_book_id', id);
        }
      });
    } catch (e) {
      if (looksUniqueViolation(e)) {
        throw ApiException('已有同名帳本', status: 409);
      }
      rethrow;
    }
    return _toBook(await _loadBook(id));
  }

  /// Inserts the system income and expense names from `app.go` `seedCategories`.
  Future<void> _seedCategories(String bookId) async {
    var sort = 0;
    for (final n in incomeSeed) {
      sort++;
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: newId(),
              bookId: bookId,
              name: n,
              kind: 'income',
              isSystem: const Value(true),
              sort: Value(sort),
            ),
          );
    }
    sort = 0;
    for (final n in expenseSeed) {
      sort++;
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: newId(),
              bookId: bookId,
              name: n,
              kind: 'expense',
              isSystem: const Value(true),
              sort: Value(sort),
            ),
          );
    }
  }

  Future<String?> _pref(String key) async {
    final row = await (db.select(
      db.appPrefs,
    )..where((p) => p.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _setPref(String key, String? value) async {
    await db
        .into(db.appPrefs)
        .insertOnConflictUpdate(
          AppPrefsCompanion.insert(key: key, value: Value(value)),
        );
  }

  @override
  /// Renames a book. Version must match or the response is 409
  /// 「資料已被更新，請重抓再送」 (optimistic lock, `books.go` `handleBooksPatch`).
  Future<Book> patchBook({
    required String id,
    required String name,
    required int version,
  }) async {
    final b = await _loadBook(id);
    _rejectArchived(b);
    name = name.trim();
    if (name.isEmpty) throw ApiException('名稱不能空', status: 400);
    try {
      final n = await (db.update(db.books)..where(
            (row) => row.id.equals(id) & row.version.equals(version),
          ))
          .write(
            BooksCompanion(
              name: Value(name),
              version: Value(version + 1),
            ),
          );
      if (n == 0) throw ApiException('資料已被更新，請重抓再送', status: 409);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (looksUniqueViolation(e)) {
        throw ApiException('已有同名帳本', status: 409);
      }
      rethrow;
    }
    return _toBook(await _loadBook(id));
  }

  @override
  /// Sets `archived_at`. A second call is a no-op when already archived
  /// (`books.go` `handleBooksArchive`).
  Future<Book> archiveBook(String id) async {
    await _loadBook(id);
    final cur = await _loadBook(id);
    await (db.update(db.books)..where(
          (b) => b.id.equals(id) & b.archivedAt.isNull(),
        ))
        .write(
          BooksCompanion(
            archivedAt: Value(_ts()),
            version: Value(cur.version + 1),
          ),
        );
    return _toBook(await _loadBook(id));
  }

  @override
  /// Clears `archived_at`. 409 「已有同名未封存帳本」 when the name is taken
  /// (`books.go` `handleBooksUnarchive`).
  Future<Book> unarchiveBook(String id) async {
    await _loadBook(id);
    try {
      final cur = await _loadBook(id);
      await (db.update(db.books)..where((b) => b.id.equals(id))).write(
        BooksCompanion(
          archivedAt: const Value(null),
          version: Value(cur.version + 1),
        ),
      );
    } catch (e) {
      if (looksUniqueViolation(e)) {
        throw ApiException('已有同名未封存帳本', status: 409);
      }
      rethrow;
    }
    return _toBook(await _loadBook(id));
  }

  @override
  /// Deletes an empty book. Any account, live entry, or live trade forces
  /// 409 「帳本還有帳戶或分錄，只能封存」 (`books.go` `handleBooksDelete`).
  Future<void> deleteBook(String id) async {
    await _loadBook(id);
    final nAcc = await _count(
      'SELECT COUNT(*) AS c FROM accounts WHERE book_id = ?',
      [Variable.withString(id)],
    );
    final nEnt = await _count(
      'SELECT COUNT(*) AS c FROM entries WHERE book_id = ? AND deleted_at IS NULL',
      [Variable.withString(id)],
    );
    final nTr = await _count(
      'SELECT COUNT(*) AS c FROM trades WHERE book_id = ? AND deleted_at IS NULL',
      [Variable.withString(id)],
    );
    if (nAcc + nEnt + nTr > 0) {
      throw ApiException('帳本還有帳戶或分錄，只能封存', status: 409);
    }
    await (db.delete(db.books)..where((b) => b.id.equals(id))).go();
  }

  Future<int> _count(String sql, List<Variable> args) async {
    final row = await db.customSelect(sql, variables: args).getSingle();
    return asInt(row.data['c']);
  }

  @override
  /// Remembers [id] as `last_book_id`. Archived books must be unarchived first
  /// (`books.go` `handleBooksSelect`).
  Future<Book> selectBook(String id) async {
    final b = await _loadBook(id);
    if (b.archivedAt != null && b.archivedAt!.isNotEmpty) {
      throw ApiException('帳本已封存，請先取消封存', status: 409);
    }
    await _setPref('last_book_id', id);
    return _toBook(b);
  }

  /// Last book the UI selected. Null until the first book is created or selected.
  Future<String?> lastBookId() => _pref('last_book_id');

  @override
  /// Accounts with cash balance and, for broker/exchange, position market value.
  /// Ports `accounts.go` `handleAccountsList` / `accountsWithBalance`.
  Future<List<Account>> listAccounts(String bookId) async {
    await _loadBook(bookId);
    return _accountsWithBalance(bookId);
  }

  Future<List<Account>> _accountsWithBalance(String bookId) async {
    final rows = await (db.select(db.accounts)
          ..where((a) => a.bookId.equals(bookId))
          ..orderBy([
            (a) => OrderingTerm(expression: a.type),
            (a) => OrderingTerm(expression: a.createdAt),
          ]))
        .get();
    final out = <Account>[];
    for (final a in rows) {
      final bal = await _accountCash(a.id);
      int? mv;
      if (a.type == 'broker' || a.type == 'exchange') {
        mv = await _accountPositionMv(a.id);
      }
      out.add(
        Account(
          id: a.id,
          bookId: a.bookId,
          name: a.name,
          type: a.type,
          archivedAt: a.archivedAt,
          version: a.version,
          cashBalance: bal,
          positionMv: mv,
        ),
      );
    }
    return out;
  }

  /// Cash on one account. Ports `accounts.go` `accountCash`.
  ///
  /// Opening balance and income add, expense subtracts, a transfer subtracts
  /// from the source and adds to the destination. Buys subtract TWD proceeds
  /// (cost including fee); sells add proceeds (gross minus fee). Credit-card
  /// sign is not flipped here — that happens in [cashNetAt] for net worth.
  Future<int> _accountCash(String accountId) async {
    final entries = await (db.select(db.entries)..where(
          (e) =>
              e.deletedAt.isNull() &
              (e.accountId.equals(accountId) |
                  e.toAccountId.equals(accountId)),
        ))
        .get();
    var entryBal = 0;
    for (final e in entries) {
      if (e.type == 'opening_balance' || e.type == 'income') {
        if (e.accountId == accountId) entryBal += e.amount;
      } else if (e.type == 'expense' && e.accountId == accountId) {
        entryBal -= e.amount;
      } else if (e.type == 'transfer') {
        if (e.accountId == accountId) entryBal -= e.amount;
        if (e.toAccountId == accountId) entryBal += e.amount;
      }
    }
    final trades = await (db.select(
      db.trades,
    )..where((t) => t.deletedAt.isNull() & t.accountId.equals(accountId)))
        .get();
    var tradeBal = 0;
    for (final t in trades) {
      if (t.side == 'buy') {
        tradeBal -= t.proceedsOrCostTwd;
      } else if (t.side == 'sell') {
        tradeBal += t.proceedsOrCostTwd;
      }
    }
    return entryBal + tradeBal;
  }

  /// Market value of open lots on a broker or exchange account.
  ///
  /// Ports `accounts.go` `accountPositionMV`. USD prices are multiplied by
  /// the book's USD/TWD, or 32 when no FX row exists. A missing quote uses
  /// cost, the same fallback as `stats.go` `positionMark`.
  Future<int> _accountPositionMv(String accountId) async {
    final rows = await db.customSelect(
      '''
      SELECT p.qty, p.cost_twd, i.quote_currency, q.price, q.ccy, f.usd_twd
      FROM positions p
      JOIN instruments i ON i.id = p.instrument_id
      LEFT JOIN quotes q ON q.instrument_id = p.instrument_id
      LEFT JOIN fx_rates f ON f.book_id = p.book_id
      WHERE p.account_id = ? AND CAST(p.qty AS REAL) > 0
      ''',
      variables: [Variable.withString(accountId)],
    ).get();
    var total = Decimal.zero;
    for (final r in rows) {
      final qty = decOrZero(r.data['qty']?.toString());
      final cost = decOrZero(r.data['cost_twd']?.toString());
      final priceRaw = r.data['price']?.toString();
      if (priceRaw != null && priceRaw.isNotEmpty) {
        var px = dec(priceRaw);
        final pccy = r.data['ccy']?.toString();
        if (pccy == 'USD') {
          // Go default when fx_rates has no row yet.
          var mult = Decimal.fromInt(32);
          final fx = r.data['usd_twd']?.toString();
          if (fx != null && fx.isNotEmpty) mult = dec(fx);
          px = px * mult;
        }
        total += qty * px;
      } else {
        total += cost;
      }
    }
    return round0(total);
  }

  @override
  /// Creates an account. Type must be cash, bank, credit_card, broker, or
  /// exchange. Duplicate active name is 409 「已有同名帳戶」 (`accounts.go`).
  Future<Account> createAccount({
    required String bookId,
    required String name,
    required String type,
  }) async {
    final b = await _loadBook(bookId);
    _rejectArchived(b);
    name = name.trim();
    if (name.isEmpty) throw ApiException('請填帳戶名稱', status: 400);
    const types = {'cash', 'bank', 'credit_card', 'broker', 'exchange'};
    if (!types.contains(type)) throw ApiException('帳戶類型不對', status: 400);
    final id = newId();
    try {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: id,
              bookId: bookId,
              name: name,
              type: type,
              createdAt: _ts(),
            ),
          );
    } catch (e) {
      if (looksUniqueViolation(e)) {
        throw ApiException('已有同名帳戶', status: 409);
      }
      rethrow;
    }
    final list = await _accountsWithBalance(bookId);
    return list.firstWhere((a) => a.id == id);
  }

  @override
  /// Renames an account. Version mismatch is 409 「資料已被更新，請重抓再送」.
  Future<Account> patchAccount({
    required String id,
    required String name,
    required int version,
  }) async {
    final row = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) throw ApiException('找不到帳戶', status: 404);
    final b = await _loadBook(row.bookId);
    _rejectArchived(b);
    name = name.trim();
    try {
      final n = await (db.update(db.accounts)..where(
            (a) => a.id.equals(id) & a.version.equals(version),
          ))
          .write(
            AccountsCompanion(name: Value(name), version: Value(version + 1)),
          );
      if (n == 0) throw ApiException('資料已被更新，請重抓再送', status: 409);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (looksUniqueViolation(e)) {
        throw ApiException('已有同名帳戶', status: 409);
      }
      rethrow;
    }
    final list = await _accountsWithBalance(row.bookId);
    return list.firstWhere((a) => a.id == id);
  }

  @override
  /// Hides an account from new entries without deleting its history.
  Future<void> archiveAccount(String id) async {
    final row = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) throw ApiException('找不到帳戶', status: 404);
    _rejectArchived(await _loadBook(row.bookId));
    await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        archivedAt: Value(_ts()),
        version: Value(row.version + 1),
      ),
    );
  }

  @override
  /// Deletes an account with no live entries or trades. Otherwise 409
  /// 「帳戶還有流水，請改封存」 (`accounts.go` `handleAccountsDelete`).
  Future<void> deleteAccount(String id) async {
    final row = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) throw ApiException('找不到帳戶', status: 404);
    _rejectArchived(await _loadBook(row.bookId));
    final n = await _count(
      'SELECT COUNT(*) AS c FROM entries WHERE (account_id = ? OR to_account_id = ?) AND deleted_at IS NULL',
      [Variable.withString(id), Variable.withString(id)],
    );
    final n2 = await _count(
      'SELECT COUNT(*) AS c FROM trades WHERE account_id = ? AND deleted_at IS NULL',
      [Variable.withString(id)],
    );
    if (n + n2 > 0) throw ApiException('帳戶還有流水，請改封存', status: 409);
    await (db.delete(
      db.openingCashDrafts,
    )..where((d) => d.accountId.equals(id))).go();
    await (db.delete(db.accounts)..where((a) => a.id.equals(id))).go();
  }

  @override
  /// Categories for one book, ordered by kind then sort (`categories.go`).
  Future<List<Category>> listCategories(String bookId) async {
    await _loadBook(bookId);
    final rows = await (db.select(db.categories)
          ..where((c) => c.bookId.equals(bookId))
          ..orderBy([
            (c) => OrderingTerm(expression: c.kind),
            (c) => OrderingTerm(expression: c.sort),
            (c) => OrderingTerm(expression: c.name),
          ]))
        .get();
    return [for (final c in rows) _toCat(c)];
  }

  @override
  /// Adds a user category. Kind must be income or expense. Not a system row.
  Future<Category> createCategory({
    required String bookId,
    required String name,
    required String kind,
  }) async {
    final b = await _loadBook(bookId);
    _rejectArchived(b);
    name = name.trim();
    if (name.isEmpty) throw ApiException('請填分類名稱', status: 400);
    if (kind != 'income' && kind != 'expense') {
      throw ApiException('分類必須是收入或支出', status: 400);
    }
    final maxSort = await db.customSelect(
      'SELECT COALESCE(MAX(sort),0)+1 AS s FROM categories WHERE book_id = ? AND kind = ?',
      variables: [Variable.withString(bookId), Variable.withString(kind)],
    ).getSingle();
    final sort = asInt(maxSort.data['s']);
    final id = newId();
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            bookId: bookId,
            name: name,
            kind: kind,
            isSystem: const Value(false),
            sort: Value(sort),
          ),
        );
    final row = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id))).getSingle();
    return _toCat(row);
  }

  @override
  /// Renames a category. Version mismatch is 409.
  Future<Category> patchCategory({
    required String id,
    required String name,
    required int version,
  }) async {
    final row = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) throw ApiException('找不到分類', status: 404);
    _rejectArchived(await _loadBook(row.bookId));
    name = name.trim();
    final n = await (db.update(db.categories)..where(
          (c) => c.id.equals(id) & c.version.equals(version),
        ))
        .write(
          CategoriesCompanion(name: Value(name), version: Value(version + 1)),
        );
    if (n == 0) throw ApiException('資料已被更新，請重抓再送', status: 409);
    return _toCat(
      await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle(),
    );
  }

  @override
  /// Hides a category. System categories can be archived but not deleted.
  Future<void> archiveCategory(String id) async {
    final row = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) throw ApiException('找不到分類', status: 404);
    _rejectArchived(await _loadBook(row.bookId));
    await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        archivedAt: Value(_ts()),
        version: Value(row.version + 1),
      ),
    );
  }

  @override
  /// Deletes a non-system category that has no live entries
  /// (`categories.go` `handleCategoriesDelete`).
  Future<void> deleteCategory(String id) async {
    final row = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) throw ApiException('找不到分類', status: 404);
    if (row.isSystem) throw ApiException('系統分類不能刪，請改封存', status: 409);
    _rejectArchived(await _loadBook(row.bookId));
    final n = await _count(
      'SELECT COUNT(*) AS c FROM entries WHERE category_id = ? AND deleted_at IS NULL',
      [Variable.withString(id)],
    );
    if (n > 0) throw ApiException('分類還有分錄，請改封存', status: 409);
    await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
  }

  @override
  /// Live entries for one book. Optional day, range, account, or category
  /// filters. Ports `entries.go` `handleEntriesList`. Deleted rows are omitted.
  Future<List<Entry>> listEntries({
    required String bookId,
    String? date,
    String? from,
    String? to,
    String? accountId,
    String? categoryId,
  }) async {
    await _loadBook(bookId);
    final q = db.select(db.entries)
      ..where((e) => e.bookId.equals(bookId) & e.deletedAt.isNull());
    if (date != null && date.isNotEmpty) {
      q.where((e) => e.date.equals(date));
    } else {
      if (from != null && from.isNotEmpty) {
        q.where((e) => e.date.isBiggerOrEqualValue(from));
      }
      if (to != null && to.isNotEmpty) {
        q.where((e) => e.date.isSmallerOrEqualValue(to));
      }
    }
    if (accountId != null && accountId.isNotEmpty) {
      q.where(
        (e) =>
            e.accountId.equals(accountId) | e.toAccountId.equals(accountId),
      );
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      q.where((e) => e.categoryId.equals(categoryId));
    }
    q.orderBy([
      (e) => OrderingTerm(expression: e.date),
      (e) => OrderingTerm(expression: e.createdAt),
    ]);
    return [for (final e in await q.get()) _toEntry(e)];
  }

  @override
  /// Inserts an income, expense, or transfer.
  ///
  /// Ports `entries.go` `handleEntriesCreate` plus `app.go` `idempotency`.
  /// A repeated [idempotencyKey] returns the stored entry and does not insert
  /// again. `opening_balance` is system-only. Amount must be > 0. An empty
  /// date becomes the Taipei creation day ([_today]). A date strictly before
  /// the book's opening date is 400 「不能記開帳日之前的帳」.
  Future<Entry> createEntry({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    // Same key replays the first response. Empty key is not cached.
    final cached = await _idempotentGet(idempotencyKey);
    if (cached != null) return Entry.fromJson(cached);

    final bookId = asStr(body['book_id']);
    if (bookId.isEmpty) throw ApiException('缺少 book_id', status: 400);
    final b = await _loadBook(bookId);
    _rejectArchived(b);
    final type = asStr(body['type']);
    // Only applyOpening writes this type.
    if (type == 'opening_balance') {
      throw ApiException('開帳分錄只能由系統寫入', status: 400);
    }
    final amount = asInt(body['amount']);
    if (amount <= 0) throw ApiException('金額必須大於 0', status: 400);
    var date = asStr(body['date']);
    if (date.isEmpty) date = _today();
    if (!isIsoDateStr(date)) throw ApiException('日期格式不對', status: 400);
    // Lexicographic compare is safe for YYYY-MM-DD. Opening day itself is allowed.
    if (b.openingDate != null && date.compareTo(b.openingDate!) < 0) {
      throw ApiException('不能記開帳日之前的帳', status: 400);
    }
    final accountId = asStr(body['account_id']);
    final toAccountId = asStrN(body['to_account_id']);
    final categoryId = asStrN(body['category_id']);
    await _validateEntry(
      bookId: b.id,
      type: type,
      acc: accountId,
      to: toAccountId,
      cat: categoryId,
    );
    final id = newId();
    final ts = _ts();
    await db
        .into(db.entries)
        .insert(
          EntriesCompanion.insert(
            id: id,
            bookId: b.id,
            date: date,
            type: type,
            amount: amount,
            accountId: accountId,
            toAccountId: Value(toAccountId),
            categoryId: Value(categoryId),
            note: Value(asStr(body['note'])),
            instrumentId: Value(asStrN(body['instrument_id'])),
            createdAt: ts,
            updatedAt: ts,
          ),
        );
    final row = await (db.select(
      db.entries,
    )..where((e) => e.id.equals(id))).getSingle();
    final entry = _toEntry(row);
    await _idempotentPut(idempotencyKey, _entryJson(entry));
    return entry;
  }

  Map<String, dynamic> _entryJson(Entry e) => {
    'id': e.id,
    'book_id': e.bookId,
    'date': e.date,
    'type': e.type,
    'amount': e.amount,
    'account_id': e.accountId,
    'to_account_id': e.toAccountId,
    'category_id': e.categoryId,
    'note': e.note,
    'created_at': e.createdAt,
    'version': e.version,
  };

  /// Returns the stored JSON for [key], or null when the key is new or blank.
  ///
  /// Ports the replay half of `app.go` `idempotency`. Used by [createEntry]
  /// and [createTrade] only (the POSTs the UI sends).
  Future<Map<String, dynamic>?> _idempotentGet(String key) async {
    if (key.isEmpty) return null;
    final row = await (db.select(
      db.idempotencyKeys,
    )..where((k) => k.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    return asJsonMap(jsonDecode(row.responseBody));
  }

  /// Saves a successful POST body so the next call with [key] is a replay.
  Future<void> _idempotentPut(String key, Map<String, dynamic> body) async {
    if (key.isEmpty) return;
    await db
        .into(db.idempotencyKeys)
        .insertOnConflictUpdate(
          IdempotencyKeysCompanion.insert(
            key: key,
            method: 'POST',
            path: '',
            responseStatus: 201,
            responseBody: jsonEncode(body),
            createdAt: _ts(),
          ),
        );
  }

  /// Account, category, and transfer checks from `entries.go` `validateEntry`.
  ///
  /// Income and expense need a same-book category of the same kind and no
  /// destination account. Transfers need a different destination in the same
  /// book, no category, and cannot move between two credit cards.
  Future<void> _validateEntry({
    required String bookId,
    required String type,
    required String acc,
    String? to,
    String? cat,
  }) async {
    final account = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(acc))).getSingleOrNull();
    if (account == null) throw ApiException('帳戶不存在', status: 400);
    if (account.bookId != bookId) throw ApiException('帳戶不屬於這本帳', status: 400);
    switch (type) {
      case 'expense':
      case 'income':
        if (cat == null || cat.isEmpty) throw ApiException('請選分類', status: 400);
        final c = await (db.select(
          db.categories,
        )..where((x) => x.id.equals(cat))).getSingleOrNull();
        if (c == null) throw ApiException('分類不存在', status: 400);
        if (c.bookId != bookId) throw ApiException('分類不屬於這本帳', status: 400);
        if (c.kind != type) throw ApiException('分類種類和收支不符', status: 400);
        if (to != null && to.isNotEmpty) {
          throw ApiException('收支不要填轉入帳戶', status: 400);
        }
      case 'transfer':
        if (to == null || to.isEmpty) {
          throw ApiException('轉帳請選轉入帳戶', status: 400);
        }
        if (to == acc) throw ApiException('不能轉給自己', status: 400);
        final dest = await (db.select(
          db.accounts,
        )..where((a) => a.id.equals(to))).getSingleOrNull();
        if (dest == null) throw ApiException('轉入帳戶不存在', status: 400);
        if (dest.bookId != bookId) {
          throw ApiException('轉入帳戶不屬於這本帳', status: 400);
        }
        if (account.type == 'credit_card' && dest.type == 'credit_card') {
          throw ApiException('兩張信用卡之間不能轉帳', status: 400);
        }
        if (cat != null && cat.isNotEmpty) {
          throw ApiException('轉帳不要填分類', status: 400);
        }
      default:
        throw ApiException('類型不對', status: 400);
    }
  }

  /// Net cash of the book on [asOf], inclusive.
  ///
  /// Ports `stats.go` `cashNetAt`. Credit cards flip the sign (a positive
  /// card balance is debt). Opening balance and income add; expense and the
  /// source side of a transfer subtract; the transfer destination adds.
  /// Buys subtract TWD proceeds and sells add them. Airdrops and opening
  /// lots do not move cash — their cost is in positions, and opening cash
  /// is the `opening_balance` entry.
  Future<int> cashNetAt(String bookId, String asOf) async {
    final entries = await (db.select(db.entries)..where(
          (e) =>
              e.bookId.equals(bookId) &
              e.deletedAt.isNull() &
              e.date.isSmallerOrEqualValue(asOf),
        ))
        .get();
    final trades = await (db.select(db.trades)..where(
          (t) =>
              t.bookId.equals(bookId) &
              t.deletedAt.isNull() &
              t.date.isSmallerOrEqualValue(asOf),
        ))
        .get();
    final accounts = await (db.select(
      db.accounts,
    )..where((a) => a.bookId.equals(bookId))).get();
    final typeById = {for (final a in accounts) a.id: a.type};
    var n = 0;
    void addDelta(String accountId, int signed) {
      final type = typeById[accountId];
      // A card charge (negative signed on an expense) increases what is owed,
      // so the contribution to net worth is inverted.
      if (type == 'credit_card') {
        n -= signed;
      } else {
        n += signed;
      }
    }

    for (final e in entries) {
      var signed = 0;
      switch (e.type) {
        case 'opening_balance':
        case 'income':
          signed = e.amount;
        case 'expense':
        case 'transfer':
          signed = -e.amount;
      }
      addDelta(e.accountId, signed);
      if (e.type == 'transfer' && e.toAccountId != null) {
        addDelta(e.toAccountId!, e.amount);
      }
    }
    for (final t in trades) {
      var signed = 0;
      if (t.side == 'buy') {
        signed = -t.proceedsOrCostTwd;
      } else if (t.side == 'sell') {
        signed = t.proceedsOrCostTwd;
      }
      addDelta(t.accountId, signed);
    }
    return n;
  }

  /// Open-lot market value and unrealized P&L. Ports `stats.go` `positionMark`.
  ///
  /// Quantity must be > 0. USD prices use the book FX rate, or 32 if none is
  /// stored. A lot with no quote is marked at cost and sets `unquoted`, so
  /// net worth still includes it instead of dropping to zero.
  Future<({int mv, int unreal, String? asOf, bool unquoted})> _positionMark(
    String bookId,
  ) async {
    final rows = await db.customSelect(
      '''
      SELECT p.qty, p.cost_twd, i.quote_currency, q.price, q.ccy, q.as_of, f.usd_twd
      FROM positions p
      JOIN instruments i ON i.id = p.instrument_id
      LEFT JOIN quotes q ON q.instrument_id = i.id
      LEFT JOIN fx_rates f ON f.book_id = p.book_id
      WHERE p.book_id = ? AND CAST(p.qty AS REAL) > 0
      ''',
      variables: [Variable.withString(bookId)],
    ).get();
    var mvD = Decimal.zero;
    var costD = Decimal.zero;
    String? asOf;
    var unquoted = false;
    for (final r in rows) {
      final qty = decOrZero(r.data['qty']?.toString());
      final cost = decOrZero(r.data['cost_twd']?.toString());
      costD += cost;
      final priceRaw = r.data['price']?.toString();
      if (priceRaw == null || priceRaw.isEmpty) {
        // Unquoted lot still counts, at cost, and the summary says so.
        unquoted = true;
        mvD += cost;
        continue;
      }
      var px = dec(priceRaw);
      var ccy = asStr(r.data['quote_currency']);
      final pccy = r.data['ccy']?.toString();
      if (pccy != null && pccy.isNotEmpty) ccy = pccy;
      if (ccy == 'USD') {
        // Same 32 fallback as account market value and quotes.go.
        var mult = Decimal.fromInt(32);
        final fx = r.data['usd_twd']?.toString();
        if (fx != null && fx.isNotEmpty) mult = dec(fx);
        px = px * mult;
      }
      mvD += qty * px;
      final qasof = r.data['as_of']?.toString();
      if (qasof != null && (asOf == null || qasof.compareTo(asOf) > 0)) {
        asOf = qasof;
      }
    }
    return (
      mv: round0(mvD),
      unreal: round0(mvD - costD),
      asOf: asOf,
      unquoted: unquoted,
    );
  }

  @override
  /// Home summary. Ports `stats.go` `handleStatsSummary`.
  ///
  /// Month defaults to the current Taipei `YYYY-MM`. Today expense is that
  /// Taipei day. Net worth is [cashNetAt] through today plus [_positionMark].
  /// Change versus opening is net worth minus cash on the opening date minus
  /// the TWD cost of opening lots (so the opening snapshot itself is zero
  /// change when nothing else has happened).
  Future<StatsSummary> statsSummary({
    required String bookId,
    String? month,
  }) async {
    final b = await _loadBook(bookId);
    month = (month == null || month.isEmpty) ? yearMonthNow(_now()) : month;
    if (month.length < 7) throw ApiException('月份格式不對', status: 400);
    month = month.substring(0, 7);
    final start = monthStart(month);
    if (!isIsoDateStr(start)) throw ApiException('月份格式不對', status: 400);
    final end = monthEndExclusive(month);
    final today = _today();

    Future<int> sumType(String type, String from, String to, {bool eq = false}) async {
      final sql = eq
          ? 'SELECT COALESCE(SUM(amount),0) AS s FROM entries WHERE book_id = ? AND deleted_at IS NULL AND type = ? AND date = ?'
          : 'SELECT COALESCE(SUM(amount),0) AS s FROM entries WHERE book_id = ? AND deleted_at IS NULL AND type = ? AND date >= ? AND date < ?';
      final vars = eq
          ? [
              Variable.withString(bookId),
              Variable.withString(type),
              Variable.withString(from),
            ]
          : [
              Variable.withString(bookId),
              Variable.withString(type),
              Variable.withString(from),
              Variable.withString(to),
            ];
      final row = await db.customSelect(sql, variables: vars).getSingle();
      return asInt(row.data['s']);
    }

    final todayExp = await sumType('expense', today, today, eq: true);
    final monthExp = await sumType('expense', start, end);
    final monthInc = await sumType('income', start, end);
    final cashNet = await cashNetAt(bookId, today);
    final mark = await _positionMark(bookId);
    // 資產 = cash (cards as debt) + marked positions.
    final netWorth = cashNet + mark.mv;
    var openingNet = 0;
    if (b.openingDate != null) {
      openingNet = await cashNetAt(bookId, b.openingDate!);
      final openCost = await db.customSelect(
        "SELECT COALESCE(SUM(proceeds_or_cost_twd),0) AS s FROM trades WHERE book_id = ? AND deleted_at IS NULL AND side = 'opening'",
        variables: [Variable.withString(bookId)],
      ).getSingle();
      // Opening lots are not in cashNetAt; add their cost so the baseline
      // matches the opening net worth (cash + position cost).
      openingNet += asInt(openCost.data['s']);
    }
    return StatsSummary(
      todayExpense: todayExp,
      monthExpense: monthExp,
      monthIncome: monthInc,
      netWorth: netWorth,
      netWorthChangeVsOpening: netWorth - openingNet,
      cashNet: cashNet,
      positionMv: mark.mv,
      unrealized: mark.unreal,
      quoteAsOf: mark.asOf,
      somePositionsUnquoted: mark.unquoted,
      today: today,
      month: month,
    );
  }

  @override
  /// One point per day from [from] through [to], inclusive.
  ///
  /// Ports `stats.go` `handleStatsDaily`. [from] may not be earlier than the
  /// opening date (400 「from 不可早於開帳日」). Expense and income are that day's
  /// booked sums from `type = 'expense'` / `'income'` only — transfers and
  /// opening_balance never add to those two fields. [DailyPoint.cashNet] is
  /// a running total (opening + transfers included) and is only for the
  /// 現金淨資產 toggle, not the 支出 / 收入 line.
  Future<List<DailyPoint>> statsDaily({
    required String bookId,
    required String from,
    required String to,
  }) async {
    final b = await _loadBook(bookId);
    if (from.isEmpty || to.isEmpty) {
      throw ApiException('需要 from 與 to', status: 400);
    }
    if (!isIsoDateStr(from) || !isIsoDateStr(to)) {
      throw ApiException('日期格式不對', status: 400);
    }
    // The chart cannot start before the book exists.
    if (b.openingDate != null && from.compareTo(b.openingDate!) < 0) {
      throw ApiException('from 不可早於開帳日', status: 400);
    }
    final days = <String>[];
    var cur = DateTime.parse(from);
    final last = DateTime.parse(to);
    while (!cur.isAfter(last)) {
      days.add(
        '${cur.year}-${pad2(cur.month)}-${pad2(cur.day)}',
      );
      cur = cur.add(const Duration(days: 1));
    }
    final entries = await (db.select(db.entries)..where(
          (e) =>
              e.bookId.equals(bookId) &
              e.deletedAt.isNull() &
              e.date.isBiggerOrEqualValue(from) &
              e.date.isSmallerOrEqualValue(to),
        ))
        .get();
    final exp = <String, int>{};
    final inc = <String, int>{};
    for (final e in entries) {
      if (e.type == 'expense') {
        exp[e.date] = (exp[e.date] ?? 0) + e.amount;
      } else if (e.type == 'income') {
        inc[e.date] = (inc[e.date] ?? 0) + e.amount;
      }
    }
    final out = [
      for (final d in days)
        DailyPoint(
          date: d,
          expense: exp[d] ?? 0,
          income: inc[d] ?? 0,
          cashNet: 0,
        ),
    ];
    // Running cash starts the day before the opening day, so the opening
    // balance entry on that day is included in the first points.
    var baseFrom = from;
    if (b.openingDate != null) baseFrom = b.openingDate!;
    var running = await cashNetAt(bookId, prevDay(baseFrom));
    final idx = <String, int>{};
    final accounts = await (db.select(
      db.accounts,
    )..where((a) => a.bookId.equals(bookId))).get();
    final typeById = {for (final a in accounts) a.id: a.type};
    void add(String date, String aid, int signed) {
      final type = typeById[aid];
      final delta = type == 'credit_card' ? -signed : signed;
      idx[date] = (idx[date] ?? 0) + delta;
    }

    for (final e in entries) {
      var signed = 0;
      switch (e.type) {
        case 'opening_balance':
        case 'income':
          signed = e.amount;
        case 'expense':
        case 'transfer':
          signed = -e.amount;
      }
      add(e.date, e.accountId, signed);
      if (e.type == 'transfer' && e.toAccountId != null) {
        add(e.date, e.toAccountId!, e.amount);
      }
    }
    final trades = await (db.select(db.trades)..where(
          (t) =>
              t.bookId.equals(bookId) &
              t.deletedAt.isNull() &
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerOrEqualValue(to),
        ))
        .get();
    for (final t in trades) {
      var signed = 0;
      if (t.side == 'buy') {
        signed = -t.proceedsOrCostTwd;
      } else if (t.side == 'sell') {
        signed = t.proceedsOrCostTwd;
      }
      add(t.date, t.accountId, signed);
    }
    return [
      for (final p in out)
        DailyPoint(
          date: p.date,
          expense: p.expense,
          income: p.income,
          cashNet: running += idx[p.date] ?? 0,
        ),
    ];
  }

  @override
  /// Expense totals by category for one month, or [[from], [to]] inclusive.
  ///
  /// Purpose: the 分析 pie is real booked expenses, not a placeholder.
  /// Rule: only `type = 'expense'`. Transfers and opening_balance never
  /// appear. A LEFT JOIN keeps rows with a null category_id and labels
  /// them 未分類. Zero groups are dropped. Ordered by amount descending.
  /// Key logic: [from]/[to] win so a year view can pass the calendar
  /// year; otherwise [month] is `[YYYY-MM-01, next month)`.
  Future<List<CategoryAmount>> statsByCategory({
    required String bookId,
    String? month,
    String? from,
    String? to,
  }) async {
    await _loadBook(bookId);
    late final String start;
    late final String endInclusive;
    if (from != null &&
        from.isNotEmpty &&
        to != null &&
        to.isNotEmpty) {
      if (!isIsoDateStr(from) || !isIsoDateStr(to)) {
        throw ApiException('日期格式不對', status: 400);
      }
      start = from;
      endInclusive = to;
    } else {
      month = (month == null || month.isEmpty) ? yearMonthNow(_now()) : month;
      month = month.substring(0, 7);
      start = monthStart(month);
      if (!isIsoDateStr(start)) throw ApiException('月份格式不對', status: 400);
      endInclusive = monthEnd(month);
    }
    final rows = await db.customSelect(
      '''
      SELECT COALESCE(c.id, '') AS category_id,
             COALESCE(c.name, '未分類') AS name,
             COALESCE(SUM(e.amount),0) AS amount
      FROM entries e
      LEFT JOIN categories c ON c.id = e.category_id
      WHERE e.book_id = ? AND e.deleted_at IS NULL AND e.type = 'expense'
        AND e.date >= ? AND e.date <= ?
      GROUP BY COALESCE(c.id, ''), COALESCE(c.name, '未分類')
      HAVING SUM(e.amount) > 0
      ORDER BY amount DESC
      ''',
      variables: [
        Variable.withString(bookId),
        Variable.withString(start),
        Variable.withString(endInclusive),
      ],
    ).get();
    return [
      for (final r in rows)
        CategoryAmount(
          categoryId: asStr(r.data['category_id']),
          name: asStr(r.data['name']),
          amount: asInt(r.data['amount']),
        ),
    ];
  }

  @override
  /// Holdings with market value when a quote exists. Ports `trades.go`
  /// `handlePositionsList`. USD uses the book FX rate or 32. No quote leaves
  /// market value null (the summary still marks that lot at cost). A
  /// non-positive quantity is [Position.closed].
  Future<List<Position>> listPositions(String bookId) async {
    await _loadBook(bookId);
    final rows = await db.customSelect(
      '''
      SELECT p.id, p.account_id, a.name AS account_name, i.symbol, i.name AS iname,
             i.asset_class, i.quote_currency, p.qty, p.cost_twd, p.realized_twd,
             p.cost_unknown, q.price, q.ccy, q.as_of, f.usd_twd
      FROM positions p
      JOIN accounts a ON a.id = p.account_id
      JOIN instruments i ON i.id = p.instrument_id
      LEFT JOIN quotes q ON q.instrument_id = i.id
      LEFT JOIN fx_rates f ON f.book_id = p.book_id
      WHERE p.book_id = ?
      ORDER BY CAST(p.qty AS REAL) DESC, i.symbol
      ''',
      variables: [Variable.withString(bookId)],
    ).get();
    final out = <Position>[];
    for (final r in rows) {
      final qty = asStr(r.data['qty']);
      final cost = asStr(r.data['cost_twd']);
      final qd = decOrZero(qty);
      final cd = decOrZero(cost);
      int? marketValue;
      int? unrealized;
      String? unrealizedPct;
      String? quoteAsOf;
      final priceRaw = r.data['price']?.toString();
      if (priceRaw != null && priceRaw.isNotEmpty) {
        var px = dec(priceRaw);
        var ccy = asStr(r.data['quote_currency']);
        final pccy = r.data['ccy']?.toString();
        if (pccy != null && pccy.isNotEmpty) ccy = pccy;
        if (ccy == 'USD') {
          // 32 until a real USD/TWD row exists (stats.go positionMark).
          var mult = Decimal.fromInt(32);
          final fx = r.data['usd_twd']?.toString();
          if (fx != null && fx.isNotEmpty) mult = dec(fx);
          px = px * mult;
        }
        final mv = qd * px;
        final unreal = mv - cd;
        marketValue = round0(mv);
        unrealized = round0(unreal);
        if (cd != Decimal.zero) {
          unrealizedPct = (div(unreal, cd) * Decimal.fromInt(100)).toString();
        }
        quoteAsOf = r.data['as_of']?.toString();
      }
      out.add(
        Position(
          id: asStr(r.data['id']),
          accountId: asStr(r.data['account_id']),
          accountName: asStr(r.data['account_name']),
          symbol: asStr(r.data['symbol']),
          name: asStr(r.data['iname']),
          assetClass: asStr(r.data['asset_class']),
          qty: qty,
          costTwd: cost,
          realizedTwd: asInt(r.data['realized_twd']),
          costUnknown: r.data['cost_unknown'] == true ||
              r.data['cost_unknown'] == 1,
          marketValue: marketValue,
          unrealized: unrealized,
          unrealizedPct: unrealizedPct,
          quoteAsOf: quoteAsOf,
          closed: !(qd > Decimal.zero),
        ),
      );
    }
    return out;
  }

  @override
  /// Live trades in date order, including `pair_id` for transfers.
  ///
  /// Ports `trades.go` `handleTradesList`. Symbol, name, asset class, and
  /// quote currency are added so the ledger can open the record sheet
  /// without a second query. Deleted rows stay out. Both transfer legs
  /// are returned; the 帳本 shows only `transfer_out`.
  Future<List<Map<String, dynamic>>> listTrades(String bookId) async {
    await _loadBook(bookId);
    final rows = await (db.select(db.trades)
          ..where((t) => t.bookId.equals(bookId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .get();
    final instruments = await (db.select(
      db.instruments,
    )..where((i) => i.bookId.equals(bookId))).get();
    final byId = {for (final instrument in instruments) instrument.id: instrument};
    return [
      for (final t in rows) _tradeJson(t, byId[t.instrumentId]),
    ];
  }

  Map<String, dynamic> _tradeJson(TradeRow t, [InstrumentRow? instrument]) {
    final json = <String, dynamic>{
      'id': t.id,
      'book_id': t.bookId,
      'date': t.date,
      'account_id': t.accountId,
      'instrument_id': t.instrumentId,
      'side': t.side,
      'qty': t.qty,
      'price': t.price,
      'price_ccy': t.priceCcy,
      'fee_twd': t.feeTwd,
      'proceeds_or_cost_twd': t.proceedsOrCostTwd,
      'fx_usd_twd': t.fxUsdTwd,
      'realized_twd': t.realizedTwd,
      'pair_id': t.pairId,
      'note': t.note,
      'created_at': t.createdAt,
      'version': t.version,
    };
    if (instrument != null) {
      json['symbol'] = instrument.symbol;
      json['name'] = instrument.name;
      json['asset_class'] = instrument.assetClass;
      json['quote_currency'] = instrument.quoteCurrency;
    }
    return json;
  }

  @override
  /// Inserts a buy, sell, airdrop, or paired transfer.
  ///
  /// Ports `trades.go` `handleTradesCreate`. The whole write, including the
  /// position update, is one transaction. A repeated [idempotencyKey] returns
  /// the first JSON body. Date defaults to the Taipei day and cannot be
  /// before the opening date (「不能記開帳日之前的帳」). Buys and sells require a
  /// price; proceeds are TWD (`qty × price × fx`, fee added on buys and
  /// subtracted on sells). Cost on the position is moving average: buys add
  /// proceeds, sells realize `round(proceeds − avg × qty)` and refuse a qty
  /// larger than the holding (409 「賣出數量大於持倉」). `side: transfer` is two
  /// legs, see [_applyTransfer].
  Future<Map<String, dynamic>> createTrade({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    final cached = await _idempotentGet(idempotencyKey);
    if (cached != null) return cached;

    final bookId = asStr(body['book_id']);
    if (bookId.isEmpty) throw ApiException('缺少 book_id', status: 400);
    final b = await _loadBook(bookId);
    _rejectArchived(b);
    var date = asStr(body['date']);
    if (date.isEmpty) date = _today();
    if (!isIsoDateStr(date)) throw ApiException('日期格式不對', status: 400);
    // Same opening-day rule as entries. The opening day itself is allowed.
    if (b.openingDate != null && date.compareTo(b.openingDate!) < 0) {
      throw ApiException('不能記開帳日之前的帳', status: 400);
    }
    final qty = decOrZero(asStr(body['qty']));
    if (!qtyPositive(qty)) throw ApiException('數量必須大於 0', status: 400);
    final feeTwd = asInt(body['fee_twd']);
    if (feeTwd < 0) throw ApiException('手續費不能為負', status: 400);
    var side = asStr(body['side']);
    const sides = {
      'buy',
      'sell',
      'airdrop',
      'transfer_in',
      'transfer_out',
      'transfer',
    };
    if (!sides.contains(side)) throw ApiException('成交方向不對', status: 400);

    return db.transaction(() async {
      final accountId = asStr(body['account_id']);
      final acc = await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(accountId))).getSingleOrNull();
      if (acc == null) throw ApiException('帳戶不存在', status: 400);
      if (acc.bookId != b.id ||
          (acc.type != 'broker' && acc.type != 'exchange')) {
        throw ApiException('成交帳戶必須是券商或交易所', status: 400);
      }
      final iid = await ensureInstrument(
        db,
        bookId: b.id,
        existing: asStrN(body['instrument_id']),
        symbol: asStr(body['symbol']),
        name: asStr(body['name']),
        assetClass: asStr(body['asset_class']),
        quoteCcy: asStr(body['quote_currency']),
      );
      // Book FX for USD prices. Missing or zero rate stays 1 until refresh
      // stores a rate; TWD prices force fx back to 1 below.
      var fx = Decimal.one;
      final fxRow = await (db.select(
        db.fxRates,
      )..where((f) => f.bookId.equals(b.id))).getSingleOrNull();
      if (fxRow != null && dec(fxRow.usdTwd) != Decimal.zero) {
        fx = dec(fxRow.usdTwd);
      }
      if (side == 'transfer') {
        final to = asStrN(body['to_account_id']);
        if (to == null) throw ApiException('轉倉請選轉入帳戶', status: 400);
        final pair = await _applyTransfer(
          bookId: b.id,
          date: date,
          fromAcc: accountId,
          toAcc: to,
          iid: iid,
          qty: qty,
          fee: feeTwd,
          note: asStr(body['note']),
          fx: fx,
        );
        await _idempotentPut(idempotencyKey, pair);
        return pair;
      }

      Decimal price = Decimal.zero;
      var priceCcy = asStr(body['price_ccy']);
      if (side == 'buy' || side == 'sell') {
        if (asStr(body['price']).isEmpty) {
          throw ApiException('買賣請填單價', status: 400);
        }
        try {
          price = dec(asStr(body['price']));
        } catch (_) {
          throw ApiException('單價不對', status: 400);
        }
        if (price < Decimal.zero) throw ApiException('單價不對', status: 400);
        if (priceCcy.isEmpty) priceCcy = 'TWD';
      }
      var useFx = fx;
      if (priceCcy == 'TWD' || priceCcy.isEmpty) useFx = Decimal.one;
      int proceeds = 0;
      int? realized;
      switch (side) {
        case 'buy':
          // Fee is part of cost, so it increases TWD proceeds.
          proceeds = round0(qty * price * useFx) + feeTwd;
        case 'sell':
          final gross = round0(qty * price * useFx);
          if (feeTwd > gross) throw ApiException('手續費大於成交額', status: 400);
          proceeds = gross - feeTwd;
        case 'airdrop':
          proceeds = 0;
          priceCcy = '';
      }

      var pos = await (db.select(db.positions)..where(
            (p) => p.accountId.equals(accountId) & p.instrumentId.equals(iid),
          ))
          .getSingleOrNull();
      var posQty = pos == null ? Decimal.zero : dec(pos.qty);
      var posCost = pos == null ? Decimal.zero : dec(pos.costTwd);
      var posReal = pos?.realizedTwd ?? 0;
      var avg = Decimal.zero;
      if (posQty > Decimal.zero) avg = div(posCost, posQty);
      switch (side) {
        case 'buy':
        case 'airdrop':
          final addCost = side == 'airdrop' ? Decimal.zero : dInt(proceeds);
          posCost += addCost;
          posQty += qty;
        case 'sell':
          // Live sells reject immediately. Opening edits use the replay's
          // 「修改後持倉會變負數」 instead, because a later buy can cover a sell.
          if (qty > posQty) throw ApiException('賣出數量大於持倉', status: 409);
          // Moving-average realized P&L.
          final rlz = round0(dInt(proceeds) - avg * qty);
          realized = rlz;
          posQty -= qty;
          posCost -= avg * qty;
          if (posCost < Decimal.zero) posCost = Decimal.zero;
          posReal += rlz;
      }
      final tid = newId();
      final ts = _ts();
      await db
          .into(db.trades)
          .insert(
            TradesCompanion.insert(
              id: tid,
              bookId: b.id,
              date: date,
              accountId: accountId,
              instrumentId: iid,
              side: side,
              qty: qty.toString(),
              price: Value(
                side == 'buy' || side == 'sell' ? price.toString() : null,
              ),
              priceCcy: Value(
                side == 'buy' || side == 'sell' ? priceCcy : null,
              ),
              feeTwd: Value(feeTwd),
              proceedsOrCostTwd: Value(proceeds),
              fxUsdTwd: Value(useFx.toString()),
              realizedTwd: Value(realized),
              note: Value(asStr(body['note'])),
              createdAt: ts,
              updatedAt: ts,
            ),
          );
      if (pos == null) {
        await db
            .into(db.positions)
            .insert(
              PositionsCompanion.insert(
                id: newId(),
                bookId: b.id,
                accountId: accountId,
                instrumentId: iid,
                qty: Value(posQty.toString()),
                costTwd: Value(posCost.toString()),
                realizedTwd: Value(posReal),
                updatedAt: ts,
              ),
            );
      } else {
        await (db.update(db.positions)..where((p) => p.id.equals(pos.id)))
            .write(
          PositionsCompanion(
            qty: Value(posQty.toString()),
            costTwd: Value(posCost.toString()),
            realizedTwd: Value(posReal),
            version: Value(pos.version + 1),
            updatedAt: Value(ts),
          ),
        );
      }
      final row = await (db.select(
        db.trades,
      )..where((t) => t.id.equals(tid))).getSingle();
      final json = _tradeJson(row);
      await _idempotentPut(idempotencyKey, json);
      return json;
    });
  }

  /// Moves a lot between two broker or exchange accounts.
  ///
  /// Ports `trades.go` `applyTransfer`. Writes `transfer_out` and
  /// `transfer_in` linked by `pair_id` each way. Cost moved is `avg × qty`.
  /// A fee becomes an expense in the system category 投資費用 when that
  /// category exists. Returns `{out, in}` ids.
  Future<Map<String, dynamic>> _applyTransfer({
    required String bookId,
    required String date,
    required String fromAcc,
    required String toAcc,
    required String iid,
    required Decimal qty,
    required int fee,
    required String note,
    required Decimal fx,
  }) async {
    if (fromAcc == toAcc) throw ApiException('不能轉給自己', status: 400);
    final dest = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(toAcc))).getSingleOrNull();
    if (dest == null) throw ApiException('轉入帳戶不存在', status: 400);
    if (dest.bookId != bookId ||
        (dest.type != 'broker' && dest.type != 'exchange')) {
      throw ApiException('轉入帳戶必須是券商或交易所', status: 400);
    }
    final pos = await (db.select(db.positions)..where(
          (p) => p.accountId.equals(fromAcc) & p.instrumentId.equals(iid),
        ))
        .getSingleOrNull();
    if (pos == null) throw ApiException('轉出帳戶沒有此持倉', status: 400);
    var posQty = dec(pos.qty);
    var posCost = dec(pos.costTwd);
    if (qty > posQty) throw ApiException('轉出數量大於持倉', status: 400);
    var avg = Decimal.zero;
    if (posQty > Decimal.zero) avg = div(posCost, posQty);
    // Cost follows the shares; the source's average does not change.
    final move = avg * qty;
    posQty -= qty;
    posCost -= move;
    if (posCost < Decimal.zero) posCost = Decimal.zero;
    final ts = _ts();
    await (db.update(db.positions)..where((p) => p.id.equals(pos.id))).write(
      PositionsCompanion(
        qty: Value(posQty.toString()),
        costTwd: Value(posCost.toString()),
        version: Value(pos.version + 1),
        updatedAt: Value(ts),
      ),
    );
    final outID = newId();
    final inID = newId();
    await db
        .into(db.trades)
        .insert(
          TradesCompanion.insert(
            id: outID,
            bookId: bookId,
            date: date,
            accountId: fromAcc,
            instrumentId: iid,
            side: 'transfer_out',
            qty: qty.toString(),
            feeTwd: Value(fee),
            proceedsOrCostTwd: const Value(0),
            fxUsdTwd: Value(fx.toString()),
            pairId: Value(inID),
            note: Value(note),
            createdAt: ts,
            updatedAt: ts,
          ),
        );
    await db
        .into(db.trades)
        .insert(
          TradesCompanion.insert(
            id: inID,
            bookId: bookId,
            date: date,
            accountId: toAcc,
            instrumentId: iid,
            side: 'transfer_in',
            qty: qty.toString(),
            feeTwd: const Value(0),
            proceedsOrCostTwd: Value(round0(move)),
            fxUsdTwd: Value(fx.toString()),
            pairId: Value(outID),
            note: Value(note),
            createdAt: ts,
            updatedAt: ts,
          ),
        );
    final inPos = await (db.select(db.positions)..where(
          (p) => p.accountId.equals(toAcc) & p.instrumentId.equals(iid),
        ))
        .getSingleOrNull();
    if (inPos == null) {
      await db
          .into(db.positions)
          .insert(
            PositionsCompanion.insert(
              id: newId(),
              bookId: bookId,
              accountId: toAcc,
              instrumentId: iid,
              qty: Value(qty.toString()),
              costTwd: Value(move.toString()),
              updatedAt: ts,
            ),
          );
    } else {
      await (db.update(db.positions)..where((p) => p.id.equals(inPos.id)))
          .write(
        PositionsCompanion(
          qty: Value((dec(inPos.qty) + qty).toString()),
          costTwd: Value((dec(inPos.costTwd) + move).toString()),
          version: Value(inPos.version + 1),
          updatedAt: Value(ts),
        ),
      );
    }
    if (fee > 0) {
      final cat = await (db.select(db.categories)..where(
            (c) =>
                c.bookId.equals(bookId) &
                c.name.equals('投資費用') &
                c.kind.equals('expense'),
          ))
          .getSingleOrNull();
      if (cat != null) {
        await db
            .into(db.entries)
            .insert(
              EntriesCompanion.insert(
                id: newId(),
                bookId: bookId,
                date: date,
                type: 'expense',
                amount: fee,
                accountId: fromAcc,
                categoryId: Value(cat.id),
                note: const Value('搬倉手續費'),
                createdAt: ts,
                updatedAt: ts,
              ),
            );
      }
    }
    return {'out': outID, 'in': inID};
  }

  @override
  /// Drafts plus a preview net worth. Ports `opening.go` `handleOpeningGet`.
  ///
  /// Preview adds cash drafts (credit cards subtracted) and position costs.
  /// [OpeningSnapshot.someCostUnknown] is set when any draft has no cost.
  Future<OpeningSnapshot> getOpening(String bookId) async {
    final b = await _loadBook(bookId);
    final accounts = await _accountsWithBalance(bookId);
    final cashRows = await (db.select(
      db.openingCashDrafts,
    )..where((d) => d.bookId.equals(bookId))).get();
    final cashDrafts = [
      for (final d in cashRows)
        OpeningCashDraft(accountId: d.accountId, amount: d.amount),
    ];
    final posRows = await (db.select(
      db.openingPositionDrafts,
    )..where((d) => d.bookId.equals(bookId))).get();
    final positionDrafts = [
      for (final p in posRows)
        OpeningPositionDraft(
          accountId: p.accountId,
          instrumentId: p.instrumentId,
          symbol: p.symbol,
          name: p.name,
          assetClass: p.assetClass,
          quoteCurrency: p.quoteCurrency,
          qty: p.qty,
          costTwd: p.costTwd,
          costUnknown: p.costUnknown,
        ),
    ];
    var preview = 0;
    for (final d in cashDrafts) {
      final typ = accounts
          .where((a) => a.id == d.accountId)
          .map((a) => a.type)
          .firstWhere((_) => true, orElse: () => '');
      if (typ == 'credit_card') {
        preview -= d.amount;
      } else {
        preview += d.amount;
      }
    }
    for (final p in positionDrafts) {
      preview += round0(decOrZero(p.costTwd));
    }
    final hasUnknown = positionDrafts.any((p) => p.costUnknown);
    return OpeningSnapshot(
      openingDate: b.openingDate,
      accounts: accounts,
      cashDrafts: cashDrafts,
      positionDrafts: positionDrafts,
      previewNetWorth: preview,
      someCostUnknown: hasUnknown,
    );
  }

  @override
  /// Saves opening date, cash drafts, and/or position drafts, then materializes.
  ///
  /// Ports `opening.go` `handleOpeningPut`. The whole body runs in one
  /// transaction. [applyOpening] replays opening lots and later trades in
  /// time order (moving-average cost). If that replay would make a holding
  /// negative, it throws 422 「修改後持倉會變負數」 and the transaction rolls
  /// back the date, the drafts, and the positions together.
  ///
  /// Keys are optional. A missing `positions` key re-dates existing opening
  /// trades instead of replacing them. A missing `accounts` key leaves cash
  /// drafts alone. `opening_date` of null or "" clears the date.
  Future<OpeningSnapshot> putOpening({
    required String bookId,
    required Map<String, dynamic> body,
  }) async {
    final b = await _loadBook(bookId);
    _rejectArchived(b);
    // One transaction: date, drafts, materialized rows, and the replay.
    // 422 from rebuildPositions undoes all of them.
    await db.transaction(() async {
      if (body.containsKey('opening_date')) {
        final raw = body['opening_date'];
        if (raw == null || asStr(raw).isEmpty) {
          await (db.update(db.books)..where((x) => x.id.equals(bookId))).write(
            BooksCompanion(
              openingDate: const Value(null),
              version: Value(b.version + 1),
            ),
          );
        } else {
          final od = asDate(asStr(raw));
          if (!isIsoDateStr(od)) throw ApiException('開帳日格式不對', status: 400);
          // Block moving the opening day past an entry or trade that is not
          // itself an opening row. Opening rows are rewritten onto the new day.
          final earliest = await _earliestNonOpening(bookId);
          if (earliest != null && earliest.compareTo(od) < 0) {
            throw ApiException(
              '已有早於新開帳日的紀錄（$earliest），不能把開帳日往後改',
              status: 400,
            );
          }
          await (db.update(db.books)..where((x) => x.id.equals(bookId))).write(
            BooksCompanion(
              openingDate: Value(od),
              version: Value(b.version + 1),
            ),
          );
        }
      }
      if (body.containsKey('accounts')) {
        await (db.delete(
          db.openingCashDrafts,
        )..where((d) => d.bookId.equals(bookId))).go();
        final accounts = body['accounts'];
        if (accounts is List) {
          for (final raw in accounts) {
            if (raw is! Map) continue;
            final m = Map<String, dynamic>.from(raw);
            final amount = asInt(m['amount']);
            if (amount < 0) throw ApiException('開帳金額不能為負', status: 400);
            final aid = asStr(m['account_id']);
            if (aid.isEmpty) throw ApiException('缺少 account_id', status: 400);
            try {
              await db
                  .into(db.openingCashDrafts)
                  .insertOnConflictUpdate(
                    OpeningCashDraftsCompanion.insert(
                      bookId: bookId,
                      accountId: aid,
                      amount: amount,
                    ),
                  );
            } catch (_) {
              throw ApiException('帳戶不存在或不屬於這本帳', status: 400);
            }
          }
        }
      }
      if (body.containsKey('positions')) {
        await (db.delete(
          db.openingPositionDrafts,
        )..where((d) => d.bookId.equals(bookId))).go();
        final positions = body['positions'];
        if (positions is List) {
          for (final raw in positions) {
            if (raw is! Map) continue;
            final m = Map<String, dynamic>.from(raw);
            Decimal qty;
            try {
              qty = dec(asStr(m['qty']));
            } catch (_) {
              throw ApiException('數量必須大於 0', status: 400);
            }
            if (!qtyPositive(qty)) {
              throw ApiException('數量必須大於 0', status: 400);
            }
            var cost = Decimal.zero;
            final costRaw = asStr(m['cost_twd']);
            if (costRaw.isNotEmpty) {
              try {
                cost = dec(costRaw);
              } catch (_) {
                throw ApiException('成本不對', status: 400);
              }
              if (cost < Decimal.zero) throw ApiException('成本不對', status: 400);
            }
            final unknown = m['cost_unknown'] == true;
            if (unknown) cost = Decimal.zero;
            final symbol = asStr(m['symbol']);
            if (symbol.isEmpty) throw ApiException('請填標的代號', status: 400);
            var assetClass = asStr(m['asset_class']);
            if (assetClass.isEmpty) assetClass = 'tw_stock';
            var quoteCcy = asStr(m['quote_currency']);
            if (quoteCcy.isEmpty) {
              quoteCcy = assetClass == 'tw_stock' ? 'TWD' : 'USD';
            }
            await db
                .into(db.openingPositionDrafts)
                .insert(
                  OpeningPositionDraftsCompanion.insert(
                    id: newId(),
                    bookId: bookId,
                    accountId: asStr(m['account_id']),
                    instrumentId: Value(asStrN(m['instrument_id'])),
                    symbol: symbol,
                    name: Value(asStr(m['name'])),
                    assetClass: assetClass,
                    quoteCurrency: quoteCcy,
                    qty: qty.toString(),
                    costTwd: Value(cost.toString()),
                    costUnknown: Value(unknown),
                  ),
                );
          }
        }
      }
      // Replay only when the client sent positions. Cash-only saves re-date
      // opening trades and replace opening_balance entries.
      await applyOpening(
        db,
        bookId: bookId,
        applyPositions: body.containsKey('positions'),
        clock: _clock,
      );
    });
    return getOpening(bookId);
  }

  /// Earliest user entry or non-opening trade, used to block a later opening day.
  ///
  /// `opening_balance` entries and `opening` trades are excluded because
  /// [applyOpening] moves those onto the new date (`opening.go` LEAST query).
  Future<String?> _earliestNonOpening(String bookId) async {
    final e = await db.customSelect(
      "SELECT MIN(date) AS d FROM entries WHERE book_id = ? AND type <> 'opening_balance'",
      variables: [Variable.withString(bookId)],
    ).getSingle();
    final t = await db.customSelect(
      "SELECT MIN(date) AS d FROM trades WHERE book_id = ? AND side <> 'opening'",
      variables: [Variable.withString(bookId)],
    ).getSingle();
    final ed = e.data['d']?.toString();
    final td = t.data['d']?.toString();
    final dates = [
      if (ed != null && ed.isNotEmpty && ed != 'null') asDate(ed),
      if (td != null && td.isNotEmpty && td != 'null') asDate(td),
    ];
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }

  @override
  /// Refreshes USD/TWD and every unlocked instrument. Ports `quotes.go`
  /// `handleQuotesRefresh`.
  ///
  /// FX and each symbol are skipped when tried in the last five minutes, or
  /// when the stored `as_of` is younger than five minutes. A locked quote
  /// (manual or otherwise) is never overwritten. FX failure appends 「匯率」
  /// and, when the book has no rate yet, inserts a manual 32. A symbol
  /// failure is listed by symbol and the previous price stays. The message
  /// is 「報價失敗」 when anything failed. Sources and their fallbacks are in
  /// [QuoteClient].
  Future<QuoteRefresh> refreshQuotes(String bookId) async {
    await _loadBook(bookId);
    final fxRow = await (db.select(
      db.fxRates,
    )..where((f) => f.bookId.equals(bookId))).getSingleOrNull();
    var needFX =
        fxRow == null ||
        _now().difference(DateTime.tryParse(fxRow.asOf)?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0)) >
            const Duration(minutes: 5);
    final fxKey = 'fx:$bookId';
    if (needFX && _recentlyAttempted(fxKey)) needFX = false;
    final failures = <String>[];
    if (needFX) {
      _markAttempt(fxKey);
      try {
        final rate = await quotes.fetchUsdTwd();
        await db
            .into(db.fxRates)
            .insertOnConflictUpdate(
              FxRatesCompanion.insert(
                bookId: bookId,
                usdTwd: rate.toString(),
                asOf: _ts(),
                source: const Value('auto'),
              ),
            );
      } catch (_) {
        failures.add('匯率');
        if (fxRow == null) {
          // No rate at all: keep valuation working with the Go default of 32.
          await db
              .into(db.fxRates)
              .insertOnConflictUpdate(
                FxRatesCompanion.insert(
                  bookId: bookId,
                  usdTwd: '32',
                  asOf: _ts(),
                  source: const Value('manual'),
                ),
              );
        }
      }
    }
    final insts = await db.customSelect(
      '''
      SELECT i.id, i.symbol, i.asset_class, i.quote_currency,
             COALESCE(q.locked, 0) AS locked, COALESCE(q.source, '') AS source, q.as_of
      FROM instruments i LEFT JOIN quotes q ON q.instrument_id = i.id
      WHERE i.book_id = ?
      ''',
      variables: [Variable.withString(bookId)],
    ).get();
    var updated = 0;
    for (final it in insts) {
      final locked = it.data['locked'] == true || it.data['locked'] == 1;
      final source = asStr(it.data['source']);
      // Locked manual quotes must never be overwritten by auto fetch.
      if (locked && source == 'manual') continue;
      if (locked) continue;
      final asof = DateTime.tryParse(asStr(it.data['as_of']));
      if (asof != null && _now().difference(asof.toUtc()) < const Duration(minutes: 5)) {
        continue;
      }
      final iid = asStr(it.data['id']);
      final symbol = asStr(it.data['symbol']);
      final ikey = 'q:$iid';
      if (_recentlyAttempted(ikey)) {
        final prev = _lastFail[bookId] ?? const [];
        if (prev.contains(symbol)) failures.add(symbol);
        continue;
      }
      _markAttempt(ikey);
      try {
        final (price, ccy) = await quotes.fetchQuote(
          symbol,
          asStr(it.data['asset_class']),
        );
        await db
            .into(db.quotes)
            .insertOnConflictUpdate(
              QuotesCompanion.insert(
                instrumentId: iid,
                price: price.toString(),
                ccy: ccy,
                asOf: _ts(),
                source: const Value('auto'),
                locked: const Value(false),
              ),
            );
        updated++;
      } catch (_) {
        failures.add(symbol);
      }
    }
    _lastFail[bookId] = [...failures];
    return QuoteRefresh(
      updated: updated,
      failed: failures,
      message: failures.isEmpty ? '' : '報價失敗',
      quoteFailed: failures.isNotEmpty,
    );
  }

  /// Writes a manual price. [locked] true keeps [refreshQuotes] from replacing it
  /// (`quotes.go` `handleQuotesManual`).
  Future<void> setManualQuote({
    required String instrumentId,
    required String price,
    String ccy = 'TWD',
    bool locked = false,
  }) async {
    final px = dec(price);
    if (!qtyPositive(px)) throw ApiException('價格不對', status: 400);
    await db
        .into(db.quotes)
        .insertOnConflictUpdate(
          QuotesCompanion.insert(
            instrumentId: instrumentId,
            price: px.toString(),
            ccy: ccy.isEmpty ? 'TWD' : ccy,
            asOf: _ts(),
            source: const Value('manual'),
            locked: Value(locked),
          ),
        );
  }

  @override
  /// JSON backup of one book. Ports `backup.go` `exportBook`.
  ///
  /// Keys and columns match the Go file so a Go export imports here and a
  /// file written here imports there: `book`, `accounts`, `categories`,
  /// `instruments`, `entries`, `trades`, `positions`, `quotes`, `fx_rates`.
  /// `book.user_id` is the nil UUID because this device has no users table;
  /// import ignores it. Trade `pair_id` is the sibling's id. Deleted rows
  /// are included (`deleted_at` set) the way Go exports them.
  Future<Map<String, dynamic>> exportBook(String id) async {
    final b = await _loadBook(id);
    Future<List<Map<String, dynamic>>> q(String sql) async {
      final rows = await db
          .customSelect(sql, variables: [Variable.withString(id)])
          .get();
      return [for (final r in rows) _exportRow(r.data)];
    }

    return {
      'book': {
        'id': b.id,
        // Go's book row always has user_id. Local books have none.
        'user_id': '00000000-0000-0000-0000-000000000000',
        'name': b.name,
        'archived_at': b.archivedAt,
        'base_currency': b.baseCurrency,
        'opening_date': b.openingDate,
        'timezone': b.timezone,
        'cost_method': b.costMethod,
        'version': b.version,
        'created_at': b.createdAt,
      },
      'accounts': await q(
        'SELECT id, name, type, archived_at, created_at, version FROM accounts WHERE book_id = ? ORDER BY created_at',
      ),
      'categories': await q(
        'SELECT id, name, kind, is_system, archived_at, sort, version FROM categories WHERE book_id = ? ORDER BY kind, sort',
      ),
      'instruments': await q(
        'SELECT id, symbol, name, asset_class, quote_currency FROM instruments WHERE book_id = ?',
      ),
      'entries': await q(
        'SELECT id, date, type, amount, account_id, to_account_id, category_id, note, instrument_id, created_at, updated_at, deleted_at, version FROM entries WHERE book_id = ? ORDER BY date, created_at',
      ),
      'trades': await q(
        'SELECT id, date, account_id, instrument_id, side, qty, price, price_ccy, fee_twd, proceeds_or_cost_twd, fx_usd_twd, realized_twd, pair_id, note, created_at, updated_at, deleted_at, version FROM trades WHERE book_id = ? ORDER BY date, created_at',
      ),
      'positions': await q(
        'SELECT id, account_id, instrument_id, qty, cost_twd, realized_twd, cost_unknown, version, updated_at FROM positions WHERE book_id = ?',
      ),
      'quotes': await q(
        'SELECT q.instrument_id, q.price, q.ccy, q.as_of, q.source, q.locked FROM quotes q JOIN instruments i ON i.id = q.instrument_id WHERE i.book_id = ?',
      ),
      'fx_rates': await q(
        'SELECT book_id, usd_twd, as_of, source FROM fx_rates WHERE book_id = ?',
      ),
    };
  }

  Map<String, dynamic> _exportRow(Map<String, Object?> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) {
      if (v is bool) {
        out[k] = v;
      } else if (v is int || v is double) {
        out[k] = v;
      } else if (v == null) {
        out[k] = null;
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  @override
  /// Replaces the contents of book [id] with [payload]. Ports `backup.go`
  /// `importBook`.
  ///
  /// Runs in one transaction. Child rows are deleted (quotes first, then
  /// trades, positions, entries, drafts, fx, instruments, categories,
  /// accounts) and inserted again with new ids. Account, category,
  /// instrument, and trade ids are remapped so foreign keys, including
  /// transfer `pair_id`, point at the new rows. `pair_id` is written in a
  /// second pass after both legs exist. An empty category list re-seeds the
  /// system categories. The target book's id is kept; name and opening date
  /// are copied from `payload['book']` when present. A failure rolls back
  /// and surfaces as 400 「還原失敗」.
  Future<Book> importBook({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final b = await _loadBook(id);
    _rejectArchived(b);
    try {
      await db.transaction(() async {
        await _importInto(id, payload);
      });
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('還原失敗：$e', status: 400);
    }
    return _toBook(await _loadBook(id));
  }

  Future<void> _importInto(String bookId, Map<String, dynamic> payload) async {
    // Child-before-parent, same order as backup.go, so foreign keys clear.
    for (final stmt in [
      'DELETE FROM quotes WHERE instrument_id IN (SELECT id FROM instruments WHERE book_id = ?)',
      'DELETE FROM trades WHERE book_id = ?',
      'DELETE FROM positions WHERE book_id = ?',
      'DELETE FROM entries WHERE book_id = ?',
      'DELETE FROM opening_position_drafts WHERE book_id = ?',
      'DELETE FROM opening_cash_drafts WHERE book_id = ?',
      'DELETE FROM fx_rates WHERE book_id = ?',
      'DELETE FROM instruments WHERE book_id = ?',
      'DELETE FROM categories WHERE book_id = ?',
      'DELETE FROM accounts WHERE book_id = ?',
    ]) {
      await db.customStatement(stmt, [bookId]);
    }

    final bookRaw = payload['book'];
    if (bookRaw is Map) {
      final name = asStr(bookRaw['name']);
      if (name.isNotEmpty) {
        await (db.update(db.books)..where((b) => b.id.equals(bookId))).write(
          BooksCompanion(name: Value(name)),
        );
      }
      final od = bookRaw['opening_date'];
      if (od is String && od.isNotEmpty) {
        await (db.update(db.books)..where((b) => b.id.equals(bookId))).write(
          BooksCompanion(openingDate: Value(asDate(od))),
        );
      }
    }

    final accMap = <String, String>{};
    final catMap = <String, String>{};
    final instMap = <String, String>{};
    final tradeMap = <String, String>{};

    final accounts = _asList(payload['accounts']);
    for (final ac in accounts) {
      final old = asStr(ac['id']);
      final nid = newId();
      if (old.isNotEmpty) accMap[old] = nid;
      var version = asInt(ac['version']);
      if (version == 0) version = 1;
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: nid,
              bookId: bookId,
              name: asStr(ac['name']),
              type: asStr(ac['type']),
              createdAt: asStr(ac['created_at']).isEmpty
                  ? _ts()
                  : asStr(ac['created_at']),
              version: Value(version),
            ),
          );
      final archived = asStrN(ac['archived_at']);
      if (archived != null) {
        await (db.update(db.accounts)..where((a) => a.id.equals(nid))).write(
          AccountsCompanion(archivedAt: Value(_ts())),
        );
      }
    }

    final cats = _asList(payload['categories']);
    if (cats.isEmpty) {
      // A backup with no categories still gets the system seeds.
      await _seedCategories(bookId);
    } else {
      for (final c in cats) {
        final old = asStr(c['id']);
        final nid = newId();
        if (old.isNotEmpty) catMap[old] = nid;
        var version = asInt(c['version']);
        if (version == 0) version = 1;
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: nid,
                bookId: bookId,
                name: asStr(c['name']),
                kind: asStr(c['kind']),
                isSystem: Value(c['is_system'] == true || c['is_system'] == 1),
                sort: Value(asInt(c['sort'])),
                version: Value(version),
              ),
            );
      }
    }

    for (final inst in _asList(payload['instruments'])) {
      final old = asStr(inst['id']);
      final nid = newId();
      if (old.isNotEmpty) instMap[old] = nid;
      await db
          .into(db.instruments)
          .insert(
            InstrumentsCompanion.insert(
              id: nid,
              bookId: bookId,
              symbol: asStr(inst['symbol']),
              name: Value(asStr(inst['name'])),
              assetClass: asStr(inst['asset_class']),
              quoteCurrency: asStr(inst['quote_currency']),
            ),
          );
    }

    String lookup(String old, Map<String, String> m) => m[old] ?? old;
    String? lookupN(Object? old, Map<String, String> m) {
      final s = asStrN(old);
      if (s == null) return null;
      return lookup(s, m);
    }

    for (final e in _asList(payload['entries'])) {
      final nid = newId();
      var version = asInt(e['version']);
      if (version == 0) version = 1;
      final ts = _ts();
      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              id: nid,
              bookId: bookId,
              date: asDate(asStr(e['date'])),
              type: asStr(e['type']),
              amount: asInt(e['amount']),
              accountId: lookup(asStr(e['account_id']), accMap),
              toAccountId: Value(lookupN(e['to_account_id'], accMap)),
              categoryId: Value(lookupN(e['category_id'], catMap)),
              note: Value(asStr(e['note'])),
              instrumentId: Value(lookupN(e['instrument_id'], instMap)),
              createdAt: ts,
              updatedAt: ts,
              version: Value(version),
            ),
          );
      if (asStrN(e['deleted_at']) != null) {
        await (db.update(db.entries)..where((x) => x.id.equals(nid))).write(
          EntriesCompanion(deletedAt: Value(_ts())),
        );
      }
    }

    final insertedPairs = <({String newId, String? pairOf})>[];
    for (final t in _asList(payload['trades'])) {
      final old = asStr(t['id']);
      final nid = newId();
      if (old.isNotEmpty) tradeMap[old] = nid;
      var version = asInt(t['version']);
      if (version == 0) version = 1;
      var fx = asStr(t['fx_usd_twd']);
      if (fx.isEmpty) fx = '1';
      final price = asStrN(t['price']);
      final ts = _ts();
      await db
          .into(db.trades)
          .insert(
            TradesCompanion.insert(
              id: nid,
              bookId: bookId,
              date: asDate(asStr(t['date'])),
              accountId: lookup(asStr(t['account_id']), accMap),
              instrumentId: lookup(asStr(t['instrument_id']), instMap),
              side: asStr(t['side']),
              qty: asStr(t['qty']),
              price: Value(price),
              priceCcy: Value(asStrN(t['price_ccy'])),
              feeTwd: Value(asInt(t['fee_twd'])),
              proceedsOrCostTwd: Value(asInt(t['proceeds_or_cost_twd'])),
              fxUsdTwd: Value(fx),
              realizedTwd: Value(
                t['realized_twd'] == null ? null : asInt(t['realized_twd']),
              ),
              note: Value(asStr(t['note'])),
              createdAt: ts,
              updatedAt: ts,
              version: Value(version),
            ),
          );
      insertedPairs.add((newId: nid, pairOf: asStrN(t['pair_id'])));
    }
    // Second pass: pair_id uses the new id of the sibling, not the old one.
    for (final it in insertedPairs) {
      if (it.pairOf == null) continue;
      final sib = tradeMap[it.pairOf!];
      if (sib == null) continue;
      await (db.update(db.trades)..where((x) => x.id.equals(it.newId))).write(
        TradesCompanion(pairId: Value(sib)),
      );
    }

    for (final p in _asList(payload['positions'])) {
      var version = asInt(p['version']);
      if (version == 0) version = 1;
      await db
          .into(db.positions)
          .insert(
            PositionsCompanion.insert(
              id: newId(),
              bookId: bookId,
              accountId: lookup(asStr(p['account_id']), accMap),
              instrumentId: lookup(asStr(p['instrument_id']), instMap),
              qty: Value(asStr(p['qty'])),
              costTwd: Value(asStr(p['cost_twd'])),
              realizedTwd: Value(asInt(p['realized_twd'])),
              costUnknown: Value(
                p['cost_unknown'] == true || p['cost_unknown'] == 1,
              ),
              version: Value(version),
              updatedAt: _ts(),
            ),
          );
    }

    for (final q in _asList(payload['quotes'])) {
      final iid = lookup(asStr(q['instrument_id']), instMap);
      final price = asStr(q['price']);
      if (iid.isEmpty || price.isEmpty) continue;
      var ccy = asStr(q['ccy']);
      if (ccy.isEmpty) ccy = 'TWD';
      var source = asStr(q['source']);
      if (source.isEmpty) source = 'manual';
      var asof = _ts();
      final rawAsOf = asStrN(q['as_of']);
      if (rawAsOf != null) asof = rawAsOf;
      await db
          .into(db.quotes)
          .insertOnConflictUpdate(
            QuotesCompanion.insert(
              instrumentId: iid,
              price: price,
              ccy: ccy,
              asOf: asof,
              source: Value(source),
              locked: Value(q['locked'] == true || q['locked'] == 1),
            ),
          );
    }

    for (final f in _asList(payload['fx_rates'])) {
      final usd = asStr(f['usd_twd']);
      if (usd.isEmpty) continue;
      var source = asStr(f['source']);
      if (source.isEmpty) source = 'manual';
      var asof = _ts();
      final rawAsOf = asStrN(f['as_of']);
      if (rawAsOf != null) asof = rawAsOf;
      await db
          .into(db.fxRates)
          .insertOnConflictUpdate(
            FxRatesCompanion.insert(
              bookId: bookId,
              usdTwd: usd,
              asOf: asof,
              source: Value(source),
            ),
          );
    }
  }

  List<Map<String, dynamic>> _asList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  @override
  /// Closes the quote HTTP client. The database is closed by its owner.
  void close() {
    quotes.close();
  }

  /// Preview one Apple Pay URL. Does not insert an entry or an import key.
  ///
  /// Rule: a stored key makes [ImportLine.duplicate] true (the sheet starts
  /// it unticked and badges 重複). A Taipei day strictly before the book's
  /// opening date sets [ImportLine.beforeOpening]; the sheet then refuses
  /// the tick and explains 不能記開帳日之前的帳. The opening day itself is
  /// allowed, same as `entries.go`. Category and account are suggestions
  /// from the mapping tables, then from the category name and the card.
  Future<ImportLine> previewApplePay({
    required String bookId,
    required Uri uri,
  }) async {
    final draft = parseApplePayUri(uri, clock: _now());
    if (draft == null) throw ApiException('不是記帳連結', status: 400);
    final book = await _loadBook(bookId);
    final existing = await (db.select(db.importKeys)..where(
          (k) => k.bookId.equals(bookId) & k.importKey.equals(draft.importKey),
        ))
        .getSingleOrNull();
    final opening = book.openingDate;
    final before =
        opening != null &&
        opening.isNotEmpty &&
        draft.date.compareTo(opening) < 0;
    return ImportLine(
      importKey: draft.importKey,
      amount: draft.amount,
      merchant: draft.merchant,
      cardLabel: draft.cardLabel,
      cardLast4: draft.cardLast4,
      note: draft.entryNote,
      occurredAt: draft.occurredAt,
      date: draft.date,
      duplicate: existing != null,
      beforeOpening: before,
      categoryId: await _suggestImportCategory(bookId, draft),
      accountId: await _suggestImportAccount(bookId, draft),
    );
  }

  /// Writes the ticked rows. Call this only after the user confirms.
  ///
  /// Rule: an empty list writes nothing. Each row is an expense. A date
  /// before the opening date throws 不能記開帳日之前的帳 and the transaction
  /// rolls every row in this confirm back. The import key is inserted if
  /// it is new. A duplicate the user explicitly ticked still inserts an
  /// entry; the existing key is left so the next preview stays 重複.
  /// Merchant→category and card_last4→account mappings are upserted from
  /// the accounts and categories the user confirmed.
  /// Holdings are not replayed here: an expense does not change them, and
  /// a replay would replace an opening lot's exact cost with the rounded
  /// proceeds column. Cash balances update because they are summed from
  /// entries on read.
  Future<int> confirmApplePay({
    required String bookId,
    required List<ImportCommit> rows,
  }) async {
    if (rows.isEmpty) return 0;
    final book = await _loadBook(bookId);
    _rejectArchived(book);
    return db.transaction(() async {
      var saved = 0;
      for (final row in rows) {
        if (!isIsoDateStr(row.date)) {
          throw ApiException('日期格式不對', status: 400);
        }
        if (book.openingDate != null &&
            book.openingDate!.isNotEmpty &&
            row.date.compareTo(book.openingDate!) < 0) {
          throw ApiException('不能記開帳日之前的帳', status: 400);
        }
        if (row.amount <= 0) throw ApiException('金額必須大於 0', status: 400);
        await _validateEntry(
          bookId: book.id,
          type: 'expense',
          acc: row.accountId,
          cat: row.categoryId,
        );
        final id = newId();
        final ts = _ts();
        await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: id,
            bookId: book.id,
            date: row.date,
            type: 'expense',
            amount: row.amount,
            accountId: row.accountId,
            categoryId: Value(row.categoryId),
            note: Value(row.note),
            createdAt: ts,
            updatedAt: ts,
          ),
        );
        final key = await (db.select(db.importKeys)..where(
              (k) =>
                  k.bookId.equals(book.id) & k.importKey.equals(row.importKey),
            ))
            .getSingleOrNull();
        if (key == null) {
          await db.into(db.importKeys).insert(
            ImportKeysCompanion.insert(
              bookId: book.id,
              importKey: row.importKey,
              entryId: Value(id),
              createdAt: ts,
            ),
          );
        }
        final merchant = row.merchant.trim();
        if (merchant.isNotEmpty) {
          await db.into(db.merchantCategoryMaps).insertOnConflictUpdate(
            MerchantCategoryMapsCompanion.insert(
              bookId: book.id,
              merchant: merchant,
              categoryId: row.categoryId,
            ),
          );
        }
        final last4 = row.cardLast4.trim();
        if (last4.isNotEmpty) {
          await db.into(db.cardAccountMaps).insertOnConflictUpdate(
            CardAccountMapsCompanion.insert(
              bookId: book.id,
              cardLast4: last4,
              accountId: row.accountId,
            ),
          );
        }
        saved += 1;
      }
      return saved;
    });
  }

  /// Mapping first, then a category whose name equals the URL `category`.
  /// Only a live expense category is suggested. Apple Pay charges are expenses.
  Future<String?> _suggestImportCategory(
    String bookId,
    ApplePayDraft draft,
  ) async {
    final merchant = draft.merchant.trim();
    if (merchant.isNotEmpty) {
      final map = await (db.select(db.merchantCategoryMaps)..where(
            (m) => m.bookId.equals(bookId) & m.merchant.equals(merchant),
          ))
          .getSingleOrNull();
      if (map != null) {
        final cat = await (db.select(
          db.categories,
        )..where((c) => c.id.equals(map.categoryId))).getSingleOrNull();
        if (cat != null &&
            cat.bookId == bookId &&
            cat.archivedAt == null &&
            cat.kind == 'expense') {
          return cat.id;
        }
      }
    }
    final name = draft.categoryName.trim();
    if (name.isEmpty) return null;
    final named = await (db.select(db.categories)..where(
          (c) =>
              c.bookId.equals(bookId) &
              c.name.equals(name) &
              c.kind.equals('expense') &
              c.archivedAt.isNull(),
        ))
        .get();
    if (named.isEmpty) return null;
    return named.first.id;
  }

  /// Mapping first, then an account whose name contains the last 4 digits
  /// or equals the card label. Archived accounts are skipped.
  Future<String?> _suggestImportAccount(
    String bookId,
    ApplePayDraft draft,
  ) async {
    final last4 = draft.cardLast4.trim();
    if (last4.isNotEmpty) {
      final map = await (db.select(db.cardAccountMaps)..where(
            (m) => m.bookId.equals(bookId) & m.cardLast4.equals(last4),
          ))
          .getSingleOrNull();
      if (map != null) {
        final account = await (db.select(
          db.accounts,
        )..where((a) => a.id.equals(map.accountId))).getSingleOrNull();
        if (account != null &&
            account.bookId == bookId &&
            account.archivedAt == null) {
          return account.id;
        }
      }
    }
    final accounts = await (db.select(db.accounts)..where(
          (a) => a.bookId.equals(bookId) & a.archivedAt.isNull(),
        ))
        .get();
    if (last4.length >= 4) {
      for (final account in accounts) {
        if (account.name.contains(last4)) return account.id;
      }
    }
    if (draft.card.isNotEmpty) {
      for (final account in accounts) {
        if (account.name == draft.card) return account.id;
      }
    }
    return null;
  }

  @override
  /// See [ApiClient.patchEntry]. Cash changes because the entry row changes.
  /// Holdings are rewritten by [_replayHoldings] in the same transaction.
  Future<Entry> patchEntry({
    required String id,
    required Map<String, dynamic> body,
  }) async {
    return db.transaction(() async {
      final row = await (db.select(db.entries)..where(
            (e) => e.id.equals(id) & e.deletedAt.isNull(),
          ))
          .getSingleOrNull();
      if (row == null) throw ApiException('找不到分錄', status: 404);
      final book = await _loadBook(row.bookId);
      _rejectArchived(book);
      if (row.type == 'opening_balance') {
        throw ApiException('開帳分錄不能改', status: 409);
      }
      if (asInt(body['version']) != row.version) {
        throw ApiException('資料已被更新，請重抓再送', status: 409);
      }
      final requestedType = asStr(body['type']);
      if (requestedType.isNotEmpty && requestedType != row.type) {
        throw ApiException('類型不能改', status: 400);
      }
      var amount = row.amount;
      if (body.containsKey('amount')) {
        amount = asInt(body['amount']);
        if (amount <= 0) throw ApiException('金額必須大於 0', status: 400);
      }
      var date = row.date;
      if (asStr(body['date']).isNotEmpty) date = asStr(body['date']);
      _rejectBeforeOpening(book, date);
      final accountId = asStr(body['account_id']).isNotEmpty
          ? asStr(body['account_id'])
          : row.accountId;
      final to = body.containsKey('to_account_id')
          ? asStrN(body['to_account_id'])
          : row.toAccountId;
      final cat = body.containsKey('category_id')
          ? asStrN(body['category_id'])
          : row.categoryId;
      final note = body.containsKey('note') ? asStr(body['note']) : row.note;
      final instrument = body.containsKey('instrument_id')
          ? asStrN(body['instrument_id'])
          : row.instrumentId;
      await _validateEntry(
        bookId: book.id,
        type: row.type,
        acc: accountId,
        to: to,
        cat: cat,
      );
      final n = await (db.update(db.entries)..where(
            (e) =>
                e.id.equals(id) &
                e.version.equals(row.version) &
                e.deletedAt.isNull(),
          ))
          .write(
            EntriesCompanion(
              amount: Value(amount),
              accountId: Value(accountId),
              toAccountId: Value(to),
              categoryId: Value(cat),
              date: Value(date),
              note: Value(note),
              instrumentId: Value(instrument),
              updatedAt: Value(_ts()),
              version: Value(row.version + 1),
            ),
          );
      if (n == 0) throw ApiException('資料已被更新，請重抓再送', status: 409);
      await _replayHoldings(book.id);
      final updated = await (db.select(
        db.entries,
      )..where((e) => e.id.equals(id))).getSingle();
      return _toEntry(updated);
    });
  }

  @override
  /// See [ApiClient.deleteEntry]. The soft-delete and the replay commit
  /// together, or neither does.
  Future<void> deleteEntry({required String id, required int version}) async {
    await db.transaction(() async {
      final row = await (db.select(db.entries)..where(
            (e) => e.id.equals(id) & e.deletedAt.isNull(),
          ))
          .getSingleOrNull();
      if (row == null) throw ApiException('找不到分錄', status: 404);
      final book = await _loadBook(row.bookId);
      _rejectArchived(book);
      if (row.type == 'opening_balance') {
        throw ApiException('開帳分錄不能刪', status: 409);
      }
      if (row.version != version) {
        throw ApiException('資料已被更新，請重抓再送', status: 409);
      }
      await _softDeleteEntry(row.id, row.version);
      await _replayHoldings(book.id);
    });
  }

  @override
  /// See [ApiClient.patchTrade]. Transfer edits write both legs, then replay.
  Future<Map<String, dynamic>> patchTrade({
    required String id,
    required Map<String, dynamic> body,
  }) async {
    return db.transaction(() async {
      final row = await _liveTrade(id);
      if (row == null) throw ApiException('找不到成交', status: 404);
      final book = await _loadBook(row.bookId);
      _rejectArchived(book);
      if (row.side == 'opening') {
        throw ApiException('開帳成交不能改', status: 409);
      }
      if (asInt(body['version']) != row.version) {
        throw ApiException('資料已被更新，請重抓再送', status: 409);
      }
      if (row.side == 'transfer_in' || row.side == 'transfer_out') {
        return _patchTransfer(row: row, book: book, body: body);
      }
      return _patchSingleTrade(row: row, book: book, body: body);
    });
  }

  @override
  /// See [ApiClient.deleteTrade]. Both transfer legs go in one transaction.
  Future<void> deleteTrade({required String id, required int version}) async {
    await db.transaction(() async {
      final row = await _liveTrade(id);
      if (row == null) throw ApiException('找不到成交', status: 404);
      final book = await _loadBook(row.bookId);
      _rejectArchived(book);
      if (row.side == 'opening') {
        throw ApiException('開帳成交不能刪', status: 409);
      }
      if (row.version != version) {
        throw ApiException('資料已被更新，請重抓再送', status: 409);
      }
      if (row.side == 'transfer_in' || row.side == 'transfer_out') {
        final pair = await _liveTrade(row.pairId ?? '');
        if (pair == null) throw ApiException('轉倉配對遺失', status: 400);
        final out = row.side == 'transfer_out' ? row : pair;
        await _syncTransferFee(
          bookId: book.id,
          oldAccountId: out.accountId,
          oldDate: out.date,
          oldFee: out.feeTwd,
          newAccountId: out.accountId,
          newDate: out.date,
          newFee: 0,
          remove: true,
        );
        await _softDeleteTrade(row.id, row.version);
        await _softDeleteTrade(pair.id, pair.version);
      } else {
        await _softDeleteTrade(row.id, row.version);
      }
      await _replayHoldings(book.id);
    });
  }

  /// Resulting date must be `YYYY-MM-DD` and not strictly before opening.
  /// The opening day itself is allowed (`entries.go`).
  void _rejectBeforeOpening(BookRow book, String date) {
    if (!isIsoDateStr(date)) throw ApiException('日期格式不對', status: 400);
    if (book.openingDate != null &&
        book.openingDate!.isNotEmpty &&
        date.compareTo(book.openingDate!) < 0) {
      throw ApiException('不能記開帳日之前的帳', status: 400);
    }
  }

  /// Rewrites `positions` from opening lots and every live trade.
  ///
  /// Purpose: edit and delete must not trust the incremental rows written
  /// by [createTrade]. Rule: [rebuildPositions] walks date order, opening
  /// lots first that day, with moving-average cost. A sell or transfer_out
  /// larger than the running quantity throws [msgNegativeHolding]. The
  /// caller is inside `db.transaction`, so the throw restores the edit.
  /// `costUnknown` is copied off the rows about to be replaced so an
  /// unrelated entry edit does not clear an unknown opening cost.
  /// Opening-lot cost uses the rounded proceeds on the trade. The unrounded
  /// draft decimal exists only inside `putOpening`.
  Future<void> _replayHoldings(String bookId) async {
    final rows = await (db.select(
      db.positions,
    )..where((p) => p.bookId.equals(bookId))).get();
    final unknown = <PosKey, bool>{
      for (final p in rows)
        if (p.costUnknown) PosKey(p.accountId, p.instrumentId): true,
    };
    await rebuildPositions(db, bookId, const <String, Decimal>{}, unknown);
  }

  Future<TradeRow?> _liveTrade(String id) {
    if (id.isEmpty) return Future<TradeRow?>.value(null);
    return (db.select(db.trades)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<void> _softDeleteEntry(String id, int version) async {
    final n = await (db.update(db.entries)..where(
          (e) =>
              e.id.equals(id) & e.version.equals(version) & e.deletedAt.isNull(),
        ))
        .write(
          EntriesCompanion(
            deletedAt: Value(_ts()),
            updatedAt: Value(_ts()),
            version: Value(version + 1),
          ),
        );
    if (n == 0) throw ApiException('資料已被更新，請重抓再送', status: 409);
  }

  Future<void> _softDeleteTrade(String id, int version) async {
    final n = await (db.update(db.trades)..where(
          (t) =>
              t.id.equals(id) & t.version.equals(version) & t.deletedAt.isNull(),
        ))
        .write(
          TradesCompanion(
            deletedAt: Value(_ts()),
            updatedAt: Value(_ts()),
            version: Value(version + 1),
          ),
        );
    if (n == 0) throw ApiException('資料已被更新，請重抓再送', status: 409);
  }

  Future<AccountRow> _requireHoldingAccount(String bookId, String accountId) async {
    final account = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (account == null) throw ApiException('帳戶不存在', status: 400);
    if (account.bookId != bookId ||
        (account.type != 'broker' && account.type != 'exchange')) {
      throw ApiException('成交帳戶必須是券商或交易所', status: 400);
    }
    return account;
  }

  Future<Decimal> _bookFx(String bookId) async {
    final fxRow = await (db.select(
      db.fxRates,
    )..where((f) => f.bookId.equals(bookId))).getSingleOrNull();
    if (fxRow != null && dec(fxRow.usdTwd) != Decimal.zero) {
      return dec(fxRow.usdTwd);
    }
    return Decimal.one;
  }

  /// Buy cost is round(qty × price × fx) + fee. Sell proceeds are that
  /// gross minus the fee, which may not exceed the gross. Airdrops are 0.
  int _tradeProceeds({
    required String side,
    required Decimal qty,
    required Decimal price,
    required Decimal fx,
    required int fee,
  }) {
    if (side == 'airdrop') return 0;
    final gross = round0(qty * price * fx);
    if (side == 'buy') return gross + fee;
    if (side == 'sell') {
      if (fee > gross) throw ApiException('手續費大於成交額', status: 400);
      return gross - fee;
    }
    throw ApiException('成交方向不對', status: 400);
  }

  bool _bodyHasInstrument(Map<String, dynamic> body) {
    return asStr(body['instrument_id']).isNotEmpty ||
        asStr(body['symbol']).isNotEmpty;
  }

  /// Resolves the instrument for an edit. An omitted symbol keeps [fallbackId].
  /// A sent symbol reuses the (book, class, symbol) row via [ensureInstrument].
  Future<String> _instrumentFromBody(
    String bookId,
    Map<String, dynamic> body, {
    required String fallbackId,
  }) async {
    var assetClass = asStr(body['asset_class']);
    var quote = asStr(body['quote_currency']);
    var name = asStr(body['name']);
    final existing = asStrN(body['instrument_id']);
    if (assetClass.isEmpty || quote.isEmpty || name.isEmpty) {
      final inst = await (db.select(
        db.instruments,
      )..where((i) => i.id.equals(fallbackId))).getSingleOrNull();
      if (inst != null) {
        if (assetClass.isEmpty) assetClass = inst.assetClass;
        if (quote.isEmpty) quote = inst.quoteCurrency;
        if (name.isEmpty) name = inst.name;
      }
    }
    return ensureInstrument(
      db,
      bookId: bookId,
      existing: existing,
      symbol: asStr(body['symbol']),
      name: name,
      assetClass: assetClass,
      quoteCcy: quote,
    );
  }

  Future<Map<String, dynamic>> _patchSingleTrade({
    required TradeRow row,
    required BookRow book,
    required Map<String, dynamic> body,
  }) async {
    final requested = asStr(body['side']);
    if (requested == 'transfer' ||
        requested == 'transfer_in' ||
        requested == 'transfer_out') {
      throw ApiException('成交方向不能改成轉倉', status: 400);
    }
    var side = row.side;
    if (requested.isNotEmpty) side = requested;
    if (side != 'buy' && side != 'sell' && side != 'airdrop') {
      throw ApiException('成交方向不對', status: 400);
    }
    var date = asStr(body['date']).isNotEmpty ? asStr(body['date']) : row.date;
    _rejectBeforeOpening(book, date);
    final accountId = asStr(body['account_id']).isNotEmpty
        ? asStr(body['account_id'])
        : row.accountId;
    await _requireHoldingAccount(book.id, accountId);
    var qty = dec(row.qty);
    if (body.containsKey('qty')) qty = decOrZero(asStr(body['qty']));
    if (!qtyPositive(qty)) throw ApiException('數量必須大於 0', status: 400);
    var fee = row.feeTwd;
    if (body.containsKey('fee_twd')) {
      fee = asInt(body['fee_twd']);
      if (fee < 0) throw ApiException('手續費不能為負', status: 400);
    }
    final note = body.containsKey('note') ? asStr(body['note']) : row.note;
    final iid = _bodyHasInstrument(body)
        ? await _instrumentFromBody(book.id, body, fallbackId: row.instrumentId)
        : row.instrumentId;

    var price = Decimal.zero;
    if (row.price != null && row.price!.isNotEmpty) price = dec(row.price!);
    var priceCcy = row.priceCcy ?? '';
    var useFx = decOrZero(row.fxUsdTwd);
    if (useFx == Decimal.zero) useFx = Decimal.one;
    var proceeds = 0;
    if (side == 'buy' || side == 'sell') {
      if (body.containsKey('price')) {
        final raw = asStr(body['price']);
        if (raw.isEmpty) throw ApiException('買賣請填單價', status: 400);
        try {
          price = dec(raw);
        } catch (_) {
          throw ApiException('單價不對', status: 400);
        }
        if (price < Decimal.zero) throw ApiException('單價不對', status: 400);
      } else if (row.price == null || row.price!.isEmpty) {
        throw ApiException('買賣請填單價', status: 400);
      }
      if (asStr(body['price_ccy']).isNotEmpty) priceCcy = asStr(body['price_ccy']);
      if (priceCcy.isEmpty) priceCcy = 'TWD';
      // Keep the fx stored on the trade unless the currency changed, so an
      // edit of the note does not reprice history at today's rate.
      if (priceCcy == 'TWD') {
        useFx = Decimal.one;
      } else if (row.priceCcy != priceCcy) {
        useFx = await _bookFx(book.id);
      }
      proceeds = _tradeProceeds(
        side: side,
        qty: qty,
        price: price,
        fx: useFx,
        fee: fee,
      );
    }

    final n = await (db.update(db.trades)..where(
          (t) =>
              t.id.equals(row.id) &
              t.version.equals(row.version) &
              t.deletedAt.isNull(),
        ))
        .write(
          TradesCompanion(
            date: Value(date),
            accountId: Value(accountId),
            instrumentId: Value(iid),
            side: Value(side),
            qty: Value(qty.toString()),
            price: Value(side == 'buy' || side == 'sell' ? price.toString() : null),
            priceCcy: Value(side == 'buy' || side == 'sell' ? priceCcy : null),
            feeTwd: Value(fee),
            proceedsOrCostTwd: Value(proceeds),
            fxUsdTwd: Value(useFx.toString()),
            realizedTwd: const Value(null),
            note: Value(note),
            updatedAt: Value(_ts()),
            version: Value(row.version + 1),
          ),
        );
    if (n == 0) throw ApiException('資料已被更新，請重抓再送', status: 409);
    await _replayHoldings(book.id);
    final updated = await (db.select(
      db.trades,
    )..where((t) => t.id.equals(row.id))).getSingle();
    return _tradeJson(updated);
  }

  /// Writes both legs of a transfer, then replays. The client's version is
  /// the leg they opened. The sibling's version is bumped too, so a stale
  /// edit of the other leg conflicts. Qty, date, instrument, and note are
  /// shared. Cost moved is recomputed by the replay, not copied.
  Future<Map<String, dynamic>> _patchTransfer({
    required TradeRow row,
    required BookRow book,
    required Map<String, dynamic> body,
  }) async {
    final pair = await _liveTrade(row.pairId ?? '');
    if (pair == null) throw ApiException('轉倉配對遺失', status: 400);
    final out = row.side == 'transfer_out' ? row : pair;
    final inn = row.side == 'transfer_in' ? row : pair;
    var date = asStr(body['date']).isNotEmpty ? asStr(body['date']) : out.date;
    _rejectBeforeOpening(book, date);
    var fromAcc = asStr(body['account_id']).isNotEmpty
        ? asStr(body['account_id'])
        : out.accountId;
    var toAcc = asStr(body['to_account_id']).isNotEmpty
        ? asStr(body['to_account_id'])
        : inn.accountId;
    if (fromAcc == toAcc) throw ApiException('不能轉給自己', status: 400);
    await _requireHoldingAccount(book.id, fromAcc);
    await _requireHoldingAccount(book.id, toAcc);
    var qty = dec(out.qty);
    if (body.containsKey('qty')) qty = decOrZero(asStr(body['qty']));
    if (!qtyPositive(qty)) throw ApiException('數量必須大於 0', status: 400);
    var fee = out.feeTwd;
    if (body.containsKey('fee_twd')) {
      fee = asInt(body['fee_twd']);
      if (fee < 0) throw ApiException('手續費不能為負', status: 400);
    }
    final note = body.containsKey('note') ? asStr(body['note']) : out.note;
    final iid = _bodyHasInstrument(body)
        ? await _instrumentFromBody(book.id, body, fallbackId: out.instrumentId)
        : out.instrumentId;
    final ts = _ts();
    Future<void> writeLeg(TradeRow leg, String accountId, int legFee) async {
      final n = await (db.update(db.trades)..where(
            (t) =>
                t.id.equals(leg.id) &
                t.version.equals(leg.version) &
                t.deletedAt.isNull(),
          ))
          .write(
            TradesCompanion(
              date: Value(date),
              accountId: Value(accountId),
              instrumentId: Value(iid),
              qty: Value(qty.toString()),
              feeTwd: Value(legFee),
              note: Value(note),
              updatedAt: Value(ts),
              version: Value(leg.version + 1),
            ),
          );
      if (n == 0) throw ApiException('資料已被更新，請重抓再送', status: 409);
    }

    await writeLeg(out, fromAcc, fee);
    await writeLeg(inn, toAcc, 0);
    await _syncTransferFee(
      bookId: book.id,
      oldAccountId: out.accountId,
      oldDate: out.date,
      oldFee: out.feeTwd,
      newAccountId: fromAcc,
      newDate: date,
      newFee: fee,
      remove: false,
    );
    await _replayHoldings(book.id);
    final updated = await (db.select(
      db.trades,
    )..where((t) => t.id.equals(row.id))).getSingle();
    return _tradeJson(updated);
  }

  /// Aligns the 搬倉手續費 expense that [_applyTransfer] created.
  ///
  /// The match is exact: same book, note, source account, date, and amount,
  /// still live. A user edit of that expense breaks the match and the row
  /// is left alone. [remove] soft-deletes the match (transfer delete, or a
  /// fee edited down to 0). A new positive fee with no match inserts one
  /// when the system category 投資費用 exists. This runs before the replay
  /// and inside the same transaction, so a negative holding rolls the fee
  /// change back with the trade.
  Future<void> _syncTransferFee({
    required String bookId,
    required String oldAccountId,
    required String oldDate,
    required int oldFee,
    required String newAccountId,
    required String newDate,
    required int newFee,
    required bool remove,
  }) async {
    EntryRow? match;
    if (oldFee > 0) {
      final found = await (db.select(db.entries)..where(
            (e) =>
                e.bookId.equals(bookId) &
                e.deletedAt.isNull() &
                e.type.equals('expense') &
                e.note.equals('搬倉手續費') &
                e.accountId.equals(oldAccountId) &
                e.date.equals(oldDate) &
                e.amount.equals(oldFee),
          ))
          .get();
      if (found.isNotEmpty) match = found.first;
    }
    if (match != null && (remove || newFee <= 0)) {
      await _softDeleteEntry(match.id, match.version);
      return;
    }
    if (match != null) {
      await (db.update(db.entries)..where((e) => e.id.equals(match!.id))).write(
        EntriesCompanion(
          amount: Value(newFee),
          accountId: Value(newAccountId),
          date: Value(newDate),
          updatedAt: Value(_ts()),
          version: Value(match.version + 1),
        ),
      );
      return;
    }
    if (remove || newFee <= 0) return;
    final cat = await (db.select(db.categories)..where(
          (c) =>
              c.bookId.equals(bookId) &
              c.name.equals('投資費用') &
              c.kind.equals('expense'),
        ))
        .getSingleOrNull();
    if (cat == null) return;
    final ts = _ts();
    await db.into(db.entries).insert(
      EntriesCompanion.insert(
        id: newId(),
        bookId: bookId,
        date: newDate,
        type: 'expense',
        amount: newFee,
        accountId: newAccountId,
        categoryId: Value(cat.id),
        note: const Value('搬倉手續費'),
        createdAt: ts,
        updatedAt: ts,
      ),
    );
  }
}


