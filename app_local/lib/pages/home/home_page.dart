import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/session/book_create_nav.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/pages/record/record_sheet.dart';
import 'package:full_jizhang/widgets/soft_card.dart';
import 'package:go_router/go_router.dart';

/// Ledger home. Rows mix cash entries and trades.
///
/// Tap a row to edit it in the record sheet. Delete asks first, then calls
/// the API, which replays opening lots and every live trade in time order.
/// A replay that would make a holding negative shows 「修改後持倉會變負數」 and
/// leaves the row in place. Opening-balance rows and opening lots are not
/// tappable here. `transfer_in` is hidden; the `transfer_out` row edits both
/// legs. Cash is not stored — it is summed again on the next load.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _name = TextEditingController(text: '生活');
  String? _bookId;
  int _generation = -1;
  bool _loading = false;
  bool _creating = false;
  String? _error;
  String? _quoteWarning;
  StatsSummary? _summary;
  List<Entry> _entries = [];
  List<Map<String, dynamic>> _trades = [];
  Map<String, Account> _accounts = {};
  Map<String, Category> _categories = {};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final books = BookScope.of(context);
    if (!books.ready) return;
    final id = books.current?.id;
    if (_bookId == id && _generation == books.generation) return;
    _bookId = id;
    _generation = books.generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load({bool refreshQuotes = false}) async {
    final books = BookScope.of(context);
    final book = books.current;
    if (book == null) {
      setState(() {
        _loading = false;
        _summary = null;
        _entries = [];
        _trades = [];
        _error = books.error;
      });
      return;
    }
    setState(() {
      _loading = _summary == null;
      _error = null;
    });
    try {
      if (refreshQuotes) {
        final refresh = await books.api.refreshQuotes(book.id);
        if (refresh.quoteFailed && refresh.message.isNotEmpty) {
          _quoteWarning = refresh.message;
        } else {
          _quoteWarning = null;
        }
      }
      // Trades join the ledger. Both transfer legs come back so a row can
      // name the other account. The list below hides transfer_in and opening.
      final results = await Future.wait<Object>([
        books.api.statsSummary(bookId: book.id),
        books.api.listEntries(bookId: book.id),
        books.api.listAccounts(book.id),
        books.api.listCategories(book.id),
        books.api.listTrades(book.id),
      ]);
      if (!mounted || BookScope.of(context).current?.id != book.id) return;
      final accounts = <String, Account>{};
      for (final account in results[2] as List<Account>) {
        accounts[account.id] = account;
      }
      final categories = <String, Category>{};
      for (final category in results[3] as List<Category>) {
        categories[category.id] = category;
      }
      setState(() {
        _summary = results[0] as StatsSummary;
        _entries = results[1] as List<Entry>;
        _trades = results[4] as List<Map<String, dynamic>>;
        _accounts = accounts;
        _categories = categories;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '請求失敗';
        _loading = false;
      });
    }
  }

  Future<void> _createBook() async {
    if (_creating) return;
    final books = BookScope.of(context);
    // Purpose: the empty-state 建立帳本 finishes on 帳本, with this book
    // current. Rule: origin is [BookCreateOrigin.firstRun], so the
    // helper returns `/` and never 設定 or 開帳. Key logic: [hadBooks]
    // is the row count before create(); an empty DB is false. The
    // route is applied after create(), not on a timer. create() still
    // selects the new book (existing behaviour).
    final hadBooks = books.books.isNotEmpty;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await books.create(_name.text);
      if (!mounted) return;
      goBookCreateRoute(
        context,
        routeAfterBookCreate(
          origin: BookCreateOrigin.firstRun,
          hadBooks: hadBooks,
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '請求失敗');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _switchBook() async {
    final books = BookScope.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final active = books.activeBooks;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              for (final book in active)
                ListTile(
                  key: Key('switch-${book.id}'),
                  title: Text(book.name),
                  trailing: book.id == books.current?.id
                      ? const Icon(Icons.check_rounded, color: AppColors.sageDark)
                      : null,
                  onTap: () => Navigator.pop(context, book.id),
                ),
              ListTile(
                key: const Key('switch-manage'),
                title: const Text('管理帳本'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, 'manage'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    if (selected == 'manage') {
      // Purpose: 管理帳本 from the 帳本 switcher is not a 設定 create.
      // Rule: `from=home` keeps 新增 on this page when a book already
      // exists, and sends a first book to `/`. Key logic: the query is
      // the origin; we do not go('/opening') after the push.
      context.push('/settings/books?from=home');
      return;
    }
    if (selected == books.current?.id) return;
    try {
      await books.select(selected);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = BookScope.of(context);
    if (!books.ready) {
      return const ColoredBox(
        key: Key('page-home'),
        color: AppColors.sheet,
        child: Center(child: CircularProgressIndicator(color: AppColors.sage)),
      );
    }
    if (books.current == null) {
      return KeyedSubtree(
        key: const Key('page-home'),
        child: _EmptyBooks(
          controller: _name,
          busy: _creating,
          error: _error ?? books.error,
          archived: books.books.any((book) => book.archived),
          onCreate: _createBook,
        ),
      );
    }
    final summary = _summary;
    final today = summary?.today.isNotEmpty == true
        ? summary!.today
        : taipeiToday();
    return PageScroll(
      key: const Key('page-home'),
      onRefresh: () => _load(refreshQuotes: true),
      children: [
        _TopBar(
          name: books.current!.name,
          quote: formatQuoteClock(summary?.quoteAsOf),
          onSwitch: _switchBook,
        ),
        if (_quoteWarning != null) ...[
          const SizedBox(height: 6),
          Text(
            _quoteWarning!,
            key: const Key('quote-warning'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.expense,
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_loading && summary == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sage),
            ),
          )
        else ...[
          if (_offerOpening) ...[
            _OpeningOffer(onTap: () => context.push('/opening')),
            const SizedBox(height: 8),
          ],
          _SpendCard(summary: summary),
          const SizedBox(height: 8),
          _NetCard(summary: summary),
          const SizedBox(height: 8),
          ..._ledger(today),
        ],
        ErrorLine(_error, lineKey: const Key('home-error')),
      ],
    );
  }

  bool get _offerOpening {
    final book = BookScope.of(context).current;
    if (book == null || book.archived) return false;
    return !_entries.any((entry) => entry.type == 'opening_balance');
  }

  List<Widget> _ledger(String today) {
    final rows = _rows();
    // Empty only when neither entries nor visible trades exist.
    if (rows.isEmpty) {
      return [
        const SoftCard(
          child: Text(
            '還沒有流水。點右下角記一筆。',
            key: Key('home-empty'),
          ),
        ),
      ];
    }
    final groups = <String, List<_LedgerRow>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.date, () => []).add(row);
    }
    return [
      for (final group in groups.entries) ...[
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDayHeading(group.key, today),
                key: Key('day-${group.key}'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              for (var i = 0; i < group.value.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: Color(0x1A3C3C43)),
                _rowWidget(group.value[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  /// Entries plus buy, sell, airdrop, and transfer_out. Opening lots and
  /// the transfer_in twin stay off the list. Newest day, then newest
  /// created time, matches the previous entry-only order.
  List<_LedgerRow> _rows() {
    final tradesById = <String, Map<String, dynamic>>{
      for (final trade in _trades) '${trade['id']}': trade,
    };
    final rows = <_LedgerRow>[
      for (final entry in _entries) _LedgerRow.entry(entry),
    ];
    for (final trade in _trades) {
      final side = '${trade['side']}';
      if (side == 'opening' || side == 'transfer_in') continue;
      rows.add(_LedgerRow.trade(trade, tradesById));
    }
    rows.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
    return rows;
  }

  Widget _rowWidget(_LedgerRow row) {
    final entry = row.entry;
    if (entry != null) {
      final opening = entry.type == 'opening_balance';
      return _EntryRow(
        entry: entry,
        account: _accounts[entry.accountId],
        toAccount: entry.toAccountId == null ? null : _accounts[entry.toAccountId],
        category: entry.categoryId == null ? null : _categories[entry.categoryId],
        // Opening cash is owned by the opening page. Tap and delete stay off.
        onTap: opening ? null : () => _editEntry(entry),
        onDelete: opening ? null : () => _deleteEntry(entry),
      );
    }
    final trade = row.trade!;
    return _TradeRow(
      trade: trade,
      account: _accounts['${trade['account_id']}'],
      toAccount: row.toAccountId == null ? null : _accounts[row.toAccountId],
      onTap: () => _editTrade(row),
      onDelete: () => _deleteTrade(trade),
    );
  }

  /// Opens the row in 記一筆. push so 存檔 / close pop back to 帳本.
  void _editEntry(Entry entry) {
    context.push(
      '/record',
      extra: RecordEdit.entry(
        id: entry.id,
        version: entry.version,
        type: entry.type,
        date: entry.date,
        accountId: entry.accountId,
        amount: entry.amount,
        toAccountId: entry.toAccountId,
        categoryId: entry.categoryId,
        note: entry.note,
      ),
    );
  }

  /// Same push as [_editEntry]: 存檔 returns to 帳本 and touch() reloads.
  void _editTrade(_LedgerRow row) {
    final trade = row.trade!;
    final price = trade['price'];
    context.push(
      '/record',
      extra: RecordEdit.trade(
        id: '${trade['id']}',
        version: jsonInt(trade['version']),
        side: '${trade['side']}',
        date: '${trade['date']}',
        accountId: '${trade['account_id']}',
        toAccountId: row.toAccountId,
        note: '${trade['note'] ?? ''}',
        symbol: trade['symbol']?.toString(),
        assetClass: trade['asset_class']?.toString(),
        quoteCurrency: trade['quote_currency']?.toString(),
        qty: trade['qty']?.toString(),
        price: price == null ? null : '$price',
        priceCcy: trade['price_ccy']?.toString(),
        feeTwd: jsonInt(trade['fee_twd']),
      ),
    );
  }

  Future<void> _deleteEntry(Entry entry) {
    return _confirmDelete(() {
      return BookScope.of(context).api.deleteEntry(
        id: entry.id,
        version: entry.version,
      );
    });
  }

  Future<void> _deleteTrade(Map<String, dynamic> trade) {
    return _confirmDelete(() {
      return BookScope.of(context).api.deleteTrade(
        id: '${trade['id']}',
        version: jsonInt(trade['version']),
      );
    });
  }

  /// Asks, then deletes. The API replays inside a transaction. 「修改後持倉會變負數」
  /// is shown on the home error line and the row stays.
  Future<void> _confirmDelete(Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('刪除這筆？'),
          content: const Text('刪除後會依時間重算餘額與持倉。'),
          actions: [
            TextButton(
              key: const Key('delete-cancel'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              key: const Key('delete-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _error = null);
    try {
      await action();
      if (!mounted) return;
      // Stay on 帳本. touch() reloads the list from SQLite so the
      // deleted row is gone and totals match the remaining entries.
      BookScope.of(context).touch();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '請求失敗');
    }
  }
}

/// One ledger line, either a cash entry or a visible trade.
class _LedgerRow {
  _LedgerRow.entry(Entry value)
    : entry = value,
      trade = null,
      toAccountId = value.toAccountId,
      date = value.date,
      createdAt = value.createdAt;

  _LedgerRow.trade(Map<String, dynamic> value, Map<String, Map<String, dynamic>> byId)
    : entry = null,
      trade = value,
      date = '${value['date']}',
      createdAt = '${value['created_at']}',
      toAccountId = _otherAccount(value, byId);

  final Entry? entry;
  final Map<String, dynamic>? trade;
  final String? toAccountId;
  final String date;
  final String createdAt;

  /// The transfer_in account, so the out row can show A → B.
  static String? _otherAccount(
    Map<String, dynamic> trade,
    Map<String, Map<String, dynamic>> byId,
  ) {
    final pairId = trade['pair_id']?.toString();
    if (pairId == null || pairId.isEmpty) return null;
    final pair = byId[pairId];
    if (pair == null) return null;
    return pair['account_id']?.toString();
  }
}

class _EmptyBooks extends StatelessWidget {
  const _EmptyBooks({
    required this.controller,
    required this.busy,
    required this.error,
    required this.archived,
    required this.onCreate,
  });

  final TextEditingController controller;
  final bool busy;
  final String? error;
  final bool archived;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: AppColors.sheet,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 36, 22, 24),
        children: [
          Text('還沒有帳本', style: text.titleLarge),
          const SizedBox(height: 8),
          Text('建立一本，就可以記帳、看資產。', style: text.bodySmall),
          const SizedBox(height: 18),
          TextField(
            key: const Key('book-name-field'),
            controller: controller,
            decoration: const InputDecoration(
              labelText: '帳本名稱',
              hintText: '生活',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            key: const Key('home-create-book'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sage,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: busy ? null : onCreate,
            child: Text(busy ? '請稍候…' : '建立帳本'),
          ),
          if (archived) ...[
            const SizedBox(height: 8),
            TextButton(
              // Purpose: archived books are managed from the empty state.
              // Rule: same home origin as the switcher, so 新增 does not
              // jump to 開帳. Key logic: `from=home` is read by the route.
              onPressed: () => context.push('/settings/books?from=home'),
              child: const Text('管理已封存的帳本'),
            ),
          ],
          ErrorLine(error, lineKey: const Key('home-error')),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.name,
    required this.quote,
    required this.onSwitch,
  });

  final String name;
  final String quote;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: const Color(0xB8FFFFFF),
          shape: const StadiumBorder(
            side: BorderSide(color: Color(0x0A000000)),
          ),
          child: InkWell(
            key: const Key('book-switcher'),
            customBorder: const StadiumBorder(),
            onTap: onSwitch,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        Text(
          quote,
          key: const Key('quote-time'),
          style: const TextStyle(fontSize: 11, color: AppColors.secondary),
        ),
      ],
    );
  }
}

class _SpendCard extends StatelessWidget {
  const _SpendCard({required this.summary});

  final StatsSummary? summary;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今天已花',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatNtd(summary?.todayExpense ?? 0),
                key: const Key('home-today'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: AppColors.sage,
                  height: 1.1,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '本月已花',
                    style: TextStyle(fontSize: 12, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatNtd(summary?.monthExpense ?? 0),
                    key: const Key('home-month'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetCard extends StatelessWidget {
  const _NetCard({required this.summary});

  final StatsSummary? summary;

  @override
  Widget build(BuildContext context) {
    final change = summary?.netWorthChangeVsOpening ?? 0;
    final deltaColor = change < 0 ? AppColors.expense : AppColors.up;
    final unquoted = summary?.somePositionsUnquoted == true
        ? ' · 部分持倉無現價，用成本估'
        : '';
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '淨資產',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatNtd(summary?.netWorth ?? 0),
            key: const Key('home-net'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatDelta(change),
            key: const Key('home-delta'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: deltaColor,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0x1A3C3C43)),
          const SizedBox(height: 6),
          Text(
            '持倉現值 ${formatNtd(summary?.positionMv ?? 0)} · 未實現 ${formatSignedNtd(summary?.unrealized ?? 0)}$unquoted',
            key: const Key('home-positions'),
            style: const TextStyle(fontSize: 10, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.account,
    required this.toAccount,
    required this.category,
    this.onTap,
    this.onDelete,
  });

  final Entry entry;
  final Account? account;
  final Account? toAccount;
  final Category? category;

  /// Null for opening_balance. Those rows are not edited from the list.
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final title = _title();
    final subtitle = _subtitle();
    final amount = _amount();
    return InkWell(
      key: Key('entry-row-${entry.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0x248FB09F),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(_icon(), size: 18, color: AppColors.sageDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              amount.text,
              key: Key('entry-${entry.id}'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: amount.color,
              ),
            ),
            if (onDelete != null)
              IconButton(
                key: Key('delete-entry-${entry.id}'),
                tooltip: '刪除',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _title() {
    final note = entry.note.trim();
    if (note.isNotEmpty) return note;
    switch (entry.type) {
      case 'transfer':
        return '轉帳';
      case 'opening_balance':
        return '開帳';
      case 'income':
        return category?.name ?? '收入';
      default:
        return category?.name ?? '支出';
    }
  }

  String _subtitle() {
    final from = account?.name ?? '';
    if (entry.type == 'transfer') {
      final to = toAccount?.name ?? '';
      if (from.isEmpty) return to;
      if (to.isEmpty) return from;
      return '$from → $to';
    }
    final cat = category?.name ?? '';
    if (from.isEmpty) return cat;
    if (cat.isEmpty) return from;
    return '$from · $cat';
  }

  ({String text, Color color}) _amount() {
    final grouped = formatGrouped(entry.amount);
    switch (entry.type) {
      case 'expense':
        return (text: '−$grouped', color: AppColors.expense);
      case 'income':
        return (text: '+$grouped', color: AppColors.sageDark);
      default:
        return (text: grouped, color: AppColors.ink);
    }
  }

  IconData _icon() {
    final haystack = '${entry.note} ${category?.name ?? ''}';
    if (entry.type == 'transfer') return Icons.swap_horiz_rounded;
    if (entry.type == 'income') return Icons.payments_outlined;
    if (entry.type == 'opening_balance') return Icons.flag_outlined;
    if (haystack.contains('咖啡')) return Icons.local_cafe_outlined;
    if (haystack.contains('餐') || haystack.contains('飯') || haystack.contains('午餐')) {
      return Icons.restaurant_rounded;
    }
    if (haystack.contains('交通') || haystack.contains('捷運')) {
      return Icons.directions_subway_outlined;
    }
    return Icons.shopping_bag_outlined;
  }
}

/// One buy, sell, airdrop, or transfer_out. Tap edits. Delete confirms.
class _TradeRow extends StatelessWidget {
  const _TradeRow({
    required this.trade,
    required this.account,
    required this.toAccount,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> trade;
  final Account? account;
  final Account? toAccount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final id = '${trade['id']}';
    final amount = _amount();
    final subtitle = _subtitle();
    return InkWell(
      key: Key('trade-row-$id'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0x248FB09F),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(_icon(), size: 18, color: AppColors.sageDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              amount.text,
              key: Key('trade-$id'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: amount.color,
              ),
            ),
            IconButton(
              key: Key('delete-trade-$id'),
              tooltip: '刪除',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title() {
    final note = '${trade['note'] ?? ''}'.trim();
    if (note.isNotEmpty) return note;
    final symbol = '${trade['symbol'] ?? ''}'.trim();
    final verb = switch ('${trade['side']}') {
      'sell' => '賣',
      'airdrop' => '空投',
      'transfer_out' => '轉倉',
      _ => '買',
    };
    if (symbol.isEmpty) return verb;
    return '$verb $symbol';
  }

  String _subtitle() {
    final from = account?.name ?? '';
    if ('${trade['side']}' == 'transfer_out') {
      final to = toAccount?.name ?? '';
      if (from.isEmpty) return to;
      if (to.isEmpty) return from;
      return '$from → $to';
    }
    return from;
  }

  /// Buy spends proceeds. Sell receives them. Transfer and airdrop show qty.
  ({String text, Color color}) _amount() {
    final side = '${trade['side']}';
    if (side == 'buy') {
      return (
        text: '−${formatGrouped(jsonInt(trade['proceeds_or_cost_twd']))}',
        color: AppColors.expense,
      );
    }
    if (side == 'sell') {
      return (
        text: '+${formatGrouped(jsonInt(trade['proceeds_or_cost_twd']))}',
        color: AppColors.sageDark,
      );
    }
    final qty = '${trade['qty'] ?? ''}';
    if (side == 'airdrop') {
      return (text: '+$qty', color: AppColors.sageDark);
    }
    return (text: qty, color: AppColors.ink);
  }

  IconData _icon() {
    switch ('${trade['side']}') {
      case 'sell':
        return Icons.trending_down_rounded;
      case 'airdrop':
        return Icons.redeem_outlined;
      case 'transfer_out':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.trending_up_rounded;
    }
  }
}

class _OpeningOffer extends StatelessWidget {
  const _OpeningOffer({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '開帳為選填，可帶入現有餘額與持倉。',
              key: Key('home-opening-hint'),
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
          TextButton(
            key: const Key('home-opening'),
            onPressed: onTap,
            child: const Text('開始開帳'),
          ),
        ],
      ),
    );
  }
}
