import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/soft_card.dart';

const _accountTypes = ['cash', 'bank', 'credit_card', 'broker', 'exchange'];

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  String? _bookId;
  int _generation = -1;
  bool _loading = false;
  bool _showClosed = false;
  String? _error;
  StatsSummary? _summary;
  List<Account> _accounts = [];
  List<Position> _positions = [];

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
    final book = BookScope.of(context).current;
    if (book == null) {
      setState(() {
        _loading = false;
        _accounts = [];
        _positions = [];
        _summary = null;
      });
      return;
    }
    setState(() {
      _loading = _summary == null;
      _error = null;
    });
    try {
      final api = BookScope.of(context).api;
      if (refreshQuotes) {
        final refresh = await api.refreshQuotes(book.id);
        if (refresh.quoteFailed && refresh.message.isNotEmpty) {
          _error = refresh.message;
        }
      }
      final results = await Future.wait<Object>([
        api.statsSummary(bookId: book.id),
        api.listAccounts(book.id),
        api.listPositions(book.id),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as StatsSummary;
        _accounts = results[1] as List<Account>;
        _positions = results[2] as List<Position>;
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

  Future<void> _addAccount() async {
    final book = BookScope.of(context).current;
    if (book == null) return;
    final created = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _NewAccountDialog(),
    );
    if (created == null || !mounted) return;
    final (accountName, type) = created;
    if (accountName.isEmpty) {
      setState(() => _error = '請填帳戶名稱');
      return;
    }
    final api = BookScope.of(context).api;
    final books = BookScope.of(context);
    try {
      await api.createAccount(bookId: book.id, name: accountName, type: type);
      if (!mounted) return;
      books.touch();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = BookScope.of(context);
    final text = Theme.of(context).textTheme;
    final live = _accounts.where((account) => !account.archived).toList();
    final open = _positions.where((position) => !position.closed).toList();
    final closed = _positions.where((position) => position.closed).toList();
    final shown = _showClosed ? _positions : open;
    final hasCard = live.any((account) => account.type == 'credit_card');
    final change = _summary?.netWorthChangeVsOpening ?? 0;
    return PageScroll(
      onRefresh: () => _load(refreshQuotes: true),
      children: [
        Row(
          children: [
            Text('資產', style: text.titleLarge),
            const Spacer(),
            IconButton(
              key: const Key('assets-refresh'),
              tooltip: '更新報價',
              onPressed: books.current == null
                  ? null
                  : () => _load(refreshQuotes: true),
              icon: const Icon(Icons.refresh_rounded, color: AppColors.sageDark),
            ),
          ],
        ),
        if (!books.ready || (_loading && _summary == null && books.current != null))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sage),
            ),
          )
        else if (books.current == null)
          const SoftCard(child: Text('請先建立帳本', key: Key('assets-empty-book')))
        else ...[
          SoftCard(
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
                  formatNtd(_summary?.netWorth ?? 0),
                  key: const Key('assets-net'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDelta(change),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: change < 0 ? AppColors.expense : AppColors.up,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SoftCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      '帳戶',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      key: const Key('assets-add-account'),
                      onPressed: _addAccount,
                      child: const Text('管理'),
                    ),
                  ],
                ),
                if (live.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '還沒有帳戶',
                      key: Key('assets-no-accounts'),
                      style: TextStyle(fontSize: 13, color: AppColors.secondary),
                    ),
                  )
                else
                  for (var i = 0; i < live.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Color(0x1A3C3C43)),
                    _AccountRow(account: live[i]),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SoftCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      '持倉',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (closed.isNotEmpty)
                      TextButton(
                        key: const Key('assets-closed'),
                        onPressed: () => setState(() => _showClosed = !_showClosed),
                        child: Text(_showClosed ? '隱藏已平倉' : '全部'),
                      ),
                  ],
                ),
                if (shown.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '還沒有持倉',
                      key: Key('assets-no-positions'),
                      style: TextStyle(fontSize: 13, color: AppColors.secondary),
                    ),
                  )
                else
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Color(0x1A3C3C43)),
                    _PositionRow(position: shown[i]),
                  ],
              ],
            ),
          ),
          if (live.isNotEmpty && !hasCard) ...[
            const SizedBox(height: 8),
            const SoftCard(
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.sage,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '還沒有負債帳戶',
                          key: Key('assets-no-debt'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '新增信用卡後，淨資產會自動扣除',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        ErrorLine(_error, lineKey: const Key('assets-error')),
      ],
    );
  }
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
            key: const Key('account-name-field'),
            controller: _name,
            decoration: const InputDecoration(labelText: '名稱'),
          ),
          const SizedBox(height: 12),
          DropdownButton<String>(
            key: const Key('account-type-field'),
            isExpanded: true,
            value: _type,
            items: [
              for (final item in _accountTypes)
                DropdownMenuItem(
                  value: item,
                  child: Text(accountTypeLabel(item)),
                ),
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
          key: const Key('account-create'),
          onPressed: () => Navigator.pop(context, (_name.text.trim(), _type)),
          child: const Text('建立'),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final balance = account.type == 'credit_card'
        ? '欠 ${formatNtd(account.cashBalance)}'
        : formatNtd(account.cashBalance);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0x248FB09F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon(account.type), size: 18, color: AppColors.sageDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  key: Key('account-${account.id}'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  account.canHold && account.positionMv != null
                      ? '${accountTypeLabel(account.type)} · 持倉現值 ${formatNtd(account.positionMv!)}'
                      : accountTypeLabel(account.type),
                  style: const TextStyle(fontSize: 11, color: AppColors.secondary),
                ),
              ],
            ),
          ),
          Text(
            balance,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  IconData _icon(String type) {
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

class _PositionRow extends StatelessWidget {
  const _PositionRow({required this.position});

  final Position position;

  @override
  Widget build(BuildContext context) {
    final pct = formatPct(position.unrealizedPct);
    final pctValue = double.tryParse(position.unrealizedPct ?? '');
    final pctColor = pctValue == null
        ? AppColors.secondary
        : (pctValue < 0 ? AppColors.expense : AppColors.up);
    final value = position.marketValue == null
        ? '無現價'
        : formatNtd(position.marketValue!);
    final qty = _qtyLabel(position);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0x248FB09F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              size: 18,
              color: AppColors.sageDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  position.title,
                  key: Key('position-${position.id}'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  position.closed
                      ? '已平倉 · ${position.accountName}'
                      : '$qty · ${position.accountName}${position.costUnknown ? ' · 成本未填' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.secondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (pct.isNotEmpty)
                Text(
                  pct,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: pctColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _qtyLabel(Position position) {
    final value = double.tryParse(position.qty);
    final text = value == null
        ? position.qty
        : (value == value.roundToDouble()
              ? value.toStringAsFixed(0)
              : value.toString());
    if (position.assetClass == 'tw_stock' || position.assetClass == 'us_stock') {
      return '$text 股';
    }
    return text;
  }
}
