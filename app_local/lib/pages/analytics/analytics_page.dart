import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/soft_card.dart';
import 'package:go_router/go_router.dart';

enum TrendMode { expense, income, cash }

const _sliceColors = <Color>[
  Color(0xFF8FB09F),
  Color(0xFFB5CDBF),
  Color(0xFFD4C4B0),
  Color(0xFFA8B5A0),
  Color(0xFFC5C0B8),
  Color(0xFF5F8574),
  Color(0xFF8B1A3A),
  Color(0xFFC9B8A6),
];

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String? _bookId;
  int _generation = -1;
  String _month = yearMonthNow();
  TrendMode _mode = TrendMode.expense;
  bool _loading = false;
  String? _error;
  List<DailyPoint> _daily = [];
  List<CategoryAmount> _slices = [];
  List<Entry> _entries = [];
  String? _selectedCategory;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final books = BookScope.of(context);
    if (!books.ready) return;
    final id = books.current?.id;
    if (_bookId == id && _generation == books.generation) return;
    _bookId = id;
    _generation = books.generation;
    _month = yearMonthNow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final book = BookScope.of(context).current;
    if (book == null) {
      setState(() {
        _loading = false;
        _daily = [];
        _slices = [];
        _entries = [];
      });
      return;
    }
    setState(() {
      _loading = _daily.isEmpty && _slices.isEmpty;
      _error = null;
    });
    try {
      final today = taipeiToday();
      final opening = book.openingDate;
      late final String from;
      late final String to;
      if (_mode == TrendMode.cash) {
        from = (opening == null || opening.isEmpty) ? '$_month-01' : opening;
        to = today;
      } else {
        final start = '$_month-01';
        final end = _month == today.substring(0, 7) ? today : monthEnd(_month);
        if (opening != null && end.compareTo(opening) < 0) {
          if (!mounted) return;
          setState(() {
            _daily = [];
            _slices = [];
            _entries = [];
            _loading = false;
          });
          return;
        }
        from = opening != null && start.compareTo(opening) < 0 ? opening : start;
        to = end;
      }
      final api = BookScope.of(context).api;
      final daily = from.compareTo(to) > 0
          ? <DailyPoint>[]
          : await api.statsDaily(bookId: book.id, from: from, to: to);
      final slices = await api.statsByCategory(bookId: book.id, month: _month);
      final entries = await api.listEntries(
        bookId: book.id,
        from: '$_month-01',
        to: monthEnd(_month),
      );
      if (!mounted) return;
      setState(() {
        _daily = daily;
        _slices = slices;
        _entries = entries;
        _loading = false;
        if (_selectedCategory != null &&
            slices.every((slice) => slice.categoryId != _selectedCategory)) {
          _selectedCategory = null;
        }
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

  void _setMode(TrendMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _load();
  }

  void _shiftMonth(int delta) {
    final next = shiftMonth(_month, delta);
    final todayMonth = taipeiToday().substring(0, 7);
    if (next.compareTo(todayMonth) > 0) return;
    final opening = BookScope.of(context).current?.openingDate;
    if (opening != null && monthEnd(next).compareTo(opening) < 0) return;
    setState(() => _month = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final books = BookScope.of(context);
    final text = Theme.of(context).textTheme;
    final monthLabel = _month == taipeiToday().substring(0, 7) ? '本月' : _monthLabel();
    final emptySpend = _slices.isEmpty && _mode == TrendMode.expense;
    return PageScroll(
      onRefresh: _load,
      children: [
        Row(
          children: [
            Text('分析', style: text.titleLarge),
            const Spacer(),
            _MonthPill(
              label: monthLabel,
              onPrev: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!books.ready || (books.current != null && _loading && _daily.isEmpty))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sage),
            ),
          )
        else if (books.current == null)
          const SoftCard(
            child: Text('請先建立帳本', key: Key('analytics-empty-book')),
          )
        else ...[
          if (!emptySpend || _mode != TrendMode.expense || _daily.isNotEmpty)
            _TrendCard(
              mode: _mode,
              monthLabel: _monthLabel(),
              daily: _daily,
              onMode: _setMode,
            ),
          if (_slices.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PieCard(
              slices: _slices,
              selected: _selectedCategory,
              onSelect: (id) {
                setState(() {
                  _selectedCategory = _selectedCategory == id ? null : id;
                });
              },
            ),
          ],
          if (_selectedCategory != null) ...[
            const SizedBox(height: 8),
            _CategoryEntries(
              entries: _entries
                  .where((entry) => entry.categoryId == _selectedCategory)
                  .toList(),
            ),
          ],
          if (emptySpend && _daily.every((point) => point.expense == 0)) ...[
            const SizedBox(height: 8),
            const _EmptySpend(),
          ],
        ],
        ErrorLine(_error, lineKey: const Key('analytics-error')),
      ],
    );
  }

  String _monthLabel() {
    final parts = _month.split('-');
    if (parts.length < 2) return _month;
    return '${parts[0]} 年 ${int.tryParse(parts[1]) ?? parts[1]} 月';
  }
}

class _MonthPill extends StatelessWidget {
  const _MonthPill({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB8FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x0A000000)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('month-prev'),
            tooltip: '上個月',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            label,
            key: const Key('analytics-month'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          IconButton(
            key: const Key('month-next'),
            tooltip: '下個月',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.mode,
    required this.monthLabel,
    required this.daily,
    required this.onMode,
  });

  final TrendMode mode;
  final String monthLabel;
  final List<DailyPoint> daily;
  final ValueChanged<TrendMode> onMode;

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      TrendMode.expense => '支出趨勢',
      TrendMode.income => '收入趨勢',
      TrendMode.cash => '現金淨資產',
    };
    final subtitle = switch (mode) {
      TrendMode.expense => '$monthLabel · 日支出',
      TrendMode.income => '$monthLabel · 日收入',
      TrendMode.cash => '不含持倉 · 帳戶現金／負債走勢',
    };
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                key: const Key('trend-title'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _Pills(mode: mode, onMode: onMode),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            key: const Key('trend-subtitle'),
            style: const TextStyle(fontSize: 11, color: AppColors.secondary),
          ),
          const SizedBox(height: 8),
          SizedBox(height: 120, child: _Line(mode: mode, daily: daily)),
        ],
      ),
    );
  }
}

class _Pills extends StatelessWidget {
  const _Pills({required this.mode, required this.onMode});

  final TrendMode mode;
  final ValueChanged<TrendMode> onMode;

  @override
  Widget build(BuildContext context) {
    Widget pill(TrendMode value, String label, Key key) {
      final on = mode == value;
      return InkWell(
        key: key,
        borderRadius: BorderRadius.circular(6),
        onTap: () => onMode(value),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: on
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: on ? AppColors.ink : AppColors.secondary,
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x1E767680),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            pill(TrendMode.expense, '支出', const Key('trend-expense')),
            pill(TrendMode.income, '收入', const Key('trend-income')),
            pill(TrendMode.cash, '現金淨資產', const Key('trend-cash')),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.mode, required this.daily});

  final TrendMode mode;
  final List<DailyPoint> daily;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return const Center(
        child: Text(
          '這個區間沒有資料',
          style: TextStyle(fontSize: 12, color: AppColors.secondary),
        ),
      );
    }
    final spots = <FlSpot>[];
    final labels = <String>[];
    for (var i = 0; i < daily.length; i++) {
      final point = daily[i];
      final value = switch (mode) {
        TrendMode.expense => point.expense,
        TrendMode.income => point.income,
        TrendMode.cash => point.cashNet,
      };
      spots.add(FlSpot(i.toDouble(), value.toDouble()));
      final day = point.date.length >= 10 ? point.date.substring(8) : '${i + 1}';
      labels.add(day.startsWith('0') ? day.substring(1) : day);
    }
    var minY = 0.0;
    var maxY = 1.0;
    for (final spot in spots) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }
    if (minY > 0 && mode != TrendMode.cash) minY = 0;
    if (maxY == minY) maxY = minY + 1;
    final interval = (labels.length / 6).clamp(1, 31).toDouble();
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: spots.length <= 1 ? 1 : (spots.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 3,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0x143C3C43),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: interval,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                if ((value - index).abs() > 0.01) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    labels[index],
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFAEAEB2),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: spots.length > 2,
            preventCurveOverShooting: true,
            color: AppColors.sage,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.sage.withValues(alpha: 0.28),
            ),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

class _PieCard extends StatelessWidget {
  const _PieCard({
    required this.slices,
    required this.selected,
    required this.onSelect,
  });

  final List<CategoryAmount> slices;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.amount);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '分類佔比',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          const Text(
            '本月支出構成',
            style: TextStyle(fontSize: 11, color: AppColors.secondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        centerSpaceRadius: 32,
                        sectionsSpace: 2,
                        sections: [
                          for (var i = 0; i < slices.length; i++)
                            PieChartSectionData(
                              value: slices[i].amount.toDouble(),
                              color: _sliceColors[i % _sliceColors.length],
                              radius: 16,
                              showTitle: false,
                            ),
                        ],
                      ),
                      duration: Duration.zero,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '總計',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          formatCompact(total),
                          key: const Key('pie-total'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < slices.length; i++)
                      InkWell(
                        key: Key('slice-${slices[i].categoryId}'),
                        onTap: () => onSelect(slices[i].categoryId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: _sliceColors[i % _sliceColors.length],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  slices[i].name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected == slices[i].categoryId
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${_percent(slices[i].amount, total)} · ${formatNtd(slices[i].amount)}',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _percent(int amount, int total) {
    if (total <= 0) return '0%';
    return '${(amount * 100 / total).round()}%';
  }
}

class _CategoryEntries extends StatelessWidget {
  const _CategoryEntries({required this.entries});

  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '這個分類',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '這個月沒有這類流水',
                style: TextStyle(fontSize: 12, color: AppColors.secondary),
              ),
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.note.isEmpty ? entry.date : '${entry.date} · ${entry.note}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '−${formatGrouped(entry.amount)}',
                      style: const TextStyle(
                        color: AppColors.expense,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _EmptySpend extends StatelessWidget {
  const _EmptySpend();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0x1F8FB09F),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.sage,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '這個月還沒有支出',
            key: Key('analytics-empty'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            '記下一筆後，趨勢與分類圖就會出現在這裡',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.secondary),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('analytics-record'),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.sage,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            onPressed: () => context.push('/record'),
            child: const Text('記一筆'),
          ),
        ],
      ),
    );
  }
}
