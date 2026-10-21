import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;

import 'package:full_jizhang/services/money.dart';

/// Public-source quotes. Ports `api/internal/app/quotes.go` `fetchUSDTWD`,
/// `fetchQuote`, `fetchYahoo`, `fetchTWSE`, and `fetchCoinGecko`.
///
/// Each step is tried in order. A timeout, HTTP error, or empty payload
/// falls through. If every step fails, the caller (LocalApi.refreshQuotes)
/// keeps the previous price, or inserts a manual USD/TWD of 32 when the book
/// has no FX row yet. Locked manual quotes are not fetched here.
class QuoteClient {
  QuoteClient({http.Client? httpClient, this.timeout = const Duration(seconds: 8)})
    : _http = httpClient ?? http.Client();

  final http.Client _http;
  final Duration timeout;

  static const _ua = 'Mozilla/5.0 (compatible; full-jizhang/1.0)';

  Future<Map<String, dynamic>> getJson(Uri url) async {
    final res = await _http
        .get(url, headers: {'User-Agent': _ua, 'Accept': 'application/json'})
        .timeout(timeout);
    if (res.statusCode >= 400) {
      throw StateError('http ${res.statusCode} ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('expected object');
  }

  /// USD/TWD: Yahoo `TWD=X`, then open.er-api, then Frankfurter.
  ///
  /// Throws `fx unavailable` when all three fail. The refresh path catches
  /// that and records 「匯率」 (`quotes.go` `fetchUSDTWD`).
  Future<Decimal> fetchUsdTwd() async {
    try {
      final y = await getJson(
        Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/TWD=X?interval=1d&range=1d',
        ),
      );
      final p = yahooLast(y);
      if (p != null) return p;
    } catch (_) {}
    try {
      final er = await getJson(
        Uri.parse('https://open.er-api.com/v6/latest/USD'),
      );
      final rates = er['rates'];
      if (rates is Map && rates['TWD'] is num && (rates['TWD'] as num) > 0) {
        return Decimal.parse(rates['TWD'].toString());
      }
    } catch (_) {}
    try {
      final fr = await getJson(
        Uri.parse('https://api.frankfurter.app/latest?from=USD&to=TWD'),
      );
      final rates = fr['rates'];
      if (rates is Map && rates['TWD'] is num && (rates['TWD'] as num) > 0) {
        return Decimal.parse(rates['TWD'].toString());
      }
    } catch (_) {}
    throw StateError('fx unavailable');
  }

  /// Price and currency for one symbol.
  ///
  /// `tw_stock`: TWSE (listed, then OTC), then Yahoo `SYMBOL.TW` in TWD.
  /// `us_stock`: Yahoo in USD. `crypto`: CoinGecko, then Yahoo `SYMBOL-USD`.
  /// `fx`: Yahoo. Anything else throws `no quote` (`quotes.go` `fetchQuote`).
  Future<(Decimal price, String ccy)> fetchQuote(
    String symbol,
    String assetClass,
  ) async {
    symbol = symbol.toUpperCase().trim();
    switch (assetClass) {
      case 'tw_stock':
        try {
          return (await fetchTwse(symbol), 'TWD');
        } catch (_) {}
        try {
          return (await fetchYahoo('$symbol.TW'), 'TWD');
        } catch (_) {}
      case 'us_stock':
        try {
          return (await fetchYahoo(symbol), 'USD');
        } catch (_) {}
      case 'crypto':
        try {
          return (await fetchCoinGecko(symbol), 'USD');
        } catch (_) {}
        try {
          return (await fetchYahoo('$symbol-USD'), 'USD');
        } catch (_) {}
      case 'fx':
        try {
          return (await fetchYahoo(symbol), 'USD');
        } catch (_) {}
    }
    throw StateError('no quote');
  }

  Future<Decimal> fetchYahoo(String symbol) async {
    final y = await getJson(
      Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1d',
      ),
    );
    final p = yahooLast(y);
    if (p == null) throw StateError('empty');
    return p;
  }

  /// TWSE/OTC last price. `z` is the last trade; `-` or blank falls back to
  /// yesterday's close `y`. Tries the listed prefix, then OTC.
  Future<Decimal> fetchTwse(String symbol) async {
    for (final prefix in ['tse_', 'otc_']) {
      try {
        final y = await getJson(
          Uri.parse(
            'https://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=$prefix$symbol.tw&json=1&delay=0',
          ),
        );
        final msg = y['msgArray'];
        if (msg is! List || msg.isEmpty) continue;
        final m = msg.first;
        if (m is! Map) continue;
        var z = '${m['z'] ?? ''}';
        if (z.isEmpty || z == '-') z = '${m['y'] ?? ''}';
        if (z.isEmpty || z == '-') continue;
        return dec(z);
      } catch (_) {
        continue;
      }
    }
    throw StateError('empty');
  }

  Future<Decimal> fetchCoinGecko(String symbol) async {
    const ids = {
      'BTC': 'bitcoin',
      'ETH': 'ethereum',
      'USDT': 'tether',
      'USDC': 'usd-coin',
      'BNB': 'binancecoin',
      'SOL': 'solana',
      'XRP': 'ripple',
      'DOGE': 'dogecoin',
    };
    final id = ids[symbol.toUpperCase()] ?? symbol.toLowerCase();
    final y = await getJson(
      Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=$id&vs_currencies=usd',
      ),
    );
    final row = y[id];
    if (row is Map && row['usd'] is num) {
      return Decimal.parse(row['usd'].toString());
    }
    throw StateError('empty');
  }

  void close() => _http.close();
}

/// `chart.result[0].meta.regularMarketPrice`, or null when the payload is empty.
Decimal? yahooLast(Map<String, dynamic> y) {
  final ch = y['chart'];
  if (ch is! Map) return null;
  final res = ch['result'];
  if (res is! List || res.isEmpty) return null;
  final r0 = res[0];
  if (r0 is! Map) return null;
  final meta = r0['meta'];
  if (meta is Map && meta['regularMarketPrice'] is num) {
    return Decimal.parse(meta['regularMarketPrice'].toString());
  }
  return null;
}
