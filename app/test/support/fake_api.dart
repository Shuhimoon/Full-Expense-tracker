import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';

AppUser sampleUser({
  String id = 'u1',
  String email = 'shuhi@example.com',
  String? lastBookId,
}) {
  return AppUser(
    id: id,
    email: email,
    lastBookId: lastBookId,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

Book sampleBook({
  String id = 'b1',
  String name = '生活',
  String? openingDate = '2020-01-01',
  bool archived = false,
  int version = 1,
}) {
  return Book(
    id: id,
    name: name,
    archivedAt: archived ? '2026-01-02T00:00:00Z' : null,
    baseCurrency: 'TWD',
    openingDate: openingDate,
    timezone: 'Asia/Taipei',
    costMethod: 'avg',
    version: version,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

Account sampleAccount({
  String id = 'a1',
  String bookId = 'b1',
  String name = '現金',
  String type = 'cash',
  int cashBalance = 8000,
  int? positionMv,
  bool archived = false,
  int version = 1,
}) {
  return Account(
    id: id,
    bookId: bookId,
    name: name,
    type: type,
    archivedAt: archived ? '2026-01-02T00:00:00Z' : null,
    version: version,
    cashBalance: cashBalance,
    positionMv: positionMv,
  );
}

Category sampleCategory({
  String id = 'c1',
  String bookId = 'b1',
  String name = '餐飲',
  String kind = 'expense',
  bool isSystem = true,
  int version = 1,
}) {
  return Category(
    id: id,
    bookId: bookId,
    name: name,
    kind: kind,
    isSystem: isSystem,
    archivedAt: null,
    sort: 0,
    version: version,
  );
}

Entry sampleEntry({
  String id = 'e1',
  String bookId = 'b1',
  required String date,
  String type = 'expense',
  int amount = 85,
  String accountId = 'a1',
  String? toAccountId,
  String? categoryId = 'c1',
  String note = '午餐',
  String createdAt = '2026-10-20T01:00:00Z',
}) {
  return Entry(
    id: id,
    bookId: bookId,
    date: date,
    type: type,
    amount: amount,
    accountId: accountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    note: note,
    createdAt: createdAt,
    version: 1,
  );
}

Position samplePosition({
  String id = 'p1',
  String accountId = 'a1',
  String accountName = '券商',
  String symbol = '2330',
  String name = '台積電',
  String assetClass = 'tw_stock',
  String qty = '100',
  int? marketValue = 900000,
  int? unrealized = 12000,
  String? unrealizedPct = '1.2',
  bool closed = false,
}) {
  return Position(
    id: id,
    accountId: accountId,
    accountName: accountName,
    symbol: symbol,
    name: name,
    assetClass: assetClass,
    qty: qty,
    costTwd: '800000',
    realizedTwd: 0,
    costUnknown: false,
    marketValue: marketValue,
    unrealized: unrealized,
    unrealizedPct: unrealizedPct,
    quoteAsOf: '2026-10-20T01:05:00Z',
    closed: closed,
  );
}

/// In-memory [ApiClient] for widget tests. Auth methods match the M2 fake.
class FakeApi implements ApiClient {
  AppUser? current;
  String? loginError;
  String? registerError;
  String? logoutError;
  int logins = 0;
  int registers = 0;
  int logouts = 0;

  List<Book> books = [];
  List<Account> accounts = [];
  List<Category> categories = [];
  List<Entry> entries = [];
  List<Position> positions = [];
  List<DailyPoint> daily = [];
  List<CategoryAmount> slices = [];
  StatsSummary? summary;
  QuoteRefresh quoteRefresh = const QuoteRefresh(
    updated: 1,
    failed: [],
    message: '',
    quoteFailed: false,
  );

  int quoteRefreshes = 0;
  int createEntryCalls = 0;
  int createTradeCalls = 0;
  int passwordCalls = 0;
  int imports = 0;
  String? createEntryError;
  int? createEntryStatus;
  Map<String, dynamic>? lastEntryBody;
  String? lastIdempotencyKey;
  Map<String, dynamic>? lastTradeBody;
  String? lastTradeKey;
  Map<String, dynamic> exportPayload = const {'ok': true};
  int _seq = 1;

  String _id(String prefix) => '$prefix${_seq++}';

  @override
  Future<AppUser> me() async {
    final user = current;
    if (user == null) throw ApiException('請先登入', status: 401);
    return user;
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    logins++;
    final error = loginError;
    if (error != null) throw ApiException(error, status: 401);
    current = sampleUser(email: email);
    return current!;
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
  }) async {
    registers++;
    final error = registerError;
    if (error != null) throw ApiException(error, status: 400);
    current = sampleUser(id: 'u2', email: email);
    return current!;
  }

  @override
  Future<void> logout() async {
    logouts++;
    final error = logoutError;
    if (error != null) throw ApiException(error, status: 500);
    current = null;
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    passwordCalls++;
    if (newPassword.length < 8) {
      throw ApiException('密碼至少 8 碼', status: 400);
    }
  }

  @override
  Future<List<Book>> listBooks() async => List<Book>.of(books);

  @override
  Future<Book> createBook({required String name}) async {
    final book = sampleBook(
      id: _id('b'),
      name: name,
      openingDate: taipeiToday(),
      version: 1,
    );
    books = [...books, book];
    return book;
  }

  @override
  Future<Book> patchBook({
    required String id,
    required String name,
    required int version,
  }) async {
    return _replaceBook(id, (book) {
      return _copyBook(book, name: name, version: version + 1);
    });
  }

  @override
  Future<Book> archiveBook(String id) async {
    return _replaceBook(id, (book) {
      return _copyBook(book, archivedAt: '2026-02-01T00:00:00Z');
    });
  }

  @override
  Future<Book> unarchiveBook(String id) async {
    return _replaceBook(id, (book) => _copyBook(book, clearArchived: true));
  }

  @override
  Future<void> deleteBook(String id) async {
    books = books.where((book) => book.id != id).toList();
  }

  @override
  Future<Book> selectBook(String id) async {
    final book = books.firstWhere((item) => item.id == id);
    final user = current;
    if (user != null) {
      current = AppUser(
        id: user.id,
        email: user.email,
        lastBookId: id,
        createdAt: user.createdAt,
      );
    }
    return book;
  }

  @override
  Future<Map<String, dynamic>> exportBook(String id) async {
    return Map<String, dynamic>.from(exportPayload);
  }

  @override
  Future<Book> importBook({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    imports++;
    return books.firstWhere((book) => book.id == id);
  }

  @override
  Future<List<Account>> listAccounts(String bookId) async {
    return accounts.where((account) => account.bookId == bookId).toList();
  }

  @override
  Future<Account> createAccount({
    required String bookId,
    required String name,
    required String type,
  }) async {
    final account = sampleAccount(
      id: _id('a'),
      bookId: bookId,
      name: name,
      type: type,
      cashBalance: 0,
    );
    accounts = [...accounts, account];
    return account;
  }

  @override
  Future<Account> patchAccount({
    required String id,
    required String name,
    required int version,
  }) async {
    final next = <Account>[];
    Account? updated;
    for (final account in accounts) {
      if (account.id == id) {
        updated = Account(
          id: account.id,
          bookId: account.bookId,
          name: name,
          type: account.type,
          archivedAt: account.archivedAt,
          version: version + 1,
          cashBalance: account.cashBalance,
          positionMv: account.positionMv,
        );
        next.add(updated);
      } else {
        next.add(account);
      }
    }
    accounts = next;
    return updated!;
  }

  @override
  Future<void> archiveAccount(String id) async {}

  @override
  Future<void> deleteAccount(String id) async {
    accounts = accounts.where((account) => account.id != id).toList();
  }

  @override
  Future<List<Category>> listCategories(String bookId) async {
    return categories.where((category) => category.bookId == bookId).toList();
  }

  @override
  Future<Category> createCategory({
    required String bookId,
    required String name,
    required String kind,
  }) async {
    final category = sampleCategory(
      id: _id('c'),
      bookId: bookId,
      name: name,
      kind: kind,
      isSystem: false,
    );
    categories = [...categories, category];
    return category;
  }

  @override
  Future<Category> patchCategory({
    required String id,
    required String name,
    required int version,
  }) async {
    final next = <Category>[];
    Category? updated;
    for (final category in categories) {
      if (category.id == id) {
        updated = Category(
          id: category.id,
          bookId: category.bookId,
          name: name,
          kind: category.kind,
          isSystem: category.isSystem,
          archivedAt: category.archivedAt,
          sort: category.sort,
          version: version + 1,
        );
        next.add(updated);
      } else {
        next.add(category);
      }
    }
    categories = next;
    return updated!;
  }

  @override
  Future<void> archiveCategory(String id) async {
    final next = <Category>[];
    for (final category in categories) {
      if (category.id != id) {
        next.add(category);
        continue;
      }
      next.add(
        Category(
          id: category.id,
          bookId: category.bookId,
          name: category.name,
          kind: category.kind,
          isSystem: category.isSystem,
          archivedAt: '2026-02-01T00:00:00Z',
          sort: category.sort,
          version: category.version,
        ),
      );
    }
    categories = next;
  }

  @override
  Future<void> deleteCategory(String id) async {
    final category = categories.firstWhere((item) => item.id == id);
    if (category.isSystem) {
      throw ApiException('系統分類不能刪，請改封存', status: 400);
    }
    categories = categories.where((item) => item.id != id).toList();
  }

  @override
  Future<List<Entry>> listEntries({
    required String bookId,
    String? date,
    String? from,
    String? to,
    String? accountId,
    String? categoryId,
  }) async {
    return entries.where((entry) {
      if (entry.bookId != bookId) return false;
      if (date != null && entry.date != date) return false;
      if (from != null && entry.date.compareTo(from) < 0) return false;
      if (to != null && entry.date.compareTo(to) > 0) return false;
      if (accountId != null && entry.accountId != accountId) return false;
      if (categoryId != null && entry.categoryId != categoryId) return false;
      return true;
    }).toList();
  }

  @override
  Future<Entry> createEntry({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    createEntryCalls++;
    lastEntryBody = Map<String, dynamic>.from(body);
    lastIdempotencyKey = idempotencyKey;
    final error = createEntryError;
    if (error != null) {
      throw ApiException(error, status: createEntryStatus ?? 400);
    }
    final entry = Entry(
      id: _id('e'),
      bookId: '${body['book_id']}',
      date: '${body['date']}',
      type: '${body['type']}',
      amount: body['amount'] as int,
      accountId: '${body['account_id']}',
      toAccountId: body['to_account_id']?.toString(),
      categoryId: body['category_id']?.toString(),
      note: '${body['note'] ?? ''}',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      version: 1,
    );
    entries = [...entries, entry];
    return entry;
  }

  @override
  Future<List<DailyPoint>> statsDaily({
    required String bookId,
    required String from,
    required String to,
  }) async {
    return daily
        .where(
          (point) =>
              point.date.compareTo(from) >= 0 && point.date.compareTo(to) <= 0,
        )
        .toList();
  }

  @override
  Future<StatsSummary> statsSummary({
    required String bookId,
    String? month,
  }) async {
    return summary ?? StatsSummary.zero(today: taipeiToday());
  }

  @override
  Future<List<CategoryAmount>> statsByCategory({
    required String bookId,
    String? month,
  }) async {
    return List<CategoryAmount>.of(slices);
  }

  @override
  Future<List<Position>> listPositions(String bookId) async {
    return List<Position>.of(positions);
  }

  @override
  Future<QuoteRefresh> refreshQuotes(String bookId) async {
    quoteRefreshes++;
    return quoteRefresh;
  }

  @override
  Future<Map<String, dynamic>> createTrade({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    createTradeCalls++;
    lastTradeBody = Map<String, dynamic>.from(body);
    lastTradeKey = idempotencyKey;
    return {'id': _id('t')};
  }

  @override
  void close() {}

  Book _replaceBook(String id, Book Function(Book book) update) {
    final next = <Book>[];
    Book? updated;
    for (final book in books) {
      if (book.id == id) {
        updated = update(book);
        next.add(updated);
      } else {
        next.add(book);
      }
    }
    books = next;
    return updated!;
  }

  Book _copyBook(
    Book book, {
    String? name,
    String? archivedAt,
    bool clearArchived = false,
    int? version,
  }) {
    return Book(
      id: book.id,
      name: name ?? book.name,
      archivedAt: clearArchived ? null : (archivedAt ?? book.archivedAt),
      baseCurrency: book.baseCurrency,
      openingDate: book.openingDate,
      timezone: book.timezone,
      costMethod: book.costMethod,
      version: version ?? book.version,
      createdAt: book.createdAt,
    );
  }
}
