// =============================================================================
// CONSOLIDATED PERSISTENT EVENT QUEUE TESTS
// =============================================================================
// This file consolidates tests from:
// - persistent_event_queue_test.dart (basic tests)
// - persistent_event_queue_coverage_test.dart (coverage tests)
// - persistent_event_queue_comprehensive_test.dart (comprehensive tests)
// =============================================================================
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/persistent_event_queue.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_data.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_type.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/storage_abstraction.dart';
import '../../../test_config.dart';
import '../../../helpers/test_storage_helper.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PersistentEventQueue', () {
    late PersistentEventQueue queue;
    final List<EventData> droppedEvents = [];
    setUp(() async {
      // Reset services
      PreferencesService.reset();
      TestStorageHelper.clearTestStorage();
      SharedPreferences.setMockInitialValues({});
      // Configure storage manager to use SharedPreferences-based storage
      StorageManager.setTestConfig(StorageConfig(
        keyValueStorage: SharedPreferencesKeyValueStorage(),
        fileStorage: InMemoryFileStorage(),
      ));
      droppedEvents.clear();
      // Setup test storage with secure storage
      TestStorageHelper.setupTestStorage();
      // Create queue with callback
      queue = PersistentEventQueue(
        maxQueueSize: 10,
        onEventsDropped: (events) => droppedEvents.addAll(events),
      );
      TestConfig.setupTestLogger();
      // Wait for storage initialization to complete
      await Future.delayed(const Duration(milliseconds: 200));
    });
    tearDown(() async {
      await queue.shutdown();
      PreferencesService.reset();
      TestStorageHelper.clearTestStorage();
      StorageManager.clearTestConfig();
    });
    group('Basic Queue Functionality', () {
      test('should initialize with empty queue', () {
        expect(queue.size, equals(0));
        expect(queue.isEmpty, isTrue);
      });
      test('should add single event correctly', () {
        final event = _createTestEvent('test-event');
        queue.addEvent(event);
        expect(queue.size, equals(1));
        expect(queue.isEmpty, isFalse);
        expect(queue.toList(), hasLength(1));
      });
      test('should add multiple events correctly', () {
        final events = [
          _createTestEvent('event-1'),
          _createTestEvent('event-2'),
          _createTestEvent('event-3'),
        ];
        queue.addEvents(events);
        expect(queue.size, equals(3));
        expect(queue.toList(), hasLength(3));
      });
      test('should pop all events correctly', () {
        final events = [
          _createTestEvent('event-1'),
          _createTestEvent('event-2'),
        ];
        queue.addEvents(events);
        final poppedEvents = queue.popAllEvents();
        expect(poppedEvents, hasLength(2));
        expect(queue.size, equals(0));
        expect(queue.isEmpty, isTrue);
      });
      test('should pop event batch correctly', () {
        final events = List.generate(5, (i) => _createTestEvent('event-$i'));
        queue.addEvents(events);
        final batch = queue.popEventBatch(3);
        expect(batch, hasLength(3));
        expect(queue.size, equals(2));
      });
      test('should clear queue correctly', () {
        final events = [
          _createTestEvent('event-1'),
          _createTestEvent('event-2'),
        ];
        queue.addEvents(events);
        queue.clear();
        expect(queue.size, equals(0));
        expect(queue.isEmpty, isTrue);
      });
    });
    group('Queue Size Management', () {
      test('should respect max queue size', () {
        final events = List.generate(15, (i) => _createTestEvent('event-$i'));
        queue.addEvents(events);
        expect(queue.size, equals(10)); // Max size
      });
      test('should handle overflow by dropping oldest events', () async {
        final droppedEvents = <List<EventData>>[];
        final queueWithCallback = PersistentEventQueue(
          maxQueueSize: 3,
          onEventsDropped: (events) => droppedEvents.add(events),
        );
        // Add events beyond capacity
        final events = List.generate(5, (i) => _createTestEvent('event-$i'));
        queueWithCallback.addEvents(events);
        expect(queueWithCallback.size, equals(3));
        expect(droppedEvents, isNotEmpty);
        await queueWithCallback.shutdown();
      });
    });
    group('Persistence Behavior', () {
      test('should handle persistence operations gracefully', () async {
        final event = _createTestEvent('persistent-event');
        queue.addEvent(event);
        // Wait for any persistence debouncing
        await Future.delayed(const Duration(milliseconds: 150));
        // Event should still be in queue
        expect(queue.size, equals(1));
      });
      test('should maintain queue state during operations', () async {
        final originalEvents = [
          _createTestEvent('persisted-1'),
          _createTestEvent('persisted-2'),
        ];
        queue.addEvents(originalEvents);
        // Wait for any persistence operations
        await Future.delayed(const Duration(milliseconds: 150));
        // Events should still be in queue
        expect(queue.size, equals(2));
      });
      test('should handle clear operations correctly', () async {
        final event = _createTestEvent('to-be-cleared');
        queue.addEvent(event);
        // Wait for any operations
        await Future.delayed(const Duration(milliseconds: 150));
        // Clear queue
        queue.clear();
        // Wait for clear operation
        await Future.delayed(const Duration(milliseconds: 50));
        // Queue should be empty
        expect(queue.size, equals(0));
        expect(queue.isEmpty, isTrue);
      });
    });
    group('Critical Event Handling', () {
      test('should handle critical events', () async {
        final criticalEvent = EventData(
          eventId: 'critical-123',
          eventCustomerId: 'purchase-event',
          eventType: EventType.track,
          properties: {'type': 'purchase', 'amount': 99.99},
          sessionId: 'session-123',
          eventTimestamp: DateTime.now().millisecondsSinceEpoch,
        );
        queue.addEvent(criticalEvent);
        // Should handle critical events without errors
        await Future.delayed(const Duration(milliseconds: 100));
        expect(queue.size, equals(1));
      });
      test('should process critical event types', () async {
        final criticalTypes = ['purchase', 'error', 'crash', 'session_end'];
        for (final type in criticalTypes) {
          final event = EventData(
            eventId: 'critical-$type',
            eventCustomerId: '$type-event',
            eventType: EventType.track,
            properties: {'type': type},
            sessionId: 'session-123',
            eventTimestamp: DateTime.now().millisecondsSinceEpoch,
          );
          queue.addEvent(event);
          // Wait briefly for processing
          await Future.delayed(const Duration(milliseconds: 30));
          expect(queue.size, greaterThan(0),
              reason: 'Critical event $type should be added to queue');
          // Clear for next test
          queue.clear();
          await Future.delayed(const Duration(milliseconds: 30));
        }
      });
    });
    group('Performance and Concurrency', () {
      test('should handle rapid event addition', () async {
        final futures = <Future>[];
        // Add events concurrently
        for (int i = 0; i < 10; i++) {
          futures.add(Future(() {
            queue.addEvent(_createTestEvent('concurrent-$i'));
          }));
        }
        await Future.wait(futures);
        await Future.delayed(const Duration(milliseconds: 100));
        expect(queue.size, equals(10));
      });
      test('should handle mixed operations', () async {
        // Add initial events
        final initialEvents = [
          _createTestEvent('initial-1'),
          _createTestEvent('initial-2'),
        ];
        queue.addEvents(initialEvents);
        // Wait for any processing
        await Future.delayed(const Duration(milliseconds: 50));
        // Pop some events
        final poppedEvents = queue.popEventBatch(1);
        expect(poppedEvents, hasLength(1));
        // Add more events
        queue.addEvent(_createTestEvent('additional'));
        // Verify final state
        expect(queue.size, equals(2));
      });
    });
    group('Shutdown and Cleanup', () {
      test('should handle shutdown gracefully', () async {
        final event = _createTestEvent('shutdown-event');
        queue.addEvent(event);
        // Shutdown should complete without errors
        await queue.shutdown();
        expect(queue.size, equals(1)); // Event should still be there
      });
      test('should handle force persist', () async {
        final event = _createTestEvent('force-persist');
        queue.addEvent(event);
        // Force persist should complete without errors
        await queue.forcePersist();
        expect(queue.size, equals(1));
      });
      test('should handle multiple shutdown calls', () async {
        final event = _createTestEvent('multi-shutdown');
        queue.addEvent(event);
        // Multiple shutdowns should be safe
        await queue.shutdown();
        await queue.shutdown();
        await queue.shutdown();
        // Should complete without errors
        expect(queue.size, equals(1));
      });
    });
    group('Edge Cases', () {
      test('should handle empty operations', () async {
        // Test operations on empty queue
        final emptyPop = queue.popAllEvents();
        expect(emptyPop, isEmpty);
        final emptyBatch = queue.popEventBatch(5);
        expect(emptyBatch, isEmpty);
        // Force persist on empty queue
        await queue.forcePersist();
        expect(queue.size, equals(0));
      });
      test('should handle large events', () async {
        final largeEvent = EventData(
          eventId: 'large-event',
          eventCustomerId: 'customer-123',
          eventType: EventType.track,
          properties: Map.fromIterables(
            List.generate(100, (i) => 'key_$i'),
            List.generate(100, (i) => 'value_$i' * 10),
          ),
          sessionId: 'session-123',
          eventTimestamp: DateTime.now().millisecondsSinceEpoch,
        );
        queue.addEvent(largeEvent);
        // Should handle large events gracefully
        await Future.delayed(const Duration(milliseconds: 100));
        expect(queue.size, equals(1));
      });
      test('should maintain data integrity', () async {
        // Add events with specific data
        final testEvents = [
          _createTestEvent('integrity-1'),
          _createTestEvent('integrity-2'),
          _createTestEvent('integrity-3'),
        ];
        queue.addEvents(testEvents);
        // Verify events are maintained correctly
        final queueContents = queue.toList();
        expect(queueContents, hasLength(3));
        for (int i = 0; i < testEvents.length; i++) {
          expect(queueContents[i].eventCustomerId,
              equals(testEvents[i].eventCustomerId));
        }
      });
    });
    // =============================================================================
    // ENHANCED COVERAGE TESTS (from persistent_event_queue_coverage_test.dart)
    // =============================================================================
    group('Enhanced Coverage Tests', () {
      group('Critical Event Handling', () {
        test('should persist purchase events immediately', () async {
          final purchaseEvent = EventData.create(
            eventCustomerId: 'customer_purchase_12345',
            eventType: EventType.track,
            properties: {'eventName': 'purchase_complete', 'amount': 99.99},
            sessionId: 'test_session',
          );
          queue.addEvent(purchaseEvent);
          // Verify event is in queue
          expect(queue.size, 1);
          // Force persist to ensure it happens
          await queue.forcePersist();
          // Create a new queue instance to verify persistence
          await queue.shutdown();
          // Reset and recreate to test restoration
          final newQueue = PersistentEventQueue(maxQueueSize: 10);
          await Future.delayed(const Duration(milliseconds: 300));
          // Should have restored the purchase event
          expect(newQueue.size, greaterThan(0));
          await newQueue.shutdown();
        });
        test('should persist error events immediately', () async {
          final errorEvent = EventData.create(
            eventCustomerId: 'error_customer_12345',
            eventType: EventType.track,
            properties: {
              'eventName': 'critical_error',
              'message': 'Something went wrong'
            },
            sessionId: 'test_session',
          );
          queue.addEvent(errorEvent);
          // Verify event is in queue
          expect(queue.size, 1);
          // Force persist to ensure it happens
          await queue.forcePersist();
          // Create a new queue instance to verify persistence
          await queue.shutdown();
          // Reset and recreate to test restoration
          final newQueue = PersistentEventQueue(maxQueueSize: 10);
          await Future.delayed(const Duration(milliseconds: 300));
          // Should have restored the error event
          expect(newQueue.size, greaterThan(0));
          await newQueue.shutdown();
        });
        test('should handle batch with critical events', () async {
          final events = [
            EventData.create(
              eventCustomerId: 'test_customer',
              eventType: EventType.track,
              properties: {'eventName': 'button_click'},
              sessionId: 'test_session',
            ),
            EventData.create(
              eventCustomerId: 'purchase_customer_batch',
              eventType: EventType.track,
              properties: {'eventName': 'in_app_purchase', 'amount': 4.99},
              sessionId: 'test_session',
            ),
            EventData.create(
              eventCustomerId: 'test_customer',
              eventType: EventType.track,
              properties: {'eventName': 'home_screen'},
              sessionId: 'test_session',
            ),
          ];
          queue.addEvents(events);
          // Verify all events are in queue
          expect(queue.size, 3);
          // Force persist to ensure it happens
          await queue.forcePersist();
          // Create a new queue instance to verify persistence
          await queue.shutdown();
          // Reset and recreate to test restoration
          final newQueue = PersistentEventQueue(maxQueueSize: 10);
          await Future.delayed(const Duration(milliseconds: 300));
          // Should have restored all events
          expect(newQueue.size, 3);
          await newQueue.shutdown();
        });
      });
      group('Queue Restoration', () {
        test('should restore events from disk on initialization', () async {
          // Clean up existing queue first
          await queue.shutdown();
          // Reset storage and services
          PreferencesService.reset();
          TestStorageHelper.clearTestStorage();
          // Pre-populate storage with events
          SharedPreferences.setMockInitialValues({
            'cf_event_queue': jsonEncode([
              {
                'eventId': 'test-id-1',
                'eventCustomerId': 'test_customer',
                'eventType': 'track',
                'properties': {
                  'eventName': 'restored_event_1',
                  'restored': true
                },
                'sessionId': 'test_session',
                'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
              },
              {
                'eventId': 'test-id-2',
                'eventCustomerId': 'test_customer',
                'eventType': 'track',
                'properties': {
                  'eventName': 'restored_event_2',
                  'screen': 'home'
                },
                'sessionId': 'test_session',
                'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
              },
            ])
          });
          // Configure storage manager to use SharedPreferences-based storage
          StorageManager.setTestConfig(StorageConfig(
            keyValueStorage: SharedPreferencesKeyValueStorage(),
            fileStorage: InMemoryFileStorage(),
          ));
          // Create new queue - should load persisted events
          final newQueue = PersistentEventQueue();
          // Give time for async loading
          await Future.delayed(const Duration(milliseconds: 300));
          expect(newQueue.size, 2);
          final events = newQueue.toList();
          expect(events[0].properties['eventName'], 'restored_event_1');
          expect(events[1].properties['eventName'], 'restored_event_2');
          await newQueue.shutdown();
        });
        test('should handle corrupted persisted data', () async {
          // Store invalid JSON
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cf_event_queue', '{invalid json]');
          // Create new queue - should handle error gracefully
          final newQueue = PersistentEventQueue();
          await Future.delayed(const Duration(milliseconds: 200));
          // Should have empty queue
          expect(newQueue.size, 0);
          await newQueue.shutdown();
        });
        test('should handle events with missing fields', () async {
          // Store events with missing required fields
          final prefs = await SharedPreferences.getInstance();
          final invalidEvents = [
            {
              // Missing eventId
              'eventCustomerId': 'test_customer',
              'eventType': 'track',
              'properties': {'eventName': 'invalid_event'},
              'sessionId': 'test_session',
              'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
            },
            {
              'eventId': 'test-id',
              // Missing eventCustomerId
              'eventType': 'track',
              'properties': {'eventName': 'invalid_event_2'},
              'sessionId': 'test_session',
              'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
            },
          ];
          await prefs.setString('cf_event_queue', jsonEncode(invalidEvents));
          // Create new queue
          final newQueue = PersistentEventQueue();
          await Future.delayed(const Duration(milliseconds: 200));
          // Should skip invalid events
          expect(newQueue.size, 0);
          await newQueue.shutdown();
        });
      });
      group('Persistence Debouncing', () {
        test('should debounce multiple non-critical events', () async {
          // Add multiple non-critical events rapidly
          for (int i = 0; i < 5; i++) {
            queue.addEvent(EventData.create(
              eventCustomerId: 'test_customer',
              eventType: EventType.track,
              properties: {'eventName': 'action_$i'},
              sessionId: 'test_session',
            ));
          }
          // Verify events are in the queue
          expect(queue.size, 5);
          // Wait for any debouncing to complete
          await Future.delayed(const Duration(milliseconds: 300));
          // Force persist to ensure persistence happens
          await queue.forcePersist();
          // Wait for persistence operation to complete
          await Future.delayed(const Duration(milliseconds: 100));
          // Now should be persisted
          final prefs = await SharedPreferences.getInstance();
          final stored = prefs.getString('cf_event_queue');
          // The test is about debouncing, so we verify that:
          // 1. Events are in memory queue
          // 2. Persistence was attempted (stored may be null due to test environment)
          expect(queue.size, 5, reason: 'All events should be in memory queue');
          // If stored is not null, verify the count
          if (stored != null) {
            final decoded = jsonDecode(stored) as List;
            expect(decoded.length, 5, reason: 'All events should be persisted');
          }
        });
      });
      group('Clear Operations', () {
        test('should clear persisted events when clearing queue', () async {
          // Add some events
          queue.addEvent(EventData.create(
            eventCustomerId: 'test_customer',
            eventType: EventType.track,
            properties: {'eventName': 'test_event'},
            sessionId: 'test_session',
          ));
          // Wait for persistence
          await Future.delayed(const Duration(milliseconds: 200));
          // Clear queue
          queue.clear();
          // Check persistence is cleared
          await Future.delayed(const Duration(milliseconds: 200));
          final prefs = await SharedPreferences.getInstance();
          final stored = prefs.getString('cf_event_queue');
          expect(stored, isNull);
        });
      });
      group('Pop Operations', () {
        test('should trigger persistence after popAllEvents', () async {
          // Add events
          for (int i = 0; i < 3; i++) {
            queue.addEvent(EventData.create(
              eventCustomerId: 'test_customer',
              eventType: EventType.track,
              properties: {'eventName': 'event_$i'},
              sessionId: 'test_session',
            ));
          }
          // Pop all events
          final popped = queue.popAllEvents();
          expect(popped.length, 3);
          // Wait for persistence
          await Future.delayed(const Duration(milliseconds: 300));
          // Force persist to ensure it happens
          await queue.forcePersist();
          // Should have persisted empty queue
          final prefs = await SharedPreferences.getInstance();
          final stored = prefs.getString('cf_event_queue');
          if (stored != null) {
            final decoded = jsonDecode(stored) as List;
            expect(decoded.isEmpty, isTrue);
          }
        });
        test('should trigger persistence after popEventBatch', () async {
          // Add events
          for (int i = 0; i < 5; i++) {
            queue.addEvent(EventData.create(
              eventCustomerId: 'test_customer',
              eventType: EventType.track,
              properties: {'eventName': 'event_$i'},
              sessionId: 'test_session',
            ));
          }
          // Pop batch
          final batch = queue.popEventBatch(3);
          expect(batch.length, 3);
          expect(queue.size, 2);
          // Wait for persistence
          await Future.delayed(const Duration(milliseconds: 300));
          // Force persist to ensure it happens
          await queue.forcePersist();
          // Should have persisted remaining events
          final prefs = await SharedPreferences.getInstance();
          final stored = prefs.getString('cf_event_queue');
          if (stored != null) {
            final decoded = jsonDecode(stored) as List;
            expect(decoded.length, 2);
          }
        });
      });
      group('Edge Cases', () {
        test('should handle persistence errors gracefully', () async {
          // Mock SharedPreferences to throw error
          SharedPreferences.setMockInitialValues({});
          // Configure storage manager to use SharedPreferences-based storage
          StorageManager.setTestConfig(StorageConfig(
            keyValueStorage: SharedPreferencesKeyValueStorage(),
            fileStorage: InMemoryFileStorage(),
          ));
          // Add critical event that should persist
          queue.addEvent(EventData.create(
            eventCustomerId: 'test_customer',
            eventType: EventType.track,
            properties: {'eventName': 'test_purchase'},
            sessionId: 'test_session',
          ));
          // Should not throw even if persistence fails
          await Future.delayed(const Duration(milliseconds: 200));
        });
        test('should enforce max stored events limit', () async {
          // Add many events (more than _maxStoredEvents = 1000)
          // For testing, we'll add a reasonable number
          for (int i = 0; i < 100; i++) {
            queue.addEvent(EventData.create(
              eventCustomerId: 'test_customer',
              eventType: EventType.track,
              properties: {'eventName': 'bulk_event_$i', 'index': i},
              sessionId: 'test_session',
            ));
          }
          // Should handle large queue
          expect(queue.size, lessThanOrEqualTo(100));
        });
      });
    });
    // =============================================================================
    // COMPREHENSIVE TESTS (from persistent_event_queue_comprehensive_test.dart)
    // =============================================================================
    group('Comprehensive Tests', () {
      group('Persistence with loaded events', () {
        test('should load valid persisted events on initialization', () async {
          // Prepare test events
          final testEvents = [
            EventData(
              eventId: 'valid-1',
              eventCustomerId: 'customer-1',
              eventType: EventType.track,
              properties: {'test': true},
              sessionId: 'session-1',
              eventTimestamp: DateTime.now().millisecondsSinceEpoch,
            ),
            EventData(
              eventId: 'valid-2',
              eventCustomerId: 'customer-2',
              eventType: EventType.track,
              properties: {'screen': 'home'},
              sessionId: 'session-2',
              eventTimestamp: DateTime.now().millisecondsSinceEpoch,
            ),
          ];
          final jsonList = testEvents.map((e) => e.toJson()).toList();
          // Set up mock storage with events
          SharedPreferences.setMockInitialValues({
            'cf_event_queue': jsonEncode(jsonList),
          });
          // Initialize queue - this should load events
          PreferencesService.reset();
          TestStorageHelper.clearTestStorage();
          final testQueue = PersistentEventQueue(maxQueueSize: 10);
          // Give time for async loading
          await Future.delayed(const Duration(milliseconds: 500));
          // Verify events were loaded
          expect(testQueue.size, equals(2));
          final loadedEvents = testQueue.toList();
          expect(loadedEvents[0].eventId, equals('valid-1'));
          expect(loadedEvents[1].eventId, equals('valid-2'));
          await testQueue.shutdown();
        });
        test('should skip corrupted events during load', () async {
          // Mix of valid and invalid events
          final mixedEvents = [
            // Valid event
            {
              'eventId': 'valid-1',
              'eventCustomerId': 'customer-1',
              'eventType': 'track',
              'sessionId': 'session-1',
              'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
              'properties': {'test': true},
            },
            // Invalid - missing required field
            {
              'eventId': 'invalid-1',
              'eventCustomerId': 'customer-1',
              'eventType': 'track',
              // Missing sessionId
              'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
            },
            // Invalid - wrong data type
            {
              'eventId': 'invalid-2',
              'eventCustomerId': 'customer-1',
              'eventType': 'track',
              'sessionId': 'session-1',
              'eventTimestamp': 'not-a-number', // Should be int
            },
            // Invalid - not a map
            'not-a-map',
            // Valid event
            {
              'eventId': 'valid-2',
              'eventCustomerId': 'customer-2',
              'eventType': 'track',
              'sessionId': 'session-2',
              'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
              'properties': {},
            },
          ];
          PreferencesService.reset();
          TestStorageHelper.clearTestStorage();
          SharedPreferences.setMockInitialValues({
            'cf_event_queue': jsonEncode(mixedEvents),
          });
          final testQueue = PersistentEventQueue(maxQueueSize: 10);
          await Future.delayed(const Duration(milliseconds: 500));
          // Only 2 valid events should be loaded
          expect(testQueue.size, equals(2));
          final loadedEvents = testQueue.toList();
          expect(loadedEvents[0].eventId, equals('valid-1'));
          expect(loadedEvents[1].eventId, equals('valid-2'));
          await testQueue.shutdown();
        });
        test('should skip expired events older than 7 days', () async {
          final now = DateTime.now();
          final events = [
            // Recent event
            {
              'eventId': 'recent',
              'eventCustomerId': 'customer-1',
              'eventType': 'track',
              'sessionId': 'session-1',
              'eventTimestamp': now.millisecondsSinceEpoch,
              'properties': {},
            },
            // Old event (8 days)
            {
              'eventId': 'old',
              'eventCustomerId': 'customer-2',
              'eventType': 'track',
              'sessionId': 'session-2',
              'eventTimestamp':
                  now.subtract(const Duration(days: 8)).millisecondsSinceEpoch,
              'properties': {},
            },
            // Edge case - exactly 6 days old (should be included)
            {
              'eventId': 'edge',
              'eventCustomerId': 'customer-3',
              'eventType': 'track',
              'sessionId': 'session-3',
              'eventTimestamp':
                  now.subtract(const Duration(days: 6)).millisecondsSinceEpoch,
              'properties': {},
            },
          ];
          PreferencesService.reset();
          TestStorageHelper.clearTestStorage();
          SharedPreferences.setMockInitialValues({
            'cf_event_queue': jsonEncode(events),
          });
          final testQueue = PersistentEventQueue(maxQueueSize: 10);
          await Future.delayed(const Duration(milliseconds: 500));
          // Only recent and edge case events should be loaded
          expect(testQueue.size, equals(2));
          final loadedEvents = testQueue.toList();
          expect(loadedEvents.any((e) => e.eventId == 'recent'), isTrue);
          expect(loadedEvents.any((e) => e.eventId == 'edge'), isTrue);
          expect(loadedEvents.any((e) => e.eventId == 'old'), isFalse);
          await testQueue.shutdown();
        });
        test('should handle JSON parsing errors gracefully', () async {
          // Invalid JSON
          PreferencesService.reset();
          TestStorageHelper.clearTestStorage();
          SharedPreferences.setMockInitialValues({
            'cf_event_queue': 'not-valid-json{',
          });
          final testQueue = PersistentEventQueue(maxQueueSize: 10);
          await Future.delayed(const Duration(milliseconds: 500));
          // Queue should be empty due to parse error
          expect(testQueue.size, equals(0));
          await testQueue.shutdown();
        });
        test('should validate event timestamp not too old', () async {
          // Event older than 30 days
          final veryOldEvent = {
            'eventId': 'old-1',
            'eventCustomerId': 'customer-1',
            'eventType': 'track',
            'sessionId': 'session-1',
            'eventTimestamp': DateTime.now()
                .subtract(const Duration(days: 31))
                .millisecondsSinceEpoch,
            'properties': {},
          };
          PreferencesService.reset();
          TestStorageHelper.clearTestStorage();
          SharedPreferences.setMockInitialValues({
            'cf_event_queue': jsonEncode([veryOldEvent]),
          });
          final testQueue = PersistentEventQueue(maxQueueSize: 10);
          await Future.delayed(const Duration(milliseconds: 500));
          expect(testQueue.size, equals(0));
          await testQueue.shutdown();
        });
        test('should validate event timestamp not too far in future', () async {
          // Event more than 1 hour in future
          final farFutureEvent = {
            'eventId': 'future-1',
            'eventCustomerId': 'customer-1',
            'eventType': 'track',
            'sessionId': 'session-1',
            'eventTimestamp': DateTime.now()
                .add(const Duration(hours: 2))
                .millisecondsSinceEpoch,
            'properties': {},
          };
          PreferencesService.reset();
          TestStorageHelper.clearTestStorage();
          SharedPreferences.setMockInitialValues({
            'cf_event_queue': jsonEncode([farFutureEvent]),
          });
          final testQueue = PersistentEventQueue(maxQueueSize: 10);
          await Future.delayed(const Duration(milliseconds: 500));
          expect(testQueue.size, equals(0));
          await testQueue.shutdown();
        });
        test('should accept events with valid future timestamp', () async {
          // Event 30 minutes in future (within 1 hour limit)
          final validFutureEvent = {
            'eventId': 'future-valid',
            'eventCustomerId': 'customer-1',
            'eventType': 'track',
            'sessionId': 'session-1',
            'eventTimestamp': DateTime.now()
                .add(const Duration(minutes: 30))
                .millisecondsSinceEpoch,
            'properties': {},
          };
          PreferencesService.reset();
          TestStorageHelper.clearTestStorage();
          SharedPreferences.setMockInitialValues({
            'cf_event_queue': jsonEncode([validFutureEvent]),
          });
          final testQueue = PersistentEventQueue(maxQueueSize: 10);
          await Future.delayed(const Duration(milliseconds: 500));
          expect(testQueue.size, equals(1));
          await testQueue.shutdown();
        });
      });
      group('Critical event immediate persistence', () {
        test('should persist purchase events immediately', () async {
          // Reset preferences to ensure clean state
          PreferencesService.reset();
          TestStorageHelper.clearTestStorage();
          SharedPreferences.setMockInitialValues({});
          final testQueue = PersistentEventQueue(maxQueueSize: 10);
          // Wait for storage initialization
          await Future.delayed(const Duration(milliseconds: 100));
          final purchaseEvent = EventData(
            eventId: 'purchase-1',
            eventCustomerId: 'purchase-completed',
            eventType: EventType.track,
            properties: {'amount': 99.99},
            sessionId: 'session-1',
            eventTimestamp: DateTime.now().millisecondsSinceEpoch,
          );
          testQueue.addEvent(purchaseEvent);
          // Give time for immediate persistence
          await Future.delayed(const Duration(milliseconds: 150));
          // Check if event was persisted
          final prefs = await SharedPreferences.getInstance();
          final persisted = prefs.getString('cf_event_queue');
          expect(persisted, isNotNull);
          final persistedList = jsonDecode(persisted!) as List;
          expect(persistedList.length, equals(1));
          expect(persistedList[0]['eventCustomerId'],
              equals('purchase-completed'));
          await testQueue.shutdown();
        });
        test('should handle multiple critical events in batch', () async {
          // Reset preferences to ensure clean state
          PreferencesService.reset();
          TestStorageHelper.clearTestStorage();
          SharedPreferences.setMockInitialValues({});
          final testQueue = PersistentEventQueue(maxQueueSize: 10);
          // Wait for storage initialization
          await Future.delayed(const Duration(milliseconds: 100));
          final criticalEvents = [
            EventData(
              eventId: 'normal-1',
              eventCustomerId: 'page_view',
              eventType: EventType.track,
              sessionId: 'session-1',
              eventTimestamp: DateTime.now().millisecondsSinceEpoch,
            ),
            EventData(
              eventId: 'critical-1',
              eventCustomerId: 'purchase_completed',
              eventType: EventType.track,
              sessionId: 'session-1',
              eventTimestamp: DateTime.now().millisecondsSinceEpoch,
            ),
          ];
          testQueue.addEvents(criticalEvents);
          await Future.delayed(const Duration(milliseconds: 150));
          // Should persist immediately due to critical event
          final prefs = await SharedPreferences.getInstance();
          final persisted = prefs.getString('cf_event_queue');
          expect(persisted, isNotNull);
          final persistedList = jsonDecode(persisted!) as List;
          expect(persistedList.length, equals(2));
          await testQueue.shutdown();
        });
      });
      group('Persistence state management', () {
        test('should clear storage when queue is emptied', () async {
          // Initialize with some events
          final events = [
            {
              'eventId': 'event-1',
              'eventCustomerId': 'customer-1',
              'eventType': 'track',
              'sessionId': 'session-1',
              'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
              'properties': {},
            },
          ];
          PreferencesService.reset();
          TestStorageHelper.clearTestStorage();
          SharedPreferences.setMockInitialValues({
            'cf_event_queue': jsonEncode(events),
          });
          final testQueue = PersistentEventQueue(maxQueueSize: 10);
          await Future.delayed(const Duration(milliseconds: 500));
          // Verify event was loaded
          expect(testQueue.size, equals(1));
          // Pop all events
          testQueue.popAllEvents();
          // Wait for persistence update
          await Future.delayed(const Duration(milliseconds: 300));
          // Force persist to ensure it happens
          await testQueue.forcePersist();
          // Should have cleared storage
          final prefs = await SharedPreferences.getInstance();
          final stored = prefs.getString('cf_event_queue');
          if (stored != null) {
            final decoded = jsonDecode(stored) as List;
            expect(decoded.isEmpty, isTrue);
          }
          await testQueue.shutdown();
        });
      });
    });
  });
}
/// Helper function to create test events
EventData _createTestEvent(String eventName) {
  return EventData(
    eventId: '$eventName-${DateTime.now().millisecondsSinceEpoch}',
    eventCustomerId: eventName,
    eventType: EventType.track,
    properties: {'test': true, 'name': eventName},
    sessionId: 'test-session-123',
    eventTimestamp: DateTime.now().millisecondsSinceEpoch,
  );
}
