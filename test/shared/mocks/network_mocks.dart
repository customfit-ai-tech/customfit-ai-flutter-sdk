// test/shared/mocks/network_mocks.dart
//
// Network-related mock classes for testing network components
// including HTTP client, connection manager, and circuit breaker mocks.
//
// This file is part of the CustomFit SDK test infrastructure.
import 'package:mockito/mockito.dart';
import 'package:customfit_ai_flutter_sdk/src/network/http_client.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/circuit_breaker.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_status.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_information.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

/// Mock HTTP client for testing network requests
class MockHttpClient extends Mock implements HttpClient {
  final List<ConnectionStatusListener> _listeners = [];
  int requestCount = 0;
  List<String> requestHistory = [];
  Map<String, dynamic> lastRequestData = {};
  Map<String, String> lastRequestHeaders = {};
  void reset() {
    requestCount = 0;
    requestHistory.clear();
    lastRequestData.clear();
    lastRequestHeaders.clear();
  }

  void trackRequest(String url,
      {Map<String, dynamic>? data, Map<String, String>? headers}) {
    requestCount++;
    requestHistory.add(url);
    if (data != null) lastRequestData = data;
    if (headers != null) lastRequestHeaders = headers;
  }
}

/// Mock connection manager for testing connection state handling
class MockConnectionManager extends Mock implements ConnectionManager {
  ConnectionStatus _status = ConnectionStatus.connected;
  final List<ConnectionStatusListener> _listeners = [];
  bool _offlineMode = false;
  int _failureCount = 0;
  String? _lastError;
  @override
  ConnectionStatus getConnectionStatus() => _status;
  @override
  bool isOffline() => _offlineMode;
  @override
  void setOfflineMode(bool offline) {
    _offlineMode = offline;
    if (offline) {
      _status = ConnectionStatus.disconnected;
    } else {
      _status = ConnectionStatus.connecting;
    }
    _notifyListeners();
  }

  @override
  void addConnectionStatusListener(ConnectionStatusListener listener) {
    _listeners.add(listener);
    // Send immediate callback with current state
    Future.microtask(() {
      listener.onConnectionStatusChanged(_status, getConnectionInformation());
    });
  }

  @override
  void removeConnectionStatusListener(ConnectionStatusListener listener) {
    _listeners.remove(listener);
  }

  @override
  ConnectionInformation getConnectionInformation() {
    return ConnectionInformation(
      status: _status,
      isOfflineMode: _offlineMode,
      lastError: _lastError,
      lastSuccessfulConnectionTimeMs: DateTime.now().millisecondsSinceEpoch,
      failureCount: _failureCount,
      nextReconnectTimeMs: 0,
    );
  }

  @override
  void recordConnectionSuccess() {
    _status = ConnectionStatus.connected;
    _failureCount = 0;
    _lastError = null;
    _notifyListeners();
  }

  @override
  void recordConnectionFailure(String error) {
    _failureCount++;
    _lastError = error;
    if (_failureCount >= 3) {
      _status = ConnectionStatus.disconnected;
    } else {
      _status = ConnectionStatus.connecting;
    }
    _notifyListeners();
  }

  @override
  void checkConnection() {
    // Mock implementation - do nothing
  }
  @override
  void shutdown() {
    _listeners.clear();
  }

  // Test helper methods
  void simulateConnectionChange(ConnectionStatus newStatus) {
    _status = newStatus;
    _notifyListeners();
  }

  void simulateNetworkFailure(String error, {int failureCount = 1}) {
    _failureCount = failureCount;
    _lastError = error;
    _status = failureCount >= 3
        ? ConnectionStatus.disconnected
        : ConnectionStatus.connecting;
    _notifyListeners();
  }

  void simulateNetworkRecovery() {
    _status = ConnectionStatus.connected;
    _failureCount = 0;
    _lastError = null;
    _notifyListeners();
  }

  void reset() {
    _status = ConnectionStatus.connected;
    _offlineMode = false;
    _failureCount = 0;
    _lastError = null;
    _listeners.clear();
  }

  void _notifyListeners() {
    final info = getConnectionInformation();
    for (final listener in List.from(_listeners)) {
      Future.microtask(() {
        listener.onConnectionStatusChanged(_status, info);
      });
    }
  }
}

/// Mock circuit breaker for testing failure protection
class MockCircuitBreaker extends Mock implements CircuitBreaker {
  bool _isOpen = false;
  int _failureCount = 0;
  final int _threshold;
  dynamic _fallbackValue;
  MockCircuitBreaker({int threshold = 3}) : _threshold = threshold;
  @override
  Future<T> executeWithCircuitBreaker<T>(
    Future<T> Function() block, {
    T? fallback,
  }) async {
    if (_isOpen) {
      if (fallback != null) {
        return fallback;
      }
      throw CircuitOpenException('Circuit breaker is open');
    }
    try {
      final result = await block();
      _failureCount = 0; // Reset on success
      return result;
    } catch (e) {
      _failureCount++;
      if (_failureCount >= _threshold) {
        _isOpen = true;
      }
      if (fallback != null) {
        return fallback;
      }
      rethrow;
    }
  }

  @override
  void reset() {
    _isOpen = false;
    _failureCount = 0;
  }

  // Test helper methods
  void simulateOpen() {
    _isOpen = true;
    _failureCount = _threshold;
  }

  void simulateClosed() {
    _isOpen = false;
    _failureCount = 0;
  }

  void simulateHalfOpen() {
    _isOpen = false;
    _failureCount = _threshold - 1;
  }

  bool get isOpen => _isOpen;
  int get failureCount => _failureCount;
}

/// Mock HTTP response for testing
class MockHttpResponse extends Mock implements http.Response {
  final int _statusCode;
  final String _body;
  final Map<String, String> _headers;
  MockHttpResponse({
    required int statusCode,
    required String body,
    Map<String, String>? headers,
  })  : _statusCode = statusCode,
        _body = body,
        _headers = headers ?? {};
  @override
  int get statusCode => _statusCode;
  @override
  String get body => _body;
  @override
  Map<String, String> get headers => _headers;
}

/// Builder for creating mock HTTP responses
class MockResponseBuilder {
  static http.Response success({
    String body = '{"success": true}',
    Map<String, String>? headers,
  }) {
    return MockHttpResponse(
      statusCode: 200,
      body: body,
      headers: headers ?? {'content-type': 'application/json'},
    );
  }

  static http.Response notModified({Map<String, String>? headers}) {
    return MockHttpResponse(
      statusCode: 304,
      body: '',
      headers: headers ?? {},
    );
  }

  static http.Response badRequest({String? message}) {
    return MockHttpResponse(
      statusCode: 400,
      body: '{"error": "${message ?? "Bad request"}"}',
    );
  }

  static http.Response unauthorized() {
    return MockHttpResponse(
      statusCode: 401,
      body: '{"error": "Unauthorized"}',
    );
  }

  static http.Response forbidden() {
    return MockHttpResponse(
      statusCode: 403,
      body: '{"error": "Forbidden"}',
    );
  }

  static http.Response notFound() {
    return MockHttpResponse(
      statusCode: 404,
      body: '{"error": "Not found"}',
    );
  }

  static http.Response rateLimited({
    String? retryAfter,
    String? message,
  }) {
    final headers = <String, String>{};
    if (retryAfter != null) {
      headers['retry-after'] = retryAfter;
    }
    return MockHttpResponse(
      statusCode: 429,
      body: '{"error": "${message ?? "Rate limit exceeded"}"}',
      headers: headers,
    );
  }

  static http.Response serverError({String? message}) {
    return MockHttpResponse(
      statusCode: 500,
      body: '{"error": "${message ?? "Internal server error"}"}',
    );
  }

  static http.Response badGateway() {
    return MockHttpResponse(
      statusCode: 502,
      body: '{"error": "Bad gateway"}',
    );
  }

  static http.Response serviceUnavailable() {
    return MockHttpResponse(
      statusCode: 503,
      body: '{"error": "Service unavailable"}',
    );
  }
}
