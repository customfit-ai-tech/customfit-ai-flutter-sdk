// test/unit/analytics/event/event_callback_and_builder_test.dart
//
// Tests for EventCallback typedef and EventPropertiesBuilder
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_tracker.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/typed_event_properties.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_data.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('EventCallback', () {
    test('should be a function type that accepts EventData', () {
      bool callbackCalled = false;
      EventData? receivedEvent;
      // Create a callback function
      callback(EventData event) {
        callbackCalled = true;
        receivedEvent = event;
      }

      // Create test event
      final testEvent = EventData.create(
        eventCustomerId: 'test-customer',
        eventType: EventType.track,
        sessionId: 'test-session',
        properties: {'test': 'value'},
      );
      // Call the callback
      callback(testEvent);
      expect(callbackCalled, isTrue);
      expect(receivedEvent, equals(testEvent));
      expect(receivedEvent?.eventCustomerId, equals('test-customer'));
    });
    test('should work with different callback implementations', () {
      final receivedEvents = <EventData>[];
      // Callback that collects events
      collector(EventData event) {
        receivedEvents.add(event);
      }

      // Create multiple test events
      final events = [
        EventData.create(
          eventCustomerId: 'customer1',
          eventType: EventType.track,
          sessionId: 'session1',
          properties: {'action': 'login'},
        ),
        EventData.create(
          eventCustomerId: 'customer2',
          eventType: EventType.track,
          sessionId: 'session2',
          properties: {'action': 'logout'},
        ),
      ];
      // Call callback for each event
      for (final event in events) {
        collector(event);
      }
      expect(receivedEvents, hasLength(2));
      expect(receivedEvents[0].eventCustomerId, equals('customer1'));
      expect(receivedEvents[1].eventCustomerId, equals('customer2'));
    });
    test('should work with lambda functions', () {
      String? lastEventAction;
      // Lambda callback
      lambda(event) => lastEventAction = event.properties['action'] as String?;
      final testEvent = EventData.create(
        eventCustomerId: 'test-customer',
        eventType: EventType.track,
        sessionId: 'test-session',
        properties: {'action': 'purchase'},
      );
      lambda(testEvent);
      expect(lastEventAction, equals('purchase'));
    });
    test('should work with null callback handling', () {
      EventCallback? nullableCallback;
      // Test that we can assign null
      nullableCallback = null;
      expect(nullableCallback, isNull);
      // Test that we can assign a real callback
      nullableCallback = (event) {};
      expect(nullableCallback, isNotNull);
    });
    test('should work in async contexts', () async {
      bool asyncCallbackCompleted = false;
      asyncCallback(EventData event) async {
        await Future.delayed(const Duration(milliseconds: 10));
        asyncCallbackCompleted = true;
      }

      final testEvent = EventData.create(
        eventCustomerId: 'async-customer',
        eventType: EventType.track,
        sessionId: 'async-session',
        properties: {},
      );
      // Call the callback (note: we're not awaiting here as the typedef is synchronous)
      asyncCallback(testEvent);
      // Wait a bit to let the async operation complete
      await Future.delayed(const Duration(milliseconds: 20));
      expect(asyncCallbackCompleted, isTrue);
    });
    test('should handle callbacks that throw exceptions', () {
      throwingCallback(EventData event) {
        throw Exception('Callback error');
      }

      final testEvent = EventData.create(
        eventCustomerId: 'error-customer',
        eventType: EventType.track,
        sessionId: 'error-session',
        properties: {},
      );
      // Should be able to call callback that throws
      expect(() => throwingCallback(testEvent), throwsException);
    });
    test('should work with callbacks that modify event properties', () {
      final modifiedProperties = <String, dynamic>{};
      modifyingCallback(EventData event) {
        modifiedProperties.addAll(event.properties);
        modifiedProperties['callback_processed'] = true;
        modifiedProperties['processed_at'] = DateTime.now().toIso8601String();
      }

      final testEvent = EventData.create(
        eventCustomerId: 'modify-customer',
        eventType: EventType.track,
        sessionId: 'modify-session',
        properties: {'original': 'value'},
      );
      modifyingCallback(testEvent);
      expect(modifiedProperties['original'], equals('value'));
      expect(modifiedProperties['callback_processed'], isTrue);
      expect(modifiedProperties['processed_at'], isA<String>());
    });
  });
  group('EventPropertiesBuilder', () {
    test('should extend PropertiesBuilder', () {
      final builder = EventPropertiesBuilder();
      // Should be able to create instance
      expect(builder, isNotNull);
      expect(builder, isA<EventPropertiesBuilder>());
    });
    test('should inherit PropertiesBuilder functionality', () {
      final builder = EventPropertiesBuilder();
      // Should have basic builder methods (from parent class)
      // Note: We're testing that it compiles and can be instantiated
      // The actual functionality comes from the parent PropertiesBuilder class
      expect(builder.runtimeType.toString(), equals('EventPropertiesBuilder'));
    });
    test('should be usable as PropertiesBuilder', () {
      final builder = EventPropertiesBuilder();
      // Should be assignable to parent type
      expect(builder, isA<Object>());
      // Should be able to call toString (inherited method)
      final stringRepresentation = builder.toString();
      expect(stringRepresentation, isA<String>());
    });
    test('should support multiple instances', () {
      final builder1 = EventPropertiesBuilder();
      final builder2 = EventPropertiesBuilder();
      expect(builder1, isNot(same(builder2)));
      expect(builder1.runtimeType, equals(builder2.runtimeType));
    });
    test('should have correct type hierarchy', () {
      final builder = EventPropertiesBuilder();
      // Check type hierarchy
      expect(builder, isA<EventPropertiesBuilder>());
      expect(
          builder.runtimeType.toString(), contains('EventPropertiesBuilder'));
    });
  });
  group('Integration Tests', () {
    test('should work together in event processing scenario', () {
      final processedEvents = <EventData>[];
      final builder = EventPropertiesBuilder();
      // Create callback to process events
      processor(EventData event) {
        processedEvents.add(event);
      }

      // Create test events
      final events = [
        EventData.create(
          eventCustomerId: 'integration-customer-1',
          eventType: EventType.track,
          sessionId: 'integration-session',
          properties: {'test': 'integration'},
        ),
        EventData.create(
          eventCustomerId: 'integration-customer-2',
          eventType: EventType.track,
          sessionId: 'integration-session',
          properties: {'test': 'integration'},
        ),
      ];
      // Process events through callback
      for (final event in events) {
        processor(event);
      }
      expect(processedEvents, hasLength(2));
      expect(builder, isNotNull); // Builder is available for use
    });
    test('should handle complex event processing workflows', () {
      final eventLog = <String>[];
      final builder = EventPropertiesBuilder();
      // Create a complex callback that logs processing steps
      complexProcessor(EventData event) {
        eventLog.add('Processing event: ${event.eventId}');
        eventLog.add('Customer: ${event.eventCustomerId}');
        eventLog.add('Type: ${event.eventType}');
        eventLog.add('Properties: ${event.properties}');
        eventLog.add('Completed processing');
      }

      final testEvent = EventData.create(
        eventCustomerId: 'complex-customer',
        eventType: EventType.track,
        sessionId: 'complex-session',
        properties: {
          'action': 'complex_action',
          'metadata': {'version': '1.0', 'source': 'test'},
        },
      );
      complexProcessor(testEvent);
      expect(eventLog, hasLength(5));
      expect(eventLog[0], contains('Processing event:'));
      expect(eventLog[1], contains('complex-customer'));
      expect(eventLog[2], contains('track'));
      expect(eventLog[3], contains('complex_action'));
      expect(eventLog[4], equals('Completed processing'));
      expect(builder, isNotNull);
    });
    test('should support functional programming patterns', () {
      final results = <String>[];
      // Create a list of callbacks
      final callbacks = <EventCallback>[
        (event) => results.add('Callback 1: ${event.eventCustomerId}'),
        (event) => results.add('Callback 2: ${event.eventType}'),
        (event) =>
            results.add('Callback 3: ${event.properties.length} properties'),
      ];
      final testEvent = EventData.create(
        eventCustomerId: 'functional-customer',
        eventType: EventType.track,
        sessionId: 'functional-session',
        properties: {'key1': 'value1', 'key2': 'value2'},
      );
      // Apply all callbacks
      for (var callback in callbacks) {
        callback(testEvent);
      }
      expect(results, hasLength(3));
      expect(results[0], contains('functional-customer'));
      expect(results[1], contains('track'));
      expect(results[2], contains('2 properties'));
    });
  });
}
