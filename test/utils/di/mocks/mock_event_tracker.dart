import 'dart:async';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_data.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_tracker.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_type.dart';

/// Mock event tracker for testing
class MockEventTracker implements EventTracker {
  final List<MockTrackedEvent> _events = [];
  final List<MockTrackedEvent> _droppedEvents = [];
  bool shouldFailFlush = false;
  bool autoFlushEnabled = true;
  EventCallback? _callback;
  List<MockTrackedEvent> get trackedEvents => List.unmodifiable(_events);
  List<MockTrackedEvent> get droppedEvents => List.unmodifiable(_droppedEvents);
  void reset() {
    _events.clear();
    _droppedEvents.clear();
    shouldFailFlush = false;
    autoFlushEnabled = true;
    _callback = null;
  }

  @override
  Future<CFResult<void>> trackEvent(
    String eventType,
    Map<String, dynamic> properties,
  ) async {
    final event = MockTrackedEvent(
      eventType: EventTypeExtension.fromString(eventType),
      properties: properties,
      timestamp: DateTime.now(),
    );
    _events.add(event);
    _callback?.call(event.toEventData());
    return CFResult.success(null);
  }

  @override
  Future<CFResult<void>> trackBatch(List<EventData> events) async {
    for (final event in events) {
      _events.add(MockTrackedEvent(
        eventType: event.eventType,
        properties: event.properties,
        timestamp: DateTime.fromMillisecondsSinceEpoch(event.eventTimestamp),
      ));
    }
    return CFResult.success(null);
  }

  @override
  void setEventCallback(EventCallback? callback) {
    _callback = callback;
  }

  @override
  void setAutoFlushEnabled(bool enabled) {
    autoFlushEnabled = enabled;
  }

  @override
  Future<CFResult<bool>> flush() async {
    if (shouldFailFlush) {
      return CFResult.error('Mock flush failure');
    }
    for (final event in _events) {
      _callback?.call(event.toEventData());
    }
    _events.clear();
    return CFResult.success(true);
  }

  @override
  int getPendingEventsCount() {
    return _events.length;
  }

  @override
  int getDroppedEventsCount() {
    return _droppedEvents.length;
  }

  @override
  void clearEvents() {
    _events.clear();
  }

  @override
  Future<void> shutdown() async {
    clearEvents();
    _callback = null;
  }

  @override
  Future<CFResult<bool>> flushEvents() async {
    return flush().then((_) => CFResult.success(true));
  }

  @override
  Map<String, dynamic> getBackpressureMetrics() {
    return {
      'backpressureActive': false,
      'eventsDropped': _droppedEvents.length,
      'queueUtilization': _events.length / 100,
    };
  }

  @override
  Map<String, dynamic> getHealthMetrics() {
    return {
      'pendingEvents': _events.length,
      'droppedEvents': _droppedEvents.length,
      'flushFailures': shouldFailFlush ? 1 : 0,
    };
  }

  @override
  void onConnectionStatusChanged(dynamic status, dynamic info) {
    // Mock implementation - no-op
  }
  @override
  void setOnBackpressureAppliedCallback(
      void Function(Map<String, dynamic>)? callback) {
    // Mock implementation - no-op
  }
  @override
  void setOnEventsDroppedCallback(void Function(int, String)? callback) {
    // Mock implementation - no-op
  }
  @override
  void setupListeners({void Function(EventData)? onEventTracked}) {
    if (onEventTracked != null) {
      _callback = onEventTracked;
    }
  }

  @override
  Future<CFResult<List<EventData>>> trackEvents(List<EventData> events) async {
    return trackBatch(events).then((_) => CFResult.success(events));
  }

  void simulateDropEvent(String eventType, Map<String, dynamic> properties) {
    final event = MockTrackedEvent(
      eventType: EventTypeExtension.fromString(eventType),
      properties: properties,
      timestamp: DateTime.now(),
    );
    _droppedEvents.add(event);
    _callback?.call(event.toEventData());
  }
}

class MockTrackedEvent {
  final EventType eventType;
  final Map<String, dynamic> properties;
  final DateTime timestamp;
  MockTrackedEvent({
    required this.eventType,
    required this.properties,
    required this.timestamp,
  });
  EventData toEventData() {
    return EventData(
      eventId: 'mock-event-${timestamp.millisecondsSinceEpoch}',
      eventCustomerId: 'mock-user',
      eventType: eventType,
      properties: properties,
      sessionId: 'mock-session',
      eventTimestamp: timestamp.millisecondsSinceEpoch,
    );
  }
}
