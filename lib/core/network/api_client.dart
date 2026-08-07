// Replaced long mock responses with production-ready ApiClient using Dio
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../storage/secure_storage_service.dart';

class ApiException implements Exception {
  ApiException({required this.code, required this.message});
  final int code;
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._(this._storage)
    : _dio = Dio(
        BaseOptions(
          baseUrl: 'https://tgrta-anpr.in/api',
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
    if (!kIsWeb) {
      if (_dio.httpClientAdapter is IOHttpClientAdapter) {
        (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        };
      }
    }
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await _storage.readToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {}
          if (kDebugMode) {
            var printUri = options.uri.toString();
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
            debugPrint('   Authorization header present: $authHeaderPresent');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}',
            );
            debugPrint('   Response: ${response.data}');
          }
          handler.next(response);
        },
        onError: (err, handler) async {
          if (kDebugMode) {
            debugPrint('‼ ${err.type} ${err.message}');
            debugPrint(
              '   Request: ${err.requestOptions.method} ${err.requestOptions.uri}',
            );
            debugPrint(
              '   Response: ${err.response?.statusCode} ${err.response?.data}',
            );
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
      return await _dio.get<T>(path, queryParameters: queryParameters, options: options);
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
