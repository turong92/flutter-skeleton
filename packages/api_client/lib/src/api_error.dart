import 'dart:convert';

import 'package:dio/dio.dart';

import 'error_codes.dart';

/// `ApiError.FieldError` of the backend.
class FieldError {
  const FieldError({required this.field, required this.code, this.message});

  final String field;
  final String code;
  final String? message;
}

/// The standard error body (`ApiError` in modules/platform).
class ApiError {
  const ApiError({
    required this.code,
    required this.title,
    required this.status,
    this.detail,
    this.traceId,
    this.spanId,
    this.timestamp,
    this.errors = const [],
    this.data,
  });

  final String code;
  final String title;
  final int status;
  final String? detail;
  final String? traceId;
  final String? spanId;
  final String? timestamp;
  final List<FieldError> errors;
  final Object? data;

  /// Null when [json] is not the `ApiError` contract (`code`, `title`, `status`).
  static ApiError? tryParse(Object? json) {
    if (json is! Map) return null;
    final code = json['code'];
    final title = json['title'];
    final status = json['status'];
    if (code is! String || title is! String || status is! int) return null;
    final errors = json['errors'];
    return ApiError(
      code: code,
      title: title,
      status: status,
      detail: json['detail'] as String?,
      traceId: json['traceId'] as String?,
      spanId: json['spanId'] as String?,
      timestamp: json['timestamp'] as String?,
      errors: errors is List
          ? [
              for (final e in errors)
                if (e is Map && e['field'] is String && e['code'] is String)
                  FieldError(
                    field: e['field'] as String,
                    code: e['code'] as String,
                    message: e['message'] as String?,
                  ),
            ]
          : const [],
      data: json['data'],
    );
  }
}

/// Thrown by [ApiClient] for every failure: a 4xx/5xx, a response that is not
/// the contract, or no response. Branch on [code] with [ErrorCodes].
class ApiRequestError implements Exception {
  ApiRequestError(this.apiError, {this.traceId});

  /// A response that is not the `ApiError` contract.
  ApiRequestError.http(int status, {String? detail})
    : apiError = ApiError(
        code: ClientErrorCodes.httpError,
        title: 'Unexpected response',
        status: status,
        detail: detail,
      ),
      traceId = null;

  /// No response: network, timeout, cancel.
  ApiRequestError.network({String? detail})
    : apiError = ApiError(
        code: ClientErrorCodes.networkError,
        title: 'No response',
        status: 0,
        detail: detail,
      ),
      traceId = null;

  /// Reads a failed Dio call. The 4xx/5xx body is parsed as an `ApiError` when
  /// it is one.
  factory ApiRequestError.fromDioException(DioException e) {
    if (e.error is ApiRequestError) return e.error! as ApiRequestError;
    final response = e.response;
    if (response == null) {
      return ApiRequestError.network(detail: e.type.name);
    }
    var body = response.data;
    if (body is String) {
      try {
        body = jsonDecode(body);
      } on FormatException {
        // not JSON: handled below as a response outside the contract
      }
    }
    final apiError = ApiError.tryParse(body);
    if (apiError == null) {
      return ApiRequestError.http(response.statusCode ?? 0);
    }
    return ApiRequestError(apiError, traceId: apiError.traceId);
  }

  final ApiError apiError;
  final String? traceId;

  String get code => apiError.code;
  int get status => apiError.status;
  String get message => apiError.detail ?? apiError.title;
  List<FieldError> get fieldErrors => apiError.errors;

  @override
  String toString() => 'ApiRequestError([$status] $code: $message)';
}
