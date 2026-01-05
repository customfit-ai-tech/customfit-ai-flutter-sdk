import 'cf_config.dart';

/// A mutable wrapper around the immutable CFConfig.
///
/// This class allows certain configuration properties to be changed at runtime
/// while keeping most of the configuration immutable. Includes change tracking
/// and validation for runtime updates.
class MutableCFConfig {
  /// The underlying immutable configuration
  final CFConfig config;

  /// Whether the SDK is in offline mode
  bool _offlineMode;

  /// Change listeners for configuration updates
  final List<Function(String property, dynamic oldValue, dynamic newValue)>
      _changeListeners = [];

  /// Track configuration changes
  final Map<String, dynamic> _changes = {};

  /// Constructor
  MutableCFConfig(this.config) : _offlineMode = config.offlineMode;

  /// Get whether the SDK is in offline mode
  bool get offlineMode => _offlineMode;

  /// Get whether auto environment attributes are enabled
  bool get autoEnvAttributesEnabled => config.autoEnvAttributesEnabled;

  /// Set offline mode with change tracking
  void setOfflineMode(bool offlineMode) {
    final oldValue = _offlineMode;
    if (oldValue != offlineMode) {
      _offlineMode = offlineMode;
      _trackChange('offlineMode', oldValue, offlineMode);
      _notifyListeners('offlineMode', oldValue, offlineMode);
    }
  }

  /// Add a change listener
  void addChangeListener(
      Function(String property, dynamic oldValue, dynamic newValue) listener) {
    _changeListeners.add(listener);
  }

  /// Remove a change listener
  void removeChangeListener(
      Function(String property, dynamic oldValue, dynamic newValue) listener) {
    _changeListeners.remove(listener);
  }

  /// Get all configuration changes since creation
  Map<String, dynamic> getChanges() {
    return Map.unmodifiable(_changes);
  }

  /// Check if configuration has been modified
  bool get hasChanges => _changes.isNotEmpty;

  /// Reset change tracking
  void clearChangeHistory() {
    _changes.clear();
  }

  /// Get configuration summary for debugging
  Map<String, dynamic> getSummary() {
    return {
      'environment': config.environment.toString(),
      'offlineMode': _offlineMode,
      'debugLoggingEnabled': config.debugLoggingEnabled,
      'eventsFlushIntervalMs': config.eventsFlushIntervalMs,
      'networkConnectionTimeoutMs': config.networkConnectionTimeoutMs,
      'changesCount': _changes.length,
      'hasChanges': hasChanges,
    };
  }

  /// Track internal changes
  void _trackChange(String property, dynamic oldValue, dynamic newValue) {
    _changes[property] = {
      'oldValue': oldValue,
      'newValue': newValue,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Notify all listeners of changes
  void _notifyListeners(String property, dynamic oldValue, dynamic newValue) {
    for (final listener in _changeListeners) {
      try {
        listener(property, oldValue, newValue);
      } catch (e) {
        // Silently ignore listener errors to prevent cascading failures
      }
    }
  }
}
