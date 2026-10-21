import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/data/database.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/services/local_api.dart';
import 'package:sqlite3/open.dart';

// In-memory ledger for rule tests. Each test gets a fresh SQLite database
// and a [LocalApi], so the checks exercise the same code the app runs.
// Linux CI loads libsqlite3 explicitly because sqlite3_flutter_libs does not
// ship a desktop binary here.

bool _sqliteOpened = false;

/// Points the sqlite3 package at the system library. Safe to call twice.
void openTestSqlite() {
  if (_sqliteOpened) return;
  _sqliteOpened = true;
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, () {
      for (final name in [
        'libsqlite3.so',
        'libsqlite3.so.0',
        '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
      ]) {
        try {
          return DynamicLibrary.open(name);
        } catch (_) {}
      }
      return DynamicLibrary.open('libsqlite3.so.0');
    });
  }
}

/// One in-memory book API. [setUp] / [tearDown] bracket each test.
class Harness {
  late AppDatabase db;
  late LocalApi api;

  Future<void> setUp() async {
    openTestSqlite();
    db = AppDatabase.memory();
    api = LocalApi(db);
  }

  Future<void> tearDown() async {
    await db.close();
  }

  Future<Book> book([String name = '生活']) => api.createBook(name: name);

  Future<Account> cash(String bookId, {String name = '現金'}) {
    return api.createAccount(bookId: bookId, name: name, type: 'cash');
  }

  Future<Account> broker(String bookId, {String name = '券商'}) {
    return api.createAccount(bookId: bookId, name: name, type: 'broker');
  }

  Future<String> expenseCat(String bookId) async {
    final cats = await api.listCategories(bookId);
    for (final c in cats) {
      if (c.kind == 'expense') return c.id;
    }
    return cats.first.id;
  }
}

String todayTaipei() => taipeiToday();
