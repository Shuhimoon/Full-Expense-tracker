import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/field_dialog.dart';
import 'package:go_router/go_router.dart';

// One existing row opened from the 帳本 list.
//
// Purpose: the record sheet edits in place instead of inserting a second
// row. [kind] is locked. An entry and a trade live in different tables, and
// the API rejects a type change (類型不能改). A transfer stays a transfer.
// A buy, sell, or airdrop may change among those three sides, not into a
// transfer (成交方向不能改成轉倉). The date still cannot be before the
// book's opening date. Save calls patch, which replays holdings.
class RecordEdit {
  const RecordEdit.entry({
    required this.id,
    required this.version,
    required this.type,
    required this.date,
    required this.accountId,
    required this.amount,
    this.toAccountId,
    this.categoryId,
    this.note = '',
  }) : kind = 'entry',
       side = '',
       symbol = null,
       assetClass = null,
       quoteCurrency = null,
       qty = null,
       price = null,
       priceCcy = null,
       feeTwd = null;

  const RecordEdit.trade({
    required this.id,
    required this.version,
    required this.side,
    required this.date,
    required this.accountId,
    this.toAccountId,
    this.note = '',
    this.symbol,
    this.assetClass,
    this.quoteCurrency,
    this.qty,
    this.price,
    this.priceCcy,
    this.feeTwd,
  }) : kind = 'trade',
       type = 'trade',
       amount = null,
       categoryId = null;

  /// `entry` or `trade`. Decides which patch method runs.
  final String kind;
  final String id;
  final int version;
  final String type;
  final String date;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String note;
  final int? amount;
  final String side;
  final String? symbol;
  final String? assetClass;
  final String? quoteCurrency;
  final String? qty;
  final String? price;
  final String? priceCcy;
  final int? feeTwd;

  bool get isTrade => kind == 'trade';

  /// Transfer legs are edited together. The sheet shows one 轉倉 row.
  bool get isTransferTrade =>
      side == 'transfer' || side == 'transfer_out' || side == 'transfer_in';
}

class RecordSheet extends StatefulWidget {
  const RecordSheet({super.key, this.edit});

  /// Null is a new row. Set when a ledger row is tapped.
  final RecordEdit? edit;

  @override
  State<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<RecordSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _symbol = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _fee = TextEditingController(text: '0');

  String _type = 'expense';
  String _side = 'buy';
  String _assetClass = 'tw_stock';
  String _priceCcy = 'TWD';
  String _date = taipeiToday();
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  List<Account> _accounts = [];
  List<Category> _categories = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _bookId;

  /// True while an existing row is open. The type chips do not switch tables.
  bool get _editing => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    if (edit == null) return;
    // Prefill before _load. The load uses ??= and must not replace these.
    _date = edit.date;
    _accountId = edit.accountId;
    _toAccountId = edit.toAccountId;
    _note.text = edit.note;
    if (edit.isTrade) {
      _type = 'trade';
      _side = edit.isTransferTrade ? 'transfer' : edit.side;
      _symbol.text = edit.symbol ?? '';
      _qty.text = edit.qty ?? '';
      _price.text = edit.price ?? '';
      // The sheet has no fee field. Keep the stored fee so a save does not
      // zero a fee the user did not touch.
      _fee.text = '${edit.feeTwd ?? 0}';
      _assetClass = edit.assetClass ?? _assetClass;
      _priceCcy = edit.priceCcy ?? edit.quoteCurrency ?? _priceCcy;
    } else {
      _type = edit.type;
      _amount.text = '${edit.amount ?? ''}';
      _categoryId = edit.categoryId;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _symbol.dispose();
    _qty.dispose();
    _price.dispose();
    _fee.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = BookScope.of(context).current?.id;
    if (_bookId == id && !_loading) return;
    _bookId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final book = BookScope.of(context).current;
    if (book == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final api = BookScope.of(context).api;
      final accounts = await api.listAccounts(book.id);
      final categories = await api.listCategories(book.id);
      if (!mounted) return;
      final live = accounts.where((account) => !account.archived).toList();
      setState(() {
        _accounts = live;
        _categories = categories.where((category) => !category.archived).toList();
        _accountId ??= live.isEmpty ? null : live.first.id;
        _categoryId ??= _firstCategory(_type);
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  String? _firstCategory(String type) {
    final kind = type == 'income' ? 'income' : 'expense';
    for (final category in _categories) {
      if (category.kind == kind) return category.id;
    }
    return null;
  }

  void _setType(String type) {
    // Edit mode cannot move an expense onto the trade table, or the reverse.
    if (_editing) return;
    setState(() {
      _type = type;
      _error = null;
      if (type == 'expense' || type == 'income') {
        _categoryId = _firstCategory(type);
      }
    });
  }

  List<Account> get _tradeAccounts =>
      _accounts.where((account) => account.canHold).toList();

  Account? _byId(String? id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Category? _categoryById(String? id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Future<void> _pickAccount({required bool toAccount}) async {
    final source = _type == 'trade' ? _tradeAccounts : _accounts;
    final picked = await _pickLabel(
      title: toAccount ? '轉入帳戶' : '帳戶',
      options: [
        for (final account in source) (account.id, account.name),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (toAccount) {
        _toAccountId = picked;
      } else {
        _accountId = picked;
      }
    });
  }

  Future<void> _pickCategory() async {
    final kind = _type == 'income' ? 'income' : 'expense';
    final picked = await _pickLabel(
      title: '分類',
      options: [
        for (final category in _categories)
          if (category.kind == kind) (category.id, category.name),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _categoryId = picked);
  }

  Future<String?> _pickLabel({
    required String title,
    required List<(String, String)> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.sheet,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (options.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('沒有可選項目'),
                ),
              for (final option in options)
                ListTile(
                  key: Key('pick-${option.$1}'),
                  title: Text(option.$2),
                  onTap: () => Navigator.pop(context, option.$1),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final opening = BookScope.of(context).current?.openingDate;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => _DateDialog(initial: _date, opening: opening),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_busy) return;
    final book = BookScope.of(context).current;
    if (book == null) {
      setState(() => _error = '請先建立帳本');
      return;
    }
    if (book.archived) {
      setState(() => _error = '帳本已封存，不能寫入');
      return;
    }
    if (!isIsoDate(_date)) {
      setState(() => _error = '日期格式不對');
      return;
    }
    if (isBeforeOpening(_date, book.openingDate)) {
      setState(() => _error = '不能記開帳日之前的帳');
      return;
    }
    final accountId = _accountId;
    if (accountId == null || accountId.isEmpty) {
      setState(() => _error = _type == 'trade' ? '請先建立券商或交易所帳戶' : '請選帳戶');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = BookScope.of(context).api;
      final edit = widget.edit;
      if (edit != null) {
        // Patch replays holdings in one transaction. A negative holding
        // throws and leaves the row as it was. No idempotency key: a patch
        // is not a second insert.
        if (edit.isTrade) {
          await _patchTrade(api, accountId, edit);
        } else {
          await _patchEntry(api, accountId, edit);
        }
      } else {
        final key = newIdempotencyKey();
        if (_type == 'trade') {
          await _saveTrade(api, book.id, accountId, key);
        } else {
          await _saveEntry(api, book.id, accountId, key);
        }
      }
      if (!mounted) return;
      BookScope.of(context).touch();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '請求失敗');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEntry(
    ApiClient api,
    String bookId,
    String accountId,
    String key,
  ) async {
    final amount = parseWholeAmount(_amount.text);
    if (amount == null || amount <= 0) {
      throw ApiException('金額必須大於 0');
    }
    final body = <String, dynamic>{
      'book_id': bookId,
      'type': _type,
      'amount': amount,
      'account_id': accountId,
      'date': _date,
      'note': _note.text.trim(),
    };
    if (_type == 'transfer') {
      final toId = _toAccountId;
      if (toId == null || toId.isEmpty) {
        throw ApiException('轉帳請選轉入帳戶');
      }
      if (toId == accountId) throw ApiException('不能轉給自己');
      body['to_account_id'] = toId;
    } else {
      final categoryId = _categoryId;
      if (categoryId == null || categoryId.isEmpty) {
        throw ApiException('請選分類');
      }
      body['category_id'] = categoryId;
    }
    await api.createEntry(body: body, idempotencyKey: key);
  }

  /// Writes the edited entry. Omitted transfer fields stay off the body so
  /// a partial update keeps the other side. The type is the original type.
  Future<void> _patchEntry(
    ApiClient api,
    String accountId,
    RecordEdit edit,
  ) async {
    final amount = parseWholeAmount(_amount.text);
    if (amount == null || amount <= 0) {
      throw ApiException('金額必須大於 0');
    }
    final body = <String, dynamic>{
      'version': edit.version,
      'type': edit.type,
      'amount': amount,
      'account_id': accountId,
      'date': _date,
      'note': _note.text.trim(),
    };
    if (edit.type == 'transfer') {
      final toId = _toAccountId;
      if (toId == null || toId.isEmpty) {
        throw ApiException('轉帳請選轉入帳戶');
      }
      if (toId == accountId) throw ApiException('不能轉給自己');
      body['to_account_id'] = toId;
    } else {
      final categoryId = _categoryId;
      if (categoryId == null || categoryId.isEmpty) {
        throw ApiException('請選分類');
      }
      body['category_id'] = categoryId;
    }
    await api.patchEntry(id: edit.id, body: body);
  }

  /// Writes the edited trade. Transfer updates both legs. Buy, sell, and
  /// airdrop send the new side. Fee comes from the prefilled controller.
  Future<void> _patchTrade(
    ApiClient api,
    String accountId,
    RecordEdit edit,
  ) async {
    final account = _byId(accountId);
    if (account == null || !account.canHold) {
      throw ApiException('成交帳戶必須是券商或交易所');
    }
    final symbol = _symbol.text.trim().toUpperCase();
    if (symbol.isEmpty) throw ApiException('請填標的代號');
    final qty = _qty.text.trim();
    final qtyValue = double.tryParse(qty);
    if (qtyValue == null || qtyValue <= 0) throw ApiException('數量必須大於 0');
    final body = <String, dynamic>{
      'version': edit.version,
      'date': _date,
      'account_id': accountId,
      'symbol': symbol,
      'name': symbol,
      'asset_class': _assetClass,
      'quote_currency': _priceCcy,
      'qty': qty,
      'fee_twd': parseWholeAmount(_fee.text) ?? 0,
      'note': _note.text.trim(),
    };
    if (_side == 'transfer') {
      final toId = _toAccountId;
      if (toId == null || toId.isEmpty) throw ApiException('轉倉請選轉入帳戶');
      if (toId == accountId) throw ApiException('不能轉給自己');
      body['to_account_id'] = toId;
    } else {
      // Not a transfer. The API rejects side transfer on a single trade.
      body['side'] = _side;
      if (_side == 'buy' || _side == 'sell') {
        final price = _price.text.trim();
        if (double.tryParse(price) == null) throw ApiException('單價不對');
        body['price'] = price;
        body['price_ccy'] = _priceCcy;
      }
    }
    await api.patchTrade(id: edit.id, body: body);
  }

  Future<void> _saveTrade(
    ApiClient api,
    String bookId,
    String accountId,
    String key,
  ) async {
    final account = _byId(accountId);
    if (account == null || !account.canHold) {
      throw ApiException('成交帳戶必須是券商或交易所');
    }
    final symbol = _symbol.text.trim().toUpperCase();
    if (symbol.isEmpty) throw ApiException('請填標的代號');
    final qty = _qty.text.trim();
    final qtyValue = double.tryParse(qty);
    if (qtyValue == null || qtyValue <= 0) throw ApiException('數量必須大於 0');
    final body = <String, dynamic>{
      'book_id': bookId,
      'date': _date,
      'account_id': accountId,
      'symbol': symbol,
      'name': symbol,
      'asset_class': _assetClass,
      'quote_currency': _priceCcy,
      'side': _side,
      'qty': qty,
      'fee_twd': parseWholeAmount(_fee.text) ?? 0,
      'note': _note.text.trim(),
    };
    if (_side == 'buy' || _side == 'sell') {
      final price = _price.text.trim();
      if (double.tryParse(price) == null) throw ApiException('單價不對');
      body['price'] = price;
      body['price_ccy'] = _priceCcy;
    }
    if (_side == 'transfer') {
      final toId = _toAccountId;
      if (toId == null || toId.isEmpty) throw ApiException('轉倉請選轉入帳戶');
      body['to_account_id'] = toId;
    }
    await api.createTrade(body: body, idempotencyKey: key);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = BookScope.of(context).current;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('record-scrim'),
              onTap: _close,
              child: const ColoredBox(color: Color(0x381C1C1E)),
            ),
          ),
          AppFrame(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  MediaQuery.paddingOf(context).top + 36,
                  12,
                  16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height - 96,
                  ),
                  child: Material(
                    color: AppColors.sheet,
                    elevation: 18,
                    shadowColor: const Color(0x40281E14),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: _body(book),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(Book? book) {
    if (book == null && !_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _nav(),
          const SizedBox(height: 12),
          const Text('請先建立帳本', key: Key('record-no-book')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _nav(),
        const SizedBox(height: 6),
        _types(),
        if (_type != 'trade') ...[
          const SizedBox(height: 8),
          const Text(
            'TWD',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.secondary),
          ),
          TextField(
            key: const Key('record-amount'),
            controller: _amount,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
              color: AppColors.sage,
            ),
            decoration: const InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: AppColors.faint),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ],
        const SizedBox(height: 6),
        _glass(),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            key: const Key('record-error'),
            style: const TextStyle(color: AppColors.expense, fontSize: 13),
          ),
        ],
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFA5C4B5), AppColors.sage],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('record-save'),
              onTap: _busy ? null : _save,
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    _busy ? '請稍候…' : '存檔',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _nav() {
    return Row(
      children: [
        TextButton(
          key: const Key('record-close'),
          onPressed: _close,
          child: const Text('取消', style: TextStyle(color: AppColors.sage, fontSize: 16)),
        ),
        Expanded(
          child: Text(
            _editing ? '修改' : '記一筆',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          key: const Key('record-done'),
          onPressed: _busy ? null : _save,
          child: const Text('完成', style: TextStyle(color: AppColors.sage, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _types() {
    Widget chip(String id, String label) {
      final on = _type == id;
      return Expanded(
        child: InkWell(
          key: Key('record-tab-$id'),
          // Locked while editing. The selected chip still shows the type.
          onTap: _editing ? null : () => _setType(id),
          borderRadius: BorderRadius.circular(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: on ? const Color(0xF2FFFFFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: on
                  ? const [
                      BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
                    ]
                  : null,
            ),
            child: SizedBox(
              height: 30,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: on ? AppColors.sage : AppColors.secondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x1E767680),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            chip('expense', '支出'),
            chip('income', '收入'),
            chip('transfer', '轉帳'),
            chip('trade', '成交'),
          ],
        ),
      ),
    );
  }

  Widget _glass() {
    final rows = <Widget>[];
    if (_type == 'trade') {
      rows.add(_valueRow('方向', _sideLabel(_side), onTap: _pickSide, rowKey: const Key('record-side')));
      rows.add(_valueRow('標的', _symbol.text.isEmpty ? '2330 / BTC' : _symbol.text, placeholder: _symbol.text.isEmpty, onTap: _editSymbol, rowKey: const Key('record-symbol')));
      rows.add(_valueRow('資產類別', assetClassLabel(_assetClass), onTap: _pickAsset, rowKey: const Key('record-asset')));
      rows.add(_valueRow('數量', _qty.text.isEmpty ? '請填' : _qty.text, placeholder: _qty.text.isEmpty, onTap: _editQty, rowKey: const Key('record-qty')));
      if (_side == 'buy' || _side == 'sell') {
        rows.add(_valueRow('單價', _price.text.isEmpty ? _priceCcy : '${_price.text} $_priceCcy', placeholder: _price.text.isEmpty, onTap: _editPrice, rowKey: const Key('record-price')));
        rows.add(_valueRow('單價幣別', _priceCcy, onTap: _pickPriceCcy, rowKey: const Key('record-price-ccy')));
      } else {
        rows.add(_valueRow('報價幣別', _priceCcy, onTap: _pickPriceCcy, rowKey: const Key('record-price-ccy')));
      }
      rows.add(_valueRow('帳戶', _byId(_accountId)?.name ?? '請選擇', placeholder: _accountId == null, onTap: () => _pickAccount(toAccount: false), rowKey: const Key('record-account')));
      if (_side == 'transfer') {
        rows.add(_valueRow('轉入', _byId(_toAccountId)?.name ?? '請選擇', placeholder: _toAccountId == null, onTap: () => _pickAccount(toAccount: true), rowKey: const Key('record-to')));
      }
    } else if (_type == 'transfer') {
      rows.add(_valueRow('轉出帳戶', _byId(_accountId)?.name ?? '請選擇', placeholder: _accountId == null, onTap: () => _pickAccount(toAccount: false), rowKey: const Key('record-account')));
      rows.add(_valueRow('轉入帳戶', _byId(_toAccountId)?.name ?? '請選擇', placeholder: _toAccountId == null, onTap: () => _pickAccount(toAccount: true), rowKey: const Key('record-to')));
    } else {
      rows.add(_valueRow('帳戶', _byId(_accountId)?.name ?? '請選擇', placeholder: _accountId == null, onTap: () => _pickAccount(toAccount: false), rowKey: const Key('record-account')));
      rows.add(_valueRow('分類', _categoryById(_categoryId)?.name ?? '請選擇', placeholder: _categoryId == null, onTap: _pickCategory, rowKey: const Key('record-category')));
    }
    rows.add(_valueRow('日期', formatRecordDate(_date, taipeiToday()), onTap: _pickDate, rowKey: const Key('record-date')));
    rows.add(_noteRow());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x9EFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xC7FFFFFF)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0x1F3C3C43)),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _noteRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 72,
            child: Text('備註', style: TextStyle(fontSize: 14, color: AppColors.secondary)),
          ),
          Expanded(
            child: TextField(
              key: const Key('record-note'),
              controller: _note,
              decoration: const InputDecoration(
                hintText: '可空',
                hintStyle: TextStyle(color: Color(0xFFC7C7CC)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueRow(
    String label,
    String value, {
    required VoidCallback onTap,
    bool placeholder = false,
    Key? rowKey,
  }) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: AppColors.secondary),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: placeholder ? FontWeight.w400 : FontWeight.w500,
                  color: placeholder ? const Color(0xFFC7C7CC) : AppColors.ink,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  String _sideLabel(String side) {
    switch (side) {
      case 'sell':
        return '賣';
      case 'airdrop':
        return '空投／股利';
      case 'transfer':
        return '轉倉';
      default:
        return '買';
    }
  }

  Future<void> _pickSide() async {
    // A transfer edit stays a transfer pair. A single trade may become a
    // buy, sell, or airdrop. It cannot become a transfer from this sheet.
    if (_editing && _side == 'transfer') return;
    final picked = await _pickLabel(
      title: '方向',
      options: _editing
          ? const [
              ('buy', '買'),
              ('sell', '賣'),
              ('airdrop', '空投／股利'),
            ]
          : const [
              ('buy', '買'),
              ('sell', '賣'),
              ('transfer', '轉倉'),
              ('airdrop', '空投／股利'),
            ],
    );
    if (picked == null || !mounted) return;
    setState(() => _side = picked);
  }

  Future<void> _pickAsset() async {
    final picked = await _pickLabel(
      title: '資產類別',
      options: [
        for (final value in assetClassValues) (value, assetClassLabel(value)),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() {
      _assetClass = picked;
      _priceCcy = defaultQuoteCurrency(picked);
    });
  }

  Future<void> _pickPriceCcy() async {
    final picked = await _pickLabel(
      title: '單價幣別',
      options: [
        for (final value in priceCurrencyValues) (value, value),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _priceCcy = picked);
  }

  Future<void> _editSymbol() async {
    final value = await _editText('標的代號', _symbol.text, const Key('record-symbol-field'));
    if (value == null || !mounted) return;
    setState(() => _symbol.text = value.toUpperCase());
  }

  Future<void> _editQty() async {
    final value = await _editText('數量', _qty.text, const Key('record-qty-field'));
    if (value == null || !mounted) return;
    setState(() => _qty.text = value);
  }

  Future<void> _editPrice() async {
    final value = await _editText('單價', _price.text, const Key('record-price-field'));
    if (value == null || !mounted) return;
    setState(() => _price.text = value);
  }

  Future<String?> _editText(String title, String initial, Key fieldKey) {
    return FieldDialog.show(
      context,
      title: title,
      initial: initial,
      fieldKey: fieldKey,
      okKey: const Key('record-text-ok'),
    );
  }
}

class _DateDialog extends StatefulWidget {
  const _DateDialog({required this.initial, required this.opening});

  final String initial;
  final String? opening;

  @override
  State<_DateDialog> createState() => _DateDialogState();
}

class _DateDialogState extends State<_DateDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String _message = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (!isIsoDate(value)) {
      setState(() => _message = '日期格式不對');
      return;
    }
    if (isBeforeOpening(value, widget.opening)) {
      setState(() => _message = '不能記開帳日之前的帳');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('日期'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('record-date-field'),
            controller: _controller,
            decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
          ),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message,
                key: const Key('record-date-error'),
                style: const TextStyle(color: AppColors.expense),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          key: const Key('record-date-ok'),
          onPressed: _submit,
          child: const Text('確定'),
        ),
      ],
    );
  }
}
