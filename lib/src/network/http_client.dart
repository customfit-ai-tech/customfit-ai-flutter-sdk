// lib/src/network/http_client.dart
//
// HTTP client implementation with connection pooling, retry logic, and network awareness.
// Handles all network communication for the CustomFit SDK including feature flag fetching,
// event tracking, and summary reporting with proper error handling and backoff strategies.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import '../config/core/cf_config.dart';
import '../core/error/cf_result.dart';
import '../core/error/error_category.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../core/error/cf_error_code.dart';
import '../core/util/exponential_backoff.dart';
import '../constants/cf_constants.dart';
import '../logging/logger.dart';
// import '../di/interfaces/http_client_interface.dart'; // Interface removed

/// Connection pool metrics for monitoring
class ConnectionPoolMetrics {
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  int activeConnections = 0;
  DateTime lastUpdated = DateTime.now();

  double get successRate =>
      totalRequests > 0 ? successfulRequests / totalRequests : 0.0;

  Map<String, dynamic> toJson() => {
        'totalRequests': totalRequests,
        'successfulRequests': successfulRequests,
        'failedRequests': failedRequests,
        'activeConnections': activeConnections,
        'successRate': successRate,
        'lastUpdated': lastUpdated.toIso8601String(),
      };
}

/// HTTP client implementation mirroring Kotlin's HttpClient with connection pooling
class HttpClient {
  static const String _source = 'HttpClient';
  final CFConfig _config;
  late final Dio _dio;
  int _connectionTimeoutMs;
  int _readTimeoutMs;
  final ConnectionPoolMetrics _connectionMetrics = ConnectionPoolMetrics();

  HttpClient(this._config)
      : _connectionTimeoutMs = _config.networkConnectionTimeoutMs,
        _readTimeoutMs = _config.networkReadTimeoutMs {
    _initializeDio();
  }

  /// Test constructor that allows injecting a Dio instance
  @visibleForTesting
  HttpClient.withDio(this._config, Dio dio)
      : _connectionTimeoutMs = _config.networkConnectionTimeoutMs,
        _readTimeoutMs = _config.networkReadTimeoutMs,
        _dio = dio {
    // Ensure the injected Dio instance has proper response type
    _dio.options.responseType = ResponseType.json;
    _setupCertificatePinning();
    _setupInterceptors();
  }

  void _initializeDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: _connectionTimeoutMs),
      receiveTimeout: Duration(milliseconds: _readTimeoutMs),
      sendTimeout: Duration(
          milliseconds:
              _readTimeoutMs), // Add send timeout for POST/PUT requests
      headers: {
        // Don't set Content-Type globally - only set it for requests with bodies (POST, PUT)
        // Test with standard browser User-Agent to see if custom SDK agent is being blocked
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Connection': 'keep-alive',
      },
      // Connection pooling configuration
      persistentConnection: true,
      maxRedirects: 3,
      // Ensure proper response handling
      responseType: ResponseType.json,
      // Accept all status codes to handle error responses properly
      // This ensures we can read error response bodies
      validateStatus: (status) => true,
    ));

    _setupCertificatePinning();
    _setupInterceptors();

    Logger.i(
        'HttpClient initialized with connectTimeout=$_connectionTimeoutMs ms, readTimeout=$_readTimeoutMs ms, connection pooling enabled');

    if (_config.certificatePinningEnabled) {
      Logger.i(
          'Certificate pinning enabled with ${_config.pinnedCertificates.length} pinned certificates');
    }
  }

  void _setupCertificatePinning() {
    if (!_config.certificatePinningEnabled || kIsWeb) {
      // Certificate pinning is not supported on web
      return;
    }

    // Get the HTTP client adapter
    final httpClientAdapter = _dio.httpClientAdapter;
    if (httpClientAdapter is IOHttpClientAdapter) {
      httpClientAdapter.createHttpClient = () {
        final client = io.HttpClient();

        // Configure certificate validation
        client.badCertificateCallback = (cert, host, port) {
          if (_config.allowSelfSignedCertificates) {
            Logger.w(
                'Allowing self-signed certificate for $host:$port (development mode)');
            return true;
          }

          // Calculate SHA-256 fingerprint of the certificate
          final certDer = cert.der;
          final certSha256 = sha256.convert(certDer);
          final certFingerprint = 'sha256/${base64.encode(certSha256.bytes)}';

          // Check if the certificate fingerprint matches any pinned certificates
          final isPinned = _config.pinnedCertificates.contains(certFingerprint);

          if (!isPinned) {
            Logger.e('Certificate pinning failed for $host:$port');
            Logger.e('Certificate fingerprint: $certFingerprint');
            Logger.e(
                'Expected one of: ${_config.pinnedCertificates.join(", ")}');

            // Track certificate pinning failure
            ErrorHandler.handleError(
              'Certificate pinning validation failed for $host:$port. Fingerprint: $certFingerprint',
              source: _source,
              category: ErrorCategory.network,
              severity: ErrorSeverity.critical,
            );
          }

          return isPinned;
        };

        return client;
      };
    }
  }

  void _setupInterceptors() {
    // Don't use custom transformer for now - it causes issues with streaming
    // _dio.transformer = _CustomTransformer();

    // Add custom interceptor for full request/response/error logging and metrics
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Don't log HEAD requests here - they'll be logged in _headInternal
          if (options.method != 'HEAD') {
            Logger.d('EXECUTING ${options.method} ${options.uri}');
          }
          _updateConnectionMetrics(isStarting: true);

          // Remove Accept-Encoding headers to avoid gzip issues
          // The server sends gzipped responses when these headers are present,
          // but some Flutter HTTP clients don't handle decompression properly
          options.headers.remove('Accept-Encoding');
          options.headers.remove('accept-encoding');

          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Only log as successful for actual success status codes
          if (response.statusCode != null &&
              response.statusCode! >= 200 &&
              response.statusCode! < 300) {
            // Don't log HEAD responses here - they'll be logged in _headInternal
            if (response.requestOptions.method != 'HEAD') {
              Logger.d(
                  '${response.requestOptions.method} SUCCESSFUL: ${response.statusCode}');
            }
            _updateConnectionMetrics(isStarting: false, success: true);
          } else {
            // Don't log HEAD errors here - they'll be logged in _headInternal
            if (response.requestOptions.method != 'HEAD') {
              Logger.w(
                  '${response.requestOptions.method} ERROR: ${response.statusCode}');
            }
            _updateConnectionMetrics(isStarting: false, success: false);
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          // Don't log HEAD errors here - they'll be logged in _headInternal
          if (e.requestOptions.method != 'HEAD') {
            Logger.e('${e.requestOptions.method} FAILED: ${e.message}');
          }
          _updateConnectionMetrics(isStarting: false, success: false);

          // Add specific debug logging for 400 errors on config endpoint
          if (e.response?.statusCode == 400 &&
              e.requestOptions.path.contains("user_configs")) {
            Logger.e('=== DIO ERROR INTERCEPTOR: CONFIG 400 ERROR ===');
            Logger.e('URL: ${e.requestOptions.uri}');
            Logger.e('Method: ${e.requestOptions.method}');
            Logger.e('Request Headers: ${e.requestOptions.headers}');
            Logger.e('Request Data: ${e.requestOptions.data}');
            Logger.e('Response Status: ${e.response?.statusCode}');
            Logger.e('Response Data: ${e.response?.data}');
            Logger.e('===========================================');
          }

          // Try to extract error response body
          String? errorBody;
          if (e.response != null && e.response!.data != null) {
            try {
              if (e.response!.data is String) {
                errorBody = e.response!.data as String;
              } else if (e.response!.data is Map) {
                errorBody = jsonEncode(e.response!.data);
              } else {
                errorBody = e.response!.data.toString();
              }
            } catch (err) {
              errorBody = 'Failed to parse error response: $err';
            }
          }

          if (errorBody != null && errorBody.isNotEmpty) {
            Logger.e('Error response body: $errorBody');
          }

          // Determine error code based on error type
          final CFErrorCode errorCode = _getErrorCodeFromException(e);

          ErrorHandler.handleError(
            '${e.requestOptions.method} request failed: ${e.message}',
            source: _source,
            category: ErrorCategory.network,
            severity: errorCode.severity,
          );
          return handler.next(e);
        },
      ),
    );
  }

  /// Update connection timeout
  void updateConnectionTimeout(int timeoutMs) {
    if (timeoutMs <= 0) throw ArgumentError('Timeout must be > 0');
    _connectionTimeoutMs = timeoutMs;
    _dio.options.connectTimeout = Duration(milliseconds: timeoutMs);
    Logger.d('Updated connection timeout to $timeoutMs ms');
  }

  /// Update read timeout
  void updateReadTimeout(int timeoutMs) {
    if (timeoutMs <= 0) throw ArgumentError('Timeout must be > 0');
    _readTimeoutMs = timeoutMs;
    _dio.options.receiveTimeout = Duration(milliseconds: timeoutMs);
    _dio.options.sendTimeout =
        Duration(milliseconds: timeoutMs); // Update send timeout as well
    Logger.d('Updated read timeout to $timeoutMs ms');
  }

  /// GET request for metadata (Last-Modified, ETag) with retry
  Future<CFResult<Map<String, String>>> fetchMetadata(String url,
      {String? lastModified, String? etag}) async {
    return ExponentialBackoff.retry(
      operation: () =>
          _fetchMetadataInternal(url, lastModified: lastModified, etag: etag),
      operationName: 'fetchMetadata($url)',
    );
  }

  Future<CFResult<Map<String, String>>> _fetchMetadataInternal(String url,
      {String? lastModified, String? etag}) async {
    try {
      // Silent - metadata requests are routine polling

      // Use appropriate headers for file download, not JSON API
      final headers = {
        'Cache-Control': 'no-cache',
        // Don't send Content-Type for GET requests - that's for request bodies
        // Don't send application/json for static file requests
      };

      // Add conditional request headers if available
      if (lastModified != null &&
          lastModified.isNotEmpty &&
          lastModified != 'unchanged') {
        headers['If-Modified-Since'] = lastModified;
      }

      if (etag != null && etag.isNotEmpty && etag != 'unchanged') {
        headers['If-None-Match'] = etag;
      }

      final options = Options(
        headers: headers,
        // Set validateStatus to accept 304 Not Modified responses
        validateStatus: (status) =>
            status != null && (status >= 200 && status < 300 || status == 304),
      );

      // Use timeout wrapper for better timeout handling
      final resp = await _executeWithTimeout(
        (cancelToken) =>
            _dio.get(url, options: options, cancelToken: cancelToken),
        'GET metadata $url',
      );

      // Handle 304 Not Modified (return the same headers)
      if (resp.statusCode == 304) {
        // Silent - 304 Not Modified is expected
        return CFResult.success({
          CFConstants.http.headerLastModified: lastModified ?? 'unchanged',
          CFConstants.http.headerEtag: etag ?? 'unchanged',
        });
      }

      // Handle 200 OK with headers
      if (resp.statusCode == 200) {
        final headers = resp.headers;
        final resultHeaders = {
          CFConstants.http.headerLastModified:
              headers.value('Last-Modified') ?? '',
          CFConstants.http.headerEtag: headers.value('ETag') ?? '',
        };
        // Silent - successful metadata retrieval is routine
        return CFResult.success(resultHeaders);
      } else {
        final msg = 'Failed to fetch metadata from $url: ${resp.statusCode}';
        Logger.w('GET METADATA FAILED: $msg');
        final errorCode = CFErrorCode.fromHttpStatus(resp.statusCode ?? 0) ??
            CFErrorCode.networkUnavailable;
        ErrorHandler.handleError(msg,
            source: _source,
            category: ErrorCategory.network,
            severity: errorCode.severity);
        return CFResult.error(msg,
            code: resp.statusCode ?? 0,
            category: ErrorCategory.network,
            errorCode: errorCode);
      }
    } catch (e) {
      Logger.e('GET METADATA FAILED: ${e.toString()}');
      final errorCode = _getErrorCodeFromException(e);
      ErrorHandler.handleException(e, 'Error fetching metadata from $url',
          source: _source, severity: errorCode.severity);
      return CFResult.error('Network error fetching metadata from $url',
          exception: e,
          category: ErrorCategory.network,
          errorCode: errorCode,
          context: {'url': url});
    }
  }

  /// GET request for a JSON object with retry
  Future<CFResult<Map<String, dynamic>>> fetchJson(String url) async {
    return ExponentialBackoff.retry(
      operation: () => _fetchJsonInternal(url),
      operationName: 'fetchJson($url)',
    );
  }

  Future<CFResult<Map<String, dynamic>>> _fetchJsonInternal(String url) async {
    try {
      // Silent - GET requests are routine
      // Use timeout wrapper for better timeout handling
      final resp = await _executeWithTimeout(
        (cancelToken) => _dio.get(url, cancelToken: cancelToken),
        'GET JSON $url',
      );
      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is Map<String, dynamic>) {
          // Silent - successful GET is routine
          return CFResult.success(data);
        } else {
          final msg = 'Parsed JSON from $url is not an object';
          Logger.w('GET JSON FAILED: $msg');
          ErrorHandler.handleError(msg,
              source: _source,
              category: ErrorCategory.serialization,
              severity: ErrorSeverity.medium);
          return CFResult.error(msg, category: ErrorCategory.serialization);
        }
      } else {
        final msg = 'Failed to fetch JSON from $url: ${resp.statusCode}';
        Logger.w('GET JSON FAILED: $msg');
        final errorCode = CFErrorCode.fromHttpStatus(resp.statusCode ?? 0) ??
            CFErrorCode.networkUnavailable;
        ErrorHandler.handleError(msg,
            source: _source,
            category: ErrorCategory.network,
            severity: errorCode.severity);
        return CFResult.error(msg,
            code: resp.statusCode ?? 0,
            category: ErrorCategory.network,
            errorCode: errorCode,
            context: {'url': url});
      }
    } catch (e) {
      Logger.e('GET JSON FAILED: ${e.toString()}');
      final errorCode = _getErrorCodeFromException(e);
      ErrorHandler.handleException(e, 'Error fetching JSON from $url',
          source: _source, severity: errorCode.severity);
      return CFResult.error('Network error fetching JSON from $url',
          exception: e,
          category: ErrorCategory.network,
          errorCode: errorCode,
          context: {'url': url});
    }
  }

  /// POST raw JSON string with retry
  Future<CFResult<bool>> postJson(String url, String payload) async {
    return ExponentialBackoff.retry(
      operation: () => _postJsonInternal(url, payload),
      operationName: 'postJson($url)',
      config: RetryConfig(
        maxAttempts: 3,
        // Don't retry POST requests as aggressively
        retryableErrors: {
          CFErrorCode.networkTimeout,
          CFErrorCode.httpServiceUnavailable,
          CFErrorCode.httpGatewayTimeout,
          CFErrorCode.httpBadGateway,
        },
      ),
    );
  }

  Future<CFResult<bool>> _postJsonInternal(String url, String payload) async {
    try {
      Logger.d('EXECUTING POST JSON REQUEST');

      // Log the request details based on endpoint type
      if (url.contains("summary")) {
        Logger.i('📊 SUMMARY HTTP: POST request');
        Logger.i('📊 SUMMARY HTTP: Request body:');
        Logger.i(_prettyPrintJson(payload));
        Logger.i('📊 SUMMARY HTTP: Request body size: ${payload.length} bytes');
      } else if (url.contains("events") || url.contains("cfe")) {
        Logger.i('🔔 TRACK HTTP: POST request to event API');
        Logger.i('🔔 TRACK HTTP: Request body:');
        Logger.i(_prettyPrintJson(payload));
        Logger.i('🔔 TRACK HTTP: Request body size: ${payload.length} bytes');
      } else {
        Logger.i('📮 HTTP: POST request to $url');
        Logger.i('📮 HTTP: Request body:');
        Logger.i(_prettyPrintJson(payload));
      }

      // Use timeout wrapper for better timeout handling
      final resp = await _executeWithTimeout(
        (cancelToken) => _dio.post(
          url,
          data: payload,
          cancelToken: cancelToken,
          options: Options(headers: {
            CFConstants.http.headerContentType: CFConstants.http.contentTypeJson
          }),
        ),
        'POST $url',
      );

      if (resp.statusCode == 200 || resp.statusCode == 202) {
        // Log the response details based on endpoint type
        // Silent - successful responses are routine
        if (url.contains("summary")) {
          Logger.d('📊 SUMMARY: sent (${resp.statusCode})');
        } else if (url.contains("events") || url.contains("cfe")) {
          Logger.d('🔔 TRACK: sent (${resp.statusCode})');
        }

        // Silent - POST success is routine
        return CFResult.success(true);
      } else {
        final body = resp.data?.toString() ?? 'No error body';

        // Log the error details based on endpoint type
        if (url.contains("summary")) {
          Logger.w('📊 SUMMARY HTTP: Error code: ${resp.statusCode}');
          Logger.w('📊 SUMMARY HTTP: Error body: $body');
        } else if (url.contains("events") || url.contains("cfe")) {
          Logger.w('🔔 TRACK HTTP: Error code: ${resp.statusCode}');
          Logger.w('🔔 TRACK HTTP: Error body: $body');
        }

        // Use our error handling system
        final msg = 'API error response: $body';
        Logger.w('POST JSON FAILED: $msg');
        final errorCode = CFErrorCode.fromHttpStatus(resp.statusCode ?? 0) ??
            CFErrorCode.networkUnavailable;
        ErrorHandler.handleError(
          msg,
          source: _source,
          category: ErrorCategory.network,
          severity: errorCode.severity,
        );

        Logger.e('Error: $body');
        return CFResult.error(msg,
            code: resp.statusCode ?? 0,
            category: ErrorCategory.network,
            errorCode: errorCode,
            context: {'url': url, 'response': body});
      }
    } catch (e) {
      if (url.contains("summary")) {
        Logger.e('📊 SUMMARY HTTP: Exception: ${e.toString()}');
      } else if (url.contains("events") || url.contains("cfe")) {
        Logger.e('🔔 TRACK HTTP: Exception: ${e.toString()}');
      }

      // Handle DioException specially to extract error response
      if (e is DioException && e.response != null) {
        final statusCode = e.response!.statusCode ?? 0;
        String errorBody = 'No error body';

        try {
          // Try to extract the error response body
          if (e.response!.data != null) {
            if (e.response!.data is String) {
              errorBody = e.response!.data as String;
            } else if (e.response!.data is Map) {
              errorBody = jsonEncode(e.response!.data);
            } else {
              errorBody = e.response!.data.toString();
            }
          }
        } catch (parseError) {
          errorBody = 'Failed to parse error response: $parseError';
        }

        final msg = 'API error response: $errorBody';
        Logger.e('POST JSON FAILED: $msg');

        final errorCode = CFErrorCode.fromHttpStatus(statusCode) ??
            CFErrorCode.networkUnavailable;
        ErrorHandler.handleError(
          msg,
          source: _source,
          category: ErrorCategory.network,
          severity: errorCode.severity,
        );

        return CFResult.error(msg,
            code: statusCode,
            category: ErrorCategory.network,
            errorCode: errorCode,
            context: {'url': url, 'response': errorBody});
      }

      Logger.e('POST JSON FAILED: ${e.toString()}');
      final errorCode = _getErrorCodeFromException(e);
      ErrorHandler.handleException(
        e,
        'Failed to read API response',
        source: _source,
        severity: errorCode.severity,
      );
      return CFResult.error('Failed to read API response',
          exception: e,
          category: ErrorCategory.network,
          errorCode: errorCode,
          context: {'url': url});
    }
  }

  /// Generic POST with dynamic body & query with retry
  Future<CFResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    return ExponentialBackoff.retry(
      operation: () => _postInternal<T>(path,
          data: data, headers: headers, queryParameters: queryParameters),
      operationName: 'post($path)',
      config: RetryConfig(
        maxAttempts: 3,
        // Don't retry POST requests as aggressively
        retryableErrors: {
          CFErrorCode.networkTimeout,
          CFErrorCode.httpServiceUnavailable,
          CFErrorCode.httpGatewayTimeout,
          CFErrorCode.httpBadGateway,
        },
      ),
    );
  }

  Future<CFResult<T>> _postInternal<T>(
    String path, {
    dynamic data,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      // Silent - POST execution is routine

      // Determine if this is a tracking or summary request
      final bool isTracking = path.contains("events") || path.contains("cfe");
      final bool isSummary = path.contains("summary");

      // Log request body size only
      if (data != null) {
        final bodySize = data.toString().length;

        if (isTracking) {
          Logger.d('🔔 TRACK HTTP: POST request ($bodySize bytes)');
        } else if (isSummary) {
          Logger.d('📊 SUMMARY HTTP: POST request ($bodySize bytes)');
        } else {
          // Log for other POST requests at debug level
          Logger.d('📮 HTTP: POST to $path ($bodySize bytes)');
        }
      } else {
        if (isTracking) {
          Logger.d('🔔 TRACK HTTP: POST request (no body)');
        } else if (isSummary) {
          Logger.d('📊 SUMMARY HTTP: POST request (no body)');
        } else {
          Logger.i('📮 HTTP: POST request to $path (no body)');
        }
      }

      // Use timeout wrapper for better timeout handling
      final resp = await _executeWithTimeout(
        (cancelToken) => _dio.post(
          path,
          data: data,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
          options: Options(headers: headers),
        ),
        'POST $path',
      );

      if (resp.statusCode == 200 ||
          resp.statusCode == 202 ||
          resp.statusCode == 304) {
        // Silent - successful responses are routine
        if (isTracking) {
          Logger.d('🔔 TRACK: sent (${resp.statusCode})');
        } else if (isSummary) {
          Logger.d('📊 SUMMARY: sent (${resp.statusCode})');
        }

        // Silent - POST success is routine
        return CFResult.success(resp.data as T);
      } else {
        final body = resp.data?.toString() ?? 'No error body';
        final msg = 'Error POST $path: ${resp.statusCode}';

        // Add specific debug logging for 400 errors on config endpoint
        if (resp.statusCode == 400 && path.contains("user_configs")) {
          Logger.e('=== CONFIG FETCH 400 ERROR DEBUG ===');
          Logger.e('URL: $path');
          Logger.e('Response Status: ${resp.statusCode}');
          Logger.e('Response Body: $body');
          Logger.e('Request Headers: $headers');
          if (data != null) {
            Logger.e('Request Data:');
            Logger.e(_prettyPrintJson(data));
          }
          Logger.e('====================================');
        }

        // Add specific debug logging for 400 errors on summary endpoint
        if (resp.statusCode == 400 && path.contains("summary")) {
          Logger.e('=== SUMMARY API 400 ERROR DEBUG ===');
          Logger.e('URL: $path');
          Logger.e('Response Status: ${resp.statusCode}');
          Logger.e('Response Body: $body');
          Logger.e('Request Headers: $headers');
          if (data != null) {
            Logger.e('Request Data:');
            Logger.e(_prettyPrintJson(data));
          }
          Logger.e('=====================================');
        }

        if (isTracking) {
          Logger.w('🔔 TRACK HTTP: Error code: ${resp.statusCode}');
          Logger.w('🔔 TRACK HTTP: Error body: $body');
        } else if (isSummary) {
          Logger.w('📊 SUMMARY HTTP: Error code: ${resp.statusCode}');
          Logger.w('📊 SUMMARY HTTP: Error body: $body');

          // Add detailed logging for 400 errors on summary endpoint
          if (resp.statusCode == 400) {
            Logger.e('=== SUMMARY API 400 ERROR (Exception) ===');
            Logger.e('URL: $path');
            Logger.e('Response Status: $resp.statusCode');
            Logger.e('Response Body: $body');
            Logger.e('Response Headers: ${resp.headers}');
            if (data != null) {
              Logger.e('Request Data:');
              Logger.e(_prettyPrintJson(data));
            }
            Logger.e('========================================');
          }
        }

        final errorCode = CFErrorCode.fromHttpStatus(resp.statusCode ?? 0) ??
            CFErrorCode.networkUnavailable;
        ErrorHandler.handleError('$msg – $body',
            source: _source,
            category: ErrorCategory.network,
            severity: errorCode.severity);
        Logger.e('Error: $body');
        return CFResult.error(msg,
            code: resp.statusCode ?? 0,
            category: ErrorCategory.network,
            errorCode: errorCode,
            context: {'url': path, 'method': 'POST', 'response': body});
      }
    } catch (e) {
      final bool isTracking = path.contains("events") || path.contains("cfe");
      final bool isSummary = path.contains("summary");

      if (isTracking) {
        Logger.e('🔔 TRACK HTTP: Exception: ${e.toString()}');
      } else if (isSummary) {
        Logger.e('📊 SUMMARY HTTP: Exception: ${e.toString()}');
      }

      // Handle DioException specially to extract error response
      if (e is DioException && e.response != null) {
        final statusCode = e.response!.statusCode ?? 0;
        String errorBody = 'No error body';

        try {
          // Try to extract the error response body
          if (e.response!.data != null) {
            if (e.response!.data is String) {
              errorBody = e.response!.data as String;
            } else if (e.response!.data is Map) {
              errorBody = jsonEncode(e.response!.data);
            } else {
              errorBody = e.response!.data.toString();
            }
          }
        } catch (parseError) {
          errorBody = 'Failed to parse error response: $parseError';
        }

        final msg = 'Error POST $path: $statusCode';

        if (isTracking) {
          Logger.w('🔔 TRACK HTTP: Error code: $statusCode');
          Logger.w('🔔 TRACK HTTP: Error body: $errorBody');
        } else if (isSummary) {
          Logger.w('📊 SUMMARY HTTP: Error code: $statusCode');
          Logger.w('📊 SUMMARY HTTP: Error body: $errorBody');

          // Add detailed logging for 400 errors on summary endpoint
          if (statusCode == 400) {
            Logger.e('=== SUMMARY API 400 ERROR (Exception) ===');
            Logger.e('URL: $path');
            Logger.e('Response Status: $statusCode');
            Logger.e('Response Body: $errorBody');
            Logger.e('Response Headers: ${e.response!.headers}');
            if (data != null) {
              Logger.e('Request Data:');
              Logger.e(_prettyPrintJson(data));
            }
            Logger.e('========================================');
          }
        }

        final errorCode = CFErrorCode.fromHttpStatus(statusCode) ??
            CFErrorCode.networkUnavailable;
        ErrorHandler.handleError('$msg – $errorBody',
            source: _source,
            category: ErrorCategory.network,
            severity: errorCode.severity);
        Logger.e('Error: $errorBody');
        return CFResult.error(msg,
            code: statusCode,
            category: ErrorCategory.network,
            errorCode: errorCode,
            context: {'url': path, 'method': 'POST', 'response': errorBody});
      }

      final errorCode = _getErrorCodeFromException(e);
      ErrorHandler.handleException(e, 'Error POST $path',
          source: _source, severity: errorCode.severity);
      return CFResult.error('Network error POST $path: ${e.toString()}',
          exception: e,
          category: ErrorCategory.network,
          errorCode: errorCode,
          context: {'url': path, 'method': 'POST', 'data': data});
    }
  }

  /// HEAD request to efficiently check for metadata changes without downloading the full response body with retry
  Future<CFResult<Map<String, String>>> head(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    return ExponentialBackoff.retry(
      operation: () => _headInternal(path,
          headers: headers, queryParameters: queryParameters),
      operationName: 'head($path)',
    );
  }

  Future<CFResult<Map<String, String>>> _headInternal(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final headOptions = Options(
        headers: headers ??
            {
              'Cache-Control': 'no-cache',
            },
      );

      // Use timeout wrapper for better timeout handling
      final resp = await _executeWithTimeout(
        (cancelToken) => _dio.head(
          path,
          queryParameters: queryParameters,
          options: headOptions,
          cancelToken: cancelToken,
        ),
        'HEAD $path',
      );

      if (resp.statusCode == 200) {
        // Extract headers
        final responseHeaders = resp.headers;

        // Log important headers for caching
        final lastModified = responseHeaders.value('Last-Modified');
        final etag = responseHeaders.value('ETag');

        // Only log HEAD requests if they have meaningful changes
        // Silent for routine polling with no changes

        return CFResult.success({
          'Last-Modified': lastModified ?? '',
          'ETag': etag ?? '',
        });
      } else {
        // Only log HEAD failures if they're not routine 304s
        if (resp.statusCode != 304) {
          Logger.w('API POLL: HEAD $path - Failed (${resp.statusCode})');
        }
        final errorCode = CFErrorCode.fromHttpStatus(resp.statusCode ?? 0) ??
            CFErrorCode.networkUnavailable;
        return CFResult.error(
            'HEAD request failed with code: ${resp.statusCode}',
            code: resp.statusCode ?? 0,
            category: ErrorCategory.network,
            errorCode: errorCode,
            context: {'url': path});
      }
    } catch (e) {
      // Log HEAD exceptions at debug level unless it's a real error
      if (e is DioException && e.type == DioExceptionType.connectionError) {
        Logger.d('API POLL: HEAD request failed (network issue)');
      } else {
        Logger.e('API POLL: HEAD $path - Exception: ${e.toString()}');
      }
      final errorCode = _getErrorCodeFromException(e);
      return CFResult.error(
          'HEAD request failed with exception: ${e.toString()}',
          exception: e,
          category: ErrorCategory.network,
          errorCode: errorCode,
          context: {'url': path});
    }
  }

  /// Get connection pool metrics for monitoring
  Map<String, dynamic> getConnectionPoolMetrics() {
    return _connectionMetrics.toJson();
  }

  /// Update connection pool metrics
  void _updateConnectionMetrics({required bool isStarting, bool? success}) {
    if (isStarting) {
      _connectionMetrics.totalRequests++;
      _connectionMetrics.activeConnections++;
    } else {
      _connectionMetrics.activeConnections =
          (_connectionMetrics.activeConnections - 1)
              .clamp(0, double.infinity)
              .toInt();
      if (success == true) {
        _connectionMetrics.successfulRequests++;
      } else if (success == false) {
        _connectionMetrics.failedRequests++;
      }
    }
    _connectionMetrics.lastUpdated = DateTime.now();
  }

  /// Execute operation with comprehensive timeout handling
  Future<T> _executeWithTimeout<T>(
    Future<T> Function(CancelToken cancelToken) operation,
    String operationName, {
    Duration? customTimeout,
  }) async {
    final CancelToken cancelToken = CancelToken();

    // Determine appropriate timeout based on operation type
    Duration timeout;
    if (customTimeout != null) {
      timeout = customTimeout;
    } else if (operationName.contains('events') ||
        operationName.contains('cfe')) {
      // Event tracking should be faster to avoid blocking user experience
      timeout =
          Duration(milliseconds: CFConstants.network.eventTrackingTimeoutMs);
    } else if (operationName.contains('metadata') ||
        operationName.contains('HEAD')) {
      // Metadata polling should be quick
      timeout =
          Duration(milliseconds: CFConstants.network.metadataPollingTimeoutMs);
    } else if (operationName.contains('config') ||
        operationName.contains('settings')) {
      // Critical operations get more time
      timeout = Duration(
          milliseconds: CFConstants.network.criticalOperationTimeoutMs);
    } else {
      // Default timeout for other operations
      timeout = Duration(milliseconds: _connectionTimeoutMs + _readTimeoutMs);
    }

    try {
      return await operation(cancelToken).timeout(
        timeout,
        onTimeout: () {
          cancelToken
              .cancel('Operation timed out after ${timeout.inMilliseconds}ms');
          throw TimeoutException(
            'Network operation "$operationName" timed out after ${timeout.inMilliseconds}ms',
            timeout,
          );
        },
      );
    } on TimeoutException {
      Logger.e(
          '⏰ TIMEOUT: $operationName exceeded ${timeout.inMilliseconds}ms');
      rethrow;
    } catch (e) {
      // Handle cancellation due to timeout
      if (e.toString().contains('cancelled') ||
          e.toString().contains('timeout')) {
        Logger.e('⏰ TIMEOUT: $operationName was cancelled due to timeout');
        throw TimeoutException(
          'Network operation "$operationName" was cancelled due to timeout',
          timeout,
        );
      }
      rethrow;
    }
  }

  /// Cleanup connection pool resources
  void cleanup() {
    _dio.close();
    // Silent - connection pool cleanup is routine
  }

  /// Helper method to pretty-print JSON for logging
  String _prettyPrintJson(dynamic data) {
    try {
      if (data is String) {
        // If it's already a JSON string, decode and re-encode with formatting
        final decoded = jsonDecode(data);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } else if (data is Map || data is List) {
        // If it's a Map or List, encode with formatting
        return const JsonEncoder.withIndent('  ').convert(data);
      } else {
        // For other types, just convert to string
        return data.toString();
      }
    } catch (e) {
      // If pretty-printing fails, fall back to regular encoding
      try {
        return data is String ? data : jsonEncode(data);
      } catch (_) {
        return data.toString();
      }
    }
  }

  /// Get error code from exception
  CFErrorCode _getErrorCodeFromException(dynamic e) {
    // Handle TimeoutException first (thrown by our timeout wrapper)
    if (e is TimeoutException) {
      return CFErrorCode.networkTimeout;
    }

    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return CFErrorCode.networkTimeout;
        case DioExceptionType.connectionError:
          // Check for DNS failures
          if (e.error != null) {
            final errorString = e.error.toString();
            if (errorString.contains('Failed host lookup') ||
                errorString.contains('getaddrinfo') ||
                errorString.contains('ENOTFOUND') ||
                errorString.contains('nodename nor servname provided')) {
              return CFErrorCode.networkDnsFailure;
            } else if (errorString.contains('Connection reset') ||
                errorString.contains('Connection closed')) {
              return CFErrorCode.networkConnectionLost;
            } else if (errorString.contains('Network is unreachable') ||
                errorString.contains('No internet connection')) {
              return CFErrorCode.networkUnavailable;
            }
          }
          // Check message as fallback
          if (e.message != null) {
            if (e.message!.contains('getaddrinfo') ||
                e.message!.contains('ENOTFOUND')) {
              return CFErrorCode.networkDnsFailure;
            } else if (e.message!.contains('No internet connection') ||
                e.message!.contains('Proxy connection failed')) {
              return CFErrorCode.networkUnavailable;
            }
          }
          if (e.message?.contains('SocketException') ?? false) {
            return CFErrorCode.networkUnavailable;
          }
          return CFErrorCode.networkConnectionLost;
        case DioExceptionType.badCertificate:
          return CFErrorCode.networkSslError;
        case DioExceptionType.badResponse:
          if (e.response != null) {
            return CFErrorCode.fromHttpStatus(e.response!.statusCode ?? 0) ??
                CFErrorCode.networkUnavailable;
          }
          return CFErrorCode.networkUnavailable;
        case DioExceptionType.cancel:
          return CFErrorCode.networkConnectionLost;
        case DioExceptionType.unknown:
          return CFErrorCode.networkUnavailable;
      }
    }
    return CFErrorCode.networkUnavailable;
  }

  /// GET request implementation for interface
  Future<CFResult<T>> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      // Use timeout wrapper for better timeout handling
      final resp = await _executeWithTimeout(
        (cancelToken) => _dio.get(
          path,
          queryParameters: queryParameters,
          options: Options(headers: headers),
          cancelToken: cancelToken,
        ),
        'GET $path',
      );

      if (resp.statusCode == 200) {
        return CFResult.success(resp.data as T);
      } else {
        final errorCode = CFErrorCode.fromHttpStatus(resp.statusCode ?? 0) ??
            CFErrorCode.networkUnavailable;
        return CFResult.error(
          'GET request failed with status ${resp.statusCode}',
          code: resp.statusCode ?? 0,
          category: ErrorCategory.network,
          errorCode: errorCode,
        );
      }
    } catch (e) {
      final errorCode = _getErrorCodeFromException(e);
      return CFResult.error(
        'GET request failed: ${e.toString()}',
        exception: e,
        category: ErrorCategory.network,
        errorCode: errorCode,
      );
    }
  }

  /// PUT request implementation for interface
  Future<CFResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      // Use timeout wrapper for better timeout handling
      final resp = await _executeWithTimeout(
        (cancelToken) => _dio.put(
          path,
          data: data,
          queryParameters: queryParameters,
          options: Options(headers: headers),
          cancelToken: cancelToken,
        ),
        'PUT $path',
      );

      if (resp.statusCode == 200 || resp.statusCode == 202) {
        return CFResult.success(resp.data as T);
      } else {
        final errorCode = CFErrorCode.fromHttpStatus(resp.statusCode ?? 0) ??
            CFErrorCode.networkUnavailable;
        return CFResult.error(
          'PUT request failed with status ${resp.statusCode}',
          code: resp.statusCode ?? 0,
          category: ErrorCategory.network,
          errorCode: errorCode,
        );
      }
    } catch (e) {
      final errorCode = _getErrorCodeFromException(e);
      return CFResult.error(
        'PUT request failed: ${e.toString()}',
        exception: e,
        category: ErrorCategory.network,
        errorCode: errorCode,
      );
    }
  }

  /// Get base URL implementation for interface
  String getBaseUrl() {
    return _dio.options.baseUrl;
  }

  /// Get full URL for a path implementation for interface
  String getFullUrl(String path) {
    final baseUrl = getBaseUrl();
    if (baseUrl.isEmpty) {
      return path;
    }
    return Uri.parse(baseUrl).resolve(path).toString();
  }

  /// HEAD request for backward compatibility that returns Response object
  Future<CFResult<Response>> headResponse(String path,
      {Options? options}) async {
    return ExponentialBackoff.retry(
      operation: () => _headResponseInternal(path, options: options),
      operationName: 'headResponse($path)',
    );
  }

  Future<CFResult<Response>> _headResponseInternal(String path,
      {Options? options}) async {
    try {
      final headOptions = options ??
          Options(
            headers: {
              'Cache-Control': 'no-cache',
            },
          );

      // Use timeout wrapper for better timeout handling
      final resp = await _executeWithTimeout(
        (cancelToken) =>
            _dio.head(path, options: headOptions, cancelToken: cancelToken),
        'HEAD Response $path',
      );

      if (resp.statusCode == 200) {
        // Silent - successful HEAD requests are routine polling
        return CFResult.success(resp);
      } else {
        // Only log failures that aren't routine 304s
        if (resp.statusCode != 304) {
          Logger.w('API POLL: HEAD $path - Failed (${resp.statusCode})');
        }
        final errorCode = CFErrorCode.fromHttpStatus(resp.statusCode ?? 0) ??
            CFErrorCode.networkUnavailable;
        return CFResult.error(
            'HEAD request failed with code: ${resp.statusCode}',
            code: resp.statusCode ?? 0,
            category: ErrorCategory.network,
            errorCode: errorCode,
            context: {'url': path});
      }
    } catch (e) {
      Logger.e('API POLL: HEAD $path - Exception: ${e.toString()}');
      final errorCode = _getErrorCodeFromException(e);
      return CFResult.error(
          'HEAD request failed with exception: ${e.toString()}',
          exception: e,
          category: ErrorCategory.network,
          errorCode: errorCode,
          context: {'url': path});
    }
  }
}
