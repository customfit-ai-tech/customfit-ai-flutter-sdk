// test/unit/core/error/event_recovery_manager_test.dart
//
// Simplified tests for EventRecoveryManager after SDK simplification
// Tests basic event recovery functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/recovery_managers.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_tracker.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([EventTracker])
import 'event_recovery_manager_test.mocks.dart';

void main() {
  group('EventRecoveryManager (Simplified)', () {
    late MockEventTracker mockEventTracker;

    setUp(() {
      mockEventTracker = MockEventTracker();
    });

    group('getRecoveryStats', () {
      test('should return recovery stats', () async {
        final stats = await EventRecoveryManager.getRecoveryStats();

        expect(stats, isNotNull);
        expect(stats.failedEventsCount, isA<int>());
        expect(stats.offlineEventsCount, isA<int>());
        expect(stats.failedEventsCount, greaterThanOrEqualTo(0));
        expect(stats.offlineEventsCount, greaterThanOrEqualTo(0));
      });
    });

    group('cleanupOldFailedEvents', () {
      test('should cleanup old failed events', () async {
        final result = await EventRecoveryManager.cleanupOldFailedEvents();

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), isA<int>());
        expect(result.getOrNull(), greaterThanOrEqualTo(0));
      });
    });

    group('recoverOfflineEvents', () {
      test('should handle offline events recovery', () async {
        when(mockEventTracker.flushEvents())
            .thenAnswer((_) async => CFResult.success(true));

        final result = await EventRecoveryManager.recoverOfflineEvents(mockEventTracker);

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), isA<int>());
      });

      test('should handle offline events recovery failure', () async {
        when(mockEventTracker.flushEvents())
            .thenAnswer((_) async => CFResult.error('Flush failed'));

        final result = await EventRecoveryManager.recoverOfflineEvents(mockEventTracker);

        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Flush failed'));
      });
    });

    group('retryFailedEvents', () {
      test('should retry failed events', () async {
        when(mockEventTracker.flushEvents())
            .thenAnswer((_) async => CFResult.success(true));

        final result = await EventRecoveryManager.retryFailedEvents(
          mockEventTracker,
          maxEventsToRetry: 10,
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), isA<int>());
      });

      test('should handle retry failure', () async {
        when(mockEventTracker.flushEvents())
            .thenAnswer((_) async => CFResult.error('Retry failed'));

        final result = await EventRecoveryManager.retryFailedEvents(
          mockEventTracker,
          maxEventsToRetry: 5,
        );

        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Retry failed'));
      });
    });
  });
}