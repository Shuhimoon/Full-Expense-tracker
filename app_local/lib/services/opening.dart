import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/data/database.dart';
import 'package:full_jizhang/services/money.dart';

// Opening materialization and moving-average replay.
//
// Port of api/internal/app/opening.go `applyOpening` and `rebuildPositions`
// (the 2026-10-20 behavior: opening is editable, there is no lock step).
// `LocalApi.putOpening` calls [applyOpening] inside one transaction. A throw
// of [msgNegativeHolding] (HTTP 422) rolls the date, drafts, trades, and
// positions back to what they were.

/// Account + instrument. Positions and the replay are keyed by this pair.
class PosKey {
  const PosKey(this.acc, this.iid);
  final String acc;
  final String iid;
  @override
  bool operator ==(Object other) =>
      other is PosKey && other.acc == acc && other.iid == iid;
  @override
  int get hashCode => Object.hash(acc, iid);
}

/// One non-deleted trade, reduced to the fields the replay reads.
class ReplayTrade {
  ReplayTrade({
    required this.id,
    required this.acc,
    required this.iid,
    this.pair,
    required this.side,
    required this.qty,
    required this.proceeds,
  });
  final String id;
  final String acc;
  final String iid;
  final String? pair;
  final String side;
  final Decimal qty;
  final int proceeds;
}

/// Running quantity, moving-average cost (TWD, decimal), and realized TWD.
class PosState {
  Decimal qty = Decimal.zero;
  Decimal cost = Decimal.zero;
  int realized = 0;
}

/// Writes opening drafts into real rows, then replays positions when asked.
///
/// Ports `opening.go` `applyOpening`.
///
/// Cash drafts always replace `opening_balance` entries dated on the book's
/// opening day. Amounts of 0 or less are skipped. If [applyPositions] is
/// false (the PUT body had no `positions` key), existing `opening` trades
/// are only re-dated to the new opening day and the replay is skipped.
/// If [applyPositions] is true, those trades are deleted and rewritten from
/// the drafts, then [rebuildPositions] runs.
///
/// No opening date means nothing is materialized (the book can still record
/// later; creation itself always stores a date — see `books.go`).
Future<void> applyOpening(
  AppDatabase db, {
  required String bookId,
  required bool applyPositions,
  DateTime Function()? clock,
}) async {
  final book = await (db.select(
    db.books,
  )..where((b) => b.id.equals(bookId))).getSingleOrNull();
  if (book == null) {
    throw ApiException('伺服器錯誤', status: 500);
  }
  final od = book.openingDate;
  // Nothing to materialize until the book has an opening day.
  if (od == null || od.isEmpty) return;

  // System-owned cash rows. User entries of other types stay.
  await (db.delete(
    db.entries,
  )..where((e) => e.bookId.equals(bookId) & e.type.equals('opening_balance')))
      .go();

  if (!applyPositions) {
    // Cash-only or date-only save: keep lots, move them onto the opening day.
    await (db.update(db.trades)..where(
          (t) => t.bookId.equals(bookId) & t.side.equals('opening'),
        ))
        .write(TradesCompanion(date: Value(od)));
  } else {
    await (db.delete(
      db.trades,
    )..where((t) => t.bookId.equals(bookId) & t.side.equals('opening'))).go();
  }

  final cas = await (db.select(
    db.openingCashDrafts,
  )..where((d) => d.bookId.equals(bookId))).get();
  final ts = nowIso(clock?.call());
  for (final x in cas) {
    // Zero is "no opening cash", not a zero-amount entry.
    if (x.amount <= 0) continue;
    await db
        .into(db.entries)
        .insert(
          EntriesCompanion.insert(
            id: newId(),
            bookId: bookId,
            date: od,
            type: 'opening_balance',
            amount: x.amount,
            accountId: x.accountId,
            note: const Value('開帳'),
            createdAt: ts,
            updatedAt: ts,
          ),
        );
  }

  if (!applyPositions) return;

  final pds = await (db.select(
    db.openingPositionDrafts,
  )..where((d) => d.bookId.equals(bookId))).get();

  final openingCost = <String, Decimal>{};
  final unknown = <PosKey, bool>{};

  for (final p in pds) {
    var iid = p.instrumentId ?? '';
    if (iid.isEmpty) {
      iid = await ensureInstrument(
        db,
        bookId: bookId,
        symbol: p.symbol,
        name: p.name,
        assetClass: p.assetClass,
        quoteCcy: p.quoteCurrency,
      );
    }
    final qty = dec(p.qty);
    final cost = dec(p.costTwd);
    String? price;
    // Unit price is display-only. The replay uses [openingCost], the exact
    // decimal, not the rounded proceeds column.
    if (qty > Decimal.zero && cost > Decimal.zero) {
      price = div(cost, qty).toString();
    }
    final tid = newId();
    await db
        .into(db.trades)
        .insert(
          TradesCompanion.insert(
            id: tid,
            bookId: bookId,
            date: od,
            accountId: p.accountId,
            instrumentId: iid,
            side: 'opening',
            qty: qty.toString(),
            price: Value(price),
            priceCcy: Value(p.quoteCurrency),
            feeTwd: const Value(0),
            proceedsOrCostTwd: Value(round0(cost)),
            fxUsdTwd: const Value('1'),
            note: const Value('開帳'),
            createdAt: ts,
            updatedAt: ts,
          ),
        );
    openingCost[tid] = cost;
    if (p.costUnknown) unknown[PosKey(p.accountId, iid)] = true;
  }
  await rebuildPositions(db, bookId, openingCost, unknown, clock: clock);
}

/// Reuses an instrument id, or inserts one unique on (book, class, symbol).
///
/// Ports `trades.go` `ensureInstrument`. A blank class becomes `tw_stock`.
/// A blank quote currency is TWD for Taiwan stocks and USD otherwise.
/// A new name updates the stored name; the symbol is uppercased.
Future<String> ensureInstrument(
  AppDatabase db, {
  required String bookId,
  String? existing,
  required String symbol,
  required String name,
  required String assetClass,
  required String quoteCcy,
}) async {
  if (existing != null && existing.isNotEmpty) {
    final row = await (db.select(
      db.instruments,
    )..where((i) => i.id.equals(existing))).getSingleOrNull();
    if (row == null) throw ApiException('標的不存在', status: 400);
    if (row.bookId != bookId) throw ApiException('標的不屬於這本帳', status: 400);
    return row.id;
  }
  symbol = symbol.toUpperCase().trim();
  if (symbol.isEmpty) throw ApiException('請填標的代號', status: 400);
  if (assetClass.isEmpty) assetClass = 'tw_stock';
  if (quoteCcy.isEmpty) {
    quoteCcy = assetClass == 'tw_stock' ? 'TWD' : 'USD';
  }
  final found = await (db.select(db.instruments)..where(
        (i) =>
            i.bookId.equals(bookId) &
            i.assetClass.equals(assetClass) &
            i.symbol.equals(symbol),
      ))
      .getSingleOrNull();
  if (found != null) {
    if (name.isNotEmpty && found.name != name) {
      await (db.update(
        db.instruments,
      )..where((i) => i.id.equals(found.id))).write(
        InstrumentsCompanion(name: Value(name)),
      );
    }
    return found.id;
  }
  final id = newId();
  await db
      .into(db.instruments)
      .insert(
        InstrumentsCompanion.insert(
          id: id,
          bookId: bookId,
          symbol: symbol,
          name: Value(name),
          assetClass: assetClass,
          quoteCurrency: quoteCcy,
        ),
      );
  return id;
}

/// Replays every live trade and rewrites `positions`.
///
/// Ports `opening.go` `rebuildPositions`.
///
/// Order is date, then opening lots before anything else that day, then id.
/// Opening is the start of the day: a newly inserted opening id must not
/// sort after a same-day sell.
///
/// Pass 1 is quantity only. A sell or transfer_out larger than the running
/// quantity throws [msgNegativeHolding] (422 「修改後持倉會變負數」). That throw
/// is inside `putOpening`'s transaction, so drafts and the previous
/// positions stay.
///
/// Pass 2 is moving-average cost. Opening lots add [openingCost] (exact
/// decimal) rather than the rounded proceeds. Buys add TWD proceeds (price
/// × qty × fx, plus fee). Airdrops add quantity and no cost. Sells realize
/// `round(proceeds − avg × qty)` and reduce cost by `avg × qty`, floored at
/// zero. Transfers move `avg × qty` from the source to the destination.
/// A cycle between same-day transfer legs keeps the cost already stored on
/// the transfer_in. Realized P&L and moved cost are written back onto the
/// trade rows, then every position for the book is replaced.
Future<void> rebuildPositions(
  AppDatabase db,
  String bookId,
  Map<String, Decimal> openingCost,
  Map<PosKey, bool> unknown, {
  DateTime Function()? clock,
}) async {
  final rows = await (db.select(
    db.trades,
  )..where((t) => t.bookId.equals(bookId) & t.deletedAt.isNull())).get();
  // Same order as the SQL in opening.go: date, opening first, then id.
  rows.sort((a, b) {
    final d = a.date.compareTo(b.date);
    if (d != 0) return d;
    final ao = a.side == 'opening' ? 0 : 1;
    final bo = b.side == 'opening' ? 0 : 1;
    if (ao != bo) return ao - bo;
    return a.id.compareTo(b.id);
  });

  final trades = [
    for (final t in rows)
      ReplayTrade(
        id: t.id,
        acc: t.accountId,
        iid: t.instrumentId,
        pair: t.pairId,
        side: t.side,
        qty: dec(t.qty),
        proceeds: t.proceedsOrCostTwd,
      ),
  ];

  final qtyNow = <PosKey, Decimal>{};
  for (final t in trades) {
    final k = PosKey(t.acc, t.iid);
    var q = qtyNow[k] ?? Decimal.zero;
    switch (t.side) {
      case 'buy':
      case 'airdrop':
      case 'opening':
      case 'transfer_in':
        q = q + t.qty;
      case 'sell':
      case 'transfer_out':
        // Reject before any position row is rewritten. 422 rolls the PUT back.
        if (t.qty > q) {
          throw ApiException(msgNegativeHolding, status: 422);
        }
        q = q - t.qty;
      default:
        throw ApiException('伺服器錯誤', status: 500);
    }
    qtyNow[k] = q;
  }

  final byID = <String, ReplayTrade>{};
  final grouped = <PosKey, List<ReplayTrade>>{};
  for (final t in trades) {
    byID[t.id] = t;
    grouped.putIfAbsent(PosKey(t.acc, t.iid), () => []).add(t);
  }

  final moveCost = <String, Decimal>{};
  final computing = <String, bool>{};

  late Decimal Function(String outID) ensureMove;
  late void Function(PosState st, ReplayTrade t) fold;

  PosState stateBefore(PosKey k, String before) {
    final st = PosState();
    var found = false;
    for (final t in grouped[k] ?? const <ReplayTrade>[]) {
      if (t.id == before) {
        found = true;
        break;
      }
      fold(st, t);
    }
    if (!found) throw ApiException('伺服器錯誤', status: 500);
    return st;
  }

  fold = (st, t) {
    switch (t.side) {
      case 'opening':
        // Prefer the unrounded draft cost when this replay just inserted the lot.
        var add = dInt(t.proceeds);
        if (openingCost.containsKey(t.id)) add = openingCost[t.id]!;
        st.cost = st.cost + add;
        st.qty = st.qty + t.qty;
      case 'buy':
        st.cost = st.cost + dInt(t.proceeds);
        st.qty = st.qty + t.qty;
      case 'airdrop':
        st.qty = st.qty + t.qty;
      case 'sell':
        if (t.qty > st.qty) {
          throw ApiException(msgNegativeHolding, status: 422);
        }
        // Moving average: realized = proceeds − avg × qty, cost drops by the same avg.
        var avg = Decimal.zero;
        if (st.qty > Decimal.zero) avg = div(st.cost, st.qty);
        final rlz = round0(dInt(t.proceeds) - avg * t.qty);
        st.qty = st.qty - t.qty;
        st.cost = st.cost - avg * t.qty;
        if (st.cost < Decimal.zero) st.cost = Decimal.zero;
        st.realized += rlz;
      case 'transfer_out':
        final mc = ensureMove(t.id);
        if (t.qty > st.qty) {
          throw ApiException(msgNegativeHolding, status: 422);
        }
        st.qty = st.qty - t.qty;
        st.cost = st.cost - mc;
        if (st.cost < Decimal.zero) st.cost = Decimal.zero;
      case 'transfer_in':
        Decimal mc;
        if (t.pair == null || t.pair!.isEmpty) {
          mc = dInt(t.proceeds);
        } else {
          mc = ensureMove(t.pair!);
        }
        st.qty = st.qty + t.qty;
        st.cost = st.cost + mc;
      default:
        throw ApiException('伺服器錯誤', status: 500);
    }
  };

  ensureMove = (outID) {
    final cached = moveCost[outID];
    if (cached != null) return cached;
    if (computing[outID] == true) {
      // Two same-day transfers can cycle when each `in` sorts before its `out`.
      // Keep the cost already stored on the transfer_in so both legs agree.
      var fb = Decimal.zero;
      for (final t in trades) {
        if (t.side == 'transfer_in' && t.pair == outID) {
          fb = dInt(t.proceeds);
          break;
        }
      }
      moveCost[outID] = fb;
      return fb;
    }
    computing[outID] = true;
    try {
      final out = byID[outID];
      if (out == null) throw ApiException('伺服器錯誤', status: 500);
      final st = stateBefore(PosKey(out.acc, out.iid), out.id);
      final again = moveCost[outID];
      if (again != null) return again;
      if (out.qty > st.qty) {
        throw ApiException(msgNegativeHolding, status: 422);
      }
      var avg = Decimal.zero;
      if (st.qty > Decimal.zero) avg = div(st.cost, st.qty);
      final mc = avg * out.qty;
      moveCost[outID] = mc;
      return mc;
    } finally {
      computing.remove(outID);
    }
  };

  for (final t in trades) {
    if (t.side == 'transfer_out') ensureMove(t.id);
  }

  final states = <PosKey, PosState>{};
  for (final entry in grouped.entries) {
    final st = PosState();
    for (final t in entry.value) {
      final prevReal = st.realized;
      final prevCost = st.cost;
      fold(st, t);
      if (t.side == 'sell') {
        final rlz = st.realized - prevReal;
        await (db.update(
          db.trades,
        )..where((row) => row.id.equals(t.id))).write(
          TradesCompanion(realizedTwd: Value(rlz)),
        );
      }
      if (t.side == 'transfer_in') {
        final moved = round0(st.cost - prevCost);
        if (moved != t.proceeds) {
          await (db.update(
            db.trades,
          )..where((row) => row.id.equals(t.id))).write(
            TradesCompanion(proceedsOrCostTwd: Value(moved)),
          );
        }
      }
    }
    states[entry.key] = st;
  }

  await (db.delete(db.positions)..where((p) => p.bookId.equals(bookId))).go();
  final ts = nowIso(clock?.call());
  for (final e in states.entries) {
    await db
        .into(db.positions)
        .insert(
          PositionsCompanion.insert(
            id: newId(),
            bookId: bookId,
            accountId: e.key.acc,
            instrumentId: e.key.iid,
            qty: Value(e.value.qty.toString()),
            costTwd: Value(e.value.cost.toString()),
            realizedTwd: Value(e.value.realized),
            costUnknown: Value(unknown[e.key] == true),
            updatedAt: ts,
          ),
        );
  }
}
