// lib/src/client/cf_client_session_management.dart
//
// Session management facade for CFClient
// Handles all session-related operations including lifecycle, rotation, and activity tracking

import 'dart:async';
import '../core/session/session_manager.dart';

/// Facade component for session management operations
///
/// This component encapsulates all session-related functionality including:
/// - Session lifecycle management
/// - Session rotation and activity tracking
/// - Session statistics and monitoring
/// - Authentication change handling
class CFClientSessionManagement {
  static const _source = 'CFClientSessionManagement';

  final SessionManager? _sessionManager;
  final String _fallbackSessionId;

  CFClientSessionManagement({
    required SessionManager? sessionManager,
    required String fallbackSessionId,
  })  : _sessionManager = sessionManager,
        _fallbackSessionId = fallbackSessionId;

  // MARK: - Session Management

  /// Get the current session ID
  String getCurrentSessionId() =>
      _sessionManager?.getCurrentSessionId() ?? _fallbackSessionId;

  /// Get current session data with metadata
  SessionData? getCurrentSessionData() => _sessionManager?.getCurrentSession();

  /// Force session rotation with a manual trigger
  Future<String?> forceSessionRotation() async =>
      await _sessionManager?.forceRotation();

  /// Update session activity
  Future<void> updateSessionActivity() async =>
      await _sessionManager?.updateActivity();

  /// Handle user authentication changes
  Future<void> onUserAuthenticationChange(String? userId) async =>
      await _sessionManager?.onAuthenticationChange(userId);

  /// Get session statistics
  Map<String, dynamic> getSessionStatistics() =>
      _sessionManager?.getSessionStats() ??
      {
        'hasActiveSession': false,
        'sessionId': _fallbackSessionId,
        'sessionManagerInitialized': false,
      };

  /// Add a session rotation listener
  void addSessionRotationListener(SessionRotationListener listener) =>
      _sessionManager?.addListener(listener);

  /// Remove a session rotation listener
  void removeSessionRotationListener(SessionRotationListener listener) =>
      _sessionManager?.removeListener(listener);

  /// Check if session manager is initialized
  bool get isInitialized => _sessionManager != null;

  /// Get session manager instance (for internal use)
  SessionManager? get sessionManager => _sessionManager;
}
