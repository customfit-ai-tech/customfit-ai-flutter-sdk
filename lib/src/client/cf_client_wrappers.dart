// lib/src/client/cf_client_wrappers.dart
//
// Internal wrapper classes for CFClient listeners.
// These classes are extracted from CFClient to reduce its size.

import '../client/listener/feature_flag_change_listener.dart';
import '../client/listener/all_flags_listener.dart';
import '../logging/logger.dart';
import '../core/session/session_manager.dart';

/// Session rotation listener that integrates with CFClient
class CFClientSessionListener implements SessionRotationListener {
  final void Function(String) _updateSessionIdInManagers;
  final void Function(String?, String, RotationReason)
      _trackSessionRotationEvent;

  CFClientSessionListener({
    required void Function(String) updateSessionIdInManagers,
    required void Function(String?, String, RotationReason)
        trackSessionRotationEvent,
  })  : _updateSessionIdInManagers = updateSessionIdInManagers,
        _trackSessionRotationEvent = trackSessionRotationEvent;

  @override
  void onSessionRotated(
      String? oldSessionId, String newSessionId, RotationReason reason) {
    Logger.i(
        '🔄 Session rotated: ${oldSessionId ?? "null"} -> $newSessionId (${reason.description})');

    // Update session ID in managers
    _updateSessionIdInManagers(newSessionId);

    // Track session rotation event
    _trackSessionRotationEvent(oldSessionId, newSessionId, reason);
  }

  @override
  void onSessionRestored(String sessionId) {
    Logger.i('🔄 Session restored: $sessionId');

    // Update session ID in managers
    _updateSessionIdInManagers(sessionId);
  }

  @override
  void onSessionError(String error) {
    Logger.e('🔄 Session error: $error');
  }
}

/// Wrapper for feature flag change listeners
class FeatureFlagListenerWrapper implements FeatureFlagChangeListener {
  final void Function(String, dynamic, dynamic) callback;

  FeatureFlagListenerWrapper(this.callback);

  @override
  void onFeatureFlagChanged(
      String flagKey, dynamic oldValue, dynamic newValue) {
    callback(flagKey, oldValue, newValue);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeatureFlagListenerWrapper && other.callback == callback;
  }

  @override
  int get hashCode => callback.hashCode;
}

/// Wrapper for all flags listeners
class AllFlagsListenerWrapper implements AllFlagsListener {
  final void Function(Map<String, dynamic>, Map<String, dynamic>) callback;

  AllFlagsListenerWrapper(this.callback);

  @override
  void onAllFlagsChanged(
      Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags) {
    callback(oldFlags, newFlags);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AllFlagsListenerWrapper && other.callback == callback;
  }

  @override
  int get hashCode => callback.hashCode;
}
