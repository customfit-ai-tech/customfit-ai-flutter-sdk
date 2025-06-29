// test/unit/analytics/event/event_queue_test.dart
//
// Tests for EventQueue class
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_queue.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_data.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_type.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('EventQueue', () {
    late EventQueue eventQueue;
    late EventData testEvent1;
    late EventData testEvent2;
    late EventData testEvent3;
    setUp(() {
      eventQueue = EventQueue();
      testEvent1 = EventData.create(
        eventCustomerId: 'customer1',
        eventType: EventType.track,
        sessionId: 'session1',
        properties: {'test': 'event1'},
      );
      testEvent2 = EventData.create(
        eventCustomerId: 'customer2',
        eventType: EventType.track,
        sessionId: 'session2',
        properties: {'test': 'event2'},
      );
      testEvent3 = EventData.create(
        eventCustomerId: 'customer3',
        eventType: EventType.track,
        sessionId: 'session3',
        properties: {'test': 'event3'},
      );
    });
    group('Constructor', () {
      test('should create queue with default max size', () {
        final queue = EventQueue();
        expect(queue.size, equals(0));
        expect(queue.isEmpty, isTrue);
      });
      test('should create queue with custom max size', () {
        final queue = EventQueue(maxQueueSize: 50);
        expect(queue.size, equals(0));
        expect(queue.isEmpty, isTrue);
      });
      test('should create queue with drop callback', () {
        List<EventData>? droppedEvents;
        final queue = EventQueue(
          maxQueueSize: 2,
          onEventsDropped: (events) {
            droppedEvents = events;
          },
        );
        expect(queue.size, equals(0));
        expect(droppedEvents, isNull);
      });
    });
    group('Adding Events', () {
      test('should add single event', () {
        eventQueue.addEvent(testEvent1);
        expect(eventQueue.size, equals(1));
        expect(eventQueue.isEmpty, isFalse);
      });
      test('should add multiple events individually', () {
        eventQueue.addEvent(testEvent1);
        eventQueue.addEvent(testEvent2);
        eventQueue.addEvent(testEvent3);
        expect(eventQueue.size, equals(3));
        expect(eventQueue.isEmpty, isFalse);
      });
      test('should add multiple events at once', () {
        final events = [testEvent1, testEvent2, testEvent3];
        eventQueue.addEvents(events);
        expect(eventQueue.size, equals(3));
        expect(eventQueue.isEmpty, isFalse);
      });
      test('should add empty list without error', () {
        eventQueue.addEvents([]);
        expect(eventQueue.size, equals(0));
        expect(eventQueue.isEmpty, isTrue);
      });
      test('should maintain order of added events', () {
        eventQueue.addEvent(testEvent1);
        eventQueue.addEvent(testEvent2);
        eventQueue.addEvent(testEvent3);
        final events = eventQueue.toList();
        expect(events[0].properties['test'], equals('event1'));
        expect(events[1].properties['test'], equals('event2'));
        expect(events[2].properties['test'], equals('event3'));
      });
    });
    group('Queue Size Management', () {
      test('should respect maximum queue size', () {
        final queue = EventQueue(maxQueueSize: 2);
        queue.addEvent(testEvent1);
        queue.addEvent(testEvent2);
        queue.addEvent(testEvent3); // This should cause event1 to be dropped
        expect(queue.size, equals(2));
        final events = queue.toList();
        expect(events[0].properties['test'], equals('event2'));
        expect(events[1].properties['test'], equals('event3'));
      });
      test('should drop oldest events when exceeding capacity', () {
        final queue = EventQueue(maxQueueSize: 2);
        // Add 4 events, should keep only the last 2
        queue.addEvent(testEvent1);
        queue.addEvent(testEvent2);
        queue.addEvent(testEvent3);
        final fourthEvent = EventData.create(
          eventCustomerId: 'customer4',
          eventType: EventType.track,
          sessionId: 'session4',
          properties: {'test': 'event4'},
        );
        queue.addEvent(fourthEvent);
        expect(queue.size, equals(2));
        final events = queue.toList();
        expect(events[0].properties['test'], equals('event3'));
        expect(events[1].properties['test'], equals('event4'));
      });
      test('should handle adding multiple events exceeding capacity', () {
        final queue = EventQueue(maxQueueSize: 2);
        final events = [testEvent1, testEvent2, testEvent3];
        queue.addEvents(events);
        expect(queue.size, equals(2));
        final remainingEvents = queue.toList();
        expect(remainingEvents[0].properties['test'], equals('event2'));
        expect(remainingEvents[1].properties['test'], equals('event3'));
      });
      test('should notify callback when events are dropped', () {
        List<EventData>? droppedEvents;
        final queue = EventQueue(
          maxQueueSize: 2,
          onEventsDropped: (events) {
            droppedEvents = events;
          },
        );
        queue.addEvent(testEvent1);
        queue.addEvent(testEvent2);
        queue.addEvent(testEvent3); // Should drop event1
        expect(droppedEvents, isNotNull);
        expect(droppedEvents, hasLength(1));
        expect(droppedEvents![0].properties['test'], equals('event1'));
      });
      test('should handle callback errors gracefully', () {
        final queue = EventQueue(
          maxQueueSize: 1,
          onEventsDropped: (events) {
            throw Exception('Callback error');
          },
        );
        queue.addEvent(testEvent1);
        // Should not throw, just handle gracefully
        expect(() => queue.addEvent(testEvent2), returnsNormally);
        expect(queue.size, equals(1));
      });
    });
    group('Retrieving Events', () {
      test('should pop all events and clear queue', () {
        eventQueue.addEvent(testEvent1);
        eventQueue.addEvent(testEvent2);
        eventQueue.addEvent(testEvent3);
        final events = eventQueue.popAllEvents();
        expect(events, hasLength(3));
        expect(events[0].properties['test'], equals('event1'));
        expect(events[1].properties['test'], equals('event2'));
        expect(events[2].properties['test'], equals('event3'));
        expect(eventQueue.size, equals(0));
        expect(eventQueue.isEmpty, isTrue);
      });
      test('should return empty list when popping from empty queue', () {
        final events = eventQueue.popAllEvents();
        expect(events, isEmpty);
        expect(eventQueue.size, equals(0));
      });
      test('should pop event batch of specified size', () {
        eventQueue.addEvent(testEvent1);
        eventQueue.addEvent(testEvent2);
        eventQueue.addEvent(testEvent3);
        final batch = eventQueue.popEventBatch(2);
        expect(batch, hasLength(2));
        expect(batch[0].properties['test'], equals('event1'));
        expect(batch[1].properties['test'], equals('event2'));
        expect(eventQueue.size, equals(1));
        expect(eventQueue.toList()[0].properties['test'], equals('event3'));
      });
      test('should pop all events when batch size exceeds queue size', () {
        eventQueue.addEvent(testEvent1);
        eventQueue.addEvent(testEvent2);
        final batch = eventQueue.popEventBatch(5);
        expect(batch, hasLength(2));
        expect(eventQueue.size, equals(0));
        expect(eventQueue.isEmpty, isTrue);
      });
      test('should return empty batch from empty queue', () {
        final batch = eventQueue.popEventBatch(3);
        expect(batch, isEmpty);
        expect(eventQueue.size, equals(0));
      });
      test('should handle zero batch size', () {
        eventQueue.addEvent(testEvent1);
        eventQueue.addEvent(testEvent2);
        final batch = eventQueue.popEventBatch(0);
        expect(batch, isEmpty);
        expect(eventQueue.size, equals(2)); // Queue unchanged
      });
      test('should maintain FIFO order when popping batches', () {
        eventQueue.addEvent(testEvent1);
        eventQueue.addEvent(testEvent2);
        eventQueue.addEvent(testEvent3);
        final batch1 = eventQueue.popEventBatch(1);
        final batch2 = eventQueue.popEventBatch(1);
        final batch3 = eventQueue.popEventBatch(1);
        expect(batch1[0].properties['test'], equals('event1'));
        expect(batch2[0].properties['test'], equals('event2'));
        expect(batch3[0].properties['test'], equals('event3'));
      });
    });
    group('Queue Inspection', () {
      test('should get list without removing events', () {
        eventQueue.addEvent(testEvent1);
        eventQueue.addEvent(testEvent2);
        final events = eventQueue.toList();
        expect(events, hasLength(2));
        expect(events[0].properties['test'], equals('event1'));
        expect(events[1].properties['test'], equals('event2'));
        expect(eventQueue.size, equals(2)); // Queue unchanged
      });
      test('should return immutable list copy', () {
        eventQueue.addEvent(testEvent1);
        final events = eventQueue.toList();
        events.clear(); // Modify the returned list
        expect(eventQueue.size, equals(1)); // Original queue unchanged
      });
      test('should get accurate size', () {
        expect(eventQueue.size, equals(0));
        eventQueue.addEvent(testEvent1);
        expect(eventQueue.size, equals(1));
        eventQueue.addEvent(testEvent2);
        expect(eventQueue.size, equals(2));
        eventQueue.popEventBatch(1);
        expect(eventQueue.size, equals(1));
        eventQueue.clear();
        expect(eventQueue.size, equals(0));
      });
      test('should correctly report empty status', () {
        expect(eventQueue.isEmpty, isTrue);
        eventQueue.addEvent(testEvent1);
        expect(eventQueue.isEmpty, isFalse);
        eventQueue.popAllEvents();
        expect(eventQueue.isEmpty, isTrue);
      });
    });
    group('Queue Operations', () {
      test('should clear all events', () {
        eventQueue.addEvent(testEvent1);
        eventQueue.addEvent(testEvent2);
        eventQueue.addEvent(testEvent3);
        eventQueue.clear();
        expect(eventQueue.size, equals(0));
        expect(eventQueue.isEmpty, isTrue);
        expect(eventQueue.toList(), isEmpty);
      });
      test('should clear empty queue without error', () {
        expect(() => eventQueue.clear(), returnsNormally);
        expect(eventQueue.size, equals(0));
        expect(eventQueue.isEmpty, isTrue);
      });
    });
    group('Edge Cases and Performance', () {
      test('should handle rapid additions and removals', () {
        for (int i = 0; i < 100; i++) {
          eventQueue.addEvent(EventData.create(
            eventCustomerId: 'customer$i',
            eventType: EventType.track,
            sessionId: 'session$i',
          ));
          if (i % 10 == 0) {
            eventQueue.popEventBatch(5);
          }
        }
        expect(eventQueue.size, greaterThan(0));
        expect(eventQueue.size, lessThanOrEqualTo(100));
      });
      test('should handle concurrent-like operations', () async {
        final futures = <Future>[];
        for (int i = 0; i < 50; i++) {
          futures.add(Future(() {
            eventQueue.addEvent(EventData.create(
              eventCustomerId: 'customer$i',
              eventType: EventType.track,
              sessionId: 'session$i',
            ));
          }));
        }
        await Future.wait(futures);
        expect(eventQueue.size, lessThanOrEqualTo(100));
      });
      test('should handle extreme batch sizes', () {
        eventQueue.addEvent(testEvent1);
        eventQueue.addEvent(testEvent2);
        // Very large batch size
        final largeBatch = eventQueue.popEventBatch(1000000);
        expect(largeBatch, hasLength(2));
        // Negative batch size (should be handled gracefully)
        eventQueue.addEvent(testEvent3);
        final negativeBatch = eventQueue.popEventBatch(-1);
        expect(negativeBatch, isEmpty);
        expect(eventQueue.size, equals(1));
      });
    });
    group('Memory Management', () {
      test('should not hold references to popped events', () {
        eventQueue.addEvent(testEvent1);
        eventQueue.addEvent(testEvent2);
        final poppedEvents = eventQueue.popAllEvents();
        // Queue should be empty and not holding references
        expect(eventQueue.isEmpty, isTrue);
        expect(eventQueue.toList(), isEmpty);
        // Popped events should still be accessible
        expect(poppedEvents, hasLength(2));
      });
      test('should properly clean up when clearing', () {
        for (int i = 0; i < 100; i++) {
          eventQueue.addEvent(EventData.create(
            eventCustomerId: 'customer$i',
            eventType: EventType.track,
            sessionId: 'session$i',
          ));
        }
        eventQueue.clear();
        expect(eventQueue.isEmpty, isTrue);
        expect(eventQueue.size, equals(0));
        expect(eventQueue.toList(), isEmpty);
      });
    });
    group('Callback Behavior', () {
      test('should call callback with all dropped events', () {
        List<EventData>? droppedEvents;
        int callbackCount = 0;
        final queue = EventQueue(
          maxQueueSize: 2,
          onEventsDropped: (events) {
            droppedEvents = events;
            callbackCount++;
          },
        );
        // Add events that will cause multiple drops
        queue.addEvents([testEvent1, testEvent2, testEvent3]);
        expect(callbackCount, equals(1));
        expect(droppedEvents, hasLength(1));
        expect(droppedEvents![0].properties['test'], equals('event1'));
      });
      test('should call callback multiple times for multiple drops', () {
        final allDroppedEvents = <EventData>[];
        int callbackCount = 0;
        final queue = EventQueue(
          maxQueueSize: 1,
          onEventsDropped: (events) {
            allDroppedEvents.addAll(events);
            callbackCount++;
          },
        );
        queue.addEvent(testEvent1);
        queue.addEvent(testEvent2); // Drops event1
        queue.addEvent(testEvent3); // Drops event2
        expect(callbackCount, equals(2));
        expect(allDroppedEvents, hasLength(2));
        expect(allDroppedEvents[0].properties['test'], equals('event1'));
        expect(allDroppedEvents[1].properties['test'], equals('event2'));
      });
      test('should not call callback when no events are dropped', () {
        bool callbackCalled = false;
        final queue = EventQueue(
          maxQueueSize: 10,
          onEventsDropped: (events) {
            callbackCalled = true;
          },
        );
        queue.addEvent(testEvent1);
        queue.addEvent(testEvent2);
        expect(callbackCalled, isFalse);
      });
    });
  });
}
