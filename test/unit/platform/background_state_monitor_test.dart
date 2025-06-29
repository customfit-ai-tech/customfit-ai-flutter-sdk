// test/unit/platform/background_state_monitor_test.dart
//
// Comprehensive test suite for BackgroundStateMonitor and DefaultBackgroundStateMonitor
// Consolidated from multiple test files to eliminate duplication while maintaining complete coverage
//
// Original files consolidated:
// - background_state_monitor_test.dart (interface tests)
// - default_background_state_monitor_test.dart (implementation tests)
// - default_background_state_monitor_comprehensive_test.dart (advanced coverage tests)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:battery_plus/battery_plus.dart' as battery_plus;
import 'package:customfit_ai_flutter_sdk/src/platform/default_background_state_monitor.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/app_state.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/battery_state.dart';import '../../helpers/test_storage_helper.dart';// Test implementation of BackgroundStateMonitor interface
class TestBackgroundStateMonitor implements BackgroundStateMonitor {
  final List<AppStateListener> appStateListeners = [];
  final List<BatteryStateListener> batteryStateListeners = [];
  AppState _currentAppState = AppState.unknown;
  BatteryState _currentBatteryState = BatteryState.unknown;
  int _currentBatteryLevel = 0;
  bool _isShutdown = false;
  void setCurrentAppState(AppState state) => _currentAppState = state;
  void setCurrentBatteryState(BatteryState state) =>
      _currentBatteryState = state;
  void setCurrentBatteryLevel(int level) => _currentBatteryLevel = level;
  @override
  void addAppStateListener(AppStateListener listener) {
    if (!_isShutdown && !appStateListeners.contains(listener)) {
      appStateListeners.add(listener);
    }
  }
  @override
  void removeAppStateListener(AppStateListener listener) {
    appStateListeners.remove(listener);
  }
  @override
  void addBatteryStateListener(BatteryStateListener listener) {
    if (!_isShutdown && !batteryStateListeners.contains(listener)) {
      batteryStateListeners.add(listener);
    }
  }
  @override
  void removeBatteryStateListener(BatteryStateListener listener) {
    batteryStateListeners.remove(listener);
  }
  @override
  AppState getCurrentAppState() {
    return _isShutdown ? AppState.unknown : _currentAppState;
  }
  @override
  BatteryState getCurrentBatteryState() {
    return _isShutdown ? BatteryState.unknown : _currentBatteryState;
  }
  @override
  int getCurrentBatteryLevel() {
    return _isShutdown ? 0 : _currentBatteryLevel;
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
      listener.onAppStateChanged(newState);
    }
  }
  void simulateBatteryStateChange(BatteryState newState, int level) {
    _currentBatteryState = newState;
    _currentBatteryLevel = level;
    for (final listener in batteryStateListeners) {
      listener.onBatteryStateChanged(newState, level);
    }
  }
  bool get isShutdown => _isShutdown;
}
// Mock Session Manager for testing setupListeners functionality
class MockSessionManager {
  int onAppBackgroundCallCount = 0;
  int onAppForegroundCallCount = 0;
  int updateActivityCallCount = 0;
  void onAppBackground() {
    onAppBackgroundCallCount++;
  }
  void onAppForeground() {
    onAppForegroundCallCount++;
  }
  Future<void> updateActivity() async {
    updateActivityCallCount++;
  }
  void reset() {
    onAppBackgroundCallCount = 0;
    onAppForegroundCallCount = 0;
    updateActivityCallCount = 0;
  }
}
// Test listener implementations
class TestAppStateListener implements AppStateListener {
  final List<AppState> receivedStates = [];
  @override
  void onAppStateChanged(AppState newState) => receivedStates.add(newState);
}
class TestBatteryStateListener implements BatteryStateListener {
  final List<String> receivedChanges = [];
  @override
  void onBatteryStateChanged(BatteryState newState, int level) {
    receivedChanges.add('$newState:$level');
  }
}
// Test listener that bridges app state changes to session manager calls
class TestSessionManagerListener implements AppStateListener {
  final MockSessionManager sessionManager;
  TestSessionManagerListener(this.sessionManager);
  @override
  void onAppStateChanged(AppState state) {
    if (state == AppState.background) {
      sessionManager.onAppBackground();
    } else if (state == AppState.active) {
      sessionManager.onAppForeground();
      sessionManager.updateActivity();
    }
  }
}
// Mock listeners for advanced testing
class MockAppStateListener implements AppStateListener {
  AppState? lastState;
  int callCount = 0;
  @override
  void onAppStateChanged(AppState state) {
    lastState = state;
    callCount++;
  }
  void reset() {
    lastState = null;
    callCount = 0;
  }
}
class MockBatteryStateListener implements BatteryStateListener {
  BatteryState? lastState;
  int? lastLevel;
  int callCount = 0;
  @override
  void onBatteryStateChanged(BatteryState state, int level) {
    lastState = state;
    lastLevel = level;
    callCount++;
  }
  void reset() {
    lastState = null;
    lastLevel = null;
    callCount = 0;
  }
}
// Listeners that throw exceptions for error handling tests
class FailingAppStateListener implements AppStateListener {
  @override
  void onAppStateChanged(AppState state) {
    throw Exception('Simulated app state listener failure');
  }
}
class FailingBatteryStateListener implements BatteryStateListener {
  @override
  void onBatteryStateChanged(BatteryState state, int level) {
    throw Exception('Simulated battery state listener failure');
  }
}
// Listeners that modify the listener list during notification
class SelfRemovingAppStateListener implements AppStateListener {
  final DefaultBackgroundStateMonitor monitor;
  bool hasRemoved = false;
  SelfRemovingAppStateListener(this.monitor);
  @override
  void onAppStateChanged(AppState state) {
    if (!hasRemoved) {
      hasRemoved = true;
      monitor.removeAppStateListener(this);
    }
  }
}
class SelfRemovingBatteryStateListener implements BatteryStateListener {
  final DefaultBackgroundStateMonitor monitor;
  bool hasRemoved = false;
  SelfRemovingBatteryStateListener(this.monitor);
  @override
  void onBatteryStateChanged(BatteryState state, int level) {
    if (!hasRemoved) {
      hasRemoved = true;
      monitor.removeBatteryStateListener(this);
    }
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('BackgroundStateMonitor Comprehensive Tests', () {
    group('1. Interface Contract Tests', () {
      late TestBackgroundStateMonitor monitor;
      setUp(() {
        monitor = TestBackgroundStateMonitor();
      });
      test('should be an abstract class that can be implemented', () {
        expect(monitor, isA<BackgroundStateMonitor>());
      });
      test('should have all required methods', () {
        final appListener = TestAppStateListener();
        final batteryListener = TestBatteryStateListener();
        expect(() => monitor.addAppStateListener(appListener), returnsNormally);
        expect(
            () => monitor.removeAppStateListener(appListener), returnsNormally);
        expect(() => monitor.addBatteryStateListener(batteryListener),
            returnsNormally);
        expect(() => monitor.removeBatteryStateListener(batteryListener),
            returnsNormally);
        expect(() => monitor.getCurrentAppState(), returnsNormally);
        expect(() => monitor.getCurrentBatteryState(), returnsNormally);
        expect(() => monitor.getCurrentBatteryLevel(), returnsNormally);
        expect(() => monitor.shutdown(), returnsNormally);
      });
      test('should add app state listeners', () {
        final listener1 = TestAppStateListener();
        final listener2 = TestAppStateListener();
        monitor.addAppStateListener(listener1);
        monitor.addAppStateListener(listener2);
        expect(monitor.appStateListeners, contains(listener1));
        expect(monitor.appStateListeners, contains(listener2));
        expect(monitor.appStateListeners, hasLength(2));
      });
      test('should remove app state listeners', () {
        final listener1 = TestAppStateListener();
        final listener2 = TestAppStateListener();
        monitor.addAppStateListener(listener1);
        monitor.addAppStateListener(listener2);
        expect(monitor.appStateListeners, hasLength(2));
        monitor.removeAppStateListener(listener1);
        expect(monitor.appStateListeners, contains(listener2));
        expect(monitor.appStateListeners, hasLength(1));
        monitor.removeAppStateListener(listener2);
        expect(monitor.appStateListeners, isEmpty);
      });
      test('should not add duplicate app state listeners', () {
        final listener = TestAppStateListener();
        monitor.addAppStateListener(listener);
        monitor.addAppStateListener(listener);
        expect(monitor.appStateListeners, hasLength(1));
      });
      test('should handle removing non-existent app state listeners', () {
        final listener = TestAppStateListener();
        expect(() => monitor.removeAppStateListener(listener), returnsNormally);
        expect(monitor.appStateListeners, isEmpty);
      });
      test('should notify app state listeners of changes', () {
        final listener1 = TestAppStateListener();
        final listener2 = TestAppStateListener();
        monitor.addAppStateListener(listener1);
        monitor.addAppStateListener(listener2);
        monitor.simulateAppStateChange(AppState.active);
        expect(listener1.receivedStates, contains(AppState.active));
        expect(listener2.receivedStates, contains(AppState.active));
      });
      test('should add battery state listeners', () {
        final listener1 = TestBatteryStateListener();
        final listener2 = TestBatteryStateListener();
        monitor.addBatteryStateListener(listener1);
        monitor.addBatteryStateListener(listener2);
        expect(monitor.batteryStateListeners, contains(listener1));
        expect(monitor.batteryStateListeners, contains(listener2));
        expect(monitor.batteryStateListeners, hasLength(2));
      });
      test('should remove battery state listeners', () {
        final listener1 = TestBatteryStateListener();
        final listener2 = TestBatteryStateListener();
        monitor.addBatteryStateListener(listener1);
        monitor.addBatteryStateListener(listener2);
        expect(monitor.batteryStateListeners, hasLength(2));
        monitor.removeBatteryStateListener(listener1);
        expect(monitor.batteryStateListeners, contains(listener2));
        expect(monitor.batteryStateListeners, hasLength(1));
        monitor.removeBatteryStateListener(listener2);
        expect(monitor.batteryStateListeners, isEmpty);
      });
      test('should not add duplicate battery state listeners', () {
        final listener = TestBatteryStateListener();
        monitor.addBatteryStateListener(listener);
        monitor.addBatteryStateListener(listener);
        expect(monitor.batteryStateListeners, hasLength(1));
      });
      test('should notify battery state listeners of changes', () {
        final listener1 = TestBatteryStateListener();
        final listener2 = TestBatteryStateListener();
        monitor.addBatteryStateListener(listener1);
        monitor.addBatteryStateListener(listener2);
        monitor.simulateBatteryStateChange(BatteryState.low, 15);
        expect(listener1.receivedChanges, contains('BatteryState.low:15'));
        expect(listener2.receivedChanges, contains('BatteryState.low:15'));
      });
      test('should return current app state', () {
        monitor.setCurrentAppState(AppState.active);
        expect(monitor.getCurrentAppState(), equals(AppState.active));
        monitor.setCurrentAppState(AppState.background);
        expect(monitor.getCurrentAppState(), equals(AppState.background));
      });
      test('should return current battery state', () {
        monitor.setCurrentBatteryState(BatteryState.normal);
        expect(monitor.getCurrentBatteryState(), equals(BatteryState.normal));
        monitor.setCurrentBatteryState(BatteryState.charging);
        expect(monitor.getCurrentBatteryState(), equals(BatteryState.charging));
      });
      test('should return current battery level', () {
        monitor.setCurrentBatteryLevel(75);
        expect(monitor.getCurrentBatteryLevel(), equals(75));
        monitor.setCurrentBatteryLevel(25);
        expect(monitor.getCurrentBatteryLevel(), equals(25));
      });
      test('should handle all possible app states', () {
        for (final state in AppState.values) {
          monitor.setCurrentAppState(state);
          expect(monitor.getCurrentAppState(), equals(state));
        }
      });
      test('should handle all possible battery states', () {
        for (final state in BatteryState.values) {
          monitor.setCurrentBatteryState(state);
          expect(monitor.getCurrentBatteryState(), equals(state));
        }
      });
      test('should handle various battery levels', () {
        final levels = [0, 1, 25, 50, 75, 99, 100];
        for (final level in levels) {
          monitor.setCurrentBatteryLevel(level);
          expect(monitor.getCurrentBatteryLevel(), equals(level));
        }
      });
      test('should shutdown gracefully', () {
        final appListener = TestAppStateListener();
        final batteryListener = TestBatteryStateListener();
        monitor.addAppStateListener(appListener);
        monitor.addBatteryStateListener(batteryListener);
        expect(monitor.appStateListeners, hasLength(1));
        expect(monitor.batteryStateListeners, hasLength(1));
        monitor.shutdown();
        expect(monitor.isShutdown, isTrue);
        expect(monitor.appStateListeners, isEmpty);
        expect(monitor.batteryStateListeners, isEmpty);
      });
      test('should return default values after shutdown', () {
        monitor.setCurrentAppState(AppState.active);
        monitor.setCurrentBatteryState(BatteryState.full);
        monitor.setCurrentBatteryLevel(95);
        monitor.shutdown();
        expect(monitor.getCurrentAppState(), equals(AppState.unknown));
        expect(monitor.getCurrentBatteryState(), equals(BatteryState.unknown));
        expect(monitor.getCurrentBatteryLevel(), equals(0));
      });
      test('should not accept new listeners after shutdown', () {
        monitor.shutdown();
        final appListener = TestAppStateListener();
        final batteryListener = TestBatteryStateListener();
        monitor.addAppStateListener(appListener);
        monitor.addBatteryStateListener(batteryListener);
        expect(monitor.appStateListeners, isEmpty);
        expect(monitor.batteryStateListeners, isEmpty);
      });
      test('should handle multiple shutdown calls', () {
        monitor.shutdown();
        expect(() => monitor.shutdown(), returnsNormally);
        expect(() => monitor.shutdown(), returnsNormally);
        expect(monitor.isShutdown, isTrue);
      });
    });
    group('2. DefaultBackgroundStateMonitor Implementation Tests', () {
      late DefaultBackgroundStateMonitor monitor;
      late MockSessionManager mockSessionManager;
      setUp(() {
        monitor = DefaultBackgroundStateMonitor();
        TestStorageHelper.setupTestStorage();
        mockSessionManager = MockSessionManager();
      });
      tearDown(() async {
        TestStorageHelper.clearTestStorage();
        await Future.delayed(const Duration(milliseconds: 10));
        monitor.shutdown();
        await Future.delayed(const Duration(milliseconds: 10));
      });
      test('should initialize with default values', () {
        expect(monitor.getCurrentAppState(), equals(AppState.active));
        expect(monitor.getCurrentBatteryLevel(), equals(100));
        expect(monitor.getCurrentBatteryState(), equals(BatteryState.unknown));
      });
      test('should handle app lifecycle state changes', () {
        final listener = MockAppStateListener();
        monitor.addAppStateListener(listener);
        // Reset to ignore initial notification
        listener.reset();
        monitor.didChangeAppLifecycleState(AppLifecycleState.paused);
        expect(listener.lastState, equals(AppState.background));
        expect(listener.callCount, equals(1));
        monitor.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(listener.lastState, equals(AppState.active));
        expect(listener.callCount, equals(2));
      });
      test('should map all app lifecycle states correctly', () {
        final listener = MockAppStateListener();
        monitor.addAppStateListener(listener);
        listener.reset();
        final mappings = {
          AppLifecycleState.resumed: AppState.active,
          AppLifecycleState.inactive: AppState.inactive,
          AppLifecycleState.paused: AppState.background,
          AppLifecycleState.detached: AppState.background,
        };
        // Start with a different state to ensure each transition is detected
        monitor.didChangeAppLifecycleState(AppLifecycleState.paused);
        listener.reset(); // Reset after initial state
        for (final entry in mappings.entries) {
          // Ensure we start from a different state to trigger the change
          if (entry.value == AppState.active) {
            monitor.didChangeAppLifecycleState(AppLifecycleState.paused);
          } else {
            monitor.didChangeAppLifecycleState(AppLifecycleState.resumed);
          }
          listener.reset(); // Reset before the actual test
          monitor.didChangeAppLifecycleState(entry.key);
          expect(listener.lastState, equals(entry.value),
              reason: 'Failed to map ${entry.key} to ${entry.value}');
          expect(listener.callCount, equals(1),
              reason:
                  'Listener should be called exactly once for ${entry.key}');
        }
      });
      test('should notify battery listeners on initialization', () {
        final listener = MockBatteryStateListener();
        monitor.addBatteryStateListener(listener);
        expect(listener.callCount, equals(1));
        expect(listener.lastState, equals(BatteryState.unknown));
        expect(listener.lastLevel, equals(100));
      });
      test('should handle battery state monitoring gracefully', () async {
        final listener = MockBatteryStateListener();
        monitor.addBatteryStateListener(listener);
        expect(listener.callCount, equals(1));
        expect(listener.lastState, equals(BatteryState.unknown));
        expect(listener.lastLevel, equals(100));
      });
      test('should handle setupListeners with session manager integration', () {
        bool pausePollingCalled = false;
        bool resumePollingCalled = false;
        bool checkSdkSettingsCalled = false;
        monitor.setupListeners(
          sessionManager: null,
          onPausePolling: () => pausePollingCalled = true,
          onResumePolling: () => resumePollingCalled = true,
          onCheckSdkSettings: () => checkSdkSettingsCalled = true,
        );
        monitor.addAppStateListener(
            TestSessionManagerListener(mockSessionManager));
        mockSessionManager.reset();
        monitor.didChangeAppLifecycleState(AppLifecycleState.paused);
        expect(pausePollingCalled, isTrue);
        expect(mockSessionManager.onAppBackgroundCallCount, equals(1));
        pausePollingCalled = false;
        resumePollingCalled = false;
        checkSdkSettingsCalled = false;
        monitor.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(resumePollingCalled, isTrue);
        expect(checkSdkSettingsCalled, isTrue);
        expect(mockSessionManager.onAppForegroundCallCount, equals(1));
        expect(mockSessionManager.updateActivityCallCount, equals(1));
      });
      test('should handle null callbacks gracefully in setupListeners', () {
        expect(
          () => monitor.setupListeners(
            sessionManager: null,
            onPausePolling: null,
            onResumePolling: null,
            onCheckSdkSettings: null,
          ),
          returnsNormally,
        );
        monitor.addAppStateListener(
            TestSessionManagerListener(mockSessionManager));
        mockSessionManager.reset();
        expect(
            () => monitor.didChangeAppLifecycleState(AppLifecycleState.paused),
            returnsNormally);
        expect(
            () => monitor.didChangeAppLifecycleState(AppLifecycleState.resumed),
            returnsNormally);
        expect(mockSessionManager.onAppBackgroundCallCount, equals(1));
        expect(mockSessionManager.onAppForegroundCallCount, equals(1));
        expect(mockSessionManager.updateActivityCallCount, equals(1));
      });
      test('should handle inactive state transitions correctly', () {
        bool resumePollingCalled = false;
        bool checkSdkSettingsCalled = false;
        monitor.setupListeners(
          sessionManager: null,
          onResumePolling: () => resumePollingCalled = true,
          onCheckSdkSettings: () => checkSdkSettingsCalled = true,
        );
        monitor.addAppStateListener(
            TestSessionManagerListener(mockSessionManager));
        mockSessionManager.reset();
        monitor.didChangeAppLifecycleState(AppLifecycleState.inactive);
        expect(mockSessionManager.onAppBackgroundCallCount, equals(0));
        expect(mockSessionManager.onAppForegroundCallCount, equals(0));
        expect(resumePollingCalled, isTrue);
        expect(checkSdkSettingsCalled, isTrue);
      });
      test('should handle detached state as background transition', () {
        bool pausePollingCalled = false;
        monitor.setupListeners(
          sessionManager: null,
          onPausePolling: () => pausePollingCalled = true,
        );
        monitor.addAppStateListener(
            TestSessionManagerListener(mockSessionManager));
        monitor.didChangeAppLifecycleState(AppLifecycleState.detached);
        expect(pausePollingCalled, isTrue);
        expect(mockSessionManager.onAppBackgroundCallCount, equals(1));
      });
    });
    group('3. Advanced Error Handling and Edge Cases', () {
      late DefaultBackgroundStateMonitor monitor;
      setUp(() {
        monitor = DefaultBackgroundStateMonitor();
        TestStorageHelper.setupTestStorage();
      });
      tearDown(() async {
        TestStorageHelper.clearTestStorage();
        await Future.delayed(const Duration(milliseconds: 10));
        monitor.shutdown();
        await Future.delayed(const Duration(milliseconds: 10));
      });
      test(
          'should handle battery monitoring initialization gracefully after shutdown',
          () async {
        monitor.shutdown();
        expect(
            () => monitor.didChangeAppLifecycleState(AppLifecycleState.resumed),
            returnsNormally);
        expect(monitor.getCurrentBatteryLevel(), equals(100));
        expect(monitor.getCurrentBatteryState(), equals(BatteryState.unknown));
      });
      test('should maintain default battery state when monitoring fails', () {
        expect(monitor.getCurrentBatteryLevel(), equals(100));
        expect(monitor.getCurrentBatteryState(), equals(BatteryState.unknown));
      });
      test('should handle battery state update errors gracefully', () async {
        final listener = MockBatteryStateListener();
        monitor.addBatteryStateListener(listener);
        expect(listener.callCount, equals(1));
        expect(listener.lastState, equals(BatteryState.unknown));
        expect(listener.lastLevel, equals(100));
      });
      test(
          'should handle concurrent app state listener modifications during notification',
          () {
        final normalListener = MockAppStateListener();
        final removingListener = SelfRemovingAppStateListener(monitor);
        monitor.addAppStateListener(normalListener);
        monitor.addAppStateListener(removingListener);
        expect(normalListener.callCount, equals(1));
        expect(
            () => monitor.didChangeAppLifecycleState(AppLifecycleState.paused),
            returnsNormally);
        expect(normalListener.callCount, equals(2));
        expect(normalListener.lastState, equals(AppState.background));
      });
      test(
          'should handle concurrent battery state listener modifications during notification',
          () async {
        final normalListener = MockBatteryStateListener();
        final removingListener = SelfRemovingBatteryStateListener(monitor);
        monitor.addBatteryStateListener(normalListener);
        monitor.addBatteryStateListener(removingListener);
        expect(normalListener.callCount, equals(1));
        await Future.delayed(const Duration(milliseconds: 50));
        expect(normalListener.lastState, equals(BatteryState.unknown));
        expect(normalListener.lastLevel, equals(100));
      });
      test('should handle failing app state listeners gracefully', () {
        final goodListener = MockAppStateListener();
        final failingListener = FailingAppStateListener();
        monitor.addAppStateListener(goodListener);
        monitor.addAppStateListener(failingListener);
        expect(
            () => monitor.didChangeAppLifecycleState(AppLifecycleState.paused),
            returnsNormally);
        expect(goodListener.callCount, equals(2));
        expect(goodListener.lastState, equals(AppState.background));
      });
      test('should handle failing battery state listeners gracefully', () {
        final goodListener = MockBatteryStateListener();
        final failingListener = FailingBatteryStateListener();
        expect(() => monitor.addBatteryStateListener(goodListener),
            returnsNormally);
        expect(() => monitor.addBatteryStateListener(failingListener),
            returnsNormally);
        expect(goodListener.callCount, equals(1));
        expect(goodListener.lastState, equals(BatteryState.unknown));
        expect(goodListener.lastLevel, equals(100));
      });
      test('should handle empty listener lists during notification', () {
        final listener = MockAppStateListener();
        monitor.addAppStateListener(listener);
        monitor.removeAppStateListener(listener);
        expect(
            () => monitor.didChangeAppLifecycleState(AppLifecycleState.paused),
            returnsNormally);
      });
      test('should handle shutdown during battery monitoring initialization',
          () async {
        final newMonitor = DefaultBackgroundStateMonitor();
        await Future.delayed(const Duration(milliseconds: 1));
        newMonitor.shutdown();
        expect(newMonitor.getCurrentAppState(), equals(AppState.active));
        expect(newMonitor.getCurrentBatteryLevel(), equals(100));
      });
      test('should prevent all operations after shutdown', () {
        final listener = MockAppStateListener();
        monitor.addAppStateListener(listener);
        expect(listener.callCount, equals(1));
        monitor.shutdown();
        monitor.addAppStateListener(MockAppStateListener());
        monitor.removeAppStateListener(listener);
        monitor.addBatteryStateListener(MockBatteryStateListener());
        monitor.removeBatteryStateListener(MockBatteryStateListener());
        monitor.didChangeAppLifecycleState(AppLifecycleState.paused);
        expect(listener.callCount, equals(1));
      });
      test('should handle multiple rapid shutdowns gracefully', () {
        expect(() {
          monitor.shutdown();
          monitor.shutdown();
          monitor.shutdown();
        }, returnsNormally);
      });
    });
    group('4. Integration and Performance Tests', () {
      late TestBackgroundStateMonitor monitor;
      setUp(() {
        monitor = TestBackgroundStateMonitor();
      });
      test('should handle complete app lifecycle monitoring', () {
        final appListener = TestAppStateListener();
        final batteryListener = TestBatteryStateListener();
        monitor.addAppStateListener(appListener);
        monitor.addBatteryStateListener(batteryListener);
        monitor.simulateAppStateChange(AppState.active);
        monitor.simulateBatteryStateChange(BatteryState.normal, 80);
        monitor.simulateAppStateChange(AppState.background);
        monitor.simulateBatteryStateChange(BatteryState.low, 15);
        monitor.simulateAppStateChange(AppState.active);
        monitor.simulateBatteryStateChange(BatteryState.charging, 20);
        expect(
            appListener.receivedStates,
            equals([
              AppState.active,
              AppState.background,
              AppState.active,
            ]));
        expect(
            batteryListener.receivedChanges,
            equals([
              'BatteryState.normal:80',
              'BatteryState.low:15',
              'BatteryState.charging:20',
            ]));
      });
      test('should handle mixed listener operations', () {
        final appListener1 = TestAppStateListener();
        final appListener2 = TestAppStateListener();
        final batteryListener1 = TestBatteryStateListener();
        monitor.addAppStateListener(appListener1);
        monitor.addBatteryStateListener(batteryListener1);
        monitor.simulateAppStateChange(AppState.active);
        monitor.simulateBatteryStateChange(BatteryState.normal, 50);
        monitor.addAppStateListener(appListener2);
        monitor.simulateAppStateChange(AppState.background);
        expect(appListener1.receivedStates,
            equals([AppState.active, AppState.background]));
        expect(appListener2.receivedStates, equals([AppState.background]));
        expect(batteryListener1.receivedChanges,
            equals(['BatteryState.normal:50']));
      });
      test('should maintain state consistency', () {
        monitor.setCurrentAppState(AppState.active);
        monitor.setCurrentBatteryState(BatteryState.normal);
        monitor.setCurrentBatteryLevel(75);
        expect(monitor.getCurrentAppState(), equals(AppState.active));
        expect(monitor.getCurrentBatteryState(), equals(BatteryState.normal));
        expect(monitor.getCurrentBatteryLevel(), equals(75));
        expect(monitor.getCurrentAppState(), equals(AppState.active));
        expect(monitor.getCurrentBatteryState(), equals(BatteryState.normal));
        expect(monitor.getCurrentBatteryLevel(), equals(75));
      });
      test('should handle many listeners efficiently', () {
        final appListeners = List.generate(100, (_) => TestAppStateListener());
        final batteryListeners =
            List.generate(100, (_) => TestBatteryStateListener());
        final stopwatch = Stopwatch()..start();
        for (final listener in appListeners) {
          monitor.addAppStateListener(listener);
        }
        for (final listener in batteryListeners) {
          monitor.addBatteryStateListener(listener);
        }
        stopwatch.stop();
        expect(monitor.appStateListeners, hasLength(100));
        expect(monitor.batteryStateListeners, hasLength(100));
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
      test('should handle rapid state changes efficiently', () {
        final appListener = TestAppStateListener();
        final batteryListener = TestBatteryStateListener();
        monitor.addAppStateListener(appListener);
        monitor.addBatteryStateListener(batteryListener);
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 1000; i++) {
          final appState = AppState.values[i % AppState.values.length];
          final batteryState =
              BatteryState.values[i % BatteryState.values.length];
          final level = i % 101;
          monitor.simulateAppStateChange(appState);
          monitor.simulateBatteryStateChange(batteryState, level);
        }
        stopwatch.stop();
        expect(appListener.receivedStates, hasLength(1000));
        expect(batteryListener.receivedChanges, hasLength(1000));
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });
      test('should handle extreme battery levels', () {
        final extremeLevels = [-1000, -1, 0, 1, 100, 101, 1000];
        for (final level in extremeLevels) {
          monitor.setCurrentBatteryLevel(level);
          expect(monitor.getCurrentBatteryLevel(), equals(level));
        }
      });
      test('should handle rapid add/remove of same listener', () {
        final appListener = TestAppStateListener();
        for (int i = 0; i < 10; i++) {
          monitor.addAppStateListener(appListener);
          monitor.removeAppStateListener(appListener);
        }
        expect(monitor.appStateListeners, isEmpty);
      });
      test('should handle state changes with no listeners', () {
        expect(() => monitor.simulateAppStateChange(AppState.active),
            returnsNormally);
        expect(
            () => monitor.simulateBatteryStateChange(BatteryState.normal, 50),
            returnsNormally);
      });
    });
  });
}
