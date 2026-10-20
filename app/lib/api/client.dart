import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/net/configure_dio.dart';

/// JSON `{"error": "..."}` from the Go API, or the shared fallback.
String apiErrorMessage(Object? data) {
  if (data is Map) {
    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) return error;
  }
  if (data is String && data.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) return error;
      }
    } on FormatException {
      return data;
    }
    return data;
  }
  return '請求失敗';
}

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

ApiException apiExceptionFromDio(DioException error) {
  return ApiException(
    apiErrorMessage(error.response?.data),
    status: error.response?.statusCode,
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.lastBookId,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String? lastBookId;
  final String createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: '${json['id']}',
      email: json['email'] as String? ?? '',
      lastBookId: json['last_book_id'] as String?,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

/// `--dart-define=API_BASE=...`, otherwise web localhost and Android emulator host.
String resolveApiBase({
  String define = const String.fromEnvironment('API_BASE'),
  bool? web,
  TargetPlatform? platform,
}) {
  var configured = define.trim();
  while (configured.endsWith('/')) {
    configured = configured.substring(0, configured.length - 1);
  }
  if (configured.isNotEmpty) return configured;
  final onWeb = web ?? kIsWeb;
  if (onWeb) return 'http://127.0.0.1:8080';
  final target = platform ?? defaultTargetPlatform;
  if (target == TargetPlatform.android) return 'http://10.0.2.2:8080';
  return 'http://127.0.0.1:8080';
}

abstract class ApiClient {
  Future<AppUser> me();

  Future<AppUser> login({required String email, required String password});

  Future<AppUser> register({required String email, required String password});

  Future<void> logout();

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  Future<List<Book>> listBooks();

  Future<Book> createBook({required String name});

  Future<Book> patchBook({
    required String id,
    required String name,
    required int version,
  });

  Future<Book> archiveBook(String id);

  Future<Book> unarchiveBook(String id);

  Future<void> deleteBook(String id);

  Future<Book> selectBook(String id);

  Future<Map<String, dynamic>> exportBook(String id);

  Future<Book> importBook({
    required String id,
    required Map<String, dynamic> payload,
  });

  Future<List<Account>> listAccounts(String bookId);

  Future<Account> createAccount({
    required String bookId,
    required String name,
    required String type,
  });

  Future<Account> patchAccount({
    required String id,
    required String name,
    required int version,
  });

  Future<void> archiveAccount(String id);

  Future<void> deleteAccount(String id);

  Future<List<Category>> listCategories(String bookId);

  Future<Category> createCategory({
    required String bookId,
    required String name,
    required String kind,
  });

  Future<Category> patchCategory({
    required String id,
    required String name,
    required int version,
  });

  Future<void> archiveCategory(String id);

  Future<void> deleteCategory(String id);

  Future<List<Entry>> listEntries({
    required String bookId,
    String? date,
    String? from,
    String? to,
    String? accountId,
    String? categoryId,
  });

  Future<Entry> createEntry({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  });

  Future<List<DailyPoint>> statsDaily({
    required String bookId,
    required String from,
    required String to,
  });

  Future<StatsSummary> statsSummary({required String bookId, String? month});

  Future<List<CategoryAmount>> statsByCategory({
    required String bookId,
    String? month,
  });

  Future<List<Position>> listPositions(String bookId);

  Future<QuoteRefresh> refreshQuotes(String bookId);

  Future<Map<String, dynamic>> createTrade({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  });

  Future<OpeningSnapshot> getOpening(String bookId);

  Future<OpeningSnapshot> putOpening({
    required String bookId,
    required Map<String, dynamic> body,
  });

  void close() {}
}

class DioApiClient implements ApiClient {
  DioApiClient({String? baseUrl, Dio? dio})
    : dio = dio ?? _newDio(baseUrl ?? resolveApiBase());

  final Dio dio;

  static Dio _newDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {Headers.acceptHeader: Headers.jsonContentType},
        responseType: ResponseType.json,
      ),
    );
    configureDio(dio);
    return dio;
  }

  @override
  Future<AppUser> me() => _user(_send(() => dio.get<dynamic>('/api/me')));

  @override
  Future<AppUser> login({required String email, required String password}) {
    return _user(
      _send(
        () => dio.post<dynamic>(
          '/api/login',
          data: {'email': email, 'password': password},
          options: _json(),
        ),
      ),
    );
  }

  @override
  Future<AppUser> register({required String email, required String password}) {
    return _user(
      _send(
        () => dio.post<dynamic>(
          '/api/register',
          data: {'email': email, 'password': password},
          options: _json(),
        ),
      ),
    );
  }

  @override
  Future<void> logout() {
    return _send(
      () => dio.post<dynamic>('/api/logout', options: _json()),
    );
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _send(
      () => dio.post<dynamic>(
        '/api/password',
        data: {'old': oldPassword, 'new': newPassword},
        options: _json(idempotencyKey: newIdempotencyKey()),
      ),
    );
  }

  @override
  Future<List<Book>> listBooks() async {
    final response = await _send(() => dio.get<dynamic>('/api/books'));
    return _list(response.data, Book.fromJson);
  }

  @override
  Future<Book> createBook({required String name}) async {
    final response = await _send(
      () => dio.post<dynamic>(
        '/api/books',
        data: {'name': name},
        options: _json(idempotencyKey: newIdempotencyKey()),
      ),
    );
    return Book.fromJson(_object(response.data));
  }

  @override
  Future<Book> patchBook({
    required String id,
    required String name,
    required int version,
  }) async {
    final response = await _send(
      () => dio.patch<dynamic>(
        '/api/books/$id',
        data: {'name': name, 'version': version},
        options: _json(),
      ),
    );
    return Book.fromJson(_object(response.data));
  }

  @override
  Future<Book> archiveBook(String id) async {
    final response = await _send(
      () => dio.post<dynamic>('/api/books/$id/archive', options: _json()),
    );
    return Book.fromJson(_object(response.data));
  }

  @override
  Future<Book> unarchiveBook(String id) async {
    final response = await _send(
      () => dio.post<dynamic>('/api/books/$id/unarchive', options: _json()),
    );
    return Book.fromJson(_object(response.data));
  }

  @override
  Future<void> deleteBook(String id) {
    return _send(() => dio.delete<dynamic>('/api/books/$id'));
  }

  @override
  Future<Book> selectBook(String id) async {
    final response = await _send(
      () => dio.post<dynamic>('/api/books/$id/select', options: _json()),
    );
    return Book.fromJson(_object(response.data));
  }

  @override
  Future<Map<String, dynamic>> exportBook(String id) async {
    final response = await _send(
      () => dio.get<dynamic>('/api/books/$id/export'),
    );
    return _object(response.data);
  }

  @override
  Future<Book> importBook({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _send(
      () => dio.post<dynamic>(
        '/api/books/$id/import',
        data: payload,
        options: _json(idempotencyKey: newIdempotencyKey()),
      ),
    );
    return Book.fromJson(_object(response.data));
  }

  @override
  Future<List<Account>> listAccounts(String bookId) async {
    final response = await _send(
      () => dio.get<dynamic>('/api/accounts?${_query({'book_id': bookId})}'),
    );
    return _list(response.data, Account.fromJson);
  }

  @override
  Future<Account> createAccount({
    required String bookId,
    required String name,
    required String type,
  }) async {
    final response = await _send(
      () => dio.post<dynamic>(
        '/api/accounts',
        data: {'book_id': bookId, 'name': name, 'type': type},
        options: _json(idempotencyKey: newIdempotencyKey()),
      ),
    );
    return Account.fromJson(_object(response.data));
  }

  @override
  Future<Account> patchAccount({
    required String id,
    required String name,
    required int version,
  }) async {
    final response = await _send(
      () => dio.patch<dynamic>(
        '/api/accounts/$id',
        data: {'name': name, 'version': version},
        options: _json(),
      ),
    );
    return Account.fromJson(_object(response.data));
  }

  @override
  Future<void> archiveAccount(String id) {
    return _send(
      () => dio.post<dynamic>('/api/accounts/$id/archive', options: _json()),
    );
  }

  @override
  Future<void> deleteAccount(String id) {
    return _send(() => dio.delete<dynamic>('/api/accounts/$id'));
  }

  @override
  Future<List<Category>> listCategories(String bookId) async {
    final response = await _send(
      () => dio.get<dynamic>('/api/categories?${_query({'book_id': bookId})}'),
    );
    return _list(response.data, Category.fromJson);
  }

  @override
  Future<Category> createCategory({
    required String bookId,
    required String name,
    required String kind,
  }) async {
    final response = await _send(
      () => dio.post<dynamic>(
        '/api/categories',
        data: {'book_id': bookId, 'name': name, 'kind': kind},
        options: _json(idempotencyKey: newIdempotencyKey()),
      ),
    );
    return Category.fromJson(_object(response.data));
  }

  @override
  Future<Category> patchCategory({
    required String id,
    required String name,
    required int version,
  }) async {
    final response = await _send(
      () => dio.patch<dynamic>(
        '/api/categories/$id',
        data: {'name': name, 'version': version},
        options: _json(),
      ),
    );
    return Category.fromJson(_object(response.data));
  }

  @override
  Future<void> archiveCategory(String id) {
    return _send(
      () => dio.post<dynamic>('/api/categories/$id/archive', options: _json()),
    );
  }

  @override
  Future<void> deleteCategory(String id) {
    return _send(() => dio.delete<dynamic>('/api/categories/$id'));
  }

  @override
  Future<List<Entry>> listEntries({
    required String bookId,
    String? date,
    String? from,
    String? to,
    String? accountId,
    String? categoryId,
  }) async {
    final response = await _send(
      () => dio.get<dynamic>(
        '/api/entries?${_query({
          'book_id': bookId,
          'date': date,
          'from': from,
          'to': to,
          'account_id': accountId,
          'category_id': categoryId,
        })}',
      ),
    );
    return _list(response.data, Entry.fromJson);
  }

  @override
  Future<Entry> createEntry({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    final response = await _send(
      () => dio.post<dynamic>(
        '/api/entries',
        data: body,
        options: _json(idempotencyKey: idempotencyKey),
      ),
    );
    return Entry.fromJson(_object(response.data));
  }

  @override
  Future<StatsSummary> statsSummary({
    required String bookId,
    String? month,
  }) async {
    final response = await _send(
      () => dio.get<dynamic>(
        '/api/stats/summary?${_query({'book_id': bookId, 'month': month})}',
      ),
    );
    return StatsSummary.fromJson(_object(response.data));
  }

  @override
  Future<List<DailyPoint>> statsDaily({
    required String bookId,
    required String from,
    required String to,
  }) async {
    final response = await _send(
      () => dio.get<dynamic>(
        '/api/stats/daily?${_query({'book_id': bookId, 'from': from, 'to': to})}',
      ),
    );
    return _list(response.data, DailyPoint.fromJson);
  }

  @override
  Future<List<CategoryAmount>> statsByCategory({
    required String bookId,
    String? month,
  }) async {
    final response = await _send(
      () => dio.get<dynamic>(
        '/api/stats/expense-by-category?${_query({'book_id': bookId, 'month': month})}',
      ),
    );
    return _list(response.data, CategoryAmount.fromJson);
  }

  @override
  Future<List<Position>> listPositions(String bookId) async {
    final response = await _send(
      () => dio.get<dynamic>('/api/positions?${_query({'book_id': bookId})}'),
    );
    return _list(response.data, Position.fromJson);
  }

  @override
  Future<QuoteRefresh> refreshQuotes(String bookId) async {
    final response = await _send(
      () => dio.post<dynamic>(
        '/api/quotes/refresh?${_query({'book_id': bookId})}',
        options: _json(idempotencyKey: newIdempotencyKey()),
      ),
    );
    return QuoteRefresh.fromJson(_object(response.data));
  }

  @override
  Future<Map<String, dynamic>> createTrade({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    final response = await _send(
      () => dio.post<dynamic>(
        '/api/trades',
        data: body,
        options: _json(idempotencyKey: idempotencyKey),
      ),
    );
    return _object(response.data);
  }

  @override
  Future<OpeningSnapshot> getOpening(String bookId) async {
    final response = await _send(
      () => dio.get<dynamic>('/api/books/$bookId/opening'),
    );
    return OpeningSnapshot.fromJson(_object(response.data));
  }

  @override
  Future<OpeningSnapshot> putOpening({
    required String bookId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      () => dio.put<dynamic>(
        '/api/books/$bookId/opening',
        data: body,
        options: _json(idempotencyKey: newIdempotencyKey()),
      ),
    );
    return OpeningSnapshot.fromJson(_object(response.data));
  }

  @override
  void close() => dio.close();

  Options _json({String? idempotencyKey}) {
    return Options(
      contentType: Headers.jsonContentType,
      headers: idempotencyKey == null
          ? null
          : {'Idempotency-Key': idempotencyKey},
    );
  }

  String _query(Map<String, String?> params) {
    final parts = <String>[];
    params.forEach((key, value) {
      if (value != null && value.isNotEmpty) {
        parts.add('$key=${Uri.encodeQueryComponent(value)}');
      }
    });
    return parts.join('&');
  }

  Future<T> _send<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  Future<AppUser> _user(Future<Response<dynamic>> call) async {
    final response = await call;
    return AppUser.fromJson(_object(response.data, status: response.statusCode));
  }

  Map<String, dynamic> _object(Object? data, {int? status}) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException('請求失敗', status: status);
  }

  List<T> _list<T>(Object? data, T Function(Map<String, dynamic>) parse) {
    if (data is! List) return <T>[];
    return [
      for (final item in data)
        if (item is Map) parse(Map<String, dynamic>.from(item)),
    ];
  }
}
