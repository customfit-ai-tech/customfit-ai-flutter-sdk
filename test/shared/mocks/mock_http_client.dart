// test/shared/mocks/mock_http_client.dart
//
// Mock HTTP client implementation for testing.
// Provides comprehensive mocking capabilities for all HTTP operations,
// simulating different network scenarios and responses.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:customfit_ai_flutter_sdk/src/network/http_client.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_error_code.dart';
/// Mock HTTP client that extends Mock and implements HttpClient
class MockHttpClient extends Mock implements HttpClient {
  // Store response handlers for flexible test configuration
  final Map<String, dynamic Function()> _getHandlers = {};
  final Map<String, dynamic Function(dynamic)> _postHandlers = {};
  final Map<String, dynamic Function(dynamic)> _putHandlers = {};
  final Map<String, Map<String, String> Function()> _headHandlers = {};
  // Configuration for response delays
  Duration? responseDelay;
  // Track requests for verification
  final List<HttpRequest> requestHistory = [];
  // Connection metrics tracking
  int _totalRequests = 0;
  int _successfulRequests = 0;
  int _failedRequests = 0;
  // Base URL configuration
  String _baseUrl = 'https://api.customfit.com';
  /// Configure a GET response
  void whenGet<T>(String path, T response, {
    int statusCode = 200,
    bool isError = false,
    CFErrorCode? errorCode,
    String? errorMessage,
  }) {
    _getHandlers[path] = () {
      _recordRequest('GET', path);
      if (isError) {
        throw CFResult<T>.error(
          errorMessage ?? 'GET $path failed',
          code: statusCode,
          category: ErrorCategory.network,
          errorCode: errorCode ?? CFErrorCode.networkUnavailable,
        );
      }
      return response;
    };
  }
  /// Configure a POST response
  void whenPost<T>(String path, T response, {
    int statusCode = 200,
    bool isError = false,
    CFErrorCode? errorCode,
    String? errorMessage,
    bool Function(dynamic)? dataValidator,
  }) {
    _postHandlers[path] = (data) {
      _recordRequest('POST', path, data: data);
      if (dataValidator != null && !dataValidator(data)) {
        throw CFResult<T>.error(
          'Invalid request data',
          code: 400,
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidFormat,
        );
      }
      if (isError) {
        throw CFResult<T>.error(
          errorMessage ?? 'POST $path failed',
          code: statusCode,
          category: ErrorCategory.network,
          errorCode: errorCode ?? CFErrorCode.networkUnavailable,
        );
      }
      return response;
    };
  }
  /// Configure a HEAD response
  void whenHead(String path, Map<String, String> headers, {
    int statusCode = 200,
    bool isError = false,
  }) {
    _headHandlers[path] = () {
      _recordRequest('HEAD', path);
      if (isError) {
        throw CFResult<Map<String, String>>.error(
          'HEAD $path failed',
          code: statusCode,
          category: ErrorCategory.network,
          errorCode: CFErrorCode.networkUnavailable,
        );
      }
      return headers;
    };
  }
  /// Simulate network timeout
  void simulateTimeout(String path) {
    _getHandlers[path] = () {
      _recordRequest('GET', path);
      throw CFResult<dynamic>.error(
        'Request timeout',
        category: ErrorCategory.network,
        errorCode: CFErrorCode.networkTimeout,
      );
    };
  }
  /// Simulate network unavailable
  void simulateNetworkUnavailable() {
    _getHandlers.clear();
    _postHandlers.clear();
    _headHandlers.clear();
    // All requests will fall through to the default error
  }
  @override
  Future<CFResult<T>> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    _totalRequests++;
    if (responseDelay != null) {
      await Future.delayed(responseDelay!);
    }
    try {
      if (_getHandlers.containsKey(path)) {
        final result = _getHandlers[path]!();
        _successfulRequests++;
        return CFResult.success(result as T);
      }
      _failedRequests++;
      return CFResult.error(
        'No mock configured for GET $path',
        category: ErrorCategory.network,
        errorCode: CFErrorCode.networkUnavailable,
      );
    } catch (e) {
      _failedRequests++;
      if (e is CFResult) {
        // Extract error details and create a new CFResult with correct type
        final cfResult = e;
        return CFResult<T>.error(
          cfResult.error?.message ?? 'Error',
          category: cfResult.error?.category ?? ErrorCategory.network,
          errorCode: cfResult.error?.errorCode ?? CFErrorCode.networkUnavailable,
          exception: cfResult.error?.exception,
        );
      }
      rethrow;
    }
  }
  @override
  Future<CFResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    _totalRequests++;
    if (responseDelay != null) {
      await Future.delayed(responseDelay!);
    }
    try {
      if (_postHandlers.containsKey(path)) {
        final result = _postHandlers[path]!(data);
        _successfulRequests++;
        return CFResult.success(result as T);
      }
      _failedRequests++;
      return CFResult.error(
        'No mock configured for POST $path',
        category: ErrorCategory.network,
        errorCode: CFErrorCode.networkUnavailable,
      );
    } catch (e) {
      _failedRequests++;
      if (e is CFResult) {
        // Extract error details and create a new CFResult with correct type
        final cfResult = e;
        return CFResult<T>.error(
          cfResult.error?.message ?? 'Error',
          category: cfResult.error?.category ?? ErrorCategory.network,
          errorCode: cfResult.error?.errorCode ?? CFErrorCode.networkUnavailable,
          exception: cfResult.error?.exception,
        );
      }
      rethrow;
    }
  }
  @override
  Future<CFResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    _totalRequests++;
    if (responseDelay != null) {
      await Future.delayed(responseDelay!);
    }
    _recordRequest('PUT', path, data: data);
    if (_putHandlers.containsKey(path)) {
      final result = _putHandlers[path]!(data);
      _successfulRequests++;
      return CFResult.success(result as T);
    }
    _failedRequests++;
    return CFResult.error(
      'No mock configured for PUT $path',
      category: ErrorCategory.network,
      errorCode: CFErrorCode.networkUnavailable,
    );
  }
  @override
  Future<CFResult<Map<String, String>>> head(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    _totalRequests++;
    if (responseDelay != null) {
      await Future.delayed(responseDelay!);
    }
    try {
      if (_headHandlers.containsKey(path)) {
        final result = _headHandlers[path]!();
        _successfulRequests++;
        return CFResult.success(result);
      }
      _failedRequests++;
      return CFResult.error(
        'No mock configured for HEAD $path',
        category: ErrorCategory.network,
        errorCode: CFErrorCode.networkUnavailable,
      );
    } catch (e) {
      _failedRequests++;
      if (e is CFResult) {
        return e as CFResult<Map<String, String>>;
      }
      rethrow;
    }
  }
  @override
  Future<CFResult<Map<String, dynamic>>> fetchJson(String url) async {
    return get<Map<String, dynamic>>(url);
  }
  @override
  Future<CFResult<Map<String, String>>> fetchMetadata(
    String url, {
    String? lastModified,
    String? etag,
  }) async {
    _recordRequest('GET', url, headers: {
      if (lastModified != null) 'If-Modified-Since': lastModified,
      if (etag != null) 'If-None-Match': etag,
    });
    return head(url);
  }
  @override
  Future<CFResult<Response>> headResponse(String path, {Options? options}) async {
    final result = await head(path, headers: options?.headers as Map<String, String>?);
    if (result.isSuccess) {
      // Create a mock Response object
      final response = Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        headers: Headers.fromMap(result.data!.map((k, v) => MapEntry(k, [v]))),
      );
      return CFResult.success(response);
    }
    return CFResult.error(
      result.getErrorMessage() ?? 'HEAD request failed',
      category: ErrorCategory.network,
      errorCode: CFErrorCode.networkUnavailable,
    );
  }
  @override
  void updateConnectionTimeout(int timeoutMs) {
    // Mock implementation - just track the call
    _recordRequest('UPDATE_TIMEOUT', 'connection', data: timeoutMs);
  }
  @override
  void updateReadTimeout(int timeoutMs) {
    // Mock implementation - just track the call
    _recordRequest('UPDATE_TIMEOUT', 'read', data: timeoutMs);
  }
  @override
  String getBaseUrl() {
    return _baseUrl;
  }
  @override
  String getFullUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    }
    return '$_baseUrl$path';
  }
  @override
  Map<String, dynamic> getConnectionPoolMetrics() {
    return {
      'totalRequests': _totalRequests,
      'successfulRequests': _successfulRequests,
      'failedRequests': _failedRequests,
      'successRate': _totalRequests > 0 ? _successfulRequests / _totalRequests : 0.0,
      'activeConnections': 0,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
  
  @override
  Future<CFResult<bool>> postJson(String url, String payload) async {
    return post<bool>(url, data: payload);
  }
  
  @override
  void cleanup() {
    // Mock implementation - just reset
    reset();
  }
  /// Set the base URL for testing
  void setBaseUrl(String url) {
    _baseUrl = url;
  }
  /// Clear all configured responses
  void reset() {
    _getHandlers.clear();
    _postHandlers.clear();
    _putHandlers.clear();
    _headHandlers.clear();
    requestHistory.clear();
    _totalRequests = 0;
    _successfulRequests = 0;
    _failedRequests = 0;
    responseDelay = null;
  }
  /// Verify a request was made
  bool wasRequestMade(String method, String path, {dynamic data}) {
    return requestHistory.any((req) =>
      req.method == method &&
      req.path == path &&
      (data == null || req.data == data)
    );
  }
  /// Get all requests for a specific method and path
  List<HttpRequest> getRequests(String method, String path) {
    return requestHistory.where((req) =>
      req.method == method && req.path == path
    ).toList();
  }
  void _recordRequest(String method, String path, {
    dynamic data,
    Map<String, String>? headers,
  }) {
    requestHistory.add(HttpRequest(
      method: method,
      path: path,
      data: data,
      headers: headers,
      timestamp: DateTime.now(),
    ));
  }
}
/// Represents a recorded HTTP request
class HttpRequest {
  final String method;
  final String path;
  final dynamic data;
  final Map<String, String>? headers;
  final DateTime timestamp;
  HttpRequest({
    required this.method,
    required this.path,
    this.data,
    this.headers,
    required this.timestamp,
  });
}
/// Helper class for creating common mock responses
class MockResponses {
  /// Successful config response
  static Map<String, dynamic> successfulConfig() {
    return {
      'feature_flags': {
        'feature_a': {'enabled': true, 'value': true},
        'feature_b': {'enabled': true, 'value': 'variant_1'},
      },
      'sdk_settings': {
        'events_flush_interval_ms': 30000,
        'config_refresh_interval_ms': 60000,
      },
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  /// Empty config response
  static Map<String, dynamic> emptyConfig() {
    return {
      'feature_flags': {},
      'sdk_settings': {},
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  /// Metadata headers
  static Map<String, String> metadataHeaders({
    String? lastModified,
    String? etag,
  }) {
    return {
      'Last-Modified': lastModified ?? 'Wed, 21 Oct 2023 07:28:00 GMT',
      'ETag': etag ?? '"123456789"',
      'Content-Type': 'application/json',
    };
  }
  /// Error response body
  static Map<String, dynamic> errorResponse(String message, int code) {
    return {
      'error': {
        'message': message,
        'code': code,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}