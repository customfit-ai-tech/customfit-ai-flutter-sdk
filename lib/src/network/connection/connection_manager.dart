import 'dart:async';
import 'dart:math';

import '../../config/core/cf_config.dart';
import '../../logging/logger.dart';
import '../../core/resource_registry.dart';
import 'connection_status.dart';
import 'connection_information.dart';

/// Callback for connection status changes
abstract class ConnectionStatusListener {
  /// Called when the connection status changes
  void onConnectionStatusChanged(
      ConnectionStatus newStatus, ConnectionInformation info);
}

/// Interface for managing network connection state and listeners
abstract class ConnectionManager {
  /// Check if the manager is in offline mode
  bool isOffline();

  /// Get the current connection status
  ConnectionStatus getConnectionStatus();

  /// Get detailed connection information
  ConnectionInformation getConnectionInformation();

  /// Add a listener for connection status changes
  void addConnectionStatusListener(ConnectionStatusListener listener);

  /// Remove a previously added connection status listener
  void removeConnectionStatusListener(ConnectionStatusListener listener);

  /// Set offline mode to enable/disable network operations
  void setOfflineMode(bool offline);

  /// Record a successful connection attempt
  void recordConnectionSuccess();

  /// Record a failed connection attempt with an error message
  void recordConnectionFailure(String error);

  /// Check the current connection status and attempt to reconnect if needed
  void checkConnection();

  /// Shutdown the connection manager and release resources
  void shutdown();
}

/// Manages reconnect logic and notifies listeners
class ConnectionManagerImpl implements ConnectionManager {
  // ignore: unused_field
  final CFConfig _config;
  final List<ConnectionStatusListener> _listeners = [];
  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  bool _offlineMode = false;
  int _failureCount = 0;
  int _lastSuccessMs = 0;
  int _nextReconnectMs = 0;
  String? _lastError;

  ManagedTimer? _heartbeatTimer;
  ManagedTimer? _reconnectTimer;
  bool _isShutdown = false;

  static const _heartbeatInterval = Duration(seconds: 15);
  static const _baseDelayMs = 1000;
  static const _maxDelayMs = 30000;
  static const _maxReconnectAttempts = 3; // Limit reconnect attempts

  ConnectionManagerImpl(this._config) {
    if (!_offlineMode) _updateStatus(ConnectionStatus.connecting);
    _startHeartbeat();
  }

  /// Setup initial connection listeners
  /// This method centralizes the connection listener setup that was previously in CFClient
  void setupListeners() {
    addConnectionStatusListener(
      _BasicConnectionStatusListener(onStatusChanged: (status, info) {
        Logger.d('Connection status changed: $status');
      }),
    );
  }

  @override
  bool isOffline() => _offlineMode;

  @override
  ConnectionStatus getConnectionStatus() => _currentStatus;

  @override
  ConnectionInformation getConnectionInformation() => ConnectionInformation(
        status: _currentStatus,
        isOfflineMode: _offlineMode,
        lastError: _lastError,
        lastSuccessfulConnectionTimeMs: _lastSuccessMs,
        failureCount: _failureCount,
        nextReconnectTimeMs: _nextReconnectMs,
      );

  @override
  void addConnectionStatusListener(ConnectionStatusListener listener) {
    _listeners.add(listener);
    // immediate callback
    scheduleMicrotask(() {
      try {
        listener.onConnectionStatusChanged(
            _currentStatus, getConnectionInformation());
      } catch (e) {
        Logger.e('Error in connection status listener: $e');
      }
    });
  }

  @override
  void removeConnectionStatusListener(ConnectionStatusListener listener) {
    _listeners.remove(listener);
  }

  @override
  void setOfflineMode(bool offline) {
    // Prevent redundant transitions
    if (_offlineMode == offline) {
      Logger.d('Offline mode already set to $offline, ignoring');
      return;
    }

    _offlineMode = offline;
    _cancelReconnect();

    if (offline) {
      // Smooth transition to offline
      Logger.i('Transitioning to offline mode');
      _updateStatus(ConnectionStatus.disconnected);

      // Cancel any pending operations
      _heartbeatTimer?.cancel();
    } else {
      // Smooth transition to online
      Logger.i('Transitioning to online mode');

      // Reset failure count when coming back online
      _failureCount = 0;
      _lastError = null;

      // Restart heartbeat monitoring
      _startHeartbeat();

      // Delay initial connection attempt to allow system to stabilize
      _updateStatus(ConnectionStatus.connecting);
      _scheduleReconnect(const Duration(seconds: 10));
    }
  }

  @override
  void recordConnectionSuccess() {
    _failureCount = 0;
    _lastError = null;
    _lastSuccessMs = DateTime.now().millisecondsSinceEpoch;
    _updateStatus(ConnectionStatus.connected);
  }

  @override
  void recordConnectionFailure(String error) {
    _failureCount++;
    _lastError = error;

    if (!_offlineMode && _failureCount < _maxReconnectAttempts) {
      _updateStatus(ConnectionStatus.connecting);
      final delay = _calculateBackoff(_failureCount);
      Logger.w(
          'Connection failed (attempt $_failureCount/$_maxReconnectAttempts): $error');
      _scheduleReconnect(Duration(milliseconds: delay));
    } else if (_failureCount >= _maxReconnectAttempts) {
      Logger.w('Max reconnect attempts reached after failure: $error');
      _updateStatus(ConnectionStatus.disconnected);
    }
  }

  @override
  void checkConnection() {
    if (_offlineMode) return;
    if (_currentStatus == ConnectionStatus.connected) {
      _updateStatus(ConnectionStatus.connecting);
    }
    _scheduleReconnect(Duration.zero);
  }

  int _calculateBackoff(int failures) {
    final exp = (_baseDelayMs * (1 << failures)).clamp(0, _maxDelayMs);
    final jitter = (0.8 + (Random().nextDouble() * 0.4));
    return (exp * jitter).toInt();
  }

  void _scheduleReconnect(Duration delay) {
    if (_isShutdown) return;

    _cancelReconnect();
    if (delay > Duration.zero) {
      _nextReconnectMs =
          DateTime.now().millisecondsSinceEpoch + delay.inMilliseconds;
      Logger.d('Scheduling reconnect in ${delay.inMilliseconds}ms');
    }
    _reconnectTimer = ManagedTimer(
      owner: 'ConnectionManagerImpl_reconnect',
      duration: delay,
      callback: () {
        if (_isShutdown) return;

        if (!_offlineMode && _failureCount < _maxReconnectAttempts) {
          Logger.d(
              'Attempting reconnect (attempt ${_failureCount + 1}/$_maxReconnectAttempts)');
          _nextReconnectMs = 0;

          // Notify listeners that we're attempting to reconnect
          _updateStatus(ConnectionStatus.connecting);

          // The actual connection attempt will be handled by listeners
          // (e.g., ConfigFetcher will try to fetch config, which will call
          // recordConnectionSuccess or recordConnectionFailure)
          for (final listener in List.of(_listeners)) {
            listener.onConnectionStatusChanged(
                _currentStatus, getConnectionInformation());
          }
        } else if (_failureCount >= _maxReconnectAttempts) {
          Logger.w('Max reconnect attempts reached, going offline');
          _updateStatus(ConnectionStatus.disconnected);
        }
      },
    );
  }

  void _cancelReconnect() {
    _reconnectTimer?.dispose();
    _reconnectTimer = null;
    _nextReconnectMs = 0;
  }

  void _startHeartbeat() {
    if (_isShutdown) return;

    _heartbeatTimer?.dispose();
    _heartbeatTimer = ManagedTimer.periodic(
      owner: 'ConnectionManagerImpl_heartbeat',
      duration: _heartbeatInterval,
      callback: (_) {
        if (_isShutdown) return;

        if (!_offlineMode &&
            (_currentStatus == ConnectionStatus.disconnected ||
                DateTime.now().millisecondsSinceEpoch - _lastSuccessMs >
                    60000)) {
          checkConnection();
        }
      },
    );
  }

  @override
  void shutdown() {
    if (_isShutdown) return;

    _isShutdown = true;
    _heartbeatTimer?.dispose();
    _reconnectTimer?.dispose();
    _listeners.clear();
  }

  void _updateStatus(ConnectionStatus newStatus) {
    if (_currentStatus != newStatus) {
      final oldStatus = _currentStatus;
      _currentStatus = newStatus;
      final info = getConnectionInformation();
      Logger.d('Connection status transition: $oldStatus -> $newStatus');

      // Notify listeners asynchronously to prevent blocking
      Future.microtask(() {
        for (final listener in List.of(_listeners)) {
          try {
            listener.onConnectionStatusChanged(newStatus, info);
          } catch (e) {
            Logger.e('Error in connection status listener: $e');
          }
        }
      });
    }
  }
}

/// Basic connection status listener for internal use
class _BasicConnectionStatusListener implements ConnectionStatusListener {
  final void Function(ConnectionStatus, ConnectionInformation) onStatusChanged;

  _BasicConnectionStatusListener({required this.onStatusChanged});

  @override
  void onConnectionStatusChanged(
      ConnectionStatus status, ConnectionInformation info) {
    onStatusChanged(status, info);
  }
}
