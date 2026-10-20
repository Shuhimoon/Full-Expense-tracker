import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// Web: let the browser store the HttpOnly `sid` cookie.
void configureDio(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
