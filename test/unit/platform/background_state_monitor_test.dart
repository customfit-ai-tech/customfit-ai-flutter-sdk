// test/unit/platform/background_state_monitor_test.dart
//
// Updated test suite for BackgroundStateMonitor using new function-based infrastructure
//
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/infrastructure/platform/internal/default_background_state_monitor.dart';
import 'package:customfit_ai_flutter_sdk/src/infrastructure/types.dart';

// Test implementation of BackgroundStateMonitor interface
class TestBackgroundStateMonitor implements BackgroundStateMonitor {
  final List<void Function(AppState)> appStateListeners = [];
  final List<void Function(BatteryState)> batteryStateListeners = [];
  AppState _currentAppState = AppState.inactive;
  BatteryState _currentBatteryState = BatteryState.unknown;
  double _currentBatteryLevel = 0.0;
  bool _isShutdown = false;

  void setCurrentAppState(AppState state) => _currentAppState = state;
  void setCurrentBatteryState(BatteryState state) => _currentBatteryState = state;
  void setCurrentBatteryLevel(double level) => _currentBatteryLevel = level;

  @override
  void addAppStateListener(void Function(AppState) listener) {
    if (!_isShutdown && !appStateListeners.contains(listener)) {
      appStateListeners.add(listener);
    }
  }

  @override
  void removeAppStateListener(void Function(AppState) listener) {
    appStateListeners.remove(listener);
  }

  @override
  void addBatteryStateListener(void Function(BatteryState) listener) {
    if (!_isShutdown && !batteryStateListeners.contains(listener)) {
      batteryStateListeners.add(listener);
    }
  }

  @override
  void removeBatteryStateListener(void Function(BatteryState) listener) {
    batteryStateListeners.remove(listener);
  }

  @override
  AppState getCurrentAppState() {
    return _isShutdown ? AppState.inactive : _currentAppState;
  }

  @override
  BatteryState getCurrentBatteryState() {
    return _isShutdown ? BatteryState.unknown : _currentBatteryState;
  }

  @override
  double getBatteryLevel() {
    return _isShutdown ? 0.0 : _currentBatteryLevel;
  }

  @override
  void startMonitoring() {
    // Mock implementation
  }

  @override
  void stopMonitoring() {
    // Mock implementation
  }

  @override
  void shutdown() {
    _isShutdown = true;
    appStateListeners.clear();
    batteryStateListeners.clear();
  }

  // Test helper methods
  void simulateAppStateChange(AppState newState) {
    _currentAppState = newState;
    for (final listener in appStateListeners) {
      listener(newState);
    }
  }

  void simulateBatteryStateChange(BatteryState newState, double level) {
    _currentBatteryState = newState;
    _currentBatteryLevel = level;
    for (final listener in batteryStateListeners) {
      listener(newState);
    }
  }

  bool get isShutdown => _isShutdown;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundStateMonitor', () {
    late TestBackgroundStateMonitor monitor;

    setUp(() {
      monitor = TestBackgroundStateMonitor();
    });

    tearDown(() {
      monitor.shutdown();
    });

    test('should be instantiable', () {
      expect(monitor, isA<BackgroundStateMonitor>());
    });

    test('should start with default state', () {
      expect(monitor.getCurrentAppState(), AppState.inactive);
      expect(monitor.getCurrentBatteryState(), BatteryState.unknown);
      expect(monitor.getBatteryLevel(), 0.0);
    });

    test('should add and remove app state listeners', () {
      final receivedStates = <AppState>[];
      void listener(AppState state) => receivedStates.add(state);

      monitor.addAppStateListener(listener);
      monitor.simulateAppStateChange(AppState.foreground);
      
      expect(receivedStates, [AppState.foreground]);
      
      monitor.removeAppStateListener(listener);
      monitor.simulateAppStateChange(AppState.background);
      
      expect(receivedStates, [AppState.foreground]); // No new state added
    });

    test('should add and remove battery state listeners', () {
      final receivedStates = <BatteryState>[];
      void listener(BatteryState state) => receivedStates.add(state);

      monitor.addBatteryStateListener(listener);
      monitor.simulateBatteryStateChange(BatteryState.charging, 0.5);
      
      expect(receivedStates, [BatteryState.charging]);
      
      monitor.removeBatteryStateListener(listener);
      monitor.simulateBatteryStateChange(BatteryState.full, 1.0);
      
      expect(receivedStates, [BatteryState.charging]); // No new state added
    });

    test('should shutdown gracefully', () {
      final receivedStates = <AppState>[];
      void listener(AppState state) => receivedStates.add(state);
      
      monitor.addAppStateListener(listener);
      monitor.shutdown();
      
      expect(monitor.isShutdown, true);
      expect(monitor.getCurrentAppState(), AppState.inactive);
      
      // Should not add new listeners after shutdown
      monitor.addAppStateListener(listener);
      expect(monitor.appStateListeners.length, 0);
    });
  });

  group('DefaultBackgroundStateMonitor', () {
    late DefaultBackgroundStateMonitor monitor;

    setUp(() {
      monitor = DefaultBackgroundStateMonitor();
    });

    tearDown(() {
      monitor.shutdown();
    });

    test('should be instantiable', () {
      expect(monitor, isA<BackgroundStateMonitor>());
    });

    test('should have default states', () {
      expect(monitor.getCurrentAppState(), AppState.foreground);
      expect(monitor.getCurrentBatteryState(), BatteryState.unknown);
      expect(monitor.getBatteryLevel(), greaterThanOrEqualTo(0.0));
      expect(monitor.getBatteryLevel(), lessThanOrEqualTo(1.0));
    });

    test('should handle app state listeners', () {
      final receivedStates = <AppState>[];
      void listener(AppState state) => receivedStates.add(state);

      monitor.addAppStateListener(listener);
      
      // Should immediately call with current state
      expect(receivedStates.length, 1);
      expect(receivedStates.first, AppState.foreground);
      
      monitor.removeAppStateListener(listener);
    });

    test('should handle battery state listeners', () {
      final receivedStates = <BatteryState>[];
      void listener(BatteryState state) => receivedStates.add(state);

      monitor.addBatteryStateListener(listener);
      
      // Should immediately call with current state
      expect(receivedStates.length, 1);
      expect(receivedStates.first, BatteryState.unknown);
      
      monitor.removeBatteryStateListener(listener);
    });

    test('should start and stop monitoring', () {
      expect(() => monitor.startMonitoring(), returnsNormally);
      expect(() => monitor.stopMonitoring(), returnsNormally);
    });

    test('should shutdown gracefully', () {
      expect(() => monitor.shutdown(), returnsNormally);
    });
  });
}