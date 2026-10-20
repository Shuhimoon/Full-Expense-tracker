import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
          options: Options(contentType: Headers.jsonContentType),
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
          options: Options(contentType: Headers.jsonContentType),
        ),
      ),
    );
  }

  @override
  Future<void> logout() {
    return _send(
      () => dio.post<dynamic>(
        '/api/logout',
        options: Options(contentType: Headers.jsonContentType),
      ),
    );
  }

  @override
  void close() => dio.close();

  Future<T> _send<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  Future<AppUser> _user(Future<Response<dynamic>> call) async {
    final response = await call;
    final data = response.data;
    if (data is Map<String, dynamic>) return AppUser.fromJson(data);
    if (data is Map) return AppUser.fromJson(Map<String, dynamic>.from(data));
    throw ApiException('請求失敗', status: response.statusCode);
  }
}
