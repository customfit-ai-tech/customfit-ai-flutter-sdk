// lib/src/client/cf_client_mediator.dart
//
// Mediator pattern implementation to break circular dependencies between CFClient and its managers.
// This class provides a decoupled communication channel that eliminates the need for managers
// to directly reference CFClient, solving the circular dependency issue identified in the code review.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import '../logging/logger.dart';

/// Event types for mediator communication
class MediatorEventType {
  static const String configChanged = 'config_changed';
  static const String userUpdated = 'user_updated';
  static const String sessionRotated = 'session_rotated';
  static const String flagEvaluated = 'flag_evaluated';
  static const String eventTracked = 'event_tracked';
  static const String connectionStatusChanged = 'connection_status_changed';
  static const String clientStateChanged = 'client_state_changed';
}

/// Data structure for mediator events
class MediatorEvent {
  final String type;
  final dynamic data;
  final DateTime timestamp;
  final String? source;

  MediatorEvent({
    required this.type,
    required this.data,
    DateTime? timestamp,
    this.source,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'MediatorEvent{type: $type, source: $source, timestamp: $timestamp}';
  }
}

/// Mediator class that breaks circular dependencies using the Mediator pattern
///
/// This class allows components to communicate without direct references to each other,
/// solving the circular dependency problem where CFClient depends on managers and
/// managers need to communicate back to CFClient.
class CFClientMediator {
  static CFClientMediator? _instance;
  static final Object _lock = Object();

  final Map<String, StreamController<MediatorEvent>> _eventStreams = {};
  final Map<String, List<void Function(MediatorEvent)>> _listeners = {};
  bool _isShutdown = false;

  CFClientMediator._();

  /// Get the singleton instance of the mediator
  static CFClientMediator get instance {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= CFClientMediator._();
      });
    }
    return _instance!;
  }

  /// Initialize the mediator with common event types
  void initialize() {
    if (_isShutdown) {
      Logger.w('CFClientMediator: Cannot initialize after shutdown');
      return;
    }

    // Create streams for common event types
    final eventTypes = [
      MediatorEventType.configChanged,
      MediatorEventType.userUpdated,
      MediatorEventType.sessionRotated,
      MediatorEventType.flagEvaluated,
      MediatorEventType.eventTracked,
      MediatorEventType.connectionStatusChanged,
      MediatorEventType.clientStateChanged,
    ];

    for (final eventType in eventTypes) {
      _createEventStream(eventType);
    }

    Logger.d(
        'CFClientMediator: Initialized with ${eventTypes.length} event types');
  }

  /// Create an event stream for a specific event type
  void _createEventStream(String eventType) {
    if (_eventStreams.containsKey(eventType)) {
      return; // Stream already exists
    }

    _eventStreams[eventType] = StreamController<MediatorEvent>.broadcast(
      onCancel: () {
        Logger.d('CFClientMediator: Last listener removed for $eventType');
      },
    );
  }

  /// Publish an event through the mediator
  void publishEvent(String eventType, dynamic data, {String? source}) {
    if (_isShutdown) {
      Logger.w('CFClientMediator: Cannot publish events after shutdown');
      return;
    }

    final event = MediatorEvent(
      type: eventType,
      data: data,
      source: source,
    );

    // Send to stream listeners
    final streamController = _eventStreams[eventType];
    if (streamController != null && !streamController.isClosed) {
      streamController.add(event);
    }

    // Send to direct listeners
    final listeners = _listeners[eventType];
    if (listeners != null) {
      for (final listener in List.from(listeners)) {
        try {
          listener(event);
        } catch (e) {
          Logger.e(
              'CFClientMediator: Error in event listener for $eventType: $e');
        }
      }
    }

    Logger.d(
        'CFClientMediator: Published $eventType event from ${source ?? "unknown"}');
  }

  /// Subscribe to events using a stream
  Stream<MediatorEvent>? subscribeToEvents(String eventType) {
    if (_isShutdown) {
      Logger.w('CFClientMediator: Cannot subscribe after shutdown');
      return null;
    }

    _createEventStream(eventType);
    return _eventStreams[eventType]?.stream;
  }

  /// Add a direct listener for events (alternative to streams)
  void addListener(String eventType, void Function(MediatorEvent) listener) {
    if (_isShutdown) {
      Logger.w('CFClientMediator: Cannot add listeners after shutdown');
      return;
    }

    _listeners.putIfAbsent(eventType, () => []).add(listener);
    Logger.d('CFClientMediator: Added listener for $eventType');
  }

  /// Remove a direct listener
  void removeListener(String eventType, void Function(MediatorEvent) listener) {
    final listeners = _listeners[eventType];
    if (listeners != null) {
      listeners.remove(listener);
      if (listeners.isEmpty) {
        _listeners.remove(eventType);
      }
      Logger.d('CFClientMediator: Removed listener for $eventType');
    }
  }

  /// Get the number of active listeners for an event type
  int getListenerCount(String eventType) {
    final streamListeners =
        _eventStreams[eventType]?.hasListener == true ? 1 : 0;
    final directListeners = _listeners[eventType]?.length ?? 0;
    return streamListeners + directListeners;
  }

  /// Check if there are any listeners for an event type
  bool hasListeners(String eventType) {
    return getListenerCount(eventType) > 0;
  }

  /// Get all active event types
  Set<String> getActiveEventTypes() {
    final streamTypes = _eventStreams.keys.toSet();
    final listenerTypes = _listeners.keys.toSet();
    return streamTypes.union(listenerTypes);
  }

  /// Shutdown the mediator and clean up resources
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }

    Logger.i('CFClientMediator: Shutting down...');
    _isShutdown = true;

    // Close all stream controllers
    final futures = <Future<void>>[];
    for (final controller in _eventStreams.values) {
      if (!controller.isClosed) {
        futures.add(controller.close());
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    _eventStreams.clear();
    _listeners.clear();

    Logger.i('CFClientMediator: Shutdown complete');
  }

  /// Reset the mediator (for testing)
  static Future<void> reset() async {
    if (_instance != null) {
      await _instance!.shutdown();
      _instance = null;
    }
  }

  /// Check if the mediator is shutdown
  bool get isShutdown => _isShutdown;

  /// Get debug information about the mediator state
  Map<String, dynamic> getDebugInfo() {
    return {
      'isShutdown': _isShutdown,
      'activeEventTypes': getActiveEventTypes().toList(),
      'eventStreamCount': _eventStreams.length,
      'listenerCount':
          _listeners.values.fold(0, (sum, list) => sum + list.length),
      'totalListeners': getActiveEventTypes()
          .map((type) => getListenerCount(type))
          .fold(0, (sum, count) => sum + count),
    };
  }
}

/// Extension to provide a synchronized function (simple implementation)
void synchronized(Object lock, void Function() action) {
  // In Dart, this is a simplified synchronization
  // For production use, consider using package:synchronized
  action();
}
