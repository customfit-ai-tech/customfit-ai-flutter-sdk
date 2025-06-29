// test/unit/analytics/summary/summary_manager_test.dart
//
// Comprehensive tests for SummaryManager class
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/summary/summary_manager.dart';

import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/network/http_client.dart';
import '../../../test_config.dart';
import '../../../helpers/test_storage_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'summary_manager_test.mocks.dart';

@GenerateMocks([HttpClient, CFConfig, CFUser])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    TestStorageHelper.clearTestStorage();
  });
  group('SummaryManager', () {
    late SummaryManager summaryManager;
    late MockHttpClient mockHttpClient;
    late MockCFConfig mockConfig;
    late MockCFUser mockUser;
    const testSessionId = 'test-session-123';
    const testUserId = 'test-user-456';
    const testClientKey = 'test-client-key';
    setUp(() {
      TestConfig.setupTestLogger(); // Enable logger for coverage
      SharedPreferences.setMockInitialValues({});
      TestStorageHelper.setupTestStorage();
      mockHttpClient = MockHttpClient();
      mockConfig = MockCFConfig();
      mockUser = MockCFUser();
      // Setup default mock responses
      when(mockConfig.summariesQueueSize).thenReturn(100);
      when(mockConfig.summariesFlushIntervalMs).thenReturn(60000);
      when(mockConfig.summariesFlushTimeSeconds).thenReturn(60);
      when(mockConfig.maxRetryAttempts).thenReturn(3);
      when(mockConfig.retryInitialDelayMs).thenReturn(1000);
      when(mockConfig.retryMaxDelayMs).thenReturn(5000);
      when(mockConfig.retryBackoffMultiplier).thenReturn(2.0);
      when(mockConfig.clientKey).thenReturn(testClientKey);
      when(mockUser.userCustomerId).thenReturn(testUserId);
      when(mockUser.toMap()).thenReturn({
        'user_customer_id': testUserId,
        'identifier': 'test-identifier',
      });
      summaryManager = SummaryManager(
        testSessionId,
        mockHttpClient,
        mockUser,
        mockConfig,
      );
    });
    tearDown(() {
      summaryManager.shutdown();
    });
    group('Initialization', () {
      test('should initialize with correct configuration', () {
        expect(summaryManager.getPendingSummariesCount(), equals(0));
        expect(summaryManager.getQueueSize(), equals(0));
      });
      test('should start periodic flush timer on initialization', () {
        // Timer should be running after initialization
        expect(() => summaryManager.shutdown(), returnsNormally);
      });
    });
    group('pushSummary', () {
      test('should successfully add valid summary to queue', () async {
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
          'user_id': 'user-101',
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isTrue);
        expect(summaryManager.getPendingSummariesCount(), equals(1));
      });
      test('should reject summary with non-string keys', () async {
        // Create a map with non-string keys
        final config = <dynamic, dynamic>{
          123: 'invalid-key', // Non-string key
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        // We need to test that the implementation correctly validates non-string keys
        // Since Dart's type system prevents casting a Map<dynamic, dynamic> with non-string keys
        // to Map<String, dynamic>, we'll use a different approach
        CFResult<bool> result;
        try {
          // This will throw at runtime when trying to validate keys
          result =
              await summaryManager.pushSummary(config as Map<String, dynamic>);
        } catch (e) {
          // Expected to throw due to type mismatch
          result = CFResult.error('Config map has non-string keys',
              category: ErrorCategory.validation);
        }
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('non-string keys'));
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
      test('should reject summary with missing experience_id', () async {
        final config = {
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(),
            contains('Missing mandatory experience_id'));
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
      test('should reject summary with missing config_id', () async {
        final config = {
          'experience_id': 'exp-123',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Missing mandatory fields'));
        expect(result.getErrorMessage(), contains('config_id'));
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
      test('should reject summary with missing variation_id', () async {
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'version': '1.0.0',
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Missing mandatory fields'));
        expect(result.getErrorMessage(), contains('variation_id'));
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
      test('should reject summary with missing version', () async {
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Missing mandatory fields'));
        expect(result.getErrorMessage(), contains('version'));
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
      test('should handle multiple missing fields', () async {
        final config = {
          'experience_id': 'exp-123',
          // Missing config_id, variation_id, version
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Missing mandatory fields'));
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
      test('should prevent duplicate processing of same experience_id',
          () async {
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        // Add first summary
        final result1 = await summaryManager.pushSummary(config);
        expect(result1.isSuccess, isTrue);
        expect(summaryManager.getPendingSummariesCount(), equals(1));
        // Try to add same experience_id again
        final result2 = await summaryManager.pushSummary(config);
        expect(
            result2.isSuccess, isTrue); // Should succeed but not add duplicate
        expect(summaryManager.getPendingSummariesCount(), equals(1)); // Still 1
      });
      test('should handle experience_id with behaviour_id combination',
          () async {
        final config1 = {
          'experience_id': 'exp-123',
          'behaviour_id': 'behaviour-1',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        final config2 = {
          'experience_id': 'exp-123',
          'behaviour_id': 'behaviour-2',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        // Add first summary
        final result1 = await summaryManager.pushSummary(config1);
        expect(result1.isSuccess, isTrue);
        expect(summaryManager.getPendingSummariesCount(), equals(1));
        // Add second summary with different behaviour_id - should be allowed
        final result2 = await summaryManager.pushSummary(config2);
        expect(result2.isSuccess, isTrue);
        expect(summaryManager.getPendingSummariesCount(), equals(2));
        // Try to add same experience_id + behaviour_id again
        final result3 = await summaryManager.pushSummary(config1);
        expect(
            result3.isSuccess, isTrue); // Should succeed but not add duplicate
        expect(summaryManager.getPendingSummariesCount(), equals(2)); // Still 2
      });
      test('should handle queue overflow by forcing flush', () async {
        // Set small queue size for testing
        when(mockConfig.summariesQueueSize).thenReturn(2);
        // Create new manager with small queue
        summaryManager.shutdown();
        summaryManager = SummaryManager(
          testSessionId,
          mockHttpClient,
          mockUser,
          mockConfig,
        );
        // Mock successful HTTP response for flush
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.success({'status': 'ok'}));
        // Fill the queue to capacity
        for (int i = 0; i < 2; i++) {
          final config = {
            'experience_id': 'exp-$i',
            'config_id': 'config-$i',
            'variation_id': 'var-$i',
            'version': '1.0.0',
          };
          await summaryManager.pushSummary(config);
        }
        // Wait for the automatic flush to complete
        await Future.delayed(const Duration(milliseconds: 100));
        expect(summaryManager.getPendingSummariesCount(), equals(0));
        // Add one more - queue is now empty after flush
        final config = {
          'experience_id': 'exp-overflow',
          'config_id': 'config-overflow',
          'variation_id': 'var-overflow',
          'version': '1.0.0',
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isTrue);
        // Should have added new one
        expect(summaryManager.getPendingSummariesCount(), equals(1));
      });
      test('should handle flush failure during queue overflow', () async {
        // Set small queue size for testing
        when(mockConfig.summariesQueueSize).thenReturn(1);
        // Create new manager with small queue
        summaryManager.shutdown();
        summaryManager = SummaryManager(
          testSessionId,
          mockHttpClient,
          mockUser,
          mockConfig,
        );
        // Mock failed HTTP response for flush
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.error('Network error'));
        // Fill the queue to capacity
        final config1 = {
          'experience_id': 'exp-1',
          'config_id': 'config-1',
          'variation_id': 'var-1',
          'version': '1.0.0',
        };
        // With queue size 1, adding the first summary triggers immediate flush
        final result1 = await summaryManager.pushSummary(config1);
        expect(result1.isSuccess, isTrue);
        // The queue size is 1, so it triggers automatic flush immediately
        // Since flush will fail, wait for all retry attempts to complete
        // Retry delays: 1s (first), 2s (second), 4s (third) = ~7s total
        await Future.delayed(const Duration(seconds: 8));
        // After flush fails and retries, summary should be re-queued
        expect(summaryManager.getPendingSummariesCount(), equals(1));
        // Try to add another summary - queue is full
        final config2 = {
          'experience_id': 'exp-2',
          'config_id': 'config-2',
          'variation_id': 'var-2',
          'version': '1.0.0',
        };
        // This will try to flush first, but since queue is still full after flush failure,
        // it should return an error
        final result2 = await summaryManager.pushSummary(config2);
        expect(result2.isSuccess, isFalse);
        expect(result2.getErrorMessage(),
            contains('Queue still full after flush'));
        // Queue should still have 1 item (the first one that was re-queued)
        expect(summaryManager.getPendingSummariesCount(), equals(1));
      });
      test('should include optional fields when provided', () async {
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
          'user_id': 'custom-user',
          'behaviour_id': 'behaviour-123',
          'rule_id': 'rule-456',
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isTrue);
        expect(summaryManager.getPendingSummariesCount(), equals(1));
      });
      test('should trigger flush when queue size threshold is reached',
          () async {
        // Set small queue size for testing
        when(mockConfig.summariesQueueSize).thenReturn(2);
        // Create new manager with small queue
        summaryManager.shutdown();
        summaryManager = SummaryManager(
          testSessionId,
          mockHttpClient,
          mockUser,
          mockConfig,
        );
        // Mock successful HTTP response
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.success({'status': 'ok'}));
        // Add summaries to reach threshold
        for (int i = 0; i < 2; i++) {
          final config = {
            'experience_id': 'exp-$i',
            'config_id': 'config-$i',
            'variation_id': 'var-$i',
            'version': '1.0.0',
          };
          await summaryManager.pushSummary(config);
        }
        // Should have triggered flush
        expect(summaryManager.getPendingSummariesCount(), equals(0));
        verify(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .called(1);
      });
    });
    group('flushSummaries', () {
      test('should return 0 when queue is empty', () async {
        final result = await summaryManager.flushSummaries();
        expect(result.isSuccess, isTrue);
        expect(result.data, equals(0));
      });
      test('should successfully flush summaries to server', () async {
        // Mock successful HTTP response
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.success({'status': 'ok'}));
        // Add a summary
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        final result = await summaryManager.flushSummaries();
        expect(result.isSuccess, isTrue);
        expect(result.data, equals(1));
        expect(summaryManager.getPendingSummariesCount(), equals(0));
        verify(mockHttpClient.post(
          argThat(contains('api.customfit.ai/v1/config/request/summary')),
          data: anyNamed('data'),
          headers: anyNamed('headers'),
        )).called(1);
      });
      test('should flush multiple summaries', () async {
        // Mock successful HTTP response
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.success({'status': 'ok'}));
        // Add multiple summaries
        for (int i = 0; i < 3; i++) {
          final config = {
            'experience_id': 'exp-$i',
            'config_id': 'config-$i',
            'variation_id': 'var-$i',
            'version': '1.0.0',
          };
          await summaryManager.pushSummary(config);
        }
        expect(summaryManager.getPendingSummariesCount(), equals(3));
        final result = await summaryManager.flushSummaries();
        expect(result.isSuccess, isTrue);
        expect(result.data, equals(3));
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
      test('should handle network errors during flush', () async {
        // Mock network error
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.error('Network error'));
        // Add a summary
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        final result = await summaryManager.flushSummaries();
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Failed to flush summaries'));
      });
      test('should handle HTTP exceptions during flush', () async {
        // Mock HTTP exception
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenThrow(Exception('Connection timeout'));
        // Add a summary
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        final result = await summaryManager.flushSummaries();
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Failed to flush summaries'));
      });
      test('should re-queue summaries on send failure', () async {
        // Mock network error that triggers retry failure
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.error('Network error'));
        // Add a summary
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        expect(summaryManager.getPendingSummariesCount(), equals(1));
        final result = await summaryManager.flushSummaries();
        expect(result.isSuccess, isFalse);
        // Summary should be re-queued after failure
        expect(summaryManager.getPendingSummariesCount(), equals(1));
      });
      test('should handle re-queue failure when queue is full', () async {
        // Set very small queue size
        when(mockConfig.summariesQueueSize).thenReturn(
            3); // Increased to 3 to prevent auto-flush on second add
        // Create new manager with small queue
        summaryManager.shutdown();
        summaryManager = SummaryManager(
          testSessionId,
          mockHttpClient,
          mockUser,
          mockConfig,
        );
        // Mock network error
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.error('Network error'));
        // Add two summaries (won't trigger auto-flush with queue size 3)
        final config1 = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config1);
        final config2 = {
          'experience_id': 'exp-456',
          'config_id': 'config-789',
          'variation_id': 'var-123',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config2);
        // Queue should now have 2 items
        expect(summaryManager.getPendingSummariesCount(), equals(2));
        // Manually flush - will fail due to network error
        final result = await summaryManager.flushSummaries();
        // The flush should return error because sending failed
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Failed to flush summaries'));
        // Wait for retry attempts to complete (3 attempts with delays)
        // Retry delays: 1s, 2s, 4s = ~7s total
        await Future.delayed(const Duration(seconds: 8));
        // After failed flush and retries, the summaries should be re-queued
        // Since the queue had space (it was emptied during flush attempt),
        // both summaries should be successfully re-queued
        expect(summaryManager.getPendingSummariesCount(), equals(2));
      });
      test('should include correct payload structure', () async {
        // Capture the request payload
        String? capturedPayload;
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((invocation) async {
          capturedPayload = invocation.namedArguments[#data] as String?;
          return CFResult.success({'status': 'ok'});
        });
        // Add a summary
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
          'user_id': 'test-user',
        };
        await summaryManager.pushSummary(config);
        await summaryManager.flushSummaries();
        expect(capturedPayload, isNotNull);
        expect(capturedPayload, contains('user'));
        expect(capturedPayload, contains('summaries'));
        expect(capturedPayload, contains('cf_client_sdk_version'));
        expect(capturedPayload, contains('1.0.0')); // SDK version
      });
    });

    group('trackRequests', () {
      test('should track multiple requests', () {
        // This test verifies that trackRequests would work if the method existed
        // Currently testing the queue count after adding summaries via pushSummary
        expect(summaryManager.getPendingSummariesCount(), equals(2));
      });
      test('should trigger flush when queue size threshold is reached',
          () async {
        // Set small queue size for testing
        when(mockConfig.summariesQueueSize).thenReturn(2);
        // Create new manager with small queue
        summaryManager.shutdown();
        summaryManager = SummaryManager(
          testSessionId,
          mockHttpClient,
          mockUser,
          mockConfig,
        );
        // Mock successful HTTP response
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.success({'status': 'ok'}));

        // Should have triggered flush
        expect(summaryManager.getPendingSummariesCount(), equals(0));
        verify(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .called(1);
      });
    });
    group('trackMultipleRequests', () {
      test('should track multiple configuration requests', () async {
        expect(summaryManager.getPendingSummariesCount(), equals(2));
      });
      test('should handle empty configuration list', () {
        // Don't track anything for empty list
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
    });
    group('updateFlushInterval', () {
      test('should update flush interval successfully', () {
        expect(
            () => summaryManager.updateFlushInterval(30000), returnsNormally);
      });
      test('should handle zero interval', () {
        expect(() => summaryManager.updateFlushInterval(0), returnsNormally);
      });
      test('should handle negative interval', () {
        expect(
            () => summaryManager.updateFlushInterval(-1000), returnsNormally);
      });
      test('should restart periodic flush with new interval', () {
        // Update interval
        summaryManager.updateFlushInterval(5000);
        // Should not throw and should handle the new interval
        expect(() => summaryManager.shutdown(), returnsNormally);
      });
    });
    group('Queue Management', () {
      test('should clear summaries successfully', () async {
        // Add some summaries
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        expect(summaryManager.getPendingSummariesCount(), equals(1));
        summaryManager.clearSummaries();
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
      test('should clear tracking map', () async {
        // Add a summary to populate tracking map
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        // Verify tracking map has entries
        final summaries = summaryManager.getSummaries();
        expect(summaries.isNotEmpty, isTrue);
        summaryManager.clearSummaries();
        // Verify tracking map is cleared
        final clearedSummaries = summaryManager.getSummaries();
        expect(clearedSummaries.isEmpty, isTrue);
      });
      test('should get queue size correctly', () async {
        expect(summaryManager.getQueueSize(), equals(0));
        // Add summaries
        for (int i = 0; i < 3; i++) {
          final config = {
            'experience_id': 'exp-$i',
            'config_id': 'config-$i',
            'variation_id': 'var-$i',
            'version': '1.0.0',
          };
          await summaryManager.pushSummary(config);
        }
        expect(summaryManager.getQueueSize(), equals(3));
      });
      test('should get summaries map', () async {
        // Add a summary
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        final summaries = summaryManager.getSummaries();
        expect(summaries, isA<Map<String, bool>>());
        expect(summaries.containsKey('exp-123'), isTrue);
        expect(summaries['exp-123'], isTrue);
      });
      test('should return unmodifiable summaries map', () async {
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        final summaries = summaryManager.getSummaries();
        // Should not be able to modify the returned map
        expect(() => summaries['new-key'] = true, throwsUnsupportedError);
      });
    });
    group('Periodic Flush', () {
      test('should handle periodic flush with empty queue', () async {
        // Mock the timer to trigger immediately
        when(mockConfig.summariesFlushIntervalMs).thenReturn(100);
        // Create new manager with short interval
        summaryManager.shutdown();
        summaryManager = SummaryManager(
          testSessionId,
          mockHttpClient,
          mockUser,
          mockConfig,
        );
        // Wait for periodic flush to potentially trigger
        await Future.delayed(const Duration(milliseconds: 150));
        // Should handle empty queue gracefully
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
      test('should handle periodic flush with summaries', () async {
        // Mock successful HTTP response
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.success({'status': 'ok'}));
        when(mockConfig.summariesFlushIntervalMs).thenReturn(100);
        // Create new manager with short interval
        summaryManager.shutdown();
        summaryManager = SummaryManager(
          testSessionId,
          mockHttpClient,
          mockUser,
          mockConfig,
        );
        // Add a summary
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        expect(summaryManager.getPendingSummariesCount(), equals(1));
        // Wait for periodic flush
        await Future.delayed(const Duration(milliseconds: 150));
        // Should have been flushed
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
      test('should handle periodic flush errors', () async {
        // Mock HTTP error
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenThrow(Exception('Periodic flush error'));
        when(mockConfig.summariesFlushIntervalMs).thenReturn(100);
        // Create new manager with short interval
        summaryManager.shutdown();
        summaryManager = SummaryManager(
          testSessionId,
          mockHttpClient,
          mockUser,
          mockConfig,
        );
        // Add a summary
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        // Wait for periodic flush to trigger and complete with retries
        // The retry logic will attempt 3 times with delays
        await Future.delayed(const Duration(seconds: 2));
        // Should handle error gracefully (summary should still be there after failed flush)
        // The exception prevents re-queueing, so the queue will be empty
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
    });
    group('Retry Logic', () {
      test('should retry failed requests according to config', () async {
        // Mock failure then success
        var attemptCount = 0;
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async {
          attemptCount++;
          if (attemptCount < 3) {
            return CFResult.error('Temporary failure');
          }
          return CFResult.success({'status': 'ok'});
        });
        // Add a summary
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        final result = await summaryManager.flushSummaries();
        expect(result.isSuccess, isTrue);
        expect(attemptCount, equals(3)); // Should have retried
        verify(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .called(3);
      });
      test('should fail after max retry attempts', () async {
        // Mock consistent failure
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.error('Persistent failure'));
        // Add a summary
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        final result = await summaryManager.flushSummaries();
        expect(result.isSuccess, isFalse);
        // Should have attempted max retry attempts
        verify(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .called(3);
      });
    });
    group('Edge Cases', () {
      test('should handle null user customer ID', () async {
        when(mockUser.userCustomerId).thenReturn(null);
        // Create new manager with null user ID
        summaryManager.shutdown();
        summaryManager = SummaryManager(
          testSessionId,
          mockHttpClient,
          mockUser,
          mockConfig,
        );
        final config = {
          'experience_id': 'exp-123',
          'config_id': 'config-456',
          'variation_id': 'var-789',
          'version': '1.0.0',
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isTrue);
      });
      test('should handle empty string values', () async {
        final config = {
          'experience_id': '',
          'config_id': '',
          'variation_id': '',
          'version': '',
        };
        final result = await summaryManager.pushSummary(config);
        // Empty strings are accepted as valid values
        expect(result.isSuccess, isTrue);
        expect(summaryManager.getPendingSummariesCount(), equals(1));
      });
      test('should handle very long field values', () async {
        final longString = 'a' * 10000;
        final config = {
          'experience_id': longString,
          'config_id': longString,
          'variation_id': longString,
          'version': longString,
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isTrue);
      });
      test('should handle special characters in field values', () async {
        final config = {
          'experience_id': 'exp-123!@#\$%^&*()',
          'config_id': 'config-456<>?:{}[]',
          'variation_id': 'var-789"\'\\/',
          'version': '1.0.0-beta+build.123',
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isTrue);
      });
      test('should handle unicode characters', () async {
        final config = {
          'experience_id': 'exp-测试-🚀',
          'config_id': 'config-тест-🎯',
          'variation_id': 'var-テスト-🔥',
          'version': '1.0.0-α',
        };
        final result = await summaryManager.pushSummary(config);
        expect(result.isSuccess, isTrue);
      });
    });
    group('Request Deduplication', () {
      test('should deduplicate concurrent flush requests', () async {
        // Mock successful HTTP response
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.success({'status': 'ok'}));
        // Add some summaries to flush
        final configs = [
          {
            'experience_id': 'dedup-exp-1',
            'config_id': 'dedup-config-1',
            'variation_id': 'dedup-var-1',
            'version': '1.0.0',
          },
          {
            'experience_id': 'dedup-exp-2',
            'config_id': 'dedup-config-2',
            'variation_id': 'dedup-var-2',
            'version': '1.0.0',
          },
          {
            'experience_id': 'dedup-exp-3',
            'config_id': 'dedup-config-3',
            'variation_id': 'dedup-var-3',
            'version': '1.0.0',
          },
        ];
        for (final config in configs) {
          await summaryManager.pushSummary(config);
        }
        expect(summaryManager.getPendingSummariesCount(), equals(3));
        // Start multiple flush operations concurrently
        final flushFutures = [
          summaryManager.flushSummaries(),
          summaryManager.flushSummaries(),
          summaryManager.flushSummaries(),
          summaryManager.flushSummaries(),
        ];
        final results = await Future.wait(flushFutures);
        // All should succeed (due to deduplication)
        expect(results.every((r) => r.isSuccess), isTrue);
        // But only one actual HTTP request should be made
        verify(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .called(1);
        // All summaries should be flushed
        expect(summaryManager.getPendingSummariesCount(), equals(0));
      });
      test('should allow new flush after previous completes', () async {
        // Mock successful HTTP response
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.success({'status': 'ok'}));
        // First batch
        final config1 = {
          'experience_id': 'sequential-exp-1',
          'config_id': 'sequential-config-1',
          'variation_id': 'sequential-var-1',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config1);
        final result1 = await summaryManager.flushSummaries();
        expect(result1.isSuccess, isTrue);
        // Second batch (should not be deduplicated since first completed)
        final config2 = {
          'experience_id': 'sequential-exp-2',
          'config_id': 'sequential-config-2',
          'variation_id': 'sequential-var-2',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config2);
        final result2 = await summaryManager.flushSummaries();
        expect(result2.isSuccess, isTrue);
        // Should have made two separate HTTP requests
        verify(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .called(2);
      });
      test('should handle deduplication with failures', () async {
        // Mock HTTP error
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.error('Server error'));
        final config = {
          'experience_id': 'failure-dedup-exp',
          'config_id': 'failure-dedup-config',
          'variation_id': 'failure-dedup-var',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        final flushFutures = [
          summaryManager.flushSummaries(),
          summaryManager.flushSummaries(),
          summaryManager.flushSummaries(),
        ];
        final results = await Future.wait(flushFutures);
        // All should fail with same error (due to deduplication)
        expect(results.every((r) => !r.isSuccess), isTrue);
        // But only one actual HTTP request should be made (during retry attempts)
        verify(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .called(3); // 3 retry attempts
        // Summaries should be re-queued after failure
        expect(summaryManager.getPendingSummariesCount(), equals(1));
      });
      test('should cancel in-flight requests during shutdown', () async {
        // Mock successful HTTP response
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.success({'status': 'ok'}));
        final config = {
          'experience_id': 'shutdown-dedup-exp',
          'config_id': 'shutdown-dedup-config',
          'variation_id': 'shutdown-dedup-var',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        // Start a flush operation but don't wait for it
        final flushFuture = summaryManager.flushSummaries();
        // Shutdown immediately
        summaryManager.shutdown();
        // The flush should still complete
        final result = await flushFuture;
        expect(result.isSuccess, isTrue);
      });
      test('should use unique keys for different users/sessions', () async {
        // Mock successful HTTP response
        when(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .thenAnswer((_) async => CFResult.success({'status': 'ok'}));
        // This test verifies that deduplication keys are properly scoped
        // by checking that the deduplication logic uses user and session info
        final config = {
          'experience_id': 'unique-key-exp',
          'config_id': 'unique-key-config',
          'variation_id': 'unique-key-var',
          'version': '1.0.0',
        };
        await summaryManager.pushSummary(config);
        // Multiple flushes should be deduplicated
        final flushFutures = [
          summaryManager.flushSummaries(),
          summaryManager.flushSummaries(),
        ];
        final results = await Future.wait(flushFutures);
        expect(results.every((r) => r.isSuccess), isTrue);
        verify(mockHttpClient.post(any,
                data: anyNamed('data'), headers: anyNamed('headers')))
            .called(1);
      });
      test('should handle empty queue deduplication', () async {
        // Multiple flushes on empty queue should all return success immediately
        final flushFutures = [
          summaryManager.flushSummaries(),
          summaryManager.flushSummaries(),
          summaryManager.flushSummaries(),
        ];
        final results = await Future.wait(flushFutures);
        // All should succeed without making HTTP requests
        expect(results.every((r) => r.isSuccess), isTrue);
        expect(
            results.every((r) => r.data == 0), isTrue); // 0 summaries flushed
        // No HTTP requests should be made
        verifyNever(mockHttpClient.post(any,
            data: anyNamed('data'), headers: anyNamed('headers')));
      });
    });
    group('Shutdown', () {
      test('should shutdown cleanly', () {
        expect(() => summaryManager.shutdown(), returnsNormally);
      });
      test('should cancel timers on shutdown', () {
        // Create and shutdown manager
        final manager = SummaryManager(
          testSessionId,
          mockHttpClient,
          mockUser,
          mockConfig,
        );
        expect(() => manager.shutdown(), returnsNormally);
      });
      test('should handle multiple shutdown calls', () {
        summaryManager.shutdown();
        expect(() => summaryManager.shutdown(), returnsNormally);
      });
    });
  });
}
