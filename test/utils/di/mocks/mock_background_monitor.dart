import 'package:customfit_ai_flutter_sdk/src/platform/app_state.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/battery_state.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/default_background_state_monitor.dart';
/// Mock background monitor for testing
class MockBackgroundMonitor implements BackgroundStateMonitor {
  AppState _currentAppState = AppState.active;
  BatteryState _currentBatteryState = BatteryState.unknown;
  int _currentBatteryLevel = 100;
  final List<AppStateListener> _appStateListeners = [];
  final List<BatteryStateListener> _batteryStateListeners = [];
  void simulateAppState(AppState state) {
    _currentAppState = state;
    _notifyAppStateListeners();
  }
  void simulateBatteryState(BatteryState state, int level) {
    _currentBatteryState = state;
    _currentBatteryLevel = level;
    _notifyBatteryStateListeners();
  }
  void reset() {
    _currentAppState = AppState.active;
    _currentBatteryState = BatteryState.unknown;
    _currentBatteryLevel = 100;
    _appStateListeners.clear();
    _batteryStateListeners.clear();
  }
  // BackgroundStateMonitor methods
  @override
  AppState getCurrentAppState() {
    return _currentAppState;
  }
  @override
  BatteryState getCurrentBatteryState() {
    return _currentBatteryState;
  }
  @override
  int getCurrentBatteryLevel() {
    return _currentBatteryLevel;
  }
  @override
  void addAppStateListener(AppStateListener listener) {
    _appStateListeners.add(listener);
    // Notify immediately
    listener.onAppStateChanged(_currentAppState);
  }
  @override
  void removeAppStateListener(AppStateListener listener) {
    _appStateListeners.remove(listener);
  }
  @override
  void addBatteryStateListener(BatteryStateListener listener) {
    _batteryStateListeners.add(listener);
    // Notify immediately
    listener.onBatteryStateChanged(_currentBatteryState, _currentBatteryLevel);
  }
  @override
  void removeBatteryStateListener(BatteryStateListener listener) {
    _batteryStateListeners.remove(listener);
  }
  @override
  void shutdown() {
    _appStateListeners.clear();
    _batteryStateListeners.clear();
  }
  void _notifyAppStateListeners() {
    for (final listener in List.from(_appStateListeners)) {
      listener.onAppStateChanged(_currentAppState);
    }
  }
  void _notifyBatteryStateListeners() {
    for (final listener in List.from(_batteryStateListeners)) {
      listener.onBatteryStateChanged(_currentBatteryState, _currentBatteryLevel);
    }
  }
}