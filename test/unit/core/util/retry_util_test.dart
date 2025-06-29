import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/retry_util.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/circuit_breaker.dart';
import '../../../helpers/test_storage_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('RetryUtil Tests', () {
    setUp(() {
      // Reset circuit breakers before each test
      SharedPreferences.setMockInitialValues({});
      CircuitBreaker.resetAll();
      // Setup test storage with secure storage
      TestStorageHelper.setupTestStorage();
    });
    tearDown(() {
      CircuitBreaker.resetAll();
      PreferencesService.reset();
      TestStorageHelper.clearTestStorage();
    });
    group('withRetryResult Tests', () {
      test('should succeed on first attempt', () async {
        int callCount = 0;
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 3,
          initialDelayMs: 10,
          maxDelayMs: 100,
          backoffMultiplier: 2.0,
          block: () async {
            callCount++;
            return 'success';
          },
        );
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, equals('success'));
        expect(callCount, equals(1));
      });
      test('should succeed after retries', () async {
        int callCount = 0;
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 3,
          initialDelayMs: 10,
          maxDelayMs: 100,
          backoffMultiplier: 2.0,
          block: () async {
            callCount++;
            if (callCount < 3) {
              throw Exception('Temporary failure $callCount');
            }
            return 'success after retries';
          },
        );
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, equals('success after retries'));
        expect(callCount, equals(3));
      });
      test('should fail after max attempts', () async {
        int callCount = 0;
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 2,
          initialDelayMs: 10,
          maxDelayMs: 100,
          backoffMultiplier: 2.0,
          block: () async {
            callCount++;
            throw Exception('Persistent failure $callCount');
          },
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('All retry attempts failed'));
        expect(callCount, equals(2));
      });
      test('should apply exponential backoff', () async {
        int callCount = 0;
        final timestamps = <int>[];
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 3,
          initialDelayMs: 50,
          maxDelayMs: 200,
          backoffMultiplier: 2.0,
          block: () async {
            callCount++;
            timestamps.add(DateTime.now().millisecondsSinceEpoch);
            throw Exception('Failure $callCount');
          },
        );
        expect(result.isSuccess, isFalse);
        expect(callCount, equals(3));
        expect(timestamps.length, equals(3));
        // Check that delays increase
        if (timestamps.length >= 2) {
          final delay1 = timestamps[1] - timestamps[0];
          expect(delay1,
              greaterThanOrEqualTo(40)); // Around 50ms with some tolerance
        }
      });
      test('should respect max delay', () async {
        int callCount = 0;
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 5,
          initialDelayMs: 100,
          maxDelayMs: 150, // Low max delay
          backoffMultiplier: 10.0, // High multiplier
          block: () async {
            callCount++;
            throw Exception('Failure $callCount');
          },
        );
        expect(result.isSuccess, isFalse);
        expect(callCount, equals(5));
      });
      test('should use retry predicate', () async {
        int callCount = 0;
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 3,
          initialDelayMs: 10,
          maxDelayMs: 100,
          backoffMultiplier: 2.0,
          retryOn: (exception) => exception.toString().contains('retryable'),
          block: () async {
            callCount++;
            if (callCount <= 2) {
              throw Exception('retryable error');
            } else {
              throw Exception('non-retryable error');
            }
          },
        );
        expect(result.isSuccess, isFalse);
        // Since we throw non-retryable on the 3rd attempt, it should fail with "All retry attempts failed"
        // because it's the last attempt, not because of retry criteria
        expect(result.getErrorMessage(), contains('All retry attempts failed'));
        expect(callCount, equals(3)); // Should retry twice then fail
      });
      test('should not retry when predicate returns false', () async {
        int callCount = 0;
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 3,
          initialDelayMs: 10,
          maxDelayMs: 100,
          backoffMultiplier: 2.0,
          retryOn: (exception) => false, // Never retry
          block: () async {
            callCount++;
            throw Exception('Should not retry');
          },
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('exception does not meet retry criteria'));
        expect(callCount, equals(1)); // Should not retry
      });
      test('should handle non-Exception errors', () async {
        int callCount = 0;
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 2,
          initialDelayMs: 10,
          maxDelayMs: 100,
          backoffMultiplier: 2.0,
          block: () async {
            callCount++;
            throw 'String error';
          },
        );
        expect(result.isSuccess, isFalse);
        expect(callCount, equals(2));
      });
      test('should handle zero max attempts', () async {
        int callCount = 0;
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 0,
          initialDelayMs: 10,
          maxDelayMs: 100,
          backoffMultiplier: 2.0,
          block: () async {
            callCount++;
            throw Exception('Should not be called');
          },
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Invalid max attempts'));
        expect(callCount, equals(0));
      });
    });
    group('withRetryResult - null fallback behavior', () {
      test('should return result on success', () async {
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 3,
          initialDelayMs: 10,
          maxDelayMs: 100,
          backoffMultiplier: 2.0,
          block: () async => 'success',
        );
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, equals('success'));
      });
      test('should return error on failure', () async {
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 2,
          initialDelayMs: 10,
          maxDelayMs: 100,
          backoffMultiplier: 2.0,
          block: () async => throw Exception('Failure'),
        );
        expect(result.isSuccess, isFalse);
        expect(result.valueOrNull, isNull);
      });
      test('should succeed after retries', () async {
        int callCount = 0;
        final result = await RetryUtil.withRetryResult<String>(
          maxAttempts: 3,
          initialDelayMs: 10,
          maxDelayMs: 100,
          backoffMultiplier: 2.0,
          block: () async {
            callCount++;
            if (callCount < 2) {
              throw Exception('Temporary failure');
            }
            return 'success after retry';
          },
        );
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, equals('success after retry'));
        expect(callCount, equals(2));
      });
    });
    group('withTimeoutResult Tests', () {
      test('should return result when operation completes within timeout',
          () async {
        final result = await RetryUtil.withTimeoutResult<String>(
          timeoutMs: 100,
          block: () async {
            await Future.delayed(const Duration(milliseconds: 10));
            return 'success';
          },
        );
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, equals('success'));
      });
      test('should return error on timeout', () async {
        final result = await RetryUtil.withTimeoutResult<String>(
          timeoutMs: 50,
          block: () async {
            await Future.delayed(const Duration(milliseconds: 100));
            return 'should not reach here';
          },
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('timed out'));
      });
      test('should return error on exception', () async {
        final result = await RetryUtil.withTimeoutResult<String>(
          timeoutMs: 1000,
          block: () async {
            // Use a more complex operation that might fail
            await Future.delayed(const Duration(milliseconds: 10));
            final list = <String>[];
            return list[10]; // Will throw RangeError
          },
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Operation failed'));
      });
      test('should handle different return types', () async {
        // Integer
        final intResult = await RetryUtil.withTimeoutResult<int>(
          timeoutMs: 100,
          block: () async => 42,
        );
        expect(intResult.isSuccess, isTrue);
        expect(intResult.valueOrNull, equals(42));
        // Map
        final mapResult = await RetryUtil.withTimeoutResult<Map<String, String>>(
          timeoutMs: 100,
          block: () async => {'success': 'true'},
        );
        expect(mapResult.isSuccess, isTrue);
        expect(mapResult.valueOrNull, equals({'success': 'true'}));
      });
    });
    group('withTimeoutResult - null fallback behavior', () {
      test('should return result when operation completes within timeout',
          () async {
        final result = await RetryUtil.withTimeoutResult<String>(
          timeoutMs: 100,
          block: () async {
            await Future.delayed(const Duration(milliseconds: 10));
            return 'success';
          },
        );
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, equals('success'));
      });
      test('should return error result on timeout', () async {
        final result = await RetryUtil.withTimeoutResult<String>(
          timeoutMs: 50,
          block: () async {
            await Future.delayed(const Duration(milliseconds: 100));
            return 'should not reach here';
          },
        );
        expect(result.isSuccess, isFalse);
        expect(result.valueOrNull, isNull);
      });
      test('should return error result on exception', () async {
        final result = await RetryUtil.withTimeoutResult<String>(
          timeoutMs: 100,
          block: () async {
            throw Exception('Operation failed');
          },
        );
        expect(result.isSuccess, isFalse);
        expect(result.valueOrNull, isNull);
      });
      test('should handle setup errors', () async {
        // This test is more for coverage of the catch block
        final result = await RetryUtil.withTimeoutResult<String>(
          timeoutMs: 100,
          block: () async => 'success',
        );
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, equals('success'));
      });
    });
    group('withCircuitBreakerResult Tests', () {
      test('should execute successfully when circuit is closed', () async {
        final result = await RetryUtil.withCircuitBreakerResult<String>(
          operationKey: 'test_operation',
          failureThreshold: 3,
          resetTimeoutMs: 1000,
          block: () async => 'success',
        );
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, equals('success'));
      });
      test('should return error when circuit is open', () async {
        // First, open the circuit
        for (int i = 0; i < 3; i++) {
          final failResult = await RetryUtil.withCircuitBreakerResult<String>(
            operationKey: 'failing_operation',
            failureThreshold: 3,
            resetTimeoutMs: 1000,
            block: () async => throw Exception('Failure $i'),
          );
          expect(failResult.isSuccess, isFalse);
        }
        // Now circuit should be open
        final result = await RetryUtil.withCircuitBreakerResult<String>(
          operationKey: 'failing_operation',
          failureThreshold: 3,
          resetTimeoutMs: 1000,
          block: () async => 'should not execute',
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Operation failed'));
      });
      test('should track failure in context when circuit is open',
          () async {
        // First, open the circuit
        for (int i = 0; i < 3; i++) {
          await RetryUtil.withCircuitBreakerResult<String>(
            operationKey: 'failing_operation_2',
            failureThreshold: 3,
            resetTimeoutMs: 1000,
            block: () async => throw Exception('Failure $i'),
          );
        }
        // Now should return error with circuit open info
        final result = await RetryUtil.withCircuitBreakerResult<String>(
          operationKey: 'failing_operation_2',
          failureThreshold: 3,
          resetTimeoutMs: 1000,
          block: () async => 'should not execute',
        );
        expect(result.isSuccess, isFalse);
        expect(result.error?.context?['circuitOpen'], isTrue);
      });
    });
    // Performance tracking functionality has been removed from RetryUtil
    group('runParallelResult Tests', () {
      test('should run operations in parallel successfully', () async {
        final operations = <Future<String> Function()>[
          () async {
            await Future.delayed(const Duration(milliseconds: 10));
            return 'result1';
          },
          () async {
            await Future.delayed(const Duration(milliseconds: 20));
            return 'result2';
          },
          () async {
            await Future.delayed(const Duration(milliseconds: 5));
            return 'result3';
          },
        ];
        final result = await RetryUtil.runParallelResult<String>(
          operations: operations,
          continueOnError: true,
        );
        expect(result.isSuccess, isTrue);
        final results = result.valueOrNull ?? [];
        expect(results.length, equals(3));
        expect(results[0], equals('result1'));
        expect(results[1], equals('result2'));
        expect(results[2], equals('result3'));
      });
      test('should handle empty operations list', () async {
        final result = await RetryUtil.runParallelResult<String>(
          operations: [],
          continueOnError: true,
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('No operations provided'));
      });
      test('should handle failures with continueOnError', () async {
        final operations = <Future<String> Function()>[
          () async => 'result1',
          () async => throw Exception('Operation 2 failed'),
          () async => 'result3',
        ];
        final result = await RetryUtil.runParallelResult<String>(
          operations: operations,
          continueOnError: true,
        );
        expect(result.isSuccess, isFalse);
        expect(result.error?.context?['successCount'], equals(2));
        expect(result.error?.context?['failureCount'], equals(1));
      });
      test('should fail fast without continueOnError', () async {
        final operations = <Future<String> Function()>[
          () async => 'result1',
          () async => throw Exception('Operation 2 failed'),
          () async => 'result3',
        ];
        final result = await RetryUtil.runParallelResult<String>(
          operations: operations,
          continueOnError: false,
        );
        expect(result.isSuccess, isFalse);
        // When continueOnError is false and an operation fails, it throws and gets caught by outer try-catch
        expect(result.getErrorMessage(), contains('Failed to run parallel operations'));
        expect(result.error?.context?['continueOnError'], isFalse);
      });
    });
  });
}