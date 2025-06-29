import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/recovery_managers.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_data.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_tracker.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_type.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/cache_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:convert';
import '../../../test_config.dart';
import '../../../helpers/test_storage_helper.dart';
@GenerateMocks([EventTracker, CacheManager])
import 'event_recovery_manager_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockEventTracker mockEventTracker;
  late MockCacheManager mockCacheManager;
  setUp(() {
    TestConfig.setupTestLogger(); // Enable logger for coverage
    SharedPreferences.setMockInitialValues({});
    // Setup test storage with secure storage
    TestStorageHelper.setupTestStorage();
    mockEventTracker = MockEventTracker();
    mockCacheManager = MockCacheManager();
    // Setup CacheManager singleton
    CacheManager.setTestInstance(mockCacheManager);
  });
  tearDown(() {
    CacheManager.clearTestInstance();
    PreferencesService.reset();
    TestStorageHelper.clearTestStorage();
  });
  group('EventRecoveryManager Tests', () {
    group('recoverFromEventDeliveryFailure', () {
      test('should queue event for retry on first failure', () async {
        // Arrange
        final event = EventData.create(
          eventCustomerId: 'test-user',
          eventType: EventType.track,
          properties: {'action': 'button_click'},
          sessionId: 'test-session',
        );
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode([]));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        // Act
        final result =
            await EventRecoveryManager.recoverFromEventDeliveryFailure(
          event,
          failureReason: 'Network timeout',
          attemptNumber: 1,
        );
        // Assert
        expect(result.isSuccess, true);
        // Verify event was stored for retry
        final putCall =
            verify(mockCacheManager.put('cf_failed_events', captureAny))
                .captured
                .single;
        final storedEvents = jsonDecode(putCall as String) as List;
        expect(storedEvents.length, 1);
        expect(storedEvents[0]['attemptNumber'], 1);
        expect(storedEvents[0]['failureReason'], 'Network timeout');
      });
      test('should increment attempt number on subsequent failures', () async {
        // Arrange
        final event = EventData.create(
          eventCustomerId: 'test-user',
          eventType: EventType.track,
          properties: {'action': 'button_click'},
          sessionId: 'test-session',
        );
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode([]));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        // Act
        final result =
            await EventRecoveryManager.recoverFromEventDeliveryFailure(
          event,
          failureReason: 'Server error',
          attemptNumber: 3,
        );
        // Assert
        expect(result.isSuccess, true);
        // Verify attempt number was stored
        final putCall =
            verify(mockCacheManager.put('cf_failed_events', captureAny))
                .captured
                .single;
        final storedEvents = jsonDecode(putCall as String) as List;
        expect(storedEvents[0]['attemptNumber'], 3);
      });
      test('should move to failed storage after max attempts', () async {
        // Arrange
        final event = EventData(
          eventId: 'test-event-id',
          eventCustomerId: 'test-user',
          eventType: EventType.track,
          sessionId: 'test-session',
          eventTimestamp: DateTime.now().millisecondsSinceEpoch,
          properties: {'action': 'button_click'},
        );
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode([]));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        // Act
        final result =
            await EventRecoveryManager.recoverFromEventDeliveryFailure(
          event,
          failureReason: 'Permanent failure',
          attemptNumber: 5, // Max attempts
        );
        // Assert
        expect(result.isSuccess, true);
        // Verify event was stored with max attempts reached
        final putCall =
            verify(mockCacheManager.put('cf_failed_events', captureAny))
                .captured
                .single;
        final storedEvents = jsonDecode(putCall as String) as List;
        expect(storedEvents[0]['attemptNumber'], 5);
        expect(storedEvents[0]['failureReason'], contains('Permanent failure'));
      });
      test('should handle queue size limit', () async {
        // Arrange
        final event = EventData(
          eventId: 'test-event-id',
          eventCustomerId: 'test-user',
          eventType: EventType.track,
          sessionId: 'test-session',
          eventTimestamp: DateTime.now().millisecondsSinceEpoch,
          properties: {'action': 'new_event'},
        );
        // Create a list of 1000 events (at max limit)
        final existingEvents = List.generate(
            1000,
            (i) => {
                  'eventId': 'event-$i',
                  'eventCustomerId': 'test-user',
                  'eventType': 'track',
                  'properties': {'id': i},
                  'sessionId': 'test-session',
                  'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
                });
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode(existingEvents));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        // Act
        final result =
            await EventRecoveryManager.recoverFromEventDeliveryFailure(
          event,
          failureReason: 'Network error',
        );
        // Assert
        expect(result.isSuccess, true);
        // Verify oldest event was removed
        final putCall =
            verify(mockCacheManager.put('cf_failed_events', captureAny))
                .captured
                .single;
        final storedEvents = jsonDecode(putCall as String) as List;
        expect(storedEvents.length, 1000); // Still at limit
        expect(storedEvents.last['properties']['action'], 'new_event');
      });
    });
    group('recoverOfflineEvents', () {
      test('should successfully recover offline events', () async {
        // Arrange
        final offlineEvents = [
          {
            'eventId': 'offline-event-1',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'action': 'offline_event_1'},
            'sessionId': 'test-session',
            'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
          },
          {
            'eventId': 'offline-event-2',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'action': 'offline_event_2'},
            'sessionId': 'test-session',
            'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
          },
        ];
        when(mockCacheManager.get<String>('cf_offline_events'))
            .thenAnswer((_) async => jsonEncode(offlineEvents));
        when(mockCacheManager.remove('cf_offline_events'))
            .thenAnswer((_) async => true);
        when(mockEventTracker.trackEvent(any, any))
            .thenAnswer((_) async => CFResult<EventData>.success(EventData(
                  eventId: 'test-event-id',
                  eventCustomerId: 'test-user',
                  eventType: EventType.track,
                  sessionId: 'test-session',
                  eventTimestamp: DateTime.now().millisecondsSinceEpoch,
                  properties: {},
                )));
        // Act
        final result = await EventRecoveryManager.recoverOfflineEvents(
          mockEventTracker,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 2); // Both events recovered
        // Verify events were tracked
        verify(mockEventTracker.trackEvent('track', any)).called(2);
        // Verify offline events were cleared
        verify(mockCacheManager.remove('cf_offline_events')).called(1);
      });
      test('should handle empty offline queue', () async {
        // Arrange
        when(mockCacheManager.get<String>('cf_offline_events'))
            .thenAnswer((_) async => jsonEncode([]));
        // Act
        final result = await EventRecoveryManager.recoverOfflineEvents(
          mockEventTracker,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 0);
        // Verify no events were tracked
        verifyNever(mockEventTracker.trackEvent(any, any));
        // Verify offline events were not cleared (no need)
        verifyNever(mockCacheManager.remove('cf_offline_events'));
      });
      test('should handle partial recovery failure', () async {
        // Arrange
        final offlineEvents = [
          {
            'eventId': 'offline-event-1',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'action': 'offline_event_1'},
            'sessionId': 'test-session',
            'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
          },
          {
            'eventId': 'offline-event-2',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'action': 'offline_event_2'},
            'sessionId': 'test-session',
            'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
          },
          {
            'eventId': 'offline-event-3',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'action': 'offline_event_3'},
            'sessionId': 'test-session',
            'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
          },
        ];
        when(mockCacheManager.get<String>('cf_offline_events'))
            .thenAnswer((_) async => jsonEncode(offlineEvents));
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode([]));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        when(mockCacheManager.remove('cf_offline_events'))
            .thenAnswer((_) async => true);
        // First event succeeds, second fails, third succeeds
        var callCount = 0;
        when(mockEventTracker.trackEvent(any, any)).thenAnswer((_) async {
          callCount++;
          if (callCount == 2) {
            throw Exception('Network error during recovery');
          }
          return CFResult<EventData>.success(EventData(
            eventId: 'test-event-id',
            eventCustomerId: 'test-user',
            eventType: EventType.track,
            sessionId: 'test-session',
            eventTimestamp: DateTime.now().millisecondsSinceEpoch,
            properties: {},
          ));
        });
        // Act
        final result = await EventRecoveryManager.recoverOfflineEvents(
          mockEventTracker,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 2); // 2 out of 3 recovered
        // Verify failed event was re-queued
        verify(mockCacheManager.put('cf_failed_events', any)).called(1);
      });
    });
    group('storeEventOffline', () {
      test('should store event offline successfully', () async {
        // Arrange
        final event = EventData(
          eventId: 'test-event-id',
          eventCustomerId: 'test-user',
          eventType: EventType.track,
          sessionId: 'test-session',
          eventTimestamp: DateTime.now().millisecondsSinceEpoch,
          properties: {'action': 'offline_action'},
        );
        when(mockCacheManager.get<String>('cf_offline_events'))
            .thenAnswer((_) async => jsonEncode([]));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        // Act
        final result = await EventRecoveryManager.storeEventOffline(event);
        // Assert
        expect(result.isSuccess, true);
        // Verify event was stored
        final putCall =
            verify(mockCacheManager.put('cf_offline_events', captureAny))
                .captured
                .single;
        final storedEvents = jsonDecode(putCall as String) as List;
        expect(storedEvents.length, 1);
        expect(storedEvents[0]['properties']['action'], 'offline_action');
      });
      test('should handle offline queue size limit', () async {
        // Arrange
        final event = EventData(
          eventId: 'test-event-id',
          eventCustomerId: 'test-user',
          eventType: EventType.track,
          sessionId: 'test-session',
          eventTimestamp: DateTime.now().millisecondsSinceEpoch,
          properties: {'action': 'new_offline_event'},
        );
        // Create a list of 1000 events (at max limit)
        final existingEvents = List.generate(
            1000,
            (i) => {
                  'eventId': 'event-$i',
                  'eventCustomerId': 'test-user',
                  'eventType': 'track',
                  'properties': {'id': i},
                  'sessionId': 'test-session',
                  'eventTimestamp':
                      DateTime.now().millisecondsSinceEpoch - (i * 1000),
                });
        when(mockCacheManager.get<String>('cf_offline_events'))
            .thenAnswer((_) async => jsonEncode(existingEvents));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        // Act
        final result = await EventRecoveryManager.storeEventOffline(event);
        // Assert
        expect(result.isSuccess, true);
        // Verify oldest event was removed
        final putCall =
            verify(mockCacheManager.put('cf_offline_events', captureAny))
                .captured
                .single;
        final storedEvents = jsonDecode(putCall as String) as List;
        expect(storedEvents.length, 1000); // Still at limit
        expect(storedEvents.last['properties']['action'], 'new_offline_event');
        // First event (oldest) should be removed
        expect(storedEvents.first['properties']['id'], 1);
      });
    });
    group('retryFailedEvents', () {
      test('should successfully retry failed events', () async {
        // Arrange
        final failedEvents = [
          {
            'eventId': 'failed-event-1',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'action': 'failed_event_1'},
            'sessionId': 'test-session',
            'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
            'attemptNumber': 2,
          },
          {
            'eventId': 'failed-event-2',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'action': 'failed_event_2'},
            'sessionId': 'test-session',
            'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
            'attemptNumber': 1,
          },
        ];
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode(failedEvents));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        when(mockEventTracker.trackEvent(any, any))
            .thenAnswer((_) async => CFResult<EventData>.success(EventData(
                  eventId: 'test-event-id',
                  eventCustomerId: 'test-user',
                  eventType: EventType.track,
                  sessionId: 'test-session',
                  eventTimestamp: DateTime.now().millisecondsSinceEpoch,
                  properties: {},
                )));
        // Act
        final result = await EventRecoveryManager.retryFailedEvents(
          mockEventTracker,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 2); // Both events succeeded
        // Verify events were tracked
        verify(mockEventTracker.trackEvent('track', any)).called(2);
        // Verify failed events list was updated (cleared)
        final putCall =
            verify(mockCacheManager.put('cf_failed_events', captureAny))
                .captured
                .single;
        final remainingEvents = jsonDecode(putCall as String) as List;
        expect(remainingEvents, isEmpty);
      });
      test('should limit number of events to retry', () async {
        // Arrange
        final failedEvents = List.generate(
            100,
            (i) => {
                  'eventId': 'failed-event-$i',
                  'eventCustomerId': 'test-user',
                  'eventType': 'track',
                  'properties': {'id': i},
                  'sessionId': 'test-session',
                  'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
                  'attemptNumber': 1,
                });
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode(failedEvents));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        when(mockEventTracker.trackEvent(any, any))
            .thenAnswer((_) async => CFResult<EventData>.success(EventData(
                  eventId: 'test-event-id',
                  eventCustomerId: 'test-user',
                  eventType: EventType.track,
                  sessionId: 'test-session',
                  eventTimestamp: DateTime.now().millisecondsSinceEpoch,
                  properties: {},
                )));
        // Act
        final result = await EventRecoveryManager.retryFailedEvents(
          mockEventTracker,
          maxEventsToRetry: 10,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 10); // Only 10 events retried
        // Verify only 10 events were tracked
        verify(mockEventTracker.trackEvent('track', any)).called(10);
        // Verify remaining events are still in queue
        final putCall =
            verify(mockCacheManager.put('cf_failed_events', captureAny))
                .captured
                .single;
        final remainingEvents = jsonDecode(putCall as String) as List;
        expect(remainingEvents.length, 90);
      });
      test('should handle events that still fail on retry', () async {
        // Arrange
        final failedEvents = [
          {
            'eventId': 'event-will-succeed',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'action': 'will_succeed'},
            'sessionId': 'test-session',
            'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
            'attemptNumber': 1,
          },
          {
            'eventId': 'event-will-fail',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'action': 'will_fail'},
            'sessionId': 'test-session',
            'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
            'attemptNumber': 2,
          },
        ];
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode(failedEvents));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        // First event succeeds, second fails
        when(mockEventTracker.trackEvent(any, any))
            .thenAnswer((invocation) async {
          final properties =
              invocation.positionalArguments[1] as Map<String, dynamic>;
          if (properties['action'] == 'will_fail') {
            throw Exception('Still failing');
          }
          return CFResult<EventData>.success(EventData(
            eventId: 'test-event-id',
            eventCustomerId: 'test-user',
            eventType: EventType.track,
            sessionId: 'test-session',
            eventTimestamp: DateTime.now().millisecondsSinceEpoch,
            properties: {},
          ));
        });
        // Act
        final result = await EventRecoveryManager.retryFailedEvents(
          mockEventTracker,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 1); // Only 1 succeeded
        // Verify failed event was kept with incremented attempt
        final putCall =
            verify(mockCacheManager.put('cf_failed_events', captureAny))
                .captured
                .single;
        final remainingEvents = jsonDecode(putCall as String) as List;
        expect(remainingEvents.length, 1);
        expect(remainingEvents[0]['attemptNumber'], 3);
        expect(
            remainingEvents[0]['lastFailureReason'], contains('Still failing'));
      });
      test('should not retry events that reached max attempts', () async {
        // Arrange
        final failedEvents = [
          {
            'eventId': 'max-attempts-event',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'action': 'max_attempts_reached'},
            'sessionId': 'test-session',
            'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
            'attemptNumber': 5,
          },
        ];
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode(failedEvents));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        // Act
        final result = await EventRecoveryManager.retryFailedEvents(
          mockEventTracker,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 0); // No events retried
        // Verify event was not tracked
        verifyNever(mockEventTracker.trackEvent(any, any));
        // Verify event was kept with max attempts flag
        final putCall =
            verify(mockCacheManager.put('cf_failed_events', captureAny))
                .captured
                .single;
        final remainingEvents = jsonDecode(putCall as String) as List;
        expect(remainingEvents.length, 1);
        expect(remainingEvents[0]['maxAttemptsReached'], true);
      });
    });
    group('cleanupOldFailedEvents', () {
      test('should remove events older than max age', () async {
        // Arrange
        final now = DateTime.now();
        final failedEvents = [
          {
            'eventId': 'old-event-1',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'id': 1},
            'sessionId': 'test-session',
            'eventTimestamp':
                now.subtract(const Duration(days: 10)).millisecondsSinceEpoch,
            'timestamp':
                now.subtract(const Duration(days: 10)).millisecondsSinceEpoch,
          },
          {
            'eventId': 'old-event-2',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'id': 2},
            'sessionId': 'test-session',
            'eventTimestamp':
                now.subtract(const Duration(days: 5)).millisecondsSinceEpoch,
            'timestamp':
                now.subtract(const Duration(days: 5)).millisecondsSinceEpoch,
          },
          {
            'eventId': 'old-event-3',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'id': 3},
            'sessionId': 'test-session',
            'eventTimestamp':
                now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
            'timestamp':
                now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
          },
        ];
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode(failedEvents));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        // Act
        final result = await EventRecoveryManager.cleanupOldFailedEvents(
          maxAge: const Duration(days: 7),
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 1); // One event removed
        // Verify only recent events were kept
        final putCall =
            verify(mockCacheManager.put('cf_failed_events', captureAny))
                .captured
                .single;
        final remainingEvents = jsonDecode(putCall as String) as List;
        expect(remainingEvents.length, 2);
        expect(remainingEvents[0]['properties']['id'], 2);
        expect(remainingEvents[1]['properties']['id'], 3);
      });
      test('should handle empty failed events list', () async {
        // Arrange
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode([]));
        // Act
        final result = await EventRecoveryManager.cleanupOldFailedEvents();
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 0); // No events removed
        // Verify put was not called since no changes
        verifyNever(mockCacheManager.put(any, any));
      });
      test('should handle events without timestamp', () async {
        // Arrange
        final failedEvents = [
          {
            'eventId': 'no-timestamp-event',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'id': 1},
            'sessionId': 'test-session',
            // No timestamp
          },
          {
            'eventId': 'with-timestamp-event',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'id': 2},
            'sessionId': 'test-session',
            'eventTimestamp': DateTime.now().millisecondsSinceEpoch,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        ];
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode(failedEvents));
        when(mockCacheManager.put(any, any)).thenAnswer((_) async => true);
        // Act
        final result = await EventRecoveryManager.cleanupOldFailedEvents();
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 1); // Event without timestamp removed
        // Verify only events with timestamp were kept
        final putCall =
            verify(mockCacheManager.put('cf_failed_events', captureAny))
                .captured
                .single;
        final remainingEvents = jsonDecode(putCall as String) as List;
        expect(remainingEvents.length, 1);
        expect(remainingEvents[0]['properties']['id'], 2);
      });
    });
    group('getRecoveryStats', () {
      test('should return correct statistics', () async {
        // Arrange
        final now = DateTime.now();
        final failedEvents = [
          {
            'eventId': 'failed-stats-1',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'id': 1},
            'sessionId': 'test-session',
            'eventTimestamp':
                now.subtract(const Duration(days: 5)).millisecondsSinceEpoch,
            'timestamp':
                now.subtract(const Duration(days: 5)).millisecondsSinceEpoch,
          },
          {
            'eventId': 'failed-stats-2',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'id': 2},
            'sessionId': 'test-session',
            'eventTimestamp':
                now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
            'timestamp':
                now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
          },
        ];
        final offlineEvents = [
          {
            'eventId': 'offline-stats-1',
            'eventCustomerId': 'test-user',
            'eventType': 'track',
            'properties': {'id': 3},
            'sessionId': 'test-session',
            'eventTimestamp':
                now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
            'timestamp':
                now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
          },
        ];
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode(failedEvents));
        when(mockCacheManager.get<String>('cf_offline_events'))
            .thenAnswer((_) async => jsonEncode(offlineEvents));
        // Act
        final stats = await EventRecoveryManager.getRecoveryStats();
        // Assert
        expect(stats.failedEventsCount, 2);
        expect(stats.offlineEventsCount, 1);
        expect(stats.oldestFailedEventTime, isNotNull);
        expect(
            stats.oldestFailedEventTime!
                .isBefore(now.subtract(const Duration(days: 4))),
            true);
        expect(stats.oldestOfflineEventTime, isNotNull);
        expect(
            stats.oldestOfflineEventTime!
                .isAfter(now.subtract(const Duration(hours: 3))),
            true);
      });
      test('should handle empty queues', () async {
        // Arrange
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenAnswer((_) async => jsonEncode([]));
        when(mockCacheManager.get<String>('cf_offline_events'))
            .thenAnswer((_) async => jsonEncode([]));
        // Act
        final stats = await EventRecoveryManager.getRecoveryStats();
        // Assert
        expect(stats.failedEventsCount, 0);
        expect(stats.offlineEventsCount, 0);
        expect(stats.oldestFailedEventTime, isNull);
        expect(stats.oldestOfflineEventTime, isNull);
      });
      test('should handle cache errors gracefully', () async {
        // Arrange
        when(mockCacheManager.get<String>('cf_failed_events'))
            .thenThrow(Exception('Cache error'));
        when(mockCacheManager.get<String>('cf_offline_events'))
            .thenThrow(Exception('Cache error'));
        // Act
        final stats = await EventRecoveryManager.getRecoveryStats();
        // Assert
        expect(stats.failedEventsCount, 0);
        expect(stats.offlineEventsCount, 0);
        expect(stats.oldestFailedEventTime, isNull);
        expect(stats.oldestOfflineEventTime, isNull);
      });
    });
    group('Error Handling', () {
      test('should handle cache read errors', () async {
        // Arrange
        final event = EventData(
          eventId: 'test-event-id',
          eventCustomerId: 'test-user',
          eventType: EventType.track,
          sessionId: 'test-session',
          eventTimestamp: DateTime.now().millisecondsSinceEpoch,
          properties: {'action': 'test'},
        );
        when(mockCacheManager.get<String>(any))
            .thenThrow(Exception('Cache read error'));
        when(mockCacheManager.put(any, any))
            .thenThrow(Exception('Cache write error'));
        // Act
        final result =
            await EventRecoveryManager.recoverFromEventDeliveryFailure(
          event,
          failureReason: 'Test failure',
        );
        // Assert
        // EventRecoveryManager is designed to be resilient and returns success
        // even when cache operations fail (it logs errors but continues)
        expect(result.isSuccess, true);
      });
      test('should handle JSON parsing errors', () async {
        // Arrange
        when(mockCacheManager.get<String>('cf_offline_events'))
            .thenAnswer((_) async => 'invalid json');
        // Act
        final result = await EventRecoveryManager.recoverOfflineEvents(
          mockEventTracker,
        );
        // Assert
        // EventRecoveryManager is designed to be resilient and returns success
        // even when cache operations fail (it logs errors but continues)
        expect(result.isSuccess, true);
      });
    });
  });
  group('EventRecoveryStats Tests', () {
    test('should create stats with all fields', () {
      final now = DateTime.now();
      final stats = EventRecoveryStats(
        failedEventsCount: 10,
        offlineEventsCount: 5,
        oldestFailedEventTime: now.subtract(const Duration(days: 2)),
        oldestOfflineEventTime: now.subtract(const Duration(hours: 1)),
      );
      expect(stats.failedEventsCount, 10);
      expect(stats.offlineEventsCount, 5);
      expect(stats.oldestFailedEventTime, isNotNull);
      expect(stats.oldestOfflineEventTime, isNotNull);
    });
    test('should create stats with null dates', () {
      final stats = EventRecoveryStats(
        failedEventsCount: 0,
        offlineEventsCount: 0,
        oldestFailedEventTime: null,
        oldestOfflineEventTime: null,
      );
      expect(stats.failedEventsCount, 0);
      expect(stats.offlineEventsCount, 0);
      expect(stats.oldestFailedEventTime, isNull);
      expect(stats.oldestOfflineEventTime, isNull);
    });
    test('should format toString correctly', () {
      final stats = EventRecoveryStats(
        failedEventsCount: 3,
        offlineEventsCount: 2,
      );
      final str = stats.toString();
      expect(str, contains('failed: 3'));
      expect(str, contains('offline: 2'));
      expect(str, contains('EventRecoveryStats'));
    });
  });
}
