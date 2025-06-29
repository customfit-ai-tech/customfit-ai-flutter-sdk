// test/unit/client/cf_client_events_test.dart
//
// Comprehensive tests for CFClientEvents class to achieve 80%+ coverage
// Tests all event tracking methods, error handling, and edge cases
// Also includes additional tests for lifecycle events, flush, and method chaining
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:customfit_ai_flutter_sdk/src/client/cf_client_events.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_tracker.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import '../../utils/test_constants.dart';
import '../../helpers/test_storage_helper.dart';
import '../../test_config.dart';
@GenerateMocks([EventTracker])
import 'cf_client_events_test.mocks.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestConfig.setupTestLogger(); // Enable logger for coverage
    SharedPreferences.setMockInitialValues({});
    TestStorageHelper.setupTestStorage();
  });
  tearDown(() {
    TestStorageHelper.clearTestStorage();
  });
  group('CFClientEvents', () {
    late CFClientEvents eventsComponent;
    late MockEventTracker mockEventTracker;
    late CFConfig testConfig;
    late CFUser testUser;
    late String testSessionId;
    setUp(() {
      mockEventTracker = MockEventTracker();
      testSessionId = 'test-session-123';
      testConfig = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(true)
          .setOfflineMode(false)
          .build().getOrThrow();
      testUser = CFUser.builder('test-user-123')
          .addStringProperty('test_key', 'test_value')
          .build().getOrThrow();
      eventsComponent = CFClientEvents(
        config: testConfig,
        user: testUser,
        eventTracker: mockEventTracker,
        sessionId: testSessionId,
      );
    });
    group('Constructor', () {
      test('should create instance with all required parameters', () {
        expect(eventsComponent, isNotNull);
      });
    });
    group('trackEvent', () {
      test('should track simple event successfully', () async {
        // Arrange
        const eventName = 'button_clicked';
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult<void>.success(null),
        );
        // Act
        final result = await eventsComponent.trackEvent(eventName);
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.data, isTrue);
        verify(mockEventTracker
            .trackEvent(eventName, {'event_name': eventName})).called(1);
      });
      test('should handle empty event name', () async {
        // Act
        final result = await eventsComponent.trackEvent('');
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), equals('Event name cannot be empty'));
        verifyNever(mockEventTracker.trackEvent(any, any));
      });
      test('should handle whitespace-only event name', () async {
        // Act
        final result = await eventsComponent.trackEvent('   ');
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), equals('Event name cannot be empty'));
        verifyNever(mockEventTracker.trackEvent(any, any));
      });
      test('should handle event tracker failure', () async {
        // Arrange
        const eventName = 'failed_event';
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult.error('Network error'),
        );
        // Act
        final result = await eventsComponent.trackEvent(eventName);
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Failed to track event'));
        expect(result.getErrorMessage(), contains('Network error'));
      });
      test('should handle event tracker exception', () async {
        // Arrange
        const eventName = 'exception_event';
        when(mockEventTracker.trackEvent(any, any))
            .thenThrow(Exception('Unexpected error'));
        // Act
        final result = await eventsComponent.trackEvent(eventName);
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Error tracking event'));
        expect(result.getErrorMessage(), contains('Unexpected error'));
      });
    });
    group('trackEventWithProperties', () {
      test('should track event with properties successfully', () async {
        // Arrange
        const eventName = 'purchase_completed';
        final properties = {
          'product_id': 'prod_123',
          'amount': 99.99,
          'currency': 'USD',
        };
        final expectedProperties = {
          ...properties,
          'event_name': eventName,
        };
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult<void>.success(null),
        );
        // Act
        final result = await eventsComponent.trackEventWithProperties(
            eventName, properties);
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.data, isTrue);
        verify(mockEventTracker.trackEvent(eventName, expectedProperties))
            .called(1);
      });
      test('should track event with empty properties', () async {
        // Arrange
        const eventName = 'simple_event';
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult<void>.success(null),
        );
        // Act
        final result =
            await eventsComponent.trackEventWithProperties(eventName, {});
        // Assert
        expect(result.isSuccess, isTrue);
        verify(mockEventTracker
            .trackEvent(eventName, {'event_name': eventName})).called(1);
      });
      test('should handle empty event name with properties', () async {
        // Act
        final result = await eventsComponent
            .trackEventWithProperties('', {'prop': 'value'});
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), equals('Event name cannot be empty'));
        verifyNever(mockEventTracker.trackEvent(any, any));
      });
      test('should handle event tracker failure with properties', () async {
        // Arrange
        const eventName = 'failed_event';
        final properties = {'test': 'value'};
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult.error('Tracking failed'),
        );
        // Act
        final result = await eventsComponent.trackEventWithProperties(
            eventName, properties);
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Failed to track event'));
        expect(result.getErrorMessage(), contains('Tracking failed'));
      });
    });
    group('trackConversion', () {
      test('should track conversion successfully', () async {
        // Arrange
        const conversionName = 'signup_completed';
        final properties = {
          'plan_type': 'premium',
          'signup_source': 'landing_page',
        };
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult<void>.success(null),
        );
        // Act
        final result =
            await eventsComponent.trackConversion(conversionName, properties);
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.data, isTrue);
        // Verify the conversion event was tracked with correct properties
        final captured = verify(mockEventTracker.trackEvent(
                'conversion_$conversionName', captureAny))
            .captured;
        final trackedProperties = captured[0] as Map<String, dynamic>;
        expect(trackedProperties['plan_type'], equals('premium'));
        expect(trackedProperties['signup_source'], equals('landing_page'));
        expect(trackedProperties['_is_conversion'], isTrue);
        expect(trackedProperties['_conversion_type'], equals(conversionName));
        expect(trackedProperties['_tracked_at'], isNotNull);
        expect(trackedProperties['event_name'],
            equals('conversion_$conversionName'));
      });
      test('should handle conversion tracking failure', () async {
        // Arrange
        const conversionName = 'failed_conversion';
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult.error('Conversion failed'),
        );
        // Act
        final result =
            await eventsComponent.trackConversion(conversionName, {});
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Failed to track event'));
        expect(result.getErrorMessage(), contains('Conversion failed'));
      });
      test('should handle trackConversion exception', () async {
        // Arrange
        const conversionName = 'exception_conversion';
        when(mockEventTracker.trackEvent(any, any))
            .thenThrow(Exception('Conversion exception'));
        // Act
        final result = await eventsComponent
            .trackConversion(conversionName, {'value': 100});
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(),
            contains('Error tracking event "conversion_exception_conversion"'));
        expect(result.getErrorMessage(), contains('Conversion exception'));
      });
    });
    group('trackUserPropertyChange', () {
      test('should track user property change successfully', () async {
        // Arrange
        const propertyName = 'plan_upgraded';
        final changeDetails = {
          'old_plan': 'basic',
          'new_plan': 'premium',
          'upgrade_reason': 'feature_limit_reached',
        };
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult<void>.success(null),
        );
        // Act
        final result = await eventsComponent.trackUserPropertyChange(
            propertyName, changeDetails);
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.data, isTrue);
        final captured = verify(mockEventTracker.trackEvent(
                'user_property_changed', captureAny))
            .captured;
        final trackedProperties = captured[0] as Map<String, dynamic>;
        expect(trackedProperties['old_plan'], equals('basic'));
        expect(trackedProperties['new_plan'], equals('premium'));
        expect(trackedProperties['upgrade_reason'],
            equals('feature_limit_reached'));
        expect(trackedProperties['_property_name'], equals(propertyName));
        expect(trackedProperties['_user_id'], equals(testUser.userCustomerId));
        expect(trackedProperties['_session_id'], equals(testSessionId));
        expect(
            trackedProperties['event_name'], equals('user_property_changed'));
      });
      test('should handle user property change tracking failure', () async {
        // Arrange
        const propertyName = 'failed_change';
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult.error('Property change failed'),
        );
        // Act
        final result =
            await eventsComponent.trackUserPropertyChange(propertyName, {});
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Failed to track event'));
        expect(result.getErrorMessage(), contains('Property change failed'));
      });
      test('should handle trackUserPropertyChange exception', () async {
        // Arrange
        const propertyName = 'exception_property';
        when(mockEventTracker.trackEvent(any, any))
            .thenThrow(Exception('Property change exception'));
        // Act
        final result = await eventsComponent.trackUserPropertyChange(
            propertyName, {'old': 'value1', 'new': 'value2'});
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(),
            contains('Error tracking event "user_property_changed"'));
        expect(result.getErrorMessage(), contains('Property change exception'));
      });
    });
    group('trackLifecycleEvent', () {
      test('should track lifecycle event successfully', () async {
        // Arrange
        const lifecycleEvent = 'app_launched';
        final context = {
          'launch_time': DateTime.now().toIso8601String(),
          'cold_start': true,
        };
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult<void>.success(null),
        );
        // Act
        final result =
            await eventsComponent.trackLifecycleEvent(lifecycleEvent, context);
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.data, isTrue);
        final captured =
            verify(mockEventTracker.trackEvent('app_lifecycle', captureAny))
                .captured;
        final trackedProperties = captured[0] as Map<String, dynamic>;
        expect(trackedProperties['_lifecycle_event'], equals(lifecycleEvent));
        expect(trackedProperties['launch_time'], isNotNull);
        expect(trackedProperties['cold_start'], isTrue);
        expect(trackedProperties['_app_version'], equals('unknown'));
        expect(trackedProperties['_platform'], equals('flutter'));
      });
      test('should handle lifecycle event tracking failure', () async {
        // Arrange
        const lifecycleEvent = 'app_background';
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
            (_) async => CFResult.error('Lifecycle tracking failed'));
        // Act
        final result =
            await eventsComponent.trackLifecycleEvent(lifecycleEvent, {});
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Failed to track event'));
        expect(result.getErrorMessage(), contains('Lifecycle tracking failed'));
      });
      test('should handle lifecycle event tracking exception', () async {
        // Arrange
        const lifecycleEvent = 'app_foreground';
        when(mockEventTracker.trackEvent(any, any))
            .thenThrow(Exception('Lifecycle exception'));
        // Act
        final result = await eventsComponent.trackLifecycleEvent(
            lifecycleEvent, {'timestamp': DateTime.now().toIso8601String()});
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(),
            contains('Error tracking event "app_lifecycle"'));
        expect(result.getErrorMessage(), contains('Lifecycle exception'));
      });
    });
    group('flushEvents', () {
      test('should flush events successfully', () async {
        // Arrange
        when(mockEventTracker.flush()).thenAnswer(
          (_) async => CFResult.success(true),
        );
        // Act
        final result = await eventsComponent.flushEvents();
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.data, isTrue);
        verify(mockEventTracker.flush()).called(1);
      });
      test('should handle flush failure', () async {
        // Arrange
        when(mockEventTracker.flush())
            .thenAnswer((_) async => CFResult.error('Flush failed'));
        // Act
        final result = await eventsComponent.flushEvents();
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Failed to flush events'));
        expect(result.getErrorMessage(), contains('Flush failed'));
      });
      test('should handle flush exception', () async {
        // Arrange
        when(mockEventTracker.flush())
            .thenThrow(Exception('Network error during flush'));
        // Act
        final result = await eventsComponent.flushEvents();
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Error flushing events'));
        expect(
            result.getErrorMessage(), contains('Network error during flush'));
      });
    });
    group('getPendingEventCount', () {
      test('should return pending event count', () {
        // Arrange
        const expectedCount = 42;
        when(mockEventTracker.getPendingEventsCount())
            .thenReturn(expectedCount);
        // Act
        final count = eventsComponent.getPendingEventCount();
        // Assert
        expect(count, equals(expectedCount));
        verify(mockEventTracker.getPendingEventsCount()).called(1);
      });
      test('should return 0 on exception', () {
        // Arrange
        when(mockEventTracker.getPendingEventsCount())
            .thenThrow(Exception('Count error'));
        // Act
        final count = eventsComponent.getPendingEventCount();
        // Assert
        expect(count, equals(0));
      });
    });
    group('Method chaining and fluent API', () {
      test('should enable method chaining', () {
        // Act
        final result = eventsComponent.enableMethodChaining();
        // Assert
        expect(result, equals(eventsComponent));
        expect(result, isA<CFClientEvents>());
      });
      test('should add user property and return self', () {
        // Act
        final result = eventsComponent.addUserProperty('page', 'checkout');
        // Assert
        expect(result, equals(eventsComponent));
        expect(result, isA<CFClientEvents>());
      });
      test('should handle user property addition exception', () {
        // This test verifies the catch block in addUserProperty
        // Since we can't easily mock the internal implementation,
        // we're testing that the method still returns self even on error
        final result = eventsComponent.addUserProperty(
            'very_long_key_' * 100, // Very long key
            {
              'nested': {
                'deeply': {'nested': 'value'}
              }
            });
        // Assert - should still return self
        expect(result, equals(eventsComponent));
        expect(result, isA<CFClientEvents>());
      });
      test('should support fluent API chaining', () async {
        // Arrange
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult<void>.success(null),
        );
        // Act - test method chaining
        final chainResult = eventsComponent
            .addUserProperty('theme', 'dark')
            .addUserProperty('language', 'en')
            .enableMethodChaining();
        // Assert
        expect(chainResult, equals(eventsComponent));
        // Verify we can still track events after chaining
        final trackResult = await eventsComponent.trackEvent('chained_event');
        expect(trackResult.isSuccess, isTrue);
      });
    });
    group('Edge Cases and Error Handling', () {
      test('should handle very long event names', () async {
        // Arrange
        final longEventName = 'a' * 1000; // Very long event name
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult<void>.success(null),
        );
        // Act
        final result = await eventsComponent.trackEvent(longEventName);
        // Assert
        expect(result.isSuccess, isTrue);
        verify(mockEventTracker.trackEvent(longEventName, any)).called(1);
      });
      test('should handle special characters in event names', () async {
        // Arrange
        const specialEventName = 'event-with_special.chars@123!';
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult<void>.success(null),
        );
        // Act
        final result = await eventsComponent.trackEvent(specialEventName);
        // Assert
        expect(result.isSuccess, isTrue);
        verify(mockEventTracker.trackEvent(specialEventName, any)).called(1);
      });
      test('should handle null values in properties', () async {
        // Arrange
        const eventName = 'null_properties_event';
        final propertiesWithNull = {
          'valid_property': 'value',
          'null_property': null,
          'empty_string': '',
          'zero_number': 0,
          'false_boolean': false,
        };
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult<void>.success(null),
        );
        // Act
        final result = await eventsComponent.trackEventWithProperties(
            eventName, propertiesWithNull);
        // Assert
        expect(result.isSuccess, isTrue);
        final captured =
            verify(mockEventTracker.trackEvent(eventName, captureAny)).captured;
        final trackedProperties = captured[0] as Map<String, dynamic>;
        expect(trackedProperties['valid_property'], equals('value'));
        expect(trackedProperties['null_property'], isNull);
        expect(trackedProperties['empty_string'], equals(''));
        expect(trackedProperties['zero_number'], equals(0));
        expect(trackedProperties['false_boolean'], isFalse);
      });
    });
    group('Integration scenarios', () {
      test('should handle multiple lifecycle events in sequence', () async {
        // Arrange
        final events = ['app_launched', 'app_background', 'app_foreground'];
        when(mockEventTracker.trackEvent(any, any))
            .thenAnswer((_) async => CFResult<void>.success(null));
        // Act
        final results = <CFResult<bool>>[];
        for (final event in events) {
          results.add(await eventsComponent.trackLifecycleEvent(event, {}));
        }
        // Assert
        expect(results.every((r) => r.isSuccess), isTrue);
        verify(mockEventTracker.trackEvent('app_lifecycle', any)).called(3);
      });
      test('should handle flush after multiple events', () async {
        // Arrange
        when(mockEventTracker.trackEvent(any, any)).thenAnswer(
          (_) async => CFResult<void>.success(null),
        );
        when(mockEventTracker.flush()).thenAnswer(
          (_) async => CFResult.success(true),
        );
        when(mockEventTracker.getPendingEventsCount()).thenReturn(5);
        // Act
        await eventsComponent.trackEvent('event1');
        await eventsComponent.trackEvent('event2');
        await eventsComponent.trackEvent('event3');
        final countBefore = eventsComponent.getPendingEventCount();
        final flushResult = await eventsComponent.flushEvents();
        // Mock returns 0 after flush
        when(mockEventTracker.getPendingEventsCount()).thenReturn(0);
        final countAfter = eventsComponent.getPendingEventCount();
        // Assert
        expect(countBefore, equals(5));
        expect(flushResult.isSuccess, isTrue);
        expect(countAfter, equals(0));
      });
    });
  });
}
