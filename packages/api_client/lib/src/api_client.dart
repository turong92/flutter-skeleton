import 'dart:async';

import 'package:dio/dio.dart';

import 'api_error.dart';
import 'page.dart';

/// Extra headers for every request (credentials, time zone, ...). Called per
/// request, so a rotated token is picked up without rebuilding the client.
typedef HeaderProvider = FutureOr<Map<String, String>> Function();

typedef JsonDecoder<T> = T Function(Map<String, Object?> json);

/// REST client for the backend's `/api/v1`. Knows the response envelope
/// (`value`, `values`, `pagination`) and the standard error body, nothing about
/// who is logged in: credentials arrive through [headerProviders] and 401
/// recovery is an interceptor added to [dio] by the auth package.
class ApiClient {
  ApiClient({
    required String baseUrl,
    Iterable<HeaderProvider> headerProviders = const [],
    this.onError,
    HttpClientAdapter? adapter,
    Duration timeout = const Duration(seconds: 15),
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: timeout,
           receiveTimeout: timeout,
           sendTimeout: timeout,
         ),
       ) {
    if (adapter != null) dio.httpClientAdapter = adapter;
    final providers = List.of(headerProviders);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra[skipAuthKey] != true) {
            for (final provider in providers) {
              for (final entry in (await provider()).entries) {
                options.headers.putIfAbsent(entry.key, () => entry.value);
              }
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  /// `RequestOptions.extra` key set by `skipAuth: true`. Interceptors that
  /// work on credentials (the 401 recovery) leave such requests alone.
  static const skipAuthKey = 'skipAuth';

  /// The Dio instance. Interceptors of other packages are added here.
  final Dio dio;

  /// Called once with the error just before a call throws it (logging, global
  /// handling). A throw inside it is the caller's bug, not swallowed.
  final void Function(ApiRequestError error)? onError;

  /// `{ value }` envelope.
  Future<T> value<T>(
    String path, {
    required JsonDecoder<T> decode,
    String method = 'GET',
    Object? json,
    Map<String, Object?>? query,
    Map<String, String>? headers,
    bool skipAuth = false,
  }) async {
    final response = await _send(path, method, json, query, headers, skipAuth);
    return decode(_object(response, 'value'));
  }

  /// `{ values }` envelope.
  Future<List<T>> list<T>(
    String path, {
    required JsonDecoder<T> decode,
    String method = 'GET',
    Object? json,
    Map<String, Object?>? query,
    Map<String, String>? headers,
    bool skipAuth = false,
  }) async {
    final response = await _send(path, method, json, query, headers, skipAuth);
    return _items(response, decode);
  }

  /// `{ values, pagination }` envelope.
  Future<Page<T>> page<T>(
    String path, {
    required JsonDecoder<T> decode,
    String method = 'GET',
    Object? json,
    Map<String, Object?>? query,
    Map<String, String>? headers,
    bool skipAuth = false,
  }) async {
    final response = await _send(path, method, json, query, headers, skipAuth);
    return Page(
      items: _items(response, decode),
      pagination: PageInfo.fromJson(_object(response, 'pagination')),
    );
  }

  /// A call without a response body (204).
  Future<void> noContent(
    String path, {
    String method = 'GET',
    Object? json,
    Map<String, Object?>? query,
    Map<String, String>? headers,
    bool skipAuth = false,
  }) async {
    await _send(path, method, json, query, headers, skipAuth);
  }

  Future<Response<Object?>> _send(
    String path,
    String method,
    Object? json,
    Map<String, Object?>? query,
    Map<String, String>? headers,
    bool skipAuth,
  ) async {
    try {
      return await dio.request<Object?>(
        path,
        data: json,
        queryParameters: query,
        options: Options(
          method: method,
          headers: headers,
          extra: {if (skipAuth) skipAuthKey: true},
        ),
      );
    } on DioException catch (e, stackTrace) {
      final error = ApiRequestError.fromDioException(e);
      onError?.call(error);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Map<String, Object?> _object(Response<Object?> response, String key) {
    final body = response.data;
    final inner = body is Map ? body[key] : null;
    if (inner is! Map<String, Object?>) {
      throw _malformed(response, 'missing "$key" in the response');
    }
    return inner;
  }

  List<T> _items<T>(Response<Object?> response, JsonDecoder<T> decode) {
    final body = response.data;
    final values = body is Map ? body['values'] : null;
    if (values is! List) {
      throw _malformed(response, 'missing "values" in the response');
    }
    return [for (final item in values) decode(item as Map<String, Object?>)];
  }

  ApiRequestError _malformed(Response<Object?> response, String detail) {
    final error = ApiRequestError.http(
      response.statusCode ?? 0,
      detail: detail,
    );
    onError?.call(error);
    return error;
  }
}
