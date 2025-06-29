// import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'event_data.dart';
import '../../logging/logger.dart';

/// Queue for storing events before they are sent.
class EventQueue {
  /// Internal queue for events.
  final Queue<EventData> _queue = Queue<EventData>();

  /// Maximum number of events that can be stored in the queue.
  final int _maxQueueSize;

  /// Callback to be notified when events are dropped.
  final Function(List<EventData>)? _onEventsDropped;

  /// Create a new event queue with the given maximum size.
  EventQueue({
    int maxQueueSize = 100,
    Function(List<EventData>)? onEventsDropped,
  })  : _maxQueueSize = maxQueueSize,
        _onEventsDropped = onEventsDropped;

  /// Add an event to the queue.
  ///
  /// If the queue is full, events will be dropped according to the configured policy.
  void addEvent(EventData event) {
    _queue.add(event);
    _ensureQueueSizeLimit();
  }

  /// Add multiple events to the queue with optimized bulk operations.
  ///
  /// If the queue is full, events will be dropped according to the configured policy.
  void addEvents(List<EventData> events) {
    if (events.isEmpty) return;

    // Pre-calculate final size to optimize queue operations
    final currentSize = _queue.length;
    final newSize = currentSize + events.length;

    if (newSize <= _maxQueueSize) {
      // Simple case: all events fit
      _queue.addAll(events);
    } else {
      // Complex case: need to handle overflow efficiently
      _addEventsWithOverflowHandling(events);
    }
  }

  /// Handle overflow when adding events in bulk
  void _addEventsWithOverflowHandling(List<EventData> events) {
    // Add all events first
    _queue.addAll(events);
    
    // Then ensure queue size limit (this will drop oldest events if needed)
    _ensureQueueSizeLimit();
  }

  /// Get all events in the queue and clear it.
  List<EventData> popAllEvents() {
    if (_queue.isEmpty) return [];
    final events = _queue.toList(growable: false);
    _queue.clear();
    return events;
  }

  /// Get a batch of events up to the specified size with optimized bulk operations.
  List<EventData> popEventBatch(int batchSize) {
    if (_queue.isEmpty || batchSize <= 0) return <EventData>[];

    final actualBatchSize = math.min(batchSize, _queue.length);

    // Use efficient bulk operations instead of individual removes
    final batchEvents = <EventData>[];
    
    // Bulk copy and remove in optimized loop
    for (int i = 0; i < actualBatchSize; i++) {
      batchEvents.add(_queue.removeFirst());
    }

    return batchEvents;
  }

  /// Get the current size of the queue.
  int get size => _queue.length;

  /// Check if the queue is empty.
  bool get isEmpty => _queue.isEmpty;

  /// Clear the queue.
  void clear() {
    _queue.clear();
  }

  /// Get a list of all events without removing them
  List<EventData> toList() {
    return _queue.toList();
  }

  /// Ensure the queue size doesn't exceed the limit.
  ///
  /// If the queue is too large, the oldest events will be dropped.
  void _ensureQueueSizeLimit() {
    if (_queue.length > _maxQueueSize) {
      final droppedEvents = <EventData>[];

      while (_queue.length > _maxQueueSize) {
        droppedEvents.add(_queue.removeFirst());
      }

      if (droppedEvents.isNotEmpty) {
        Logger.w(
          'EventQueue: Dropped ${droppedEvents.length} oldest events due to queue overflow (max size: $_maxQueueSize)',
        );

        if (_onEventsDropped != null) {
          try {
            _onEventsDropped(droppedEvents);
          } catch (e) {
            Logger.e('EventQueue: Error notifying about dropped events: $e');
          }
        }
      }
    }
  }
}
