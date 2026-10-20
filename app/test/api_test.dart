import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/api.dart';

void main() {
  test('apiErrorMessage reads JSON error text', () {
    expect(apiErrorMessage({'error': '帳號或密碼不對'}), '帳號或密碼不對');
    expect(apiErrorMessage('{"error":"密碼至少 8 碼"}'), '密碼至少 8 碼');
    expect(apiErrorMessage({'error': ''}), '請求失敗');
    expect(apiErrorMessage(null), '請求失敗');
    expect(apiErrorMessage('plain'), 'plain');
  });

  test('dio errors keep status and the JSON message', () {
    final exception = apiExceptionFromDio(
      DioException(
        requestOptions: RequestOptions(path: '/api/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/login'),
          statusCode: 401,
          data: {'error': '帳號或密碼不對'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    expect(exception.status, 401);
    expect(exception.isUnauthorized, isTrue);
    expect(exception.message, '帳號或密碼不對');
  });

  test('API_BASE overrides platform defaults', () {
    expect(
      resolveApiBase(define: '', web: true, platform: TargetPlatform.android),
      'http://127.0.0.1:8080',
    );
    expect(
      resolveApiBase(define: '', web: false, platform: TargetPlatform.android),
      'http://10.0.2.2:8080',
    );
    expect(
      resolveApiBase(define: '', web: false, platform: TargetPlatform.iOS),
      'http://127.0.0.1:8080',
    );
    expect(
      resolveApiBase(define: 'http://example.com/', web: true),
      'http://example.com',
    );
  });

  test('mobile client stores cookies with dio_cookie_manager', () {
    final client = DioApiClient(baseUrl: 'http://10.0.2.2:8080');
    addTearDown(client.close);
    expect(client.dio.options.baseUrl, 'http://10.0.2.2:8080');
    expect(client.dio.interceptors.whereType<CookieManager>(), isNotEmpty);
  });

  test('createEntry sends Idempotency-Key', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
    String? sent;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent =
              options.headers['Idempotency-Key'] as String? ??
              options.headers['idempotency-key'] as String?;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'id': 'e1',
                'book_id': 'b1',
                'date': '2026-10-20',
                'type': 'expense',
                'amount': 10,
                'account_id': 'a1',
                'note': '',
                'created_at': '2026-10-20T00:00:00Z',
                'version': 1,
              },
            ),
          );
        },
      ),
    );
    final client = DioApiClient(dio: dio);
    addTearDown(client.close);
    const key = '11111111-1111-4111-8111-111111111111';
    await client.createEntry(
      body: {
        'book_id': 'b1',
        'type': 'expense',
        'amount': 10,
        'account_id': 'a1',
        'date': '2026-10-20',
        'note': '',
        'category_id': 'c1',
      },
      idempotencyKey: key,
    );
    expect(sent, key);
    expect(dio.options.baseUrl, 'http://example.test');
  });
}
