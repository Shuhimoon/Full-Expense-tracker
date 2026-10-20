import 'package:dio/dio.dart';

void configureDio(Dio dio) {
  throw UnsupportedError('No HTTP adapter for ${dio.options.baseUrl}.');
}
