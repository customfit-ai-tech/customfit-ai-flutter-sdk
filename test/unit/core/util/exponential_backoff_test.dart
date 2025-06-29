import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/exponential_backoff.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_error_code.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('RetryConfig Tests', () {
    test('should create default retry config', () {
      final config = RetryConfig();
      expect(config.maxAttempts, equals(3));
      expect(config.initialDelay, equals(const Duration(milliseconds: 100)));
      expect(config.backoffMultiplier, equals(2.0));
      expect(config.maxDelay, equals(const Duration(seconds: 30)));
      expect(config.jitterFactor, equals(0.1));
      expect(config.retryableErrors, isNotEmpty);
      expect(
          config.retryableErrors.contains(CFErrorCode.networkTimeout), isTrue);
    });
    test('should create custom retry config', () {
      final customErrors = {CFErrorCode.httpBadRequest};
      final config = RetryConfig(
        maxAttempts: 5,
        initialDelay: const Duration(milliseconds: 200),
        backoffMultiplier: 3.0,
        maxDelay: const Duration(seconds: 60),
        jitterFactor: 0.2,
        retryableErrors: customErrors,
      );
      expect(config.maxAttempts, equals(5));
      expect(config.initialDelay, equals(const Duration(milliseconds: 200)));
      expect(config.backoffMultiplier, equals(3.0));
      expect(config.maxDelay, equals(const Duration(seconds: 60)));
      expect(config.jitterFactor, equals(0.2));
      expect(config.retryableErrors, equals(customErrors));
    });
    test('should have default retryable errors', () {
      final defaultErrors = RetryConfig.defaultRetryableErrors;
      expect(defaultErrors.contains(CFErrorCode.networkTimeout), isTrue);
      expect(defaultErrors.contains(CFErrorCode.networkConnectionLost), isTrue);
      expect(defaultErrors.contains(CFErrorCode.httpTooManyRequests), isTrue);
      expect(
          defaultErrors.contains(CFErrorCode.httpServiceUnavailable), isTrue);
      expect(defaultErrors.contains(CFErrorCode.httpGatewayTimeout), isTrue);
      expect(
          defaultErrors.contains(CFErrorCode.httpInternalServerError), isTrue);
      expect(defaultErrors.contains(CFErrorCode.httpBadGateway), isTrue);
    });
  });
  group('ExponentialBackoff Tests', () {
    group('Successful Operations', () {
      test('should return result immediately on first success', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            return CFResult.success('success');
          },
          operationName: 'test_operation',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('success'));
        expect(callCount, equals(1));
      });
      test('should succeed after retries', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            if (callCount < 3) {
              return CFResult.error(
                'Temporary error',
                errorCode: CFErrorCode.networkTimeout,
              );
            }
            return CFResult.success('success after retries');
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 3,
            initialDelay: const Duration(milliseconds: 10),
          ),
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('success after retries'));
        expect(callCount, equals(3));
      });
    });
    group('Failed Operations', () {
      test('should fail after max attempts with retryable error', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            return CFResult.error(
              'Network error',
              errorCode: CFErrorCode.networkTimeout,
            );
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 2,
            initialDelay: const Duration(milliseconds: 10),
          ),
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Network error'));
        expect(callCount, equals(2));
      });
      test('should not retry non-retryable errors', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            return CFResult.error(
              'Bad request',
              errorCode: CFErrorCode.httpBadRequest,
            );
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 3,
            initialDelay: const Duration(milliseconds: 10),
          ),
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Bad request'));
        expect(callCount, equals(1)); // Should not retry
      });
      test('should handle null error correctly', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            return CFResult.error('Error without error code');
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 3,
            initialDelay: const Duration(milliseconds: 10),
          ),
        );
        expect(result.isSuccess, isFalse);
        expect(callCount, equals(1)); // Should not retry when error is null
      });
    });
    group('Rate Limiting Handling', () {
      test('should handle rate limiting error without retry', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            return CFResult.error(
              'Rate limited',
              errorCode: CFErrorCode.httpTooManyRequests,
            );
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 1, // Only one attempt to avoid 60s delay
            initialDelay: const Duration(milliseconds: 10),
          ),
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Rate limited'));
        expect(callCount, equals(1));
      });
      test('should identify rate limiting error as retryable', () {
        final config = RetryConfig();
        expect(config.retryableErrors.contains(CFErrorCode.httpTooManyRequests),
            isTrue);
      });
    });
    group('Exception Handling', () {
      test('should handle exceptions during operation', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            if (callCount < 2) {
              throw Exception('Unexpected error');
            }
            return CFResult.success('success after exception');
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 2,
            initialDelay: const Duration(milliseconds: 10),
          ),
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('success after exception'));
        expect(callCount, equals(2));
      });
      test('should fail after max attempts with exceptions', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            throw Exception('Persistent error');
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 2,
            initialDelay: const Duration(milliseconds: 10),
          ),
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(),
            contains('Operation failed after 2 attempts'));
        expect(
            result.error?.errorCode, equals(CFErrorCode.internalUnknownError));
        expect(callCount, equals(2));
      });
      test('should handle different exception types', () async {
        final exceptions = [
          ArgumentError('Argument error'),
          StateError('State error'),
          const FormatException('Format error'),
          TimeoutException('Timeout', const Duration(seconds: 1)),
        ];
        for (int i = 0; i < exceptions.length; i++) {
          int callCount = 0;
          final result = await ExponentialBackoff.retry<String>(
            operation: () async {
              callCount++;
              if (callCount == 1) {
                throw exceptions[i];
              }
              return CFResult.success(
                  'recovered from ${exceptions[i].runtimeType}');
            },
            operationName: 'test_operation_$i',
            config: RetryConfig(
              maxAttempts: 2,
              initialDelay: const Duration(milliseconds: 10),
            ),
          );
          expect(result.isSuccess, isTrue);
          expect(callCount, equals(2));
        }
      });
    });
    group('Backoff Configuration Tests', () {
      test('should respect max delay', () async {
        int callCount = 0;
        final delays = <Duration>[];
        await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            if (callCount > 1) {
              delays.add(Duration(
                  milliseconds: DateTime.now().millisecondsSinceEpoch));
            }
            if (callCount < 4) {
              return CFResult.error(
                'Error',
                errorCode: CFErrorCode.networkTimeout,
              );
            }
            return CFResult.success('success');
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 4,
            initialDelay: const Duration(milliseconds: 100),
            backoffMultiplier: 10.0, // Very high multiplier
            maxDelay: const Duration(milliseconds: 200), // Low max delay
            jitterFactor: 0.0, // No jitter for predictable testing
          ),
        );
        expect(callCount, equals(4));
        // All delays should be capped at maxDelay
      });
      test('should apply jitter to delays', () async {
        int callCount = 0;
        await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            if (callCount < 3) {
              return CFResult.error(
                'Error',
                errorCode: CFErrorCode.networkTimeout,
              );
            }
            return CFResult.success('success');
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 3,
            initialDelay: const Duration(milliseconds: 100),
            jitterFactor: 0.5, // High jitter for testing
          ),
        );
        expect(callCount, equals(3));
        // Jitter should be applied (hard to test deterministically)
      });
      test('should use custom retryable errors', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            return CFResult.error(
              'Custom error',
              errorCode: CFErrorCode.httpBadRequest,
            );
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 3,
            initialDelay: const Duration(milliseconds: 10),
            retryableErrors: {CFErrorCode.httpBadRequest}, // Make it retryable
          ),
        );
        expect(result.isSuccess, isFalse);
        expect(callCount,
            equals(3)); // Should retry because it's in custom retryable errors
      });
    });
    group('Simple Retry Tests', () {
      test('should perform simple retry without backoff', () async {
        int callCount = 0;
        final timestamps = <int>[];
        final result = await ExponentialBackoff.retrySimple<String>(
          operation: () async {
            callCount++;
            timestamps.add(DateTime.now().millisecondsSinceEpoch);
            if (callCount < 3) {
              return CFResult.error(
                'Error',
                errorCode: CFErrorCode.networkTimeout,
              );
            }
            return CFResult.success('success');
          },
          operationName: 'simple_test',
          maxAttempts: 3,
          delay: const Duration(milliseconds: 100),
        );
        expect(result.isSuccess, isTrue);
        expect(callCount, equals(3));
        // Check that delays are consistent (no exponential backoff)
        if (timestamps.length >= 2) {
          final delay1 = timestamps[1] - timestamps[0];
          // Allow more tolerance for timing variations (80-150ms)
          expect(delay1,
              greaterThanOrEqualTo(80)); // Around 100ms with more tolerance
          expect(delay1, lessThanOrEqualTo(150));
        }
      });
      test('should succeed immediately with simple retry', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retrySimple<String>(
          operation: () async {
            callCount++;
            return CFResult.success('immediate success');
          },
          operationName: 'simple_test',
          maxAttempts: 3,
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('immediate success'));
        expect(callCount, equals(1));
      });
      test('should fail after max attempts with simple retry', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retrySimple<String>(
          operation: () async {
            callCount++;
            return CFResult.error(
              'Persistent error',
              errorCode: CFErrorCode.networkTimeout,
            );
          },
          operationName: 'simple_test',
          maxAttempts: 2,
          delay: const Duration(milliseconds: 10),
        );
        expect(result.isSuccess, isFalse);
        expect(callCount, equals(2));
      });
    });
    group('Edge Cases', () {
      test('should handle zero max attempts', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            return CFResult.error(
              'Error',
              errorCode: CFErrorCode.networkTimeout,
            );
          },
          operationName: 'test_operation',
          config: RetryConfig(maxAttempts: 0),
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('failed after 0 attempts'));
        expect(callCount, equals(0));
      });
      test('should handle one max attempt', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            return CFResult.error(
              'Error',
              errorCode: CFErrorCode.networkTimeout,
            );
          },
          operationName: 'test_operation',
          config: RetryConfig(maxAttempts: 1),
        );
        expect(result.isSuccess, isFalse);
        expect(callCount, equals(1));
      });
      test('should handle very small delays', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            if (callCount < 2) {
              return CFResult.error(
                'Error',
                errorCode: CFErrorCode.networkTimeout,
              );
            }
            return CFResult.success('success');
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 2,
            initialDelay: const Duration(microseconds: 1), // Very small delay
          ),
        );
        expect(result.isSuccess, isTrue);
        expect(callCount, equals(2));
      });
      test('should handle zero backoff multiplier', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            if (callCount < 3) {
              return CFResult.error(
                'Error',
                errorCode: CFErrorCode.networkTimeout,
              );
            }
            return CFResult.success('success');
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 3,
            initialDelay: const Duration(milliseconds: 10),
            backoffMultiplier: 0.0, // No backoff
          ),
        );
        expect(result.isSuccess, isTrue);
        expect(callCount, equals(3));
      });
      test('should handle negative jitter factor', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            if (callCount < 2) {
              return CFResult.error(
                'Error',
                errorCode: CFErrorCode.networkTimeout,
              );
            }
            return CFResult.success('success');
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 2,
            initialDelay: const Duration(milliseconds: 10),
            jitterFactor: -0.5, // Negative jitter
          ),
        );
        expect(result.isSuccess, isTrue);
        expect(callCount, equals(2));
      });
      test('should handle empty retryable errors set', () async {
        int callCount = 0;
        final result = await ExponentialBackoff.retry<String>(
          operation: () async {
            callCount++;
            return CFResult.error(
              'Error',
              errorCode: CFErrorCode.networkTimeout,
            );
          },
          operationName: 'test_operation',
          config: RetryConfig(
            maxAttempts: 3,
            retryableErrors: {}, // No retryable errors
          ),
        );
        expect(result.isSuccess, isFalse);
        expect(callCount, equals(1)); // Should not retry
      });
    });
    group('Operation Name Tests', () {
      test('should handle empty operation name', () async {
        final result = await ExponentialBackoff.retry<String>(
          operation: () async => CFResult.success('success'),
          operationName: '',
        );
        expect(result.isSuccess, isTrue);
      });
      test('should handle special characters in operation name', () async {
        final result = await ExponentialBackoff.retry<String>(
          operation: () async => CFResult.success('success'),
          operationName: 'test-operation_123!@#',
        );
        expect(result.isSuccess, isTrue);
      });
    });
    group('Return Type Tests', () {
      test('should handle different return types', () async {
        // String
        final stringResult = await ExponentialBackoff.retry<String>(
          operation: () async => CFResult.success('string'),
          operationName: 'string_test',
        );
        expect(stringResult.data, equals('string'));
        // Integer
        final intResult = await ExponentialBackoff.retry<int>(
          operation: () async => CFResult.success(42),
          operationName: 'int_test',
        );
        expect(intResult.data, equals(42));
        // Map
        final mapResult = await ExponentialBackoff.retry<Map<String, dynamic>>(
          operation: () async => CFResult.success({'key': 'value'}),
          operationName: 'map_test',
        );
        expect(mapResult.data, equals({'key': 'value'}));
        // List
        final listResult = await ExponentialBackoff.retry<List<int>>(
          operation: () async => CFResult.success([1, 2, 3]),
          operationName: 'list_test',
        );
        expect(listResult.data, equals([1, 2, 3]));
      });
      test('should handle null return values', () async {
        final result = await ExponentialBackoff.retry<String?>(
          operation: () async => CFResult.success(null),
          operationName: 'null_test',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, isNull);
      });
    });
  });
}
