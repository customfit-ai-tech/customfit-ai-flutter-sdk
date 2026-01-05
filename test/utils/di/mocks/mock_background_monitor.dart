import 'package:customfit_ai_flutter_sdk/src/infrastructure/types.dart';
/// Mock background monitor for testing
class MockBackgroundMonitor implements BackgroundStateMonitor {
  AppState _currentAppState = AppState.foreground;
  BatteryState _currentBatteryState = BatteryState.unknown;
  double _currentBatteryLevel = 1.0;
  final List<void Function(AppState)> _appStateListeners = [];
  final List<void Function(BatteryState)> _batteryStateListeners = [];
  void simulateAppState(AppState state) {
    _currentAppState = state;
    _notifyAppStateListeners();
  }
  void simulateBatteryState(BatteryState state, double level) {
    _currentBatteryState = state;
    _currentBatteryLevel = level;
    _notifyBatteryStateListeners();
  }
  void reset() {
    _currentAppState = AppState.foreground;
    _currentBatteryState = BatteryState.unknown;
    _currentBatteryLevel = 1.0;
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
  double getBatteryLevel() {
    return _currentBatteryLevel;
  }
  @override
  void addAppStateListener(void Function(AppState) listener) {
    _appStateListeners.add(listener);
    // Notify immediately
    listener(_currentAppState);
  }
  @override
  void removeAppStateListener(void Function(AppState) listener) {
    _appStateListeners.remove(listener);
  }
  @override
  void addBatteryStateListener(void Function(BatteryState) listener) {
    _batteryStateListeners.add(listener);
    // Notify immediately
    listener(_currentBatteryState);
  }
  @override
  void removeBatteryStateListener(void Function(BatteryState) listener) {
    _batteryStateListeners.remove(listener);
  }
  @override
  void startMonitoring() {
    // Mock implementation - no-op
  }
  
  @override
  void stopMonitoring() {
    _appStateListeners.clear();
    _batteryStateListeners.clear();
  }
  
  @override
  void shutdown() {
    stopMonitoring();
  }
  void _notifyAppStateListeners() {
    for (final listener in List.from(_appStateListeners)) {
      listener(_currentAppState);
    }
  }
  void _notifyBatteryStateListeners() {
    for (final listener in List.from(_batteryStateListeners)) {
      listener(_currentBatteryState);
    }
  }
}