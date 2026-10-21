import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:full_jizhang/format.dart';

// Apple Pay shortcut URL → one import draft.
//
// Shortcuts Wallet "Transaction" automation opens
// fulljizhang://add?amount=&merchant=&time=&card=&card_last4=&category=&note=&id=
// Nothing here writes to SQLite. The preview sheet saves only after the
// user confirms. Dedup identity is decided here so the preview and the
// stored key use the same bytes.

/// Template the settings page copies into the Shortcuts "Open URL" action.
const applePayUrlTemplate =
    'fulljizhang://add?amount=&merchant=&time=&card=&card_last4=&category=&note=&id=';

/// One parsed shortcut payload, before the book is consulted.
///
/// [importKey] is the `id` param when present, otherwise the sha256 described
/// in [applePayImportKey]. [amount] is null when the param is missing or not
/// a positive number — the row is shown but cannot be ticked. [date] is the
/// Asia/Taipei calendar day. A missing or unreadable [time] falls back to
/// [clock] and sets [timeWasFallback]; the hash still uses the raw time
/// text, so two opens of the same URL share a key even if "now" moved.
class ApplePayDraft {
  const ApplePayDraft({
    required this.importKey,
    required this.amount,
    required this.merchant,
    required this.card,
    required this.cardLast4,
    required this.categoryName,
    required this.note,
    required this.occurredAt,
    required this.date,
    required this.timeWasFallback,
  });

  final String importKey;
  final int? amount;
  final String merchant;
  final String card;
  final String cardLast4;
  final String categoryName;
  final String note;
  final DateTime occurredAt;
  final String date;
  final bool timeWasFallback;

  /// Ledger note: merchant, then the user's note when both are present.
  String get entryNote {
    if (merchant.isEmpty) return note;
    if (note.isEmpty || note == merchant) return merchant;
    return '$merchant · $note';
  }

  String get cardLabel {
    if (card.isNotEmpty) return card;
    if (cardLast4.isNotEmpty) return cardLast4;
    return '卡片';
  }
}

/// One row in the import preview, after book rules are applied.
///
/// [beforeOpening] means the Taipei day is strictly earlier than the book's
/// opening date. Those rows cannot be ticked; the sheet says
/// 「不能記開帳日之前的帳」. [duplicate] means [importKey] is already stored
/// for this book. Duplicates start unticked and are badged 重複. The user
/// may still tick one; confirm then writes another entry and leaves the key.
/// [initiallyTicked] is the only default. Nothing is selected because a
/// link arrived.
class ImportLine {
  const ImportLine({
    required this.importKey,
    required this.amount,
    required this.merchant,
    required this.cardLabel,
    required this.cardLast4,
    required this.note,
    required this.occurredAt,
    required this.date,
    required this.duplicate,
    required this.beforeOpening,
    this.categoryId,
    this.accountId,
  });

  final String importKey;
  final int? amount;
  final String merchant;
  final String cardLabel;
  final String cardLast4;
  final String note;
  final DateTime occurredAt;
  final String date;
  final bool duplicate;
  final bool beforeOpening;
  final String? categoryId;
  final String? accountId;

  /// Opening-date rows and rows with no positive amount stay disabled.
  bool get canTick => !beforeOpening && amount != null && amount! > 0;

  /// Fresh, valid rows start ticked. Duplicates and blocked rows do not.
  bool get initiallyTicked => canTick && !duplicate;

  String get merchantLabel => merchant.isEmpty ? '（無商家）' : merchant;

  String get stamp => formatImportClock(occurredAt);
}

/// Fields the user confirmed. Written only by [LocalApi.confirmApplePay].
class ImportCommit {
  const ImportCommit({
    required this.importKey,
    required this.amount,
    required this.date,
    required this.accountId,
    required this.categoryId,
    required this.note,
    required this.merchant,
    required this.cardLast4,
  });

  final String importKey;
  final int amount;
  final String date;
  final String accountId;
  final String categoryId;
  final String note;
  final String merchant;
  final String cardLast4;
}

/// True for fulljizhang://add and fulljizhang:///add. Other hosts are ignored.
bool isApplePayAddLink(Uri uri) {
  if (uri.scheme.toLowerCase() != 'fulljizhang') return false;
  final host = uri.host.toLowerCase();
  final path = uri.path;
  return host == 'add' || path == '/add' || path == 'add';
}

/// Hex sha256, or the trimmed `id` when that param is non-empty.
///
/// The hashed payload is the four raw trimmed strings joined by U+001F
/// (unit separator), not the parsed amount and not the fallback clock.
/// Currency symbols and commas therefore stay in the key: "185" and
/// "NT$185" are different charges unless Shortcuts also sends the same `id`.
String applePayImportKey({
  required String id,
  required String amount,
  required String merchant,
  required String time,
  required String cardLast4,
}) {
  final trimmedId = id.trim();
  if (trimmedId.isNotEmpty) return trimmedId;
  final payload = [
    amount.trim(),
    merchant.trim(),
    time.trim(),
    cardLast4.trim(),
  ].join('\u001f');
  return sha256.convert(utf8.encode(payload)).toString();
}

/// Parses a shortcut URL. Returns null when the scheme or host is not ours.
///
/// Missing query fields become empty. [clock] is used only when `time` is
/// empty or not a format we recognize (ISO-8601, `yyyy-MM-dd HH:mm`,
/// `yyyy/MM/dd`, `M/d/yyyy h:mm a`, `yyyy年M月d日`, English month names).
/// Zoned timestamps are converted to Asia/Taipei. Zoneless wall times are
/// read as Taipei, which is the book's zone.
ApplePayDraft? parseApplePayUri(Uri uri, {DateTime? clock}) {
  if (!isApplePayAddLink(uri)) return null;
  final query = _rawQuery(uri);
  final amountRaw = query['amount'] ?? '';
  final merchant = (query['merchant'] ?? '').trim();
  final timeRaw = query['time'] ?? '';
  final card = (query['card'] ?? '').trim();
  final cardLast4Raw = query['card_last4'] ?? '';
  final categoryName = (query['category'] ?? '').trim();
  final note = (query['note'] ?? '').trim();
  final id = query['id'] ?? '';

  final parsedTime = parseImportTime(timeRaw);
  final timeWasFallback = parsedTime == null;
  final occurredAt = parsedTime ?? (clock ?? DateTime.now()).toUtc();
  final last4 = _mappingLast4(cardLast4Raw, card);

  return ApplePayDraft(
    importKey: applePayImportKey(
      id: id,
      amount: amountRaw,
      merchant: merchant,
      time: timeRaw,
      cardLast4: cardLast4Raw,
    ),
    amount: parseImportAmount(amountRaw),
    merchant: merchant,
    card: card,
    cardLast4: last4,
    categoryName: categoryName,
    note: note,
    occurredAt: occurredAt,
    date: taipeiToday(occurredAt),
    timeWasFallback: timeWasFallback,
  );
}

/// Positive TWD integer. Currency symbols, spaces, and thousands commas are
/// stripped. A leading minus (a charge) is dropped so the expense amount
/// stays positive, matching `entries.amount`. Decimals round half away from
/// zero. Zero, blank, and non-numeric text return null.
int? parseImportAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll(
    RegExp(
      r'(NT\$|US\$|HK\$|NTD|TWD|USD|JPY|RMB|CNY|元|圓)',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceAll(RegExp(r'[$¥￥€£]'), '');
  s = s.replaceAll(RegExp(r'[\s\u00A0,，]'), '');
  if (s.startsWith('+')) s = s.substring(1);
  if (s.startsWith('-') || s.startsWith('−')) s = s.substring(1);
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) return null;
  final whole = roundDecimal(s);
  if (whole <= 0) return null;
  return whole;
}

/// Taipei wall-clock `M/d HH:mm` for the preview subtitle.
String formatImportClock(DateTime instant) {
  final time = taipeiNow(instant);
  return '${time.month}/${time.day} ${pad2(time.hour)}:${pad2(time.minute)}';
}

/// Recognized shortcut date strings as a UTC instant. Null if none match.
DateTime? parseImportTime(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  final zoned = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})$',
  ).firstMatch(s);
  if (zoned != null) {
    final wall = DateTime.utc(
      int.parse(zoned[1]!),
      int.parse(zoned[2]!),
      int.parse(zoned[3]!),
      int.parse(zoned[4]!),
      int.parse(zoned[5]!),
      int.parse(zoned[6] ?? '0'),
    );
    return wall.subtract(Duration(minutes: _offsetMinutes(zoned[7]!)));
  }

  final zh = RegExp(
    r'^(\d{4})年(\d{1,2})月(\d{1,2})日(?:\s*(上午|下午)?(\d{1,2})[:：](\d{2})(?:[:：](\d{2}))?)?$',
  ).firstMatch(s);
  if (zh != null) {
    final hour = zh[5] == null
        ? 0
        : _hour12(int.parse(zh[5]!), zh[4]);
    return _taipeiWall(
      int.parse(zh[1]!),
      int.parse(zh[2]!),
      int.parse(zh[3]!),
      hour,
      int.parse(zh[6] ?? '0'),
      int.parse(zh[7] ?? '0'),
    );
  }

  final zhSlash = RegExp(
    r'^(\d{4})/(\d{1,2})/(\d{1,2})\s+(上午|下午)(\d{1,2}):(\d{2})(?::(\d{2}))?$',
  ).firstMatch(s);
  if (zhSlash != null) {
    return _taipeiWall(
      int.parse(zhSlash[1]!),
      int.parse(zhSlash[2]!),
      int.parse(zhSlash[3]!),
      _hour12(int.parse(zhSlash[5]!), zhSlash[4]),
      int.parse(zhSlash[6]!),
      int.parse(zhSlash[7] ?? '0'),
    );
  }

  final us = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4}),?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])$',
  ).firstMatch(s);
  if (us != null) {
    final first = int.parse(us[1]!);
    final second = int.parse(us[2]!);
    // Month/day when the first number can be a month. Day/month otherwise.
    final month = first > 12 ? second : first;
    final day = first > 12 ? first : second;
    return _taipeiWall(
      int.parse(us[3]!),
      month,
      day,
      _hour12(int.parse(us[4]!), us[7]),
      int.parse(us[5]!),
      int.parse(us[6] ?? '0'),
    );
  }

  final en = RegExp(
    r'^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})(?:\s+at)?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])$',
  ).firstMatch(s);
  if (en != null) {
    final month = _englishMonth(en[1]!);
    if (month != null) {
      return _taipeiWall(
        int.parse(en[3]!),
        month,
        int.parse(en[2]!),
        _hour12(int.parse(en[4]!), en[7]),
        int.parse(en[5]!),
        int.parse(en[6] ?? '0'),
      );
    }
  }

  final dmy = RegExp(
    r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
  ).firstMatch(s);
  if (dmy != null) {
    final month = _englishMonth(dmy[2]!);
    if (month != null) {
      return _taipeiWall(
        int.parse(dmy[3]!),
        month,
        int.parse(dmy[1]!),
        int.parse(dmy[4] ?? '0'),
        int.parse(dmy[5] ?? '0'),
        int.parse(dmy[6] ?? '0'),
      );
    }
  }

  final local = RegExp(
    r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[T ](\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
  ).firstMatch(s);
  if (local != null) {
    return _taipeiWall(
      int.parse(local[1]!),
      int.parse(local[2]!),
      int.parse(local[3]!),
      int.parse(local[4] ?? '0'),
      int.parse(local[5] ?? '0'),
      int.parse(local[6] ?? '0'),
    );
  }
  return null;
}

/// Query map that keeps `+` as plus. `Uri.queryParameters` would turn the
/// offset in `2026-10-21T08:42:00+08:00` into a space.
Map<String, String> _rawQuery(Uri uri) {
  final out = <String, String>{};
  if (uri.query.isEmpty) return out;
  for (final part in uri.query.split('&')) {
    if (part.isEmpty) continue;
    final eq = part.indexOf('=');
    final key = eq < 0 ? part : part.substring(0, eq);
    final value = eq < 0 ? '' : part.substring(eq + 1);
    out[_keepPlus(key)] = _keepPlus(value);
  }
  return out;
}

String _keepPlus(String raw) =>
    Uri.decodeComponent(raw.replaceAll('+', '%2B'));

/// Last 4 digits for the mapping table. The hash does not use this.
String _mappingLast4(String cardLast4, String card) {
  final fromParam = _lastDigits(cardLast4);
  if (fromParam.isNotEmpty) return fromParam;
  return _lastDigits(card);
}

String _lastDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length <= 4) return digits;
  return digits.substring(digits.length - 4);
}

int _offsetMinutes(String zone) {
  if (zone == 'Z') return 0;
  final match = RegExp(r'^([+-])(\d{2}):?(\d{2})$').firstMatch(zone);
  if (match == null) return 0;
  final sign = match[1] == '-' ? -1 : 1;
  return sign * (int.parse(match[2]!) * 60 + int.parse(match[3]!));
}

int _hour12(int hour, String? ampm) {
  if (ampm == null || ampm.isEmpty) return hour;
  final lower = ampm.toLowerCase();
  final pm = lower == 'pm' || ampm == '下午';
  final am = lower == 'am' || ampm == '上午';
  if (pm && hour < 12) return hour + 12;
  if (am && hour == 12) return 0;
  return hour;
}

DateTime _taipeiWall(int year, int month, int day, int hour, int minute, int second) {
  return DateTime.utc(year, month, day, hour, minute, second)
      .subtract(const Duration(hours: 8));
}

int? _englishMonth(String name) {
  const months = {
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };
  return months[name.toLowerCase()];
}
