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

  test('putOpening uses the book route and keeps the error text', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
    RequestOptions? captured;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'opening_date': '2026-03-16',
                'accounts': [
                  {
                    'id': 'a1',
                    'book_id': 'b1',
                    'name': '現金',
                    'type': 'cash',
                    'cash_balance': 0,
                    'version': 1,
                  },
                ],
                'cash_drafts': [
                  {'account_id': 'a1', 'amount': 10},
                ],
                'position_drafts': [
                  {
                    'account_id': 'a1',
                    'symbol': 'BTC',
                    'name': 'BTC',
                    'asset_class': 'crypto',
                    'quote_currency': 'USD',
                    'qty': '1.5',
                    'cost_twd': '0',
                    'cost_unknown': true,
                  },
                ],
                'preview_net_worth': 10,
                'some_cost_unknown': true,
              },
            ),
          );
        },
      ),
    );
    final client = DioApiClient(dio: dio);
    addTearDown(client.close);
    final snapshot = await client.putOpening(
      bookId: 'b1',
      body: {
        'opening_date': '2026-03-16',
        'accounts': [
          {'account_id': 'a1', 'amount': 10},
        ],
        'positions': [
          {
            'symbol': 'BTC',
            'asset_class': 'crypto',
            'quote_currency': 'USD',
            'qty': '1.5',
            'cost_twd': '0',
            'cost_unknown': true,
            'account_id': 'a1',
          },
        ],
      },
    );
    expect(captured?.method, 'PUT');
    expect(captured?.path, '/api/books/b1/opening');
    final sent = captured?.headers['Idempotency-Key'] ?? captured?.headers['idempotency-key'];
    expect(sent, isA<String>());
    expect((sent as String).length, greaterThan(10));
    expect(snapshot.openingDate, '2026-03-16');
    expect(snapshot.accounts.single.name, '現金');
    expect(snapshot.cashDrafts.single.amount, 10);
    expect(snapshot.positionDrafts.single.assetClass, 'crypto');
    expect(snapshot.positionDrafts.single.costUnknown, isTrue);
    expect(snapshot.someCostUnknown, isTrue);

    final rejected = apiExceptionFromDio(
      DioException(
        requestOptions: RequestOptions(path: '/api/books/b1/opening'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/books/b1/opening'),
          statusCode: 422,
          data: {'error': '修改後持倉會變負數'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    expect(rejected.status, 422);
    expect(rejected.message, '修改後持倉會變負數');
  });
}
