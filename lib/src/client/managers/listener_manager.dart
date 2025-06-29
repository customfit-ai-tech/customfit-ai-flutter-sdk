import 'package:flutter/foundation.dart';

import '../listener/all_flags_listener.dart';
import '../listener/feature_flag_change_listener.dart';
import '../../network/connection/connection_manager.dart';
import '../../network/connection/connection_status.dart';
import '../../network/connection/connection_information.dart';

/// Manager for handling various types of listeners in the SDK
class ListenerManager {
  // Feature flag listeners
  final Map<String, Set<FeatureFlagChangeListener>> _featureFlagListeners = {};

  // All flags listeners
  final Set<AllFlagsListener> _allFlagsListeners = {};

  // Connection status listeners
  final Set<ConnectionStatusListener> _connectionStatusListeners = {};

  void registerFeatureFlagListener(
      String flagKey, FeatureFlagChangeListener listener) {
    _featureFlagListeners[flagKey] ??= {};
    _featureFlagListeners[flagKey]!.add(listener);
  }

  void unregisterFeatureFlagListener(
      String flagKey, FeatureFlagChangeListener listener) {
    final listeners = _featureFlagListeners[flagKey];
    if (listeners != null) {
      listeners.remove(listener);
      if (listeners.isEmpty) {
        _featureFlagListeners.remove(flagKey);
      }
    }
  }

  void registerAllFlagsListener(AllFlagsListener listener) {
    _allFlagsListeners.add(listener);
  }

  void unregisterAllFlagsListener(AllFlagsListener listener) {
    _allFlagsListeners.remove(listener);
  }

  void addConnectionStatusListener(ConnectionStatusListener listener) {
    _connectionStatusListeners.add(listener);
  }

  void removeConnectionStatusListener(ConnectionStatusListener listener) {
    _connectionStatusListeners.remove(listener);
  }

  /// Notify feature flag listeners of a flag change
  void notifyFeatureFlagListeners(
      String flagKey, dynamic oldValue, dynamic newValue) {
    final listeners = _featureFlagListeners[flagKey];
    if (listeners != null) {
      for (final listener in Set<FeatureFlagChangeListener>.from(listeners)) {
        try {
          listener.onFeatureFlagChanged(flagKey, oldValue, newValue);
        } catch (e) {
          debugPrint('Error notifying feature flag listener: $e');
        }
      }
    }
  }

  /// Notify all flags listeners of flag changes
  void notifyAllFlagsListeners(
      Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags) {
    for (final listener in Set<AllFlagsListener>.from(_allFlagsListeners)) {
      try {
        listener.onAllFlagsChanged(oldFlags, newFlags);
      } catch (e) {
        debugPrint('Error notifying all flags listener: $e');
      }
    }
  }

  /// Notify connection status listeners of a connection status change
  void notifyConnectionStatusListeners(
      ConnectionStatus status, ConnectionInformation info) {
    for (final listener
        in Set<ConnectionStatusListener>.from(_connectionStatusListeners)) {
      try {
        listener.onConnectionStatusChanged(status, info);
      } catch (e) {
        debugPrint('Error notifying connection status listener: $e');
      }
    }
  }

  void clearAllListeners() {
    _featureFlagListeners.clear();
    _allFlagsListeners.clear();
    _connectionStatusListeners.clear();
  }
}
