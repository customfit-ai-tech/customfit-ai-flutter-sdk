// infrastructure/network/interfaces/connection_manager.dart
//
// Abstract interface for connection management operations.
// Defines the contract for network connection state and listener management.

import '../internal/connection_status.dart';
import '../internal/connection_information.dart';

// Re-export the connection types from internal implementations
export '../internal/connection_status.dart';
export '../internal/connection_information.dart';

/// Callback interface for connection status changes
abstract class IConnectionStatusListener {
  /// Called when the connection status changes
  void onConnectionStatusChanged(
      ConnectionStatus newStatus, ConnectionInformation info);
}

/// Abstract interface for managing network connection state and listeners
abstract class IConnectionManager {
  /// Check if the manager is in offline mode
  bool isOffline();

  /// Get the current connection status
  ConnectionStatus getConnectionStatus();

  /// Get detailed connection information
  ConnectionInformation getConnectionInformation();

  /// Add a listener for connection status changes
  void addConnectionStatusListener(IConnectionStatusListener listener);

  /// Remove a previously added connection status listener
  void removeConnectionStatusListener(IConnectionStatusListener listener);

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
