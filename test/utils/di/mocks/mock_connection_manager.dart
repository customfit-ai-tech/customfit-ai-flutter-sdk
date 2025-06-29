import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_status.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_information.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_manager.dart';

/// Mock connection manager for testing
class MockConnectionManager implements ConnectionManager {
  ConnectionStatus _status = ConnectionStatus.connected;
  bool _isOffline = false;
  final List<ConnectionStatusListener> _listeners = [];
  String? _lastError;
  int _failureCount = 0;
  void setConnectionStatus(ConnectionStatus status) {
    _status = status;
    _notifyListeners();
  }

  void simulateConnectionFailure(String error) {
    _lastError = error;
    _failureCount++;
    _status = ConnectionStatus.connecting;
    _notifyListeners();
  }

  void reset() {
    _status = ConnectionStatus.connected;
    _isOffline = false;
    _listeners.clear();
    _lastError = null;
    _failureCount = 0;
  }

  @override
  bool isOffline() {
    return _isOffline;
  }

  @override
  ConnectionStatus getConnectionStatus() {
    return _status;
  }

  @override
  ConnectionInformation getConnectionInformation() {
    return ConnectionInformation(
      status: _status,
      isOfflineMode: _isOffline,
      lastError: _lastError,
      lastSuccessfulConnectionTimeMs: DateTime.now().millisecondsSinceEpoch,
      failureCount: _failureCount,
      nextReconnectTimeMs: 0,
    );
  }

  @override
  void addConnectionStatusListener(ConnectionStatusListener listener) {
    _listeners.add(listener);
    // Notify immediately
    listener.onConnectionStatusChanged(_status, getConnectionInformation());
  }

  @override
  void removeConnectionStatusListener(ConnectionStatusListener listener) {
    _listeners.remove(listener);
  }

  @override
  void setOfflineMode(bool offline) {
    _isOffline = offline;
    _status =
        offline ? ConnectionStatus.disconnected : ConnectionStatus.connected;
    _notifyListeners();
  }

  @override
  void recordConnectionSuccess() {
    _status = ConnectionStatus.connected;
    _lastError = null;
    _failureCount = 0;
    _notifyListeners();
  }

  @override
  void recordConnectionFailure(String error) {
    _lastError = error;
    _failureCount++;
    _status = ConnectionStatus.connecting;
    _notifyListeners();
  }

  @override
  void checkConnection() {
    // Mock implementation
  }
  @override
  void shutdown() {
    _listeners.clear();
  }

  void setupListeners() {
    // Mock implementation - no-op
  }
  void _notifyListeners() {
    final info = getConnectionInformation();
    for (final listener in List.from(_listeners)) {
      listener.onConnectionStatusChanged(_status, info);
    }
  }
}
