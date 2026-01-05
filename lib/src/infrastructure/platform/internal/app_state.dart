import 'package:flutter/widgets.dart';

/// App state enum defining the possible states of the application (standardized across all platforms)
enum AppState {
  /// App is active and in foreground
  active,

  /// App is in the background but still running
  background,

  /// App is inactive (transitioning between states)
  inactive,

  /// App state is unknown
  unknown,
}

/// Extension methods for AppState
extension AppStateExtension on AppState {
  /// Convert to string
  String get stringValue {
    switch (this) {
      case AppState.active:
        return 'active';
      case AppState.background:
        return 'background';
      case AppState.inactive:
        return 'inactive';
      case AppState.unknown:
        return 'unknown';
    }
  }

  /// Convert from string
  static AppState fromString(String state) {
    switch (state.toLowerCase()) {
      case 'active':
        return AppState.active;
      case 'background':
        return AppState.background;
      case 'inactive':
        return AppState.inactive;
      case 'unknown':
        return AppState.unknown;
      default:
        return AppState.unknown;
    }
  }

  /// Convert Flutter's AppLifecycleState to AppState
  static AppState fromAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        return AppState.active;
      case AppLifecycleState.inactive:
        return AppState.inactive;
      case AppLifecycleState.paused:
        return AppState.background;
      case AppLifecycleState.detached:
        return AppState.background; // Treat detached as background
      default:
        return AppState.unknown;
    }
  }
}

/// Interface for app state change listeners.
abstract class AppStateListener {
  /// Called when the app state changes.
  ///
  /// [newState] is the new state of the application.
  void onAppStateChanged(AppState newState);
}
