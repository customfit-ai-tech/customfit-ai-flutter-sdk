import 'dart:async';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart' as battery_plus;

import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../logging/logger.dart';
import '../core/session/session_manager.dart';
import 'app_state.dart';
import 'battery_state.dart';

/// Abstract class for background state monitoring.
abstract class BackgroundStateMonitor {
  /// Add app state listener
  void addAppStateListener(AppStateListener listener);

  /// Remove app state listener
  void removeAppStateListener(AppStateListener listener);

  /// Add battery state listener
  void addBatteryStateListener(BatteryStateListener listener);

  /// Remove battery state listener
  void removeBatteryStateListener(BatteryStateListener listener);

  /// Get current app state
  AppState getCurrentAppState();

  /// Get current battery state
  BatteryState getCurrentBatteryState();

  /// Get current battery level (0-100)
  int getCurrentBatteryLevel();

  /// Clean up resources
  void shutdown();
}

/// Default implementation of background state monitoring.
class DefaultBackgroundStateMonitor
    with WidgetsBindingObserver
    implements BackgroundStateMonitor {
  // App state
  AppState _currentAppState = AppState.active;

  // Battery state
  BatteryState _currentBatteryState = BatteryState.unknown;
  int _currentBatteryLevel = 100;

  // Listeners
  final List<AppStateListener> _appStateListeners = [];
  final List<BatteryStateListener> _batteryStateListeners = [];

  // Battery plugin
  final battery_plus.Battery _battery = battery_plus.Battery();
  StreamSubscription<battery_plus.BatteryState>? _batteryStateSubscription;

  // Session manager reference for background/foreground transitions
  SessionManager? _sessionManager;

  // Polling callbacks
  void Function()? _pausePollingCallback;
  void Function()? _resumePollingCallback;
  void Function()? _checkSdkSettingsCallback;

  // Shutdown flag to prevent operations after disposal
  bool _isShutdown = false;

  // Constants
  static const String _source = "DefaultBackgroundStateMonitor";

  DefaultBackgroundStateMonitor() {
    _initialize();
  }

  /// Setup listeners with callbacks for background/foreground transitions
  /// This method centralizes the background listener setup that was previously in CFClient
  void setupListeners({
    SessionManager? sessionManager,
    void Function()? onPausePolling,
    void Function()? onResumePolling,
    void Function()? onCheckSdkSettings,
  }) {
    _sessionManager = sessionManager;
    _pausePollingCallback = onPausePolling;
    _resumePollingCallback = onResumePolling;
    _checkSdkSettingsCallback = onCheckSdkSettings;

    addAppStateListener(
      _BasicAppStateListener(
        onStateChanged: (state) {
          if (state == AppState.background) {
            _pausePollingCallback?.call();
            // Notify SessionManager about background transition
            _sessionManager?.onAppBackground();
          } else if (state == AppState.active) {
            _resumePollingCallback?.call();
            _checkSdkSettingsCallback?.call();
            // Notify SessionManager about foreground transition
            _sessionManager?.onAppForeground();
            // Update session activity
            _sessionManager?.updateActivity();
          }
        },
      ),
    );

    Logger.d('Background state listeners configured');
  }

  // Initialize monitoring
  void _initialize() {
    if (_isShutdown) return;

    // Register with WidgetsBinding for lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Initialize battery monitoring
    _initializeBatteryMonitoring();
  }

  // Initialize battery monitoring
  Future<void> _initializeBatteryMonitoring() async {
    if (_isShutdown) return;

    try {
      // Get initial battery level
      _currentBatteryLevel = await _battery.batteryLevel;

      // Get initial battery state
      final batteryState = await _battery.batteryState;
      _updateBatteryState(batteryState);

      // Listen for battery state changes
      _batteryStateSubscription = _battery.onBatteryStateChanged.listen(
        _updateBatteryState,
      );
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to initialize battery monitoring",
        source: _source,
        severity: ErrorSeverity.low,
      );
    }
  }

  // Update battery state
  void _updateBatteryState(battery_plus.BatteryState batteryState) async {
    if (_isShutdown) return;

    try {
      // Get current battery level
      _currentBatteryLevel = await _battery.batteryLevel;

      // Map to our battery state enum
      final newState = BatteryStateExtension.fromBatteryPlusState(
        batteryState,
        _currentBatteryLevel,
      );

      if (newState != _currentBatteryState) {
        _currentBatteryState = newState;
        _notifyBatteryStateListeners();
      }
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to update battery state",
        source: _source,
        severity: ErrorSeverity.low,
      );
    }
  }

  // Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isShutdown) return;

    final newAppState = AppStateExtension.fromAppLifecycleState(state);

    if (newAppState != _currentAppState) {
      _currentAppState = newAppState;
      _notifyAppStateListeners();
    }
  }

  // Notify app state listeners - safe from concurrent modification
  void _notifyAppStateListeners() {
    if (_isShutdown) return;

    // Create a copy of the listeners list to avoid concurrent modification
    final listeners = List<AppStateListener>.from(_appStateListeners);

    for (final listener in listeners) {
      // Check if listener is still in the list (might have been removed)
      if (!_appStateListeners.contains(listener)) continue;

      try {
        listener.onAppStateChanged(_currentAppState);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying app state listener",
          source: _source,
          severity: ErrorSeverity.low,
        );
      }
    }
  }

  // Notify battery state listeners - safe from concurrent modification
  void _notifyBatteryStateListeners() {
    if (_isShutdown) return;

    // Create a copy of the listeners list to avoid concurrent modification
    final listeners = List<BatteryStateListener>.from(_batteryStateListeners);

    for (final listener in listeners) {
      // Check if listener is still in the list (might have been removed)
      if (!_batteryStateListeners.contains(listener)) continue;

      try {
        listener.onBatteryStateChanged(
          _currentBatteryState,
          _currentBatteryLevel,
        );
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying battery state listener",
          source: _source,
          severity: ErrorSeverity.low,
        );
      }
    }
  }

  // Add app state listener
  @override
  void addAppStateListener(AppStateListener listener) {
    if (_isShutdown) return;

    if (!_appStateListeners.contains(listener)) {
      _appStateListeners.add(listener);

      // Immediately notify with current state
      try {
        listener.onAppStateChanged(_currentAppState);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying new app state listener",
          source: _source,
          severity: ErrorSeverity.low,
        );
      }
    }
  }

  // Remove app state listener
  @override
  void removeAppStateListener(AppStateListener listener) {
    if (_isShutdown) return;
    _appStateListeners.remove(listener);
  }

  // Add battery state listener
  @override
  void addBatteryStateListener(BatteryStateListener listener) {
    if (_isShutdown) return;

    if (!_batteryStateListeners.contains(listener)) {
      _batteryStateListeners.add(listener);

      // Immediately notify with current state
      try {
        listener.onBatteryStateChanged(
          _currentBatteryState,
          _currentBatteryLevel,
        );
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying new battery state listener",
          source: _source,
          severity: ErrorSeverity.low,
        );
      }
    }
  }

  // Remove battery state listener
  @override
  void removeBatteryStateListener(BatteryStateListener listener) {
    if (_isShutdown) return;
    _batteryStateListeners.remove(listener);
  }

  // Get current app state
  @override
  AppState getCurrentAppState() => _currentAppState;

  // Get current state (legacy method for compatibility)
  AppState getCurrentState() => getCurrentAppState();

  // Get current battery state
  @override
  BatteryState getCurrentBatteryState() => _currentBatteryState;

  // Get current battery level
  @override
  int getCurrentBatteryLevel() => _currentBatteryLevel;

  // Clean up resources
  @override
  void shutdown() {
    if (_isShutdown) return;

    _isShutdown = true;

    // Cancel battery subscription first
    _batteryStateSubscription?.cancel();
    _batteryStateSubscription = null;

    // Remove from WidgetsBinding
    WidgetsBinding.instance.removeObserver(this);

    // Clear listeners
    _appStateListeners.clear();
    _batteryStateListeners.clear();
  }
}

/// Basic app state listener for internal use
class _BasicAppStateListener implements AppStateListener {
  final void Function(AppState) onStateChanged;

  _BasicAppStateListener({required this.onStateChanged});

  @override
  void onAppStateChanged(AppState state) {
    onStateChanged(state);
  }
}
