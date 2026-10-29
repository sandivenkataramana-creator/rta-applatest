// Replaced long mock responses with production-ready ApiClient using Dio
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/secure_storage_service.dart';

class ApiException implements Exception {
  ApiException({required this.code, required this.message});
  final int code;
  final String message;
  @override
  String toString() => message;
}

class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tgrta-anpr.in/api',
  );
}

class ApiClient {
  ApiClient._(this._storage)
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 15),
          responseType: ResponseType.json,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await _storage.readToken();
            if (token != null && token.isNotEmpty) {
              final normalizedToken = token.trim();
              options.headers['Authorization'] =
                  normalizedToken.toLowerCase().startsWith('bearer ')
                  ? normalizedToken
                  : 'Bearer $normalizedToken';
            }
          } catch (_) {}
          if (kDebugMode) {
            var printUri = _uriForLog(options.uri);
            if (printUri.contains('password=')) {
              printUri = printUri.replaceAll(
                RegExp(r'password=[^&]*'),
                'password=***',
              );
            }
            final authHeaderPresent = options.headers.containsKey(
              'Authorization',
            );
            debugPrint('→ ${options.method} $printUri');
            debugPrint(
              '   Dio options: contentType=${options.contentType ?? '(default)'}, '
              'responseType=${options.responseType}, '
              'connectTimeout=${options.connectTimeout}, '
              'sendTimeout=${options.sendTimeout}, '
              'receiveTimeout=${options.receiveTimeout}',
            );
            debugPrint(
              '   Request Headers: ${_headersForLog(options.headers)}',
            );
            debugPrint(
              '   Authorization Header: '
              '${_authorizationForLog(options.headers['Authorization'])}',
            );
            debugPrint('   Request Payload: ${_bodyForLog(options.data)}');
            debugPrint('   Authorization header present: $authHeaderPresent');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}',
            );
            debugPrint(
              '   Response Headers: ${_headersForLog(response.headers.map)}',
            );
            debugPrint(
              '   Response Body: ${_bodyForLog(response.data, contentType: response.headers.value(Headers.contentTypeHeader))}',
            );
          }
          handler.next(response);
        },
        onError: (err, handler) async {
          if (kDebugMode) {
            final authorization = err.requestOptions.headers['Authorization']
                ?.toString();
            debugPrint(
              '‼ HTTP ${err.response?.statusCode ?? 'no response'} '
              '${err.requestOptions.method} ${err.requestOptions.uri}',
            );
            debugPrint(
              '   Authorization present: '
              '${authorization != null && authorization.trim().isNotEmpty}',
            );
            debugPrint(
              '   Request Headers: '
              '${_headersForLog(err.requestOptions.headers)}',
            );
            debugPrint(
              '   Authorization Header: '
              '${_authorizationForLog(err.requestOptions.headers['Authorization'])}',
            );
            debugPrint(
              '   Request Payload: ${_bodyForLog(err.requestOptions.data)}',
            );
            debugPrint('   Dio error: ${err.type} ${err.message}');
            debugPrint(
              '   Request Content-Type: '
              '${err.requestOptions.headers[Headers.contentTypeHeader] ?? '(default)'}; '
              'Accept: '
              '${err.requestOptions.headers[Headers.acceptHeader] ?? '(default)'}; '
              'Response Content-Type: '
              '${err.response?.headers.value(Headers.contentTypeHeader) ?? '(unknown)'}',
            );
            final requestId =
                err.response?.headers.value('x-request-id') ??
                err.response?.headers.value('x-correlation-id');
            if (requestId != null) {
              debugPrint('   Server request ID: $requestId');
            }
            final challenge = err.response?.headers.value('www-authenticate');
            if (challenge != null) {
              debugPrint('   WWW-Authenticate: $challenge');
            }
            if (err.response != null) {
              debugPrint(
                '   Response Headers: '
                '${_headersForLog(err.response!.headers.map)}',
              );
              debugPrint(
                '   Response Body: '
                '${_bodyForLog(err.response!.data, contentType: err.response!.headers.value(Headers.contentTypeHeader))}',
              );
            }
          }
          handler.next(err);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureStorageService _storage;

  String get baseUrl => _dio.options.baseUrl;

  String buildUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$normalizedBase$normalizedPath';
  }

  static ApiClient? _instance;
  factory ApiClient(SecureStorageService storage) {
    _instance ??= ApiClient._(storage);
    return _instance!;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<String> downloadFile(
    String path,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Options? options,
  }) async {
    try {
      await _dio.download(
        path,
        savePath,
        onReceiveProgress: onReceiveProgress,
        options: options,
      );
      return savePath;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Exception _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiException(
        code: 504,
        message: 'Server request timed out. Please try again.',
      );
    }

    final rawMsg = e.message ?? e.error?.toString() ?? '';
    final isConnectionErr =
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown ||
        e.error is SocketException ||
        rawMsg.contains('XMLHttpRequest') ||
        rawMsg.contains('connection errored') ||
        rawMsg.contains('SocketException') ||
        rawMsg.contains('Failed host lookup') ||
        rawMsg.contains('Connection refused') ||
        rawMsg.contains('NetworkError');

    if (isConnectionErr &&
        (e.response == null || e.response?.statusCode == null)) {
      return ApiException(
        code: 503,
        message:
            'Unable to connect to server. Please check your internet or server status and try again.',
      );
    }

    final code = e.response?.statusCode ?? 0;
    String message = 'Network error occurred';
    dynamic errorData = e.response?.data;
    if (errorData is List<int>) {
      try {
        final decoded = utf8.decode(errorData);
        final parsed = jsonDecode(decoded);
        if (parsed is Map && parsed['message'] != null) {
          message = parsed['message'].toString();
          return ApiException(code: code, message: message);
        }
      } catch (_) {}
    }

    if (e.response?.data is Map && e.response?.data['message'] != null) {
      message = e.response!.data['message'].toString();
    } else if (code == 401) {
      message = 'Unauthorized. Please sign in again.';
    } else if (code == 403) {
      message =
          'Access denied. You do not have permission to view this resource.';
    } else if (code == 404) {
      message = 'Resource not found.';
    } else if (code == 500 || code == 502 || code == 503 || code == 504) {
      message =
          'Server is currently unavailable ($code). Please try again later.';
    } else if (rawMsg.contains('XMLHttpRequest') ||
        rawMsg.contains('connection errored')) {
      message =
          'Unable to connect to server. Please check your internet or server status and try again.';
    } else if (e.message != null && e.message!.isNotEmpty) {
      message = e.message.toString();
    }
    return ApiException(code: code, message: message);
  }
}

Map<String, String> _headersForLog(Map<String, dynamic> headers) {
  return headers.map(
    (name, value) => MapEntry(
      name,
      name.toLowerCase() == 'authorization'
          ? _authorizationForLog(value)
          : _isSensitiveLogKey(name)
          ? '[REDACTED]'
          : value.toString(),
    ),
  );
}

String _uriForLog(Uri uri) {
  final queryParameters = uri.queryParametersAll.map(
    (key, values) =>
        MapEntry(key, _isSensitiveLogKey(key) ? const ['[REDACTED]'] : values),
  );
  return uri.replace(queryParameters: queryParameters).toString();
}

String _authorizationForLog(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return '(absent)';
  final header = value.toString().trim();
  final schemeEnd = header.indexOf(' ');
  return schemeEnd > 0
      ? '${header.substring(0, schemeEnd)} [REDACTED]'
      : '[REDACTED]';
}

String _bodyForLog(dynamic body, {String? contentType}) {
  if (body == null) return '(empty)';
  dynamic value = body;
  if (body is List<int>) {
    final type = contentType?.toLowerCase() ?? '';
    if (!type.contains('json') && !type.startsWith('text/')) {
      return '[binary body: ${body.length} bytes]';
    }
    try {
      value = utf8.decode(body);
    } on FormatException {
      return '[non-text body: ${body.length} bytes]';
    }
  }

  try {
    if (value is String) {
      return _boundedLogText(jsonEncode(_redactBodyForLog(jsonDecode(value))));
    }
    return _boundedLogText(jsonEncode(_redactBodyForLog(value)));
  } on FormatException {
    return _boundedLogText(value.toString());
  } on JsonUnsupportedObjectError {
    return _boundedLogText(value.toString());
  }
}

String _boundedLogText(String value) {
  final sanitized = value.replaceAllMapped(
    RegExp(
      r'(authorization|cookie|set-cookie|access[_-]?token|refresh[_-]?token|password|secret|api[_-]?key)\s*[:=]\s*[^\s,;]+',
      caseSensitive: false,
    ),
    (match) => '${match[1]}=[REDACTED]',
  );
  return sanitized.length > 4000
      ? '${sanitized.substring(0, 4000)}... [truncated]'
      : sanitized;
}

dynamic _redactBodyForLog(dynamic value, {String? key}) {
  if (key != null && _isSensitiveLogKey(key)) return '[REDACTED]';
  if (value is Map) {
    return value.map(
      (mapKey, mapValue) => MapEntry(
        mapKey.toString(),
        _redactBodyForLog(mapValue, key: mapKey.toString()),
      ),
    );
  }
  if (value is Iterable) return value.map(_redactBodyForLog).toList();
  return value;
}

bool _isSensitiveLogKey(String key) => RegExp(
  r'authorization|cookie|token|secret|password|api.?key|registration|vehicle.?number|mobile|phone|email|owner',
  caseSensitive: false,
).hasMatch(key);

class NetworkException implements Exception {
  NetworkException(this.message);

  final String message;

  factory NetworkException.fromDio(DioException error) {
    final message =
        error.response?.data?.toString() ??
        error.message ??
        'Unknown network error';
    return NetworkException(message);
  }

  @override
  String toString() => 'NetworkException: $message';
}
