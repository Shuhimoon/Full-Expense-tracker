int jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? jsonIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

String jsonStr(Object? value) => value?.toString() ?? '';

String? jsonDate(Object? value) {
  if (value == null) return null;
  final raw = value.toString();
  if (raw.isEmpty || raw == 'null') return null;
  return raw.length >= 10 ? raw.substring(0, 10) : raw;
}

Map<String, dynamic> asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('expected object');
}

class Book {
  const Book({
    required this.id,
    required this.name,
    required this.archivedAt,
    required this.baseCurrency,
    required this.openingDate,
    required this.timezone,
    required this.costMethod,
    required this.version,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? archivedAt;
  final String baseCurrency;
  final String? openingDate;
  final String timezone;
  final String costMethod;
  final int version;
  final String createdAt;

  bool get archived => archivedAt != null && archivedAt!.isNotEmpty;

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: jsonStr(json['id']),
      name: jsonStr(json['name']),
      archivedAt: json['archived_at']?.toString(),
      baseCurrency: jsonStr(json['base_currency']).isEmpty
          ? 'TWD'
          : jsonStr(json['base_currency']),
      openingDate: jsonDate(json['opening_date']),
      timezone: jsonStr(json['timezone']).isEmpty
          ? 'Asia/Taipei'
          : jsonStr(json['timezone']),
      costMethod: jsonStr(json['cost_method']).isEmpty
          ? 'avg'
          : jsonStr(json['cost_method']),
      version: jsonInt(json['version']),
      createdAt: jsonStr(json['created_at']),
    );
  }
}

class Account {
  const Account({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    required this.archivedAt,
    required this.version,
    required this.cashBalance,
    required this.positionMv,
  });

  final String id;
  final String bookId;
  final String name;
  final String type;
  final String? archivedAt;
  final int version;
  final int cashBalance;
  final int? positionMv;

  bool get archived => archivedAt != null && archivedAt!.isNotEmpty;

  bool get canHold => type == 'broker' || type == 'exchange';

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: jsonStr(json['id']),
      bookId: jsonStr(json['book_id']),
      name: jsonStr(json['name']),
      type: jsonStr(json['type']),
      archivedAt: json['archived_at']?.toString(),
      version: jsonInt(json['version']),
      cashBalance: jsonInt(json['cash_balance']),
      positionMv: jsonIntOrNull(json['position_mv']),
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.bookId,
    required this.name,
    required this.kind,
    required this.isSystem,
    required this.archivedAt,
    required this.sort,
    required this.version,
  });

  final String id;
  final String bookId;
  final String name;
  final String kind;
  final bool isSystem;
  final String? archivedAt;
  final int sort;
  final int version;

  bool get archived => archivedAt != null && archivedAt!.isNotEmpty;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: jsonStr(json['id']),
      bookId: jsonStr(json['book_id']),
      name: jsonStr(json['name']),
      kind: jsonStr(json['kind']),
      isSystem: json['is_system'] == true,
      archivedAt: json['archived_at']?.toString(),
      sort: jsonInt(json['sort']),
      version: jsonInt(json['version']),
    );
  }
}

class Entry {
  const Entry({
    required this.id,
    required this.bookId,
    required this.date,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.toAccountId,
    required this.categoryId,
    required this.note,
    required this.createdAt,
    required this.version,
  });

  final String id;
  final String bookId;
  final String date;
  final String type;
  final int amount;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String note;
  final String createdAt;
  final int version;

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: jsonStr(json['id']),
      bookId: jsonStr(json['book_id']),
      date: jsonDate(json['date']) ?? '',
      type: jsonStr(json['type']),
      amount: jsonInt(json['amount']),
      accountId: jsonStr(json['account_id']),
      toAccountId: json['to_account_id']?.toString(),
      categoryId: json['category_id']?.toString(),
      note: jsonStr(json['note']),
      createdAt: jsonStr(json['created_at']),
      version: jsonInt(json['version']),
    );
  }
}

class StatsSummary {
  const StatsSummary({
    required this.todayExpense,
    required this.monthExpense,
    required this.monthIncome,
    required this.netWorth,
    required this.netWorthChangeVsOpening,
    required this.cashNet,
    required this.positionMv,
    required this.unrealized,
    required this.quoteAsOf,
    required this.somePositionsUnquoted,
    required this.today,
    required this.month,
  });

  final int todayExpense;
  final int monthExpense;
  final int monthIncome;
  final int netWorth;
  final int netWorthChangeVsOpening;
  final int cashNet;
  final int positionMv;
  final int unrealized;
  final String? quoteAsOf;
  final bool somePositionsUnquoted;
  final String today;
  final String month;

  factory StatsSummary.zero({required String today}) {
    return StatsSummary(
      todayExpense: 0,
      monthExpense: 0,
      monthIncome: 0,
      netWorth: 0,
      netWorthChangeVsOpening: 0,
      cashNet: 0,
      positionMv: 0,
      unrealized: 0,
      quoteAsOf: null,
      somePositionsUnquoted: false,
      today: today,
      month: today.length >= 7 ? today.substring(0, 7) : today,
    );
  }

  factory StatsSummary.fromJson(Map<String, dynamic> json) {
    return StatsSummary(
      todayExpense: jsonInt(json['today_expense']),
      monthExpense: jsonInt(json['month_expense']),
      monthIncome: jsonInt(json['month_income']),
      netWorth: jsonInt(json['net_worth']),
      netWorthChangeVsOpening: jsonInt(json['net_worth_change_vs_opening']),
      cashNet: jsonInt(json['cash_net']),
      positionMv: jsonInt(json['position_mv']),
      unrealized: jsonInt(json['unrealized']),
      quoteAsOf: json['quote_as_of']?.toString(),
      somePositionsUnquoted: json['some_positions_unquoted'] == true,
      today: jsonStr(json['today']),
      month: jsonStr(json['month']),
    );
  }
}

class DailyPoint {
  const DailyPoint({
    required this.date,
    required this.expense,
    required this.income,
    required this.cashNet,
  });

  final String date;
  final int expense;
  final int income;
  final int cashNet;

  factory DailyPoint.fromJson(Map<String, dynamic> json) {
    return DailyPoint(
      date: jsonDate(json['date']) ?? '',
      expense: jsonInt(json['expense']),
      income: jsonInt(json['income']),
      cashNet: jsonInt(json['cash_net']),
    );
  }
}

class CategoryAmount {
  const CategoryAmount({
    required this.categoryId,
    required this.name,
    required this.amount,
  });

  final String categoryId;
  final String name;
  final int amount;

  factory CategoryAmount.fromJson(Map<String, dynamic> json) {
    return CategoryAmount(
      categoryId: jsonStr(json['category_id']),
      name: jsonStr(json['name']),
      amount: jsonInt(json['amount']),
    );
  }
}

class Position {
  const Position({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.symbol,
    required this.name,
    required this.assetClass,
    required this.qty,
    required this.costTwd,
    required this.realizedTwd,
    required this.costUnknown,
    required this.marketValue,
    required this.unrealized,
    required this.unrealizedPct,
    required this.quoteAsOf,
    required this.closed,
  });

  final String id;
  final String accountId;
  final String accountName;
  final String symbol;
  final String name;
  final String assetClass;
  final String qty;
  final String costTwd;
  final int realizedTwd;
  final bool costUnknown;
  final int? marketValue;
  final int? unrealized;
  final String? unrealizedPct;
  final String? quoteAsOf;
  final bool closed;

  String get title {
    final label = name.trim();
    if (label.isEmpty || label == symbol) return symbol;
    return '$label $symbol';
  }

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: jsonStr(json['id']),
      accountId: jsonStr(json['account_id']),
      accountName: jsonStr(json['account_name']),
      symbol: jsonStr(json['symbol']),
      name: jsonStr(json['name']),
      assetClass: jsonStr(json['asset_class']),
      qty: jsonStr(json['qty']),
      costTwd: jsonStr(json['cost_twd']),
      realizedTwd: jsonInt(json['realized_twd']),
      costUnknown: json['cost_unknown'] == true,
      marketValue: jsonIntOrNull(json['market_value']),
      unrealized: jsonIntOrNull(json['unrealized']),
      unrealizedPct: json['unrealized_pct']?.toString(),
      quoteAsOf: json['quote_as_of']?.toString(),
      closed: json['closed'] == true,
    );
  }
}

class QuoteRefresh {
  const QuoteRefresh({
    required this.updated,
    required this.failed,
    required this.message,
    required this.quoteFailed,
  });

  final int updated;
  final List<String> failed;
  final String message;
  final bool quoteFailed;

  factory QuoteRefresh.fromJson(Map<String, dynamic> json) {
    final failed = <String>[];
    final raw = json['failed'];
    if (raw is List) {
      for (final item in raw) {
        failed.add(item.toString());
      }
    }
    return QuoteRefresh(
      updated: jsonInt(json['updated']),
      failed: failed,
      message: jsonStr(json['message']),
      quoteFailed: json['quote_failed'] == true,
    );
  }
}
