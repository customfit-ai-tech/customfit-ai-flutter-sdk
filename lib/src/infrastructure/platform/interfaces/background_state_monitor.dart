// infrastructure/platform/interfaces/background_state_monitor.dart
//
// Abstract interface for background state monitoring.
// Defines the contract for monitoring app lifecycle and battery state.

/// App state enumeration
enum AppState {
  foreground,
  background,
  inactive,
  detached,
}

/// Battery state enumeration
enum BatteryState {
  unknown,
  unplugged,
  charging,
  full,
}

/// Abstract interface for background state monitoring
abstract class IBackgroundStateMonitor {
  /// Get current app state
  AppState getCurrentAppState();

  /// Get current battery state
  BatteryState getCurrentBatteryState();

  /// Get battery level (0.0 to 1.0)
  double getBatteryLevel();

  /// Add listener for app state changes
  void addAppStateListener(void Function(AppState) listener);

  /// Remove app state listener
  void removeAppStateListener(void Function(AppState) listener);

  /// Add listener for battery state changes
  void addBatteryStateListener(void Function(BatteryState) listener);

  /// Remove battery state listener
  void removeBatteryStateListener(void Function(BatteryState) listener);

  /// Start monitoring
  void startMonitoring();

  /// Stop monitoring and cleanup
  void stopMonitoring();

  /// Shutdown and cleanup all resources
  void shutdown();
}
