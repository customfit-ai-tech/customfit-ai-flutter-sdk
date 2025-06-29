/// SDK connection states (standardized across all platforms)
enum ConnectionStatus {
  /// Connected to the server
  connected,
  
  /// Connecting to the server
  connecting,
  
  /// Disconnected from the server
  disconnected,
  
  /// Connection status is unknown
  unknown
}

/// Extension methods for ConnectionStatus
extension ConnectionStatusExtension on ConnectionStatus {
  /// Convert to string
  String get stringValue {
    switch (this) {
      case ConnectionStatus.connected:
        return 'connected';
      case ConnectionStatus.connecting:
        return 'connecting';
      case ConnectionStatus.disconnected:
        return 'disconnected';
      case ConnectionStatus.unknown:
        return 'unknown';
    }
  }

  /// Convert from string
  static ConnectionStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
        return ConnectionStatus.connected;
      case 'connecting':
        return ConnectionStatus.connecting;
      case 'disconnected':
        return ConnectionStatus.disconnected;
      case 'unknown':
        return ConnectionStatus.unknown;
      default:
        return ConnectionStatus.unknown;
    }
  }
}
