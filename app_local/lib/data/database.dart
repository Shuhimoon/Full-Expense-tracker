import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

// SQLite schema for the on-device ledger.
//
// Tables match the Go migrations in api/migrations (books, accounts,
// categories, instruments, entries, trades, positions, quotes, fx_rates,
// opening drafts). There is no users or sessions table: this device is the
// only owner. `app_prefs` holds last_book_id (Go: users.last_book_id).
// `idempotency_keys` ports the table behind api/internal/app/app.go
// idempotency. Partial unique indexes match the active-name rules in
// books.go and accounts.go. Do not edit database.g.dart by hand.

part 'database.g.dart';

/// One ledger. [openingDate] defaults at insert time to the creation day in
/// Asia/Taipei (`books.go` `handleBooksCreate`). [timezone] stays
/// `Asia/Taipei` and [costMethod] stays `avg` (moving-average cost).
@DataClassName('BookRow')
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get archivedAt => text().nullable()();
  TextColumn get baseCurrency => text().withDefault(const Constant('TWD'))();
  TextColumn get openingDate => text().nullable()();
  TextColumn get timezone => text().withDefault(const Constant('Asia/Taipei'))();
  TextColumn get costMethod => text().withDefault(const Constant('avg'))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Cash, bank, card, broker, or exchange account inside one book.
///
/// Active names are unique per book (partial index below). `accounts.go`
/// refuses to delete an account that still has entries or trades.
@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get archivedAt => text().nullable()();
  TextColumn get createdAt => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Income or expense category. System rows are the seeds from `app.go`
/// `seedCategories` and cannot be deleted (`categories.go`).
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get archivedAt => text().nullable()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A symbol inside one book. Unique on (book, asset class, symbol), which
/// `opening.go` / `trades.go` `ensureInstrument` uses to reuse a row.
@DataClassName('InstrumentRow')
class Instruments extends Table {
  TextColumn get id => text()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get symbol => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get assetClass => text()();
  TextColumn get quoteCurrency => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {bookId, assetClass, symbol},
  ];
}

/// Cash movement: income, expense, transfer, or system `opening_balance`.
///
/// Users cannot write `opening_balance` (`entries.go` `handleEntriesCreate`).
/// A date before the book's opening date is rejected.
@DataClassName('EntryRow')
class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get date => text()();
  TextColumn get type => text()();
  IntColumn get amount => integer()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get instrumentId =>
      text().nullable().references(Instruments, #id)();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Stored holding after a trade or an opening replay.
///
/// [qty] and [costTwd] are decimal text. Cost is moving-average TWD, rewritten
/// by `opening.go` `rebuildPositions`. One row per (account, instrument).
@DataClassName('PositionRow')
class Positions extends Table {
  TextColumn get id => text()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get instrumentId => text().references(Instruments, #id)();
  TextColumn get qty => text().withDefault(const Constant('0'))();
  TextColumn get costTwd => text().withDefault(const Constant('0'))();
  IntColumn get realizedTwd => integer().withDefault(const Constant(0))();
  BoolColumn get costUnknown => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {accountId, instrumentId},
  ];
}

/// Buy, sell, airdrop, transfer leg, or system `opening` lot.
///
/// [pairId] links transfer_out to transfer_in. Backup import remaps it after
/// both legs have new ids (`backup.go` `importBook`).
@DataClassName('TradeRow')
class Trades extends Table {
  TextColumn get id => text()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get date => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get instrumentId => text().references(Instruments, #id)();
  TextColumn get side => text()();
  TextColumn get qty => text()();
  TextColumn get price => text().nullable()();
  TextColumn get priceCcy => text().nullable()();
  IntColumn get feeTwd => integer().withDefault(const Constant(0))();
  IntColumn get proceedsOrCostTwd => integer().withDefault(const Constant(0))();
  TextColumn get fxUsdTwd => text().withDefault(const Constant('1'))();
  IntColumn get realizedTwd => integer().nullable()();
  TextColumn get pairId => text().nullable().references(Trades, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Last price for an instrument. [source] is `auto` or `manual`. A locked
/// manual quote is never overwritten (`quotes.go` `handleQuotesRefresh`).
@DataClassName('QuoteRow')
class Quotes extends Table {
  TextColumn get instrumentId =>
      text().references(Instruments, #id, onDelete: KeyAction.cascade)();
  TextColumn get price => text()();
  TextColumn get ccy => text()();
  TextColumn get asOf => text()();
  TextColumn get source => text().withDefault(const Constant('auto'))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {instrumentId};
}

/// USD/TWD for one book. Missing rate falls back to 32 in mark-to-market
/// (`stats.go` `positionMark`, `quotes.go` refresh).
@DataClassName('FxRateRow')
class FxRates extends Table {
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get usdTwd => text()();
  TextColumn get asOf => text()();
  TextColumn get source => text().withDefault(const Constant('auto'))();

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

/// Unapplied opening cash until `applyOpening` writes `opening_balance` rows.
@DataClassName('OpeningCashDraftRow')
class OpeningCashDrafts extends Table {
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get amount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {bookId, accountId};
}

/// Unapplied opening lots. `applyOpening` turns them into `opening` trades
/// and then replays the whole timeline.
@DataClassName('OpeningPositionDraftRow')
class OpeningPositionDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get instrumentId => text().nullable().references(Instruments, #id)();
  TextColumn get symbol => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get assetClass => text()();
  TextColumn get quoteCurrency => text()();
  TextColumn get qty => text()();
  TextColumn get costTwd => text().withDefault(const Constant('0'))();
  BoolColumn get costUnknown => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Device prefs. `last_book_id` is the local stand-in for `users.last_book_id`.
@DataClassName('AppPrefRow')
class AppPrefs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Confirmed Apple Pay import identities, one per book.
///
/// Purpose: a Shortcuts replay of the same Wallet transaction must not be
/// booked twice by accident. The key is the URL `id` when that param is
/// non-empty, otherwise the sha256 of the raw amount, merchant, time, and
/// card_last4. A row is inserted only when the user confirms the preview,
/// never when the link opens. The next preview of the same key is marked
/// 重複 and starts unticked. [entryId] is plain text, not a foreign key,
/// so a later soft-delete of the entry keeps the key (the charge stays
/// "already imported" until the user explicitly ticks it again).
@DataClassName('ImportKeyRow')
class ImportKeys extends Table {
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get importKey => text()();
  TextColumn get entryId => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {bookId, importKey};
}

/// Last category the user confirmed for a merchant name, per book.
///
/// Purpose: the next Apple Pay preview for the same merchant prefills the
/// category. Updated only on confirm. Cascade drops the row if the category
/// or the book is deleted, so a stale id is never prefilled.
@DataClassName('MerchantCategoryMapRow')
class MerchantCategoryMaps extends Table {
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get merchant => text()();
  TextColumn get categoryId =>
      text().references(Categories, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {bookId, merchant};
}

/// Last account the user confirmed for a card's last 4 digits, per book.
///
/// Purpose: the next preview with the same card_last4 prefills the account.
/// Updated only on confirm. The key is the normalized 4 digits, not the
/// raw query string (that raw string is what the import-key hash uses).
@DataClassName('CardAccountMapRow')
class CardAccountMaps extends Table {
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get cardLast4 => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {bookId, cardLast4};
}

/// Stored POST bodies for `Idempotency-Key`, port of `app.go` `idempotency`.
/// A repeat key returns [responseBody] and does not insert again.
@DataClassName('IdempotencyKeyRow')
class IdempotencyKeys extends Table {
  TextColumn get key => text()();
  TextColumn get method => text()();
  TextColumn get path => text()();
  IntColumn get responseStatus => integer()();
  TextColumn get responseBody => text()();
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Books,
    Accounts,
    Categories,
    Instruments,
    Entries,
    Positions,
    Trades,
    Quotes,
    FxRates,
    OpeningCashDrafts,
    OpeningPositionDrafts,
    AppPrefs,
    IdempotencyKeys,
    ImportKeys,
    MerchantCategoryMaps,
    CardAccountMaps,
  ],
)
/// Drift database. [memory] is for tests; [defaults] opens the app file.
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults() : super(_open());

  AppDatabase.memory() : super(NativeDatabase.memory());

  /// v2 adds Apple Pay import keys and merchant/card mappings.
  /// v1 files upgrade in place; existing entries and trades are not rewritten.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createLedgerIndexes();
    },
    onUpgrade: (m, from, to) async {
      // Purpose: install the import tables on a database created at v1.
      // Rule: do not touch books, entries, trades, or positions. Dedup and
      // mappings start empty, so the first confirm of a repeated shortcut
      // is what marks later previews 重複.
      if (from < 2) {
        await m.createTable(importKeys);
        await m.createTable(merchantCategoryMaps);
        await m.createTable(cardAccountMaps);
      }
    },
  );

  /// Active-name uniqueness and date indexes. Same rules as v1.
  ///
  /// Archived books and accounts may reuse a name (books.go / accounts.go
  /// unique violations → 409). Deleted entries and trades stay in the table
  /// but drop out of the date index.
  Future<void> _createLedgerIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX books_name_active ON books (name) WHERE archived_at IS NULL',
    );
    await customStatement(
      'CREATE UNIQUE INDEX accounts_book_name_active ON accounts (book_id, name) WHERE archived_at IS NULL',
    );
    await customStatement(
      'CREATE INDEX entries_book_date ON entries (book_id, date) WHERE deleted_at IS NULL',
    );
    await customStatement(
      'CREATE INDEX trades_book_date ON trades (book_id, date) WHERE deleted_at IS NULL',
    );
  }
}

QueryExecutor _open() {
  return driftDatabase(name: 'full_jizhang');
}
