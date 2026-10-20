import 'dart:math';

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

String pad2(int value) => value.toString().padLeft(2, '0');

/// Clock fields of this value are Asia/Taipei, regardless of the device zone.
DateTime taipeiNow([DateTime? clock]) {
  final utc = (clock ?? DateTime.now()).toUtc();
  return utc.add(const Duration(hours: 8));
}

String taipeiToday([DateTime? clock]) {
  final time = taipeiNow(clock);
  return '${time.year}-${pad2(time.month)}-${pad2(time.day)}';
}

String yearMonthNow([DateTime? clock]) => taipeiToday(clock).substring(0, 7);

bool isIsoDate(String value) => _isoDate.hasMatch(value);

bool isBeforeOpening(String date, String? opening) {
  if (opening == null || opening.isEmpty) return false;
  return date.compareTo(opening) < 0;
}

String formatGrouped(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return value < 0 ? '−$buffer' : buffer.toString();
}

String formatNtd(int value) {
  final body = formatGrouped(value.abs());
  return value < 0 ? '−NT\$$body' : 'NT\$$body';
}

String formatSignedNtd(int value) {
  if (value > 0) return '+${formatNtd(value)}';
  if (value < 0) return '−${formatNtd(value.abs())}';
  return formatNtd(0);
}

String formatDelta(int value) {
  if (value > 0) return '↑ ${formatNtd(value)} · 自開帳日';
  if (value < 0) return '↓ ${formatNtd(value.abs())} · 自開帳日';
  return '與開帳日相同';
}

String formatQuoteClock(String? iso) {
  if (iso == null || iso.isEmpty) return '報價 —';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '報價 —';
  final time = parsed.toUtc().add(const Duration(hours: 8));
  return '報價 ${pad2(time.hour)}:${pad2(time.minute)}';
}

String formatDayHeading(String iso, String today) {
  if (iso == today) return '今天';
  final date = DateTime.tryParse(iso);
  final todayDate = DateTime.tryParse(today);
  if (date != null && todayDate != null) {
    final yesterday = DateTime(
      todayDate.year,
      todayDate.month,
      todayDate.day,
    ).subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return '昨天';
    }
    if (date.year != todayDate.year) return '${date.year}年${date.month}月${date.day}日';
    return '${date.month}月${date.day}日';
  }
  return iso;
}

String formatRecordDate(String iso, String today) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  final monthDay = '${date.month}/${date.day}';
  if (iso == today) return '今天 · $monthDay';
  return '${date.year}/$monthDay';
}

String formatCompact(int value) {
  final abs = value.abs();
  final String body;
  if (abs >= 1000) {
    final thousands = abs / 1000;
    body = thousands >= 100
        ? '${thousands.toStringAsFixed(0)}k'
        : '${thousands.toStringAsFixed(1)}k';
  } else {
    body = formatGrouped(abs);
  }
  return value < 0 ? '−$body' : body;
}

String formatPct(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final value = double.tryParse(raw);
  if (value == null) return raw;
  final abs = value.abs();
  final digits = abs >= 10 ? abs.toStringAsFixed(0) : abs.toStringAsFixed(1);
  if (value > 0) return '+$digits%';
  if (value < 0) return '−$digits%';
  return '0%';
}

String accountTypeLabel(String type) {
  switch (type) {
    case 'cash':
      return '現金';
    case 'bank':
      return '銀行活存';
    case 'credit_card':
      return '信用卡';
    case 'broker':
      return '券商';
    case 'exchange':
      return '交易所／錢包';
    default:
      return type;
  }
}

int? parseWholeAmount(String raw) {
  final cleaned = raw.replaceAll(',', '').replaceAll('，', '').trim();
  if (!RegExp(r'^\d+$').hasMatch(cleaned)) return null;
  return int.tryParse(cleaned);
}

String monthEnd(String yearMonth) {
  final parts = yearMonth.split('-');
  if (parts.length < 2) return '$yearMonth-28';
  final year = int.tryParse(parts[0]) ?? 2000;
  final month = int.tryParse(parts[1]) ?? 1;
  final last = DateTime(year, month + 1, 0).day;
  return '$yearMonth-${pad2(last)}';
}

String shiftMonth(String yearMonth, int delta) {
  final parts = yearMonth.split('-');
  var year = int.tryParse(parts[0]) ?? 2000;
  var month = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
  month += delta;
  while (month < 1) {
    month += 12;
    year -= 1;
  }
  while (month > 12) {
    month -= 12;
    year += 1;
  }
  return '$year-${pad2(month)}';
}

String newIdempotencyKey([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
