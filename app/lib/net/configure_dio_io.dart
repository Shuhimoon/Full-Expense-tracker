import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

/// Mobile/desktop: keep the HttpOnly `sid` cookie in an in-memory [CookieJar].
void configureDio(Dio dio) {
  dio.interceptors.add(CookieManager(CookieJar()));
}
