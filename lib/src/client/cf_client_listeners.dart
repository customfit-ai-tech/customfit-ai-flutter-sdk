// lib/src/client/cf_client_listeners.dart
//
// Listener management component for CustomFit SDK.
// Handles feature flag listeners, configuration listeners, and other event subscriptions.
//
// This file is part of the CustomFit SDK for Flutter.

import '../client/listener/all_flags_listener.dart';
import '../client/listener/feature_flag_change_listener.dart';
import '../core/model/cf_user.dart';
import '../config/core/cf_config.dart';
import '../logging/logger.dart';

/// Component responsible for managing all types of listeners in the CFClient.
/// Handles feature flag listeners, configuration change listeners, and event subscriptions.
class CFClientListeners {
  static const _source = 'CFClientListeners';

  final CFConfig _config;
  final CFUser _user;
  final String _sessionId;

  // Feature config and flag listeners
  final Map<String, List<void Function(dynamic)>> _configListeners = {};
  final Map<String, List<FeatureFlagChangeListener>> _featureFlagListeners = {};
  final Set<AllFlagsListener> _allFlagsListeners = {};

  CFClientListeners({
    required CFConfig config,
    required CFUser user,
    required String sessionId,
  })  : _config = config,
        _user = user,
        _sessionId = sessionId;

  /// Add a listener for configuration changes
  ///
  /// Registers a callback that will be invoked when the configuration changes.
  /// The listener receives the updated configuration value.
  ///
  /// ## Parameters
  ///
  /// - [key]: Configuration key to listen for changes
  /// - [listener]: Callback function to invoke on changes
  ///
  /// ## Example
  ///
  /// ```dart
  /// client.listeners.addConfigListener('theme', (newValue) {
  ///   print('Theme changed to: $newValue');
  /// });
  /// ```
  void addConfigListener(String key, void Function(dynamic) listener) {
    _configListeners.putIfAbsent(key, () => []).add(listener);
    Logger.d('$_source: Added config listener for key: $key');
  }

  /// Remove a configuration listener
  ///
  /// Removes a previously registered configuration change listener.
  ///
  /// ## Parameters
  ///
  /// - [key]: Configuration key
  /// - [listener]: Listener function to remove
  ///
  /// ## Returns
  ///
  /// True if the listener was found and removed, false otherwise.
  bool removeConfigListener(String key, void Function(dynamic) listener) {
    final listeners = _configListeners[key];
    if (listeners != null) {
      final removed = listeners.remove(listener);
      if (listeners.isEmpty) {
        _configListeners.remove(key);
      }
      if (removed) {
        Logger.d('$_source: Removed config listener for key: $key');
      }
      return removed;
    }
    return false;
  }

  /// Add a feature flag change listener
  ///
  /// Registers a listener that will be notified when a specific feature flag changes.
  ///
  /// ## Parameters
  ///
  /// - [flagKey]: Feature flag key to monitor
  /// - [listener]: Listener to add
  ///
  /// ## Example
  ///
  /// ```dart
  /// client.listeners.addFeatureFlagListener('new_ui',
  ///   FeatureFlagChangeListener(
  ///     onFlagChanged: (key, oldValue, newValue) {
  ///       print('Flag $key changed from $oldValue to $newValue');
  ///     }
  ///   )
  /// );
  /// ```
  void addFeatureFlagListener(
      String flagKey, FeatureFlagChangeListener listener) {
    _featureFlagListeners.putIfAbsent(flagKey, () => []).add(listener);
    Logger.d('$_source: Added feature flag listener for: $flagKey');
  }

  /// Remove a feature flag listener
  ///
  /// Removes a previously registered feature flag change listener.
  ///
  /// ## Parameters
  ///
  /// - [flagKey]: Feature flag key
  /// - [listener]: Listener to remove
  ///
  /// ## Returns
  ///
  /// True if the listener was found and removed, false otherwise.
  bool removeFeatureFlagListener(
      String flagKey, FeatureFlagChangeListener listener) {
    final listeners = _featureFlagListeners[flagKey];
    if (listeners != null) {
      final removed = listeners.remove(listener);
      if (listeners.isEmpty) {
        _featureFlagListeners.remove(flagKey);
      }
      if (removed) {
        Logger.d('$_source: Removed feature flag listener for: $flagKey');
      }
      return removed;
    }
    return false;
  }

  /// Add an all-flags listener
  ///
  /// Registers a listener that will be notified when any feature flag changes.
  ///
  /// ## Parameters
  ///
  /// - [listener]: All-flags listener to add
  ///
  /// ## Example
  ///
  /// ```dart
  /// client.listeners.addAllFlagsListener(
  ///   AllFlagsListener(
  ///     onFlagsChanged: (flags) {
  ///       print('Flags updated: ${flags.keys.join(', ')}');
  ///     }
  ///   )
  /// );
  /// ```
  void addAllFlagsListener(AllFlagsListener listener) {
    _allFlagsListeners.add(listener);
    Logger.d('$_source: Added all-flags listener');
  }

  /// Remove an all-flags listener
  ///
  /// Removes a previously registered all-flags change listener.
  ///
  /// ## Parameters
  ///
  /// - [listener]: Listener to remove
  ///
  /// ## Returns
  ///
  /// True if the listener was found and removed, false otherwise.
  bool removeAllFlagsListener(AllFlagsListener listener) {
    final removed = _allFlagsListeners.remove(listener);
    if (removed) {
      Logger.d('$_source: Removed all-flags listener');
    }
    return removed;
  }

  /// Notify configuration listeners of a change
  ///
  /// Internal method to notify all registered configuration listeners
  /// when a configuration value changes.
  ///
  /// ## Parameters
  ///
  /// - [key]: Configuration key that changed
  /// - [newValue]: New configuration value
  void notifyConfigListeners(String key, dynamic newValue) {
    final listeners = _configListeners[key];
    if (listeners != null && listeners.isNotEmpty) {
      Logger.d(
          '$_source: Notifying ${listeners.length} config listeners for key: $key');
      for (final listener in listeners) {
        try {
          listener(newValue);
        } catch (e) {
          Logger.e('$_source: Error in config listener for $key: $e');
        }
      }
    }
  }

  /// Notify feature flag listeners of a change
  ///
  /// Internal method to notify all registered feature flag listeners
  /// when a flag value changes.
  ///
  /// ## Parameters
  ///
  /// - [flagKey]: Feature flag key that changed
  /// - [oldValue]: Previous flag value
  /// - [newValue]: New flag value
  void notifyFeatureFlagListeners(
      String flagKey, dynamic oldValue, dynamic newValue) {
    final listeners = _featureFlagListeners[flagKey];
    if (listeners != null && listeners.isNotEmpty) {
      Logger.d(
          '$_source: Notifying ${listeners.length} feature flag listeners for: $flagKey');
      for (final listener in listeners) {
        try {
          listener.onFeatureFlagChanged(flagKey, oldValue, newValue);
        } catch (e) {
          Logger.e('$_source: Error in feature flag listener for $flagKey: $e');
        }
      }
    }
  }

  /// Notify all-flags listeners of changes
  ///
  /// Internal method to notify all registered all-flags listeners
  /// when the configuration is updated.
  ///
  /// ## Parameters
  ///
  /// - [oldFlags]: Previous flag values
  /// - [newFlags]: Current flag values
  void notifyAllFlagsListeners(
      Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags) {
    if (_allFlagsListeners.isNotEmpty) {
      Logger.d(
          '$_source: Notifying ${_allFlagsListeners.length} all-flags listeners');
      for (final listener in _allFlagsListeners) {
        try {
          listener.onAllFlagsChanged(oldFlags, newFlags);
        } catch (e) {
          Logger.e('$_source: Error in all-flags listener: $e');
        }
      }
    }
  }

  /// Get count of active configuration listeners
  ///
  /// Returns the total number of configuration listeners across all keys.
  int getConfigListenerCount() {
    return _configListeners.values
        .fold(0, (sum, listeners) => sum + listeners.length);
  }

  /// Get count of active feature flag listeners
  ///
  /// Returns the total number of feature flag listeners across all flags.
  int getFeatureFlagListenerCount() {
    return _featureFlagListeners.values
        .fold(0, (sum, listeners) => sum + listeners.length);
  }

  /// Get count of all-flags listeners
  ///
  /// Returns the number of all-flags listeners.
  int getAllFlagsListenerCount() {
    return _allFlagsListeners.length;
  }

  /// Get total listener count
  ///
  /// Returns the total number of all types of listeners.
  int getTotalListenerCount() {
    return getConfigListenerCount() +
        getFeatureFlagListenerCount() +
        getAllFlagsListenerCount();
  }

  /// Clear all listeners
  ///
  /// Removes all registered listeners. This is typically called during shutdown.
  void clearAllListeners() {
    final totalCount = getTotalListenerCount();

    _configListeners.clear();
    _featureFlagListeners.clear();
    _allFlagsListeners.clear();

    Logger.i('$_source: Cleared $totalCount listeners');
  }

  /// Get listener statistics
  ///
  /// Returns a map with statistics about registered listeners.
  /// Useful for debugging and monitoring.
  Map<String, dynamic> getListenerStats() {
    return {
      'config_listeners': getConfigListenerCount(),
      'feature_flag_listeners': getFeatureFlagListenerCount(),
      'all_flags_listeners': getAllFlagsListenerCount(),
      'total_listeners': getTotalListenerCount(),
      'config_keys_with_listeners': _configListeners.keys.toList(),
      'feature_flags_with_listeners': _featureFlagListeners.keys.toList(),
    };
  }

  /// Shutdown the listeners component
  ///
  /// Performs cleanup and removes all listeners.
  void shutdown() {
    Logger.i('$_source: Shutting down listeners component');
    clearAllListeners();
  }
}
