import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:go_router/go_router.dart';

/// Four-step opening snapshot. There is no lock step: step 4 saves with PUT.
class OpeningPage extends StatefulWidget {
  const OpeningPage({super.key});

  @override
  State<OpeningPage> createState() => _OpeningPageState();
}

class _PosForm {
  _PosForm({
    required this.accountId,
    required this.assetClass,
    required this.quoteCurrency,
    this.instrumentId,
    this.name = '',
    String symbol = '',
    String qty = '',
    String cost = '',
    this.costUnknown = false,
  }) : symbol = TextEditingController(text: symbol),
       qty = TextEditingController(text: qty),
       cost = TextEditingController(text: cost);

  factory _PosForm.fromDraft(OpeningPositionDraft draft) {
    final asset = assetClassValues.contains(draft.assetClass)
        ? draft.assetClass
        : 'tw_stock';
    final quote = priceCurrencyValues.contains(draft.quoteCurrency)
        ? draft.quoteCurrency
        : defaultQuoteCurrency(asset);
    return _PosForm(
      accountId: draft.accountId,
      instrumentId: draft.instrumentId,
      name: draft.name,
      assetClass: asset,
      quoteCurrency: quote,
      symbol: draft.symbol,
      qty: draft.qty,
      cost: draft.costUnknown ? '0' : draft.costTwd,
      costUnknown: draft.costUnknown,
    );
  }

  final TextEditingController symbol;
  final TextEditingController qty;
  final TextEditingController cost;
  String accountId;
  String? instrumentId;
  String name;
  String assetClass;
  String quoteCurrency;
  bool costUnknown;

  bool get isBlank {
    return symbol.text.trim().isEmpty &&
        qty.text.trim().isEmpty &&
        cost.text.trim().isEmpty &&
        !costUnknown;
  }

  void dispose() {
    symbol.dispose();
    qty.dispose();
    cost.dispose();
  }
}

class _OpeningPageState extends State<OpeningPage> {
  final Map<String, TextEditingController> _amounts = {};
  final List<_PosForm> _positions = [];

  String? _bookId;
  List<Account> _accounts = [];
  int _step = 1;
  String _date = taipeiToday();
  late DateTime _visibleMonth = DateTime.parse('${_date.substring(0, 7)}-01');
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    for (final position in _positions) {
      position.dispose();
    }
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
      final opening = await BookScope.of(context).api.getOpening(book.id);
      if (!mounted) return;
      _replaceDrafts(book, opening);
      setState(() {
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _date = _initialDate(book, null);
        _visibleMonth = _monthOf(_date);
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '請求失敗';
      });
    }
  }

  void _replaceDrafts(Book book, OpeningSnapshot opening) {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    _amounts.clear();
    for (final position in _positions) {
      position.dispose();
    }
    _positions.clear();
    _accounts = opening.accounts.where((account) => !account.archived).toList();
    final drafted = {
      for (final draft in opening.cashDrafts) draft.accountId: draft.amount,
    };
    for (final account in _accounts) {
      final amount = drafted[account.id];
      _amounts[account.id] = TextEditingController(
        text: amount == null ? '' : '$amount',
      );
    }
    for (final draft in opening.positionDrafts) {
      _positions.add(_PosForm.fromDraft(draft));
    }
    _date = _initialDate(book, opening.openingDate);
    _visibleMonth = _monthOf(_date);
  }

  /// Current opening date when the API has one (new books default it to the
  /// creation day). Otherwise the creation day itself.
  String _initialDate(Book book, String? apiDate) {
    if (apiDate != null && isIsoDate(apiDate)) return apiDate;
    final opening = book.openingDate;
    if (opening != null && isIsoDate(opening)) return opening;
    return bookCreationDay(book.createdAt);
  }

  DateTime _monthOf(String iso) {
    final parsed = DateTime.tryParse(iso);
    final day = parsed ?? DateTime.parse('${taipeiToday().substring(0, 7)}-01');
    return DateTime(day.year, day.month);
  }

  List<Account> get _brokers =>
      _accounts.where((account) => account.canHold).toList();

  List<_PosForm> get _activePositions =>
      _positions.where((position) => !position.isBlank).toList();

  int _amountOf(Account account) => readWholeAmount(_amounts[account.id]?.text ?? '') ?? 0;

  int get _cashSum {
    var total = 0;
    for (final account in _accounts) {
      if (account.type == 'credit_card') continue;
      total += _amountOf(account);
    }
    return total;
  }

  int get _debtSum {
    var total = 0;
    for (final account in _accounts) {
      if (account.type != 'credit_card') continue;
      total += _amountOf(account);
    }
    return total;
  }

  int get _cashCount =>
      _accounts.where((account) => account.type != 'credit_card').length;

  int get _debtCount =>
      _accounts.where((account) => account.type == 'credit_card').length;

  int _costOf(_PosForm position) {
    if (position.costUnknown) return 0;
    return roundDecimal(readDecimal(position.cost.text) ?? '0');
  }

  int get _positionCost =>
      _activePositions.fold(0, (sum, position) => sum + _costOf(position));

  int get _previewNet => _cashSum - _debtSum + _positionCost;

  bool get _hasUnknown =>
      _activePositions.any((position) => position.costUnknown);

  String? _validate(int step) {
    if (step == 1 && !isIsoDate(_date)) return '開帳日格式不對';
    if (step == 2) {
      for (final account in _accounts) {
        if (readWholeAmount(_amounts[account.id]?.text ?? '') == null) {
          return '開帳金額不能為負';
        }
      }
    }
    if (step == 3) {
      if (_activePositions.isNotEmpty && _brokers.isEmpty) {
        return '請先新增券商或交易所帳戶';
      }
      for (final position in _activePositions) {
        if (position.symbol.text.trim().isEmpty) return '請填標的代號';
        final qty = readDecimal(position.qty.text);
        if (qty == null || qty == '0' || double.parse(qty) <= 0) {
          return '數量必須大於 0';
        }
        if (!position.costUnknown && readDecimal(position.cost.text) == null) {
          return '成本不對';
        }
        if (!assetClassValues.contains(position.assetClass)) return '資產類別不對';
        if (!priceCurrencyValues.contains(position.quoteCurrency)) {
          return '幣別不對';
        }
        if (position.accountId.isEmpty) return '請先新增券商或交易所帳戶';
      }
    }
    return null;
  }

  void _next() {
    if (_busy) return;
    final error = _validate(_step);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _step = (_step + 1).clamp(1, 4);
    });
  }

  void _back() {
    if (_step > 1) {
      setState(() {
        _step -= 1;
        _error = null;
      });
      return;
    }
    _leave();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  Future<void> _addAccount() async {
    final book = BookScope.of(context).current;
    if (book == null) return;
    final created = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _NewAccountDialog(),
    );
    if (created == null || !mounted) return;
    final (name, type) = created;
    if (name.isEmpty) {
      setState(() => _error = '請填帳戶名稱');
      return;
    }
    try {
      final account = await BookScope.of(context).api.createAccount(
        bookId: book.id,
        name: name,
        type: type,
      );
      if (!mounted) return;
      setState(() {
        _accounts = [..._accounts, account];
        _amounts[account.id] = TextEditingController();
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _addPosition() {
    final brokers = _brokers;
    if (brokers.isEmpty) {
      setState(() => _error = '請先新增券商或交易所帳戶');
      return;
    }
    setState(() {
      _positions.add(
        _PosForm(
          accountId: brokers.first.id,
          assetClass: 'tw_stock',
          quoteCurrency: 'TWD',
        ),
      );
      _error = null;
    });
  }

  void _removePosition(int index) {
    setState(() {
      _positions.removeAt(index).dispose();
    });
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
    for (var step = 1; step <= 3; step++) {
      final error = _validate(step);
      if (error != null) {
        setState(() {
          _step = step;
          _error = error;
        });
        return;
      }
    }
    if (_hasUnknown) {
      final confirmed = await _confirmUnknown();
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final books = BookScope.of(context);
      await books.api.putOpening(bookId: book.id, body: _payload());
      if (!mounted) return;
      await books.reload();
      if (!mounted) return;
      books.touch();
      _leave();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        if (error.message.contains('開帳日')) _step = 1;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '請求失敗');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmUnknown() async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('成本未填'),
          content: const Text('有持倉成本未填，未實現會偏大。仍要儲存？'),
          actions: [
            TextButton(
              key: const Key('opening-unknown-cancel'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回'),
            ),
            TextButton(
              key: const Key('opening-unknown-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
    return answer == true;
  }

  Map<String, dynamic> _payload() {
    return {
      'opening_date': _date,
      'accounts': [
        for (final account in _accounts)
          {'account_id': account.id, 'amount': _amountOf(account)},
      ],
      'positions': [
        for (final position in _activePositions) _positionBody(position),
      ],
    };
  }

  Map<String, dynamic> _positionBody(_PosForm position) {
    final symbol = position.symbol.text.trim().toUpperCase();
    final name = position.name.trim().isEmpty ? symbol : position.name.trim();
    final qty = readDecimal(position.qty.text) ?? '0';
    final cost = position.costUnknown
        ? '0'
        : (readDecimal(position.cost.text) ?? '0');
    final body = <String, dynamic>{
      'account_id': position.accountId,
      'symbol': symbol,
      'name': name,
      'asset_class': position.assetClass,
      'quote_currency': position.quoteCurrency,
      'qty': qty,
      'cost_twd': cost,
      'cost_unknown': position.costUnknown,
    };
    final instrumentId = position.instrumentId;
    if (instrumentId != null && instrumentId.isNotEmpty) {
      body['instrument_id'] = instrumentId;
    }
    return body;
  }

  Future<void> _pickAsset(_PosForm position) async {
    final picked = await _pick(
      title: '資產類別',
      options: [
        for (final value in assetClassValues) (value, assetClassLabel(value)),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() {
      position.assetClass = picked;
      position.quoteCurrency = defaultQuoteCurrency(picked);
    });
  }

  Future<void> _pickQuote(_PosForm position) async {
    final picked = await _pick(
      title: '報價幣別',
      options: [
        for (final value in priceCurrencyValues) (value, value),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => position.quoteCurrency = picked);
  }

  Future<void> _pickAccount(_PosForm position) async {
    final picked = await _pick(
      title: '帳戶',
      options: [
        for (final account in _brokers) (account.id, account.name),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => position.accountId = picked);
  }

  Future<String?> _pick({
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

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: AppFrame(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.sheet,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x8CFFFFFF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x143C2814),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.sage),
                    )
                  : _sheet(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheet() {
    final book = BookScope.of(context).current;
    if (book == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _nav('開始開帳'),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('請先建立帳本', key: Key('opening-no-book')),
          ),
        ],
      );
    }
    return Column(
      children: [
        _nav(_title),
        _dots(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            children: _stepBody(),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              _error!,
              key: const Key('opening-error'),
              style: const TextStyle(color: AppColors.expense, fontSize: 13),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          child: _footer(),
        ),
      ],
    );
  }

  String get _title {
    switch (_step) {
      case 2:
        return '帳戶餘額';
      case 3:
        return '現倉';
      case 4:
        return '預覽開帳';
      default:
        return '選開帳日';
    }
  }

  List<Widget> _stepBody() {
    switch (_step) {
      case 2:
        return _balances();
      case 3:
        return _holdings();
      case 4:
        return _preview();
      default:
        return _dateStep();
    }
  }

  Widget _nav(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 0),
      child: Row(
        children: [
          Material(
            color: const Color(0x248FB09F),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: const Key('opening-back'),
              borderRadius: BorderRadius.circular(10),
              onTap: _busy ? null : _back,
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppColors.sageDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const Key('opening-title'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                Text(
                  '步驟 $_step／4 · 開帳',
                  key: const Key('opening-step'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dots() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          for (var index = 1; index <= 4; index++) ...[
            if (index > 1) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: index <= _step
                      ? AppColors.sageDark
                      : const Color(0x388FB09F),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _dateStep() {
    return [
      _card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MonthCalendar(
              visible: _visibleMonth,
              selected: _date,
              onPrevious: () => setState(() {
                _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
              }),
              onNext: () => setState(() {
                _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
              }),
              onSelect: (iso) => setState(() {
                _date = iso;
                _error = null;
              }),
            ),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x1F8FB09F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '開帳日',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _date,
                            key: const Key('opening-date'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.sageDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.sageDark,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '開帳日之後才可記一筆與看分析。',
        style: TextStyle(fontSize: 11, color: AppColors.secondary, height: 1.4),
      ),
    ];
  }

  List<Widget> _balances() {
    return [
      _card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '現金／銀行／券商',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (_accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '尚無帳戶，請先新增',
                  key: Key('opening-no-accounts'),
                  style: TextStyle(fontSize: 12, color: AppColors.secondary),
                ),
              ),
            for (var index = 0; index < _accounts.length; index++) ...[
              if (index > 0)
                const Divider(height: 1, color: Color(0x1A3C3C43)),
              _accountRow(_accounts[index]),
            ],
            InkWell(
              key: const Key('opening-add-account'),
              onTap: _busy ? null : _addAccount,
              child: const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: AppColors.sageDark),
                    SizedBox(width: 6),
                    Text(
                      '新增帳戶',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sageDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          const Text(
            '現金合計',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            formatNtd(_cashSum - _debtSum),
            key: const Key('opening-cash-total'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        '信用卡請填欠款（正數）。儲存開帳後這些數字會成為基準。',
        style: TextStyle(fontSize: 11, color: AppColors.secondary, height: 1.4),
      ),
    ];
  }

  Widget _accountRow(Account account) {
    final debt = account.type == 'credit_card';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _iconBox(_accountIcon(account.type)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  debt
                      ? '${accountTypeLabel(account.type)} · 欠款（正數）'
                      : accountTypeLabel(account.type),
                  style: const TextStyle(fontSize: 11, color: AppColors.secondary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            height: 36,
            child: TextField(
              key: Key('opening-amount-${account.id}'),
              controller: _amounts[account.id],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: const Color(0xE6FFFFFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x1F3C3C43)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x1F3C3C43)),
                ),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _holdings() {
    return [
      _card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '持倉數量與成本',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (_brokers.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '請先新增券商或交易所帳戶，再加入現倉。',
                  key: Key('opening-no-brokers'),
                  style: TextStyle(fontSize: 12, color: AppColors.secondary),
                ),
              ),
            for (var index = 0; index < _positions.length; index++) ...[
              if (index > 0) const Divider(height: 1, color: Color(0x1A3C3C43)),
              _positionRow(index),
            ],
            InkWell(
              key: const Key('opening-add-position'),
              onTap: _busy ? null : _addPosition,
              child: const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: AppColors.sageDark),
                    SizedBox(width: 6),
                    Text(
                      '加入現倉',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sageDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '成本未填時未實現損益會偏大；可勾選「成本不確定」。',
        style: TextStyle(fontSize: 11, color: AppColors.secondary, height: 1.4),
      ),
    ];
  }

  Widget _positionRow(int index) {
    final position = _positions[index];
    final accountName = _accountName(position.accountId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _iconBox(Icons.trending_up_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: Key('opening-symbol-$index'),
                      controller: position.symbol,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '代號（2330 / BTC）',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Text(
                      '$accountName · ${assetClassLabel(position.assetClass)} · ${position.quoteCurrency}',
                      style: const TextStyle(fontSize: 11, color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: Key('opening-remove-$index'),
                onPressed: () => _removePosition(index),
                child: const Text('移除'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _miniPick(
                '資產類別',
                assetClassLabel(position.assetClass),
                Key('opening-asset-$index'),
                () => _pickAsset(position),
              ),
              const SizedBox(width: 8),
              _miniPick(
                '報價幣別',
                position.quoteCurrency,
                Key('opening-ccy-$index'),
                () => _pickQuote(position),
              ),
              const SizedBox(width: 8),
              _miniPick(
                '帳戶',
                accountName,
                Key('opening-account-$index'),
                () => _pickAccount(position),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _posField('數量', position.qty, Key('opening-qty-$index'))),
              const SizedBox(width: 8),
              Expanded(
                child: _posField(
                  '總成本 TWD',
                  position.cost,
                  Key('opening-cost-$index'),
                  enabled: !position.costUnknown,
                ),
              ),
            ],
          ),
          InkWell(
            key: Key('opening-unknown-$index'),
            onTap: () => setState(() {
              position.costUnknown = !position.costUnknown;
              if (position.costUnknown) position.cost.text = '0';
            }),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    position.costUnknown
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 18,
                    color: position.costUnknown
                        ? AppColors.expense
                        : AppColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '成本不確定',
                    style: TextStyle(
                      fontSize: 12,
                      color: position.costUnknown
                          ? AppColors.expense
                          : AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniPick(String label, String value, Key key, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.secondary),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posField(
    String label,
    TextEditingController controller,
    Key key, {
    bool enabled = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.secondary),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextField(
            key: key,
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: enabled ? const Color(0xE6FFFFFF) : const Color(0xFFF4F1EC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x1F3C3C43)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x1F3C3C43)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _accountName(String id) {
    for (final account in _accounts) {
      if (account.id == id) return account.name;
    }
    return '請選擇';
  }

  List<Widget> _preview() {
    final positions = _activePositions;
    return [
      _card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '開帳摘要',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            _sumRow('開帳日', _date),
            _sumRow('現金帳戶', '$_cashCount 戶 · ${formatNtd(_cashSum)}'),
            if (_debtCount > 0)
              _sumRow('信用卡', '$_debtCount 戶 · 欠 ${formatNtd(_debtSum)}'),
            _sumRow('現倉', '${positions.length} 檔 · 成本 ${formatNtd(_positionCost)}'),
            _sumRow('預覽淨資產', formatNtd(_previewNet), emphasize: true),
            if (_hasUnknown)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '有持倉成本未填',
                  key: Key('opening-unknown-flag'),
                  style: TextStyle(
                    color: AppColors.expense,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x1F8FB09F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x388FB09F)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: AppColors.sageDark),
              SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '確認數字無誤後儲存開帳。',
                    children: [
                      TextSpan(
                        text: '\n之後的記帳與分析會以此為起點。',
                        style: TextStyle(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.sageDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _sumRow(String label, String value, {bool emphasize = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x1A3C3C43))),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            key: emphasize ? const Key('opening-preview-net') : null,
            style: TextStyle(
              fontSize: emphasize ? 20 : 14,
              fontWeight: FontWeight.w700,
              letterSpacing: emphasize ? -0.5 : 0,
              color: emphasize ? AppColors.sageDark : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_step < 4) {
      return _Cta(label: _busy ? '請稍候…' : '下一步', onTap: _busy ? null : _next, buttonKey: const Key('opening-next'));
    }
    return Column(
      children: [
        _Cta(
          label: '返回修改',
          ghost: true,
          onTap: _busy
              ? null
              : () => setState(() {
                  _step = 1;
                  _error = null;
                }),
          buttonKey: const Key('opening-revise'),
        ),
        const SizedBox(height: 8),
        _Cta(
          label: _busy ? '請稍候…' : '儲存開帳',
          onTap: _busy ? null : _save,
          buttonKey: const Key('opening-save'),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xC7FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x08000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3C2814),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: child,
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0x248FB09F),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: AppColors.sageDark),
    );
  }

  IconData _accountIcon(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance_outlined;
      case 'credit_card':
        return Icons.credit_card_outlined;
      case 'broker':
        return Icons.candlestick_chart_outlined;
      case 'exchange':
        return Icons.public_outlined;
      default:
        return Icons.payments_outlined;
    }
  }
}

class _Cta extends StatelessWidget {
  const _Cta({
    required this.label,
    required this.onTap,
    required this.buttonKey,
    this.ghost = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Key buttonKey;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ghost ? const Color(0x248FB09F) : AppColors.sageDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: buttonKey,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ghost ? AppColors.sageDark : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.visible,
    required this.selected,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime visible;
  final String selected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final cells = _cells(visible.year, visible.month);
    final today = taipeiToday();
    return Column(
      children: [
        Row(
          children: [
            Text(
              '${visible.year} 年 ${visible.month} 月',
              key: const Key('opening-month'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            _monthButton(
              Icons.chevron_left_rounded,
              '上月',
              const Key('opening-month-prev'),
              onPrevious,
            ),
            const SizedBox(width: 6),
            _monthButton(
              Icons.chevron_right_rounded,
              '下月',
              const Key('opening-month-next'),
              onNext,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in ['日', '一', '二', '三', '四', '五', '六'])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (final cell in cells)
              cell.iso == null
                  ? Center(
                      child: Text(
                        '${cell.day}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFC7C7CC),
                        ),
                      ),
                    )
                  : _dayButton(
                      cell,
                      selected: cell.iso == selected,
                      today: cell.iso == today,
                      onSelect: onSelect,
                    ),
          ],
        ),
      ],
    );
  }

  Widget _monthButton(IconData icon, String tip, Key key, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: Material(
        color: const Color(0x248FB09F),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, size: 18, color: AppColors.sageDark),
          ),
        ),
      ),
    );
  }
}

class _DayCell {
  const _DayCell({required this.day, this.iso});

  final int day;
  final String? iso;
}

List<_DayCell> _cells(int year, int month) {
  final first = DateTime(year, month, 1);
  final lead = first.weekday % 7;
  final days = DateTime(year, month + 1, 0).day;
  final prevDays = DateTime(year, month, 0).day;
  final cells = <_DayCell>[
    for (var index = 0; index < lead; index++)
      _DayCell(day: prevDays - lead + 1 + index),
    for (var day = 1; day <= days; day++)
      _DayCell(day: day, iso: '$year-${pad2(month)}-${pad2(day)}'),
  ];
  var next = 1;
  while (cells.length % 7 != 0) {
    cells.add(_DayCell(day: next));
    next += 1;
  }
  return cells;
}

Widget _dayButton(
  _DayCell cell, {
  required bool selected,
  required bool today,
  required ValueChanged<String> onSelect,
}) {
  return Material(
    color: selected ? AppColors.sageDark : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      key: Key('opening-day-${cell.iso}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => onSelect(cell.iso!),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: today && !selected
              ? Border.all(color: const Color(0x735F8574), width: 1.5)
              : null,
        ),
        child: Center(
          child: Text(
            '${cell.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    ),
  );
}

class _NewAccountDialog extends StatefulWidget {
  const _NewAccountDialog();

  @override
  State<_NewAccountDialog> createState() => _NewAccountDialogState();
}

class _NewAccountDialogState extends State<_NewAccountDialog> {
  final _name = TextEditingController();
  String _type = 'cash';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增帳戶'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('opening-account-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: '名稱'),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            key: const Key('opening-account-type'),
            isExpanded: true,
            value: _type,
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('現金')),
              DropdownMenuItem(value: 'bank', child: Text('銀行活存')),
              DropdownMenuItem(value: 'credit_card', child: Text('信用卡')),
              DropdownMenuItem(value: 'broker', child: Text('券商')),
              DropdownMenuItem(value: 'exchange', child: Text('交易所／錢包')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _type = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          key: const Key('opening-account-ok'),
          onPressed: () => Navigator.pop(context, (_name.text.trim(), _type)),
          child: const Text('建立'),
        ),
      ],
    );
  }
}
