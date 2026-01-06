// infrastructure/network/internal/http_client_impl.dart
//
// Implementation of HTTP client interface for the CustomFit SDK.
// Provides essential network communication with basic error handling.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';

import 'package:dio/dio.dart';

import '../../../config/core/cf_config.dart';
import '../../../core/error/cf_result.dart';
import '../../../core/error/error_category.dart';
import '../../../core/error/cf_error_code.dart';
import '../../logging/logger.dart';
import '../interfaces/http_client.dart';

/// Implementation of HTTP client interface for CustomFit SDK
class HttpClientImpl implements IHttpClient {
  late final Dio _dio;
  final CFConfig _config;

  HttpClientImpl(this._config) {
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _config.baseApiUrl,
      connectTimeout:
          Duration(milliseconds: _config.networkConnectionTimeoutMs),
      receiveTimeout: Duration(milliseconds: _config.networkReadTimeoutMs),
      sendTimeout: Duration(milliseconds: _config.networkConnectionTimeoutMs),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'CustomFit-Flutter-SDK/1.0.0',
        'Authorization': 'Bearer ${_config.clientKey}',
      },
    ));
    // Note: Removed verbose LogInterceptor - using minimal http() logging instead
  }

  /// Perform GET request
  @override
  Future<CFResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      stopwatch.stop();

      Logger.http('GET', path, response.statusCode, stopwatch.elapsedMilliseconds);

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return CFResult.success(response.data as T);
      } else {
        return CFResult.error(
          'HTTP ${response.statusCode}: ${response.statusMessage}',
          category: ErrorCategory.network,
          errorCode: CFErrorCode.networkUnavailable,
          context: {
            'path': path,
            'statusCode': response.statusCode,
            'statusMessage': response.statusMessage,
          },
        );
      }
    } catch (e) {
      stopwatch.stop();
      Logger.http('GET', path, null, stopwatch.elapsedMilliseconds);
      Logger.e('GET $path failed: $e');
      return _handleError(e, 'GET', path);
    }
  }

  /// Perform POST request
  @override
  Future<CFResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      stopwatch.stop();

      Logger.http('POST', path, response.statusCode, stopwatch.elapsedMilliseconds);

      if (response.statusCode == 200 || response.statusCode == 202) {
        return CFResult.success(response.data as T);
      } else {
        final body = response.data?.toString() ?? 'No response body';
        Logger.w('POST $path error: $body');

        return CFResult.error(
          'HTTP ${response.statusCode}: ${response.statusMessage}',
          category: ErrorCategory.network,
          errorCode: CFErrorCode.networkUnavailable,
          context: {
            'path': path,
            'statusCode': response.statusCode,
            'statusMessage': response.statusMessage,
            'responseBody': body,
          },
        );
      }
    } catch (e) {
      stopwatch.stop();
      Logger.http('POST', path, null, stopwatch.elapsedMilliseconds);
      Logger.e('POST $path failed: $e');
      return _handleError(e, 'POST', path);
    }
  }

  /// Perform HEAD request to get response headers
  @override
  Future<CFResult<Response>> headResponse(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.head(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      stopwatch.stop();

      Logger.http('HEAD', path, response.statusCode, stopwatch.elapsedMilliseconds);

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return CFResult.success(response);
      } else {
        return CFResult.error(
          'HTTP ${response.statusCode}: ${response.statusMessage}',
          category: ErrorCategory.network,
          errorCode: CFErrorCode.networkUnavailable,
          context: {
            'path': path,
            'statusCode': response.statusCode,
            'statusMessage': response.statusMessage,
          },
        );
      }
    } catch (e) {
      stopwatch.stop();
      Logger.http('HEAD', path, null, stopwatch.elapsedMilliseconds);
      Logger.e('HEAD $path failed: $e');
      return _handleError(e, 'HEAD', path);
    }
  }

  /// Fetch metadata headers for conditional requests
  @override
  Future<CFResult<Map<String, String>>> fetchMetadata(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final headResult = await headResponse(url, headers: headers);

      if (headResult.isSuccess) {
        final response = headResult.getOrNull()!;
        final metadata = <String, String>{};

        // Extract useful metadata headers
        final responseHeaders = response.headers.map;
        for (final entry in responseHeaders.entries) {
          final key = entry.key.toLowerCase();
          final value = entry.value.isNotEmpty ? entry.value.first : '';

          if (key == 'last-modified' ||
              key == 'etag' ||
              key == 'cache-control' ||
              key == 'content-length' ||
              key == 'content-type') {
            metadata[key] = value;
          }
        }

        return CFResult.success(metadata);
      } else {
        return CFResult.error(
          headResult.getErrorMessage() ?? 'Unknown error',
          category: ErrorCategory.network,
          errorCode: CFErrorCode.networkUnavailable,
        );
      }
    } catch (e) {
      Logger.e('Metadata fetch $url failed: $e');
      return _handleError(e, 'METADATA', url);
    }
  }

  /// Handle errors and convert to CFResult
  CFResult<T> _handleError<T>(dynamic error, String method, String path) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return CFResult.error(
            'Request timeout: ${error.message}',
            exception: error,
            category: ErrorCategory.network,
            errorCode: CFErrorCode.networkTimeout,
            context: {
              'method': method,
              'path': path,
              'errorType': error.type.toString(),
            },
          );

        case DioExceptionType.connectionError:
          return CFResult.error(
            'Connection error: ${error.message}',
            exception: error,
            category: ErrorCategory.network,
            errorCode: CFErrorCode.networkUnavailable,
            context: {
              'method': method,
              'path': path,
              'errorType': error.type.toString(),
            },
          );

        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode ?? 0;
          final statusMessage =
              error.response?.statusMessage ?? 'Unknown error';

          return CFResult.error(
            'HTTP $statusCode: $statusMessage',
            exception: error,
            category: ErrorCategory.network,
            errorCode: _getErrorCodeFromStatus(statusCode),
            context: {
              'method': method,
              'path': path,
              'statusCode': statusCode,
              'statusMessage': statusMessage,
              'responseData': error.response?.data?.toString(),
            },
          );

        default:
          return CFResult.error(
            'Request failed: ${error.message}',
            exception: error,
            category: ErrorCategory.network,
            errorCode: CFErrorCode.networkUnavailable,
            context: {
              'method': method,
              'path': path,
              'errorType': error.type.toString(),
            },
          );
      }
    } else {
      return CFResult.error(
        'Unexpected error: ${error.toString()}',
        exception: error,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalUnknownError,
        context: {
          'method': method,
          'path': path,
        },
      );
    }
  }

  /// Get appropriate error code based on HTTP status
  CFErrorCode _getErrorCodeFromStatus(int statusCode) {
    if (statusCode >= 400 && statusCode < 500) {
      return CFErrorCode.httpUnauthorized;
    } else if (statusCode >= 500) {
      return CFErrorCode.httpInternalServerError;
    } else {
      return CFErrorCode.networkUnavailable;
    }
  }

  /// Close the HTTP client and clean up resources
  @override
  void close() {
    _dio.close();
  }
}
