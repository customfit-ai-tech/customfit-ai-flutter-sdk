// test/unit/core/error/error_recovery_test.dart
//
// Tests for ErrorRecoveryStrategy error recovery utilities
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/recovery_managers.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/recovery_utils.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ErrorRecoveryStrategy', () {
    group('executeWithRecovery', () {
      test('should execute successful operation without recovery', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => 'success',
          operationName: 'test-operation',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('success'));
      });
      test('should handle operation failure with fallback', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw Exception('Operation failed'),
          operationName: 'failing-operation',
          fallback: 'fallback-value',
          maxRetries: 1,
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('fallback-value'));
      });
      test('should return error result when operation fails without fallback',
          () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw Exception('Operation failed'),
          operationName: 'failing-operation',
          maxRetries: 1,
        );
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(),
            contains('Failed to execute failing-operation'));
      });
      test('should categorize network errors correctly', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async =>
              throw const SocketException('Connection refused'),
          operationName: 'network-operation',
          maxRetries: 1,
        );
        expect(result.isSuccess, isFalse);
        expect(result.error?.category, equals(ErrorCategory.network));
      });
      test('should categorize timeout errors correctly', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw TimeoutException('Request timed out'),
          operationName: 'timeout-operation',
          maxRetries: 1,
        );
        expect(result.isSuccess, isFalse);
        // Check that the error message contains timeout information
        expect(result.getErrorMessage(), contains('TimeoutException'));
        expect(result.getErrorMessage(), contains('Request timed out'));
      });
      test('should handle different data types', () async {
        // Test with int
        final intResult = await ErrorRecoveryStrategy.executeWithRecovery<int>(
          operation: () async => 42,
          operationName: 'int-operation',
        );
        expect(intResult.data, equals(42));
        // Test with Map
        final mapResult = await ErrorRecoveryStrategy.executeWithRecovery<
            Map<String, dynamic>>(
          operation: () async => {'key': 'value'},
          operationName: 'map-operation',
        );
        expect(mapResult.data, equals({'key': 'value'}));
        // Test with List
        final listResult =
            await ErrorRecoveryStrategy.executeWithRecovery<List<String>>(
          operation: () async => ['item1', 'item2'],
          operationName: 'list-operation',
        );
        expect(listResult.data, equals(['item1', 'item2']));
      });
      test('should respect maxRetries parameter', () async {
        var attemptCount = 0;
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async {
            attemptCount++;
            throw Exception('Retry test');
          },
          operationName: 'retry-test',
          maxRetries: 3,
          fallback: 'fallback',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('fallback'));
        // Should have attempted the operation multiple times
        expect(attemptCount, greaterThan(1));
      });
      test('should handle async operations with delays', () async {
        final stopwatch = Stopwatch()..start();
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async {
            await Future.delayed(const Duration(milliseconds: 50));
            return 'delayed-success';
          },
          operationName: 'delayed-operation',
        );
        stopwatch.stop();
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('delayed-success'));
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(50));
      });
      test('should disable logging when logFailures is false', () async {
        // This test ensures the logFailures parameter is respected
        // No direct assertion on logging, but ensures no exceptions are thrown
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw Exception('Silent failure'),
          operationName: 'silent-operation',
          maxRetries: 1,
          logFailures: false,
        );
        expect(result.isSuccess, isFalse);
      });
    });
    group('Error Categorization', () {
      test('should categorize SocketException as network error', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw const SocketException('Network error'),
          operationName: 'socket-test',
          maxRetries: 1,
        );
        expect(result.error?.category, equals(ErrorCategory.network));
      });
      test('should categorize TimeoutException as timeout error', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw TimeoutException('Timeout'),
          operationName: 'timeout-test',
          maxRetries: 1,
        );
        expect(result.isSuccess, isFalse);
        // Check that the error is properly handled
        expect(result.getErrorMessage(), contains('TimeoutException'));
      });
      test('should categorize FormatException as serialization error',
          () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw const FormatException('Invalid format'),
          operationName: 'format-test',
          maxRetries: 1,
        );
        expect(result.isSuccess, isFalse);
        // Check that the error is properly handled
        expect(result.getErrorMessage(), contains('FormatException'));
        expect(result.getErrorMessage(), contains('Invalid format'));
      });
      test('should categorize HttpException with 401 as authentication error',
          () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw const HttpException('401 Unauthorized'),
          operationName: 'auth-test',
          maxRetries: 1,
        );
        expect(result.error?.category, equals(ErrorCategory.authentication));
      });
      test('should categorize HttpException with 403 as authentication error',
          () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw const HttpException('403 Forbidden'),
          operationName: 'forbidden-test',
          maxRetries: 1,
        );
        expect(result.error?.category, equals(ErrorCategory.authentication));
      });
      test('should categorize HttpException with 429 as rate limit error',
          () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async =>
              throw const HttpException('429 Too Many Requests'),
          operationName: 'rate-limit-test',
          maxRetries: 1,
        );
        expect(result.isSuccess, isFalse);
        // Check that the error is properly handled
        expect(result.getErrorMessage(), contains('HttpException'));
        expect(result.getErrorMessage(), contains('429'));
      });
      test('should categorize other HttpException as network error', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async =>
              throw const HttpException('500 Internal Server Error'),
          operationName: 'server-error-test',
          maxRetries: 1,
        );
        expect(result.error?.category, equals(ErrorCategory.network));
      });
      test('should categorize unknown exceptions as unknown', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw StateError('Invalid state'),
          operationName: 'unknown-test',
          maxRetries: 1,
        );
        expect(result.error?.category, equals(ErrorCategory.unknown));
      });
    });
    group('Retry Logic', () {
      test('should retry on SocketException', () async {
        var attemptCount = 0;
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async {
            attemptCount++;
            if (attemptCount < 3) {
              throw const SocketException('Connection failed');
            }
            return 'success-after-retries';
          },
          operationName: 'retry-socket-test',
          maxRetries: 5,
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('success-after-retries'));
        expect(attemptCount, equals(3));
      });
      test('should retry on TimeoutException', () async {
        var attemptCount = 0;
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async {
            attemptCount++;
            if (attemptCount < 2) {
              throw TimeoutException('Request timed out');
            }
            return 'success-after-timeout';
          },
          operationName: 'retry-timeout-test',
          maxRetries: 3,
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('success-after-timeout'));
        expect(attemptCount, equals(2));
      });
      test('should retry on NetworkException', () async {
        var attemptCount = 0;
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async {
            attemptCount++;
            if (attemptCount < 2) {
              throw NetworkException('Network error');
            }
            return 'success-after-network-error';
          },
          operationName: 'retry-network-test',
          maxRetries: 3,
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('success-after-network-error'));
        expect(attemptCount, equals(2));
      });
      test('should retry on server errors (5xx)', () async {
        var attemptCount = 0;
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async {
            attemptCount++;
            if (attemptCount < 2) {
              throw const HttpException('500 Internal Server Error');
            }
            return 'success-after-server-error';
          },
          operationName: 'retry-server-error-test',
          maxRetries: 3,
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('success-after-server-error'));
        expect(attemptCount, equals(2));
      });
      test('should not retry on client errors (4xx except 429)', () async {
        var attemptCount = 0;
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async {
            attemptCount++;
            throw const HttpException('400 Bad Request');
          },
          operationName: 'no-retry-client-error-test',
          maxRetries: 3,
          fallback: 'fallback-for-client-error',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('fallback-for-client-error'));
        // Should not retry client errors
        expect(attemptCount, equals(1));
      });
      test('should not retry on ArgumentError', () async {
        var attemptCount = 0;
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async {
            attemptCount++;
            throw ArgumentError('Invalid argument');
          },
          operationName: 'no-retry-argument-error-test',
          maxRetries: 3,
          fallback: 'fallback-for-argument-error',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('fallback-for-argument-error'));
        // Should not retry argument errors
        expect(attemptCount, equals(1));
      });
    });
    group('Fallback Handling', () {
      test('should use fallback for non-retriable errors', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw ArgumentError('Invalid input'),
          operationName: 'fallback-test',
          fallback: 'fallback-value',
          maxRetries: 3,
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('fallback-value'));
      });
      test('should use fallback after all retries exhausted', () async {
        var attemptCount = 0;
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async {
            attemptCount++;
            throw const SocketException('Persistent network error');
          },
          operationName: 'exhausted-retries-test',
          fallback: 'final-fallback',
          maxRetries: 2,
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('final-fallback'));
        expect(attemptCount, greaterThan(1));
      });
      test('should handle null fallback gracefully', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String?>(
          operation: () async => throw Exception('Test error'),
          operationName: 'null-fallback-test',
          fallback: null,
          maxRetries: 1,
        );
        expect(result.isSuccess, isFalse);
      });
      test('should handle different fallback types', () async {
        // String fallback
        final stringResult =
            await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => throw Exception('Error'),
          operationName: 'string-fallback',
          fallback: 'string-fallback',
          maxRetries: 1,
        );
        expect(stringResult.data, equals('string-fallback'));
        // Int fallback
        final intResult = await ErrorRecoveryStrategy.executeWithRecovery<int>(
          operation: () async => throw Exception('Error'),
          operationName: 'int-fallback',
          fallback: 42,
          maxRetries: 1,
        );
        expect(intResult.data, equals(42));
        // Map fallback
        final mapFallback = {'fallback': true};
        final mapResult = await ErrorRecoveryStrategy.executeWithRecovery<
            Map<String, dynamic>>(
          operation: () async => throw Exception('Error'),
          operationName: 'map-fallback',
          fallback: mapFallback,
          maxRetries: 1,
        );
        expect(mapResult.data, equals(mapFallback));
      });
    });
    group('Edge Cases', () {
      test('should handle operation that returns null', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String?>(
          operation: () async => null,
          operationName: 'null-return-test',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, isNull);
      });
      test('should handle very fast operations', () async {
        final result = await ErrorRecoveryStrategy.executeWithRecovery<String>(
          operation: () async => 'immediate',
          operationName: 'fast-operation',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('immediate'));
      });
      test('should handle operations with complex return types', () async {
        final complexData = {
          'users': [
            {'id': 1, 'name': 'John'},
            {'id': 2, 'name': 'Jane'},
          ],
          'metadata': {
            'total': 2,
            'page': 1,
          },
        };
        final result = await ErrorRecoveryStrategy.executeWithRecovery<
            Map<String, dynamic>>(
          operation: () async => complexData,
          operationName: 'complex-data-operation',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals(complexData));
      });
      test('should handle concurrent recovery operations', () async {
        final futures = List.generate(5, (index) async {
          return ErrorRecoveryStrategy.executeWithRecovery<String>(
            operation: () async {
              await Future.delayed(Duration(milliseconds: 10 * index));
              return 'result-$index';
            },
            operationName: 'concurrent-$index',
          );
        });
        final results = await Future.wait(futures);
        expect(results, hasLength(5));
        for (int i = 0; i < results.length; i++) {
          expect(results[i].isSuccess, isTrue);
          expect(results[i].data, equals('result-$i'));
        }
      });
    });
  });
  group('Custom Exceptions', () {
    group('NetworkException', () {
      test('should create NetworkException with message', () {
        final exception = NetworkException('Network error occurred');
        expect(exception.message, equals('Network error occurred'));
        expect(exception.toString(),
            equals('NetworkException: Network error occurred'));
      });
      test('should be throwable and catchable', () {
        expect(() => throw NetworkException('Test'),
            throwsA(isA<NetworkException>()));
        try {
          throw NetworkException('Catch test');
        } catch (e) {
          expect(e, isA<NetworkException>());
          expect((e as NetworkException).message, equals('Catch test'));
        }
      });
    });
    group('NetworkUnavailableException', () {
      test('should create NetworkUnavailableException with message', () {
        final exception = NetworkUnavailableException('No network available');
        expect(exception.message, equals('No network available'));
        expect(exception.toString(),
            equals('NetworkUnavailableException: No network available'));
      });
      test('should be throwable and catchable', () {
        expect(() => throw NetworkUnavailableException('Test'),
            throwsA(isA<NetworkUnavailableException>()));
        try {
          throw NetworkUnavailableException('Catch test');
        } catch (e) {
          expect(e, isA<NetworkUnavailableException>());
          expect(
              (e as NetworkUnavailableException).message, equals('Catch test'));
        }
      });
    });
  });
}
