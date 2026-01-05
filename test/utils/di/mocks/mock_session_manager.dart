import 'dart:async';
import 'package:customfit_ai_flutter_sdk/src/core/session/session_manager.dart';
/// Mock session manager for testing
class MockSessionManager implements SessionManager {
  String _currentSessionId = 'mock-session-id';
  final List<SessionRotationListener> _listeners = [];
  int updateActivityCount = 0;
  int forceRotationCount = 0;
  void setSessionId(String sessionId) {
    final oldId = _currentSessionId;
    _currentSessionId = sessionId;
    _notifyRotation(oldId, sessionId, RotationReason.manual);
  }
  void reset() {
    _currentSessionId = 'mock-session-id';
    _listeners.clear();
    updateActivityCount = 0;
    forceRotationCount = 0;
  }
  @override
  String getCurrentSessionId() {
    return _currentSessionId;
  }
  @override
  SessionData? getCurrentSession() {
    return SessionData(
      sessionId: _currentSessionId,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
      lastActiveAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
  @override
  Future<String> forceRotation() async {
    forceRotationCount++;
    final oldId = _currentSessionId;
    _currentSessionId = 'mock-session-${DateTime.now().millisecondsSinceEpoch}';
    _notifyRotation(oldId, _currentSessionId, RotationReason.manual);
    return _currentSessionId;
  }
  @override
  Future<void> updateActivity() async {
    updateActivityCount++;
  }
  @override
  void onAuthenticationChange() {
    final oldId = _currentSessionId;
    _currentSessionId = 'mock-session-auth-${DateTime.now().millisecondsSinceEpoch}';
    _notifyRotation(oldId, _currentSessionId, RotationReason.timeout);
  }
  @override
  Future<void> onAppBackground() async {
    // Mock implementation
  }
  @override
  Future<void> onAppForeground() async {
    // Mock implementation
  }
  @override
  void addListener(SessionRotationListener listener) {
    _listeners.add(listener);
  }
  @override
  void removeListener(SessionRotationListener listener) {
    _listeners.remove(listener);
  }
  @override
  Map<String, dynamic> getSessionStats() {
    return {
      'hasActiveSession': true,
      'sessionId': _currentSessionId,
      'sessionManagerInitialized': true,
      'updateActivityCount': updateActivityCount,
      'forceRotationCount': forceRotationCount,
    };
  }
  // shutdown is a static method in SessionManager, not an instance method
  @override
  Future<void> shutdown() async {
    _listeners.clear();
  }
  void _notifyRotation(String oldId, String newId, RotationReason reason) {
    for (final listener in List.from(_listeners)) {
      listener.onSessionRotated(oldId, newId, reason);
    }
  }
  void simulateSessionError(String error) {
    for (final listener in List.from(_listeners)) {
      listener.onSessionError(error);
    }
  }
  void simulateSessionRestore(String sessionId) {
    _currentSessionId = sessionId;
    for (final listener in List.from(_listeners)) {
      listener.onSessionRestored(sessionId);
    }
  }
  Future<void> onNetworkChange() async {
    // Mock implementation
  }

  @override
  Future<void> clearSession() async {
    _currentSessionId = 'mock-session-id';
    _listeners.clear();
  }

  @override
  Future<String> rotateSession() async {
    return await forceRotation();
  }
}