import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/services/apple_pay_link.dart';

// URL parsing for the Wallet shortcut. Nothing here touches SQLite.
// The import key is the trimmed `id`, or sha256 of the raw amount, merchant,
// time, and card_last4 joined by U+001F. `+` in a timezone offset stays a
// plus. A missing time falls back to the clock for the entry date only;
// the hash still uses the raw time text.

void main() {
  test('id wins over the hash and is trimmed', () {
    final withId = parseApplePayUri(
      Uri.parse(
        'fulljizhang://add?amount=10&merchant=A&time=2026-10-21&card_last4=1234&id=%20pay-9%20',
      ),
    );
    final otherAmount = parseApplePayUri(
      Uri.parse(
        'fulljizhang://add?amount=99&merchant=B&time=nope&card_last4=0000&id=pay-9',
      ),
    );
    expect(withId, isNotNull);
    expect(withId!.importKey, 'pay-9');
    expect(otherAmount!.importKey, 'pay-9');
  });

  test('hash is stable sha256 of the raw fields, not the parsed amount', () {
    const amount = 'NT\$1,234';
    const merchant = '星巴克';
    const time = '2026-10-21T08:42:00+08:00';
    const last4 = '1234';
    final uri = Uri.parse(
      'fulljizhang://add?amount=${Uri.encodeQueryComponent(amount)}'
      '&merchant=${Uri.encodeQueryComponent(merchant)}'
      '&time=${Uri.encodeQueryComponent(time)}'
      '&card_last4=$last4',
    );
    final again = Uri.parse(uri.toString());
    final first = parseApplePayUri(uri, clock: DateTime.utc(1999));
    final second = parseApplePayUri(again, clock: DateTime.utc(2030));
    final expected = sha256
        .convert(utf8.encode([amount, merchant, time, last4].join('\u001f')))
        .toString();
    expect(first!.importKey, expected);
    expect(second!.importKey, expected);
    expect(first.amount, 1234);
    expect(first.timeWasFallback, isFalse);

    final changed = parseApplePayUri(
      Uri.parse(
        'fulljizhang://add?amount=1234&merchant=${Uri.encodeQueryComponent(merchant)}'
        '&time=${Uri.encodeQueryComponent(time)}&card_last4=$last4',
      ),
    );
    // "NT$1,234" and "1234" are different charges when Shortcuts sends no id.
    expect(changed!.importKey, isNot(expected));
    expect(changed.amount, 1234);
  });

  test('plus in the offset is not turned into a space', () {
    final draft = parseApplePayUri(
      Uri.parse('fulljizhang://add?amount=10&time=2026-10-21T08:42:00+08:00'),
      clock: DateTime.utc(1999),
    );
    expect(draft!.timeWasFallback, isFalse);
    expect(draft.date, '2026-10-21');
    expect(draft.occurredAt.toUtc(), DateTime.utc(2026, 10, 21, 0, 42));
  });

  test('amount strips currency and commas and rounds half away from zero', () {
    expect(parseImportAmount('NT\$1,234.50'), 1235);
    expect(parseImportAmount('-185'), 185);
    expect(parseImportAmount('−90'), 90);
    expect(parseImportAmount(' 1,000 元 '), 1000);
    expect(parseImportAmount(''), isNull);
    expect(parseImportAmount('0'), isNull);
    expect(parseImportAmount('abc'), isNull);
    expect(parseImportAmount('US\$0.4'), isNull);
  });

  test('common shortcut dates and a missing time', () {
    final iso = parseImportTime('2026-10-21T00:42:00Z');
    expect(iso, DateTime.utc(2026, 10, 21, 0, 42));

    final zh = parseImportTime('2026年10月21日 下午2:05');
    expect(zh, DateTime.utc(2026, 10, 21, 6, 5));

    final us = parseImportTime('10/21/2026 8:42 AM');
    expect(us, DateTime.utc(2026, 10, 21, 0, 42));

    final slash = parseImportTime('2026/10/21 08:42:00');
    expect(slash, DateTime.utc(2026, 10, 21, 0, 42));

    expect(parseImportTime(''), isNull);
    expect(parseImportTime('not a date'), isNull);

    final fallback = parseApplePayUri(
      Uri.parse('fulljizhang://add?merchant=僅商家'),
      clock: DateTime.utc(2026, 10, 20, 16, 0),
    );
    expect(fallback, isNotNull);
    expect(fallback!.amount, isNull);
    expect(fallback.merchant, '僅商家');
    expect(fallback.timeWasFallback, isTrue);
    // 16:00 UTC is 00:00 the next Taipei day.
    expect(fallback.date, '2026-10-21');
    expect(fallback.cardLabel, '卡片');
    // No positive amount, so the preview row cannot be ticked.
    expect(fallback.amount, isNull);
  });

  test('other schemes and hosts are ignored', () {
    expect(parseApplePayUri(Uri.parse('https://example.com/add')), isNull);
    expect(parseApplePayUri(Uri.parse('fulljizhang://other')), isNull);
    expect(
      isApplePayAddLink(Uri.parse('fulljizhang://add?amount=1')),
      isTrue,
    );
  });

  test('note joins merchant and the shortcut note', () {
    final draft = parseApplePayUri(
      Uri.parse(
        'fulljizhang://add?amount=20&merchant=星巴克&note=早餐&card=玉山&card_last4=****4321',
      ),
    );
    expect(draft!.entryNote, '星巴克 · 早餐');
    expect(draft.cardLabel, '玉山');
    // Mapping digits are the last four. The hash still used the raw param.
    expect(draft.cardLast4, '4321');
  });
}
