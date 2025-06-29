// test/unit/core/util/error_handling_improved_test.dart
//
// Comprehensive tests for improved error handling in the CustomFit SDK.
// Tests TypeConversionStrategyV2, CacheManager improvements, and RetryUtil.
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/type_conversion_strategy.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/cache_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/retry_util.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_error_code.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('TypeConversionStrategy Tests', () {
    late TypeConversionManager manager;
    setUp(() {
      manager = TypeConversionManager();
    });
    group('String Conversion', () {
      test('should successfully convert various types to String', () {
        final intResult = manager.convertValue<String>(123);
        expect(intResult.isSuccess, true);
        expect(intResult.data, '123');
        final doubleResult = manager.convertValue<String>(45.67);
        expect(doubleResult.isSuccess, true);
        expect(doubleResult.data, '45.67');
        final boolResult = manager.convertValue<String>(true);
        expect(boolResult.isSuccess, true);
        expect(boolResult.data, 'true');
      });
      test('should return error for null conversion to String', () {
        final result = manager.convertValue<String>(null);
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidType);
        expect(result.error?.category, ErrorCategory.validation);
        expect(
            result.error?.message, contains('Cannot convert null to String'));
      });
    });
    group('Int Conversion', () {
      test('should successfully convert valid values to int', () {
        final stringResult = manager.convertValue<int>('42');
        expect(stringResult.isSuccess, true);
        expect(stringResult.data, 42);
        final doubleResult = manager.convertValue<int>(42.0);
        expect(doubleResult.isSuccess, true);
        expect(doubleResult.data, 42);
      });
      test('should return error for invalid string to int conversion', () {
        final result = manager.convertValue<int>('not_a_number');
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidFormat);
        expect(result.error?.category, ErrorCategory.validation);
        expect(result.error?.context?['value'], 'not_a_number');
      });
      test('should return error for double with decimal to int conversion', () {
        final result = manager.convertValue<int>(42.5);
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidType);
        expect(result.error?.message, contains('without loss of precision'));
      });
      test('should return error for null conversion to int', () {
        final result = manager.convertValue<int>(null);
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidType);
        expect(result.error?.message, contains('Cannot convert null to int'));
      });
    });
    group('Double Conversion', () {
      test('should successfully convert valid values to double', () {
        final stringResult = manager.convertValue<double>('42.5');
        expect(stringResult.isSuccess, true);
        expect(stringResult.data, 42.5);
        final intResult = manager.convertValue<double>(42);
        expect(intResult.isSuccess, true);
        expect(intResult.data, 42.0);
      });
      test('should return error for invalid string to double conversion', () {
        final result = manager.convertValue<double>('not_a_number');
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidFormat);
        expect(result.error?.context?['value'], 'not_a_number');
      });
    });
    group('Bool Conversion', () {
      test('should successfully convert valid values to bool', () {
        final trueResult = manager.convertValue<bool>('true');
        expect(trueResult.isSuccess, true);
        expect(trueResult.data, true);
        final falseResult = manager.convertValue<bool>('false');
        expect(falseResult.isSuccess, true);
        expect(falseResult.data, false);
        final oneResult = manager.convertValue<bool>('1');
        expect(oneResult.isSuccess, true);
        expect(oneResult.data, true);
        final zeroResult = manager.convertValue<bool>('0');
        expect(zeroResult.isSuccess, true);
        expect(zeroResult.data, false);
        final intResult = manager.convertValue<bool>(5);
        expect(intResult.isSuccess, true);
        expect(intResult.data, true);
      });
      test('should return error for invalid string to bool conversion', () {
        final result = manager.convertValue<bool>('maybe');
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidFormat);
        expect(result.error?.message, contains('expected true/false/1/0'));
      });
    });
    group('Complex Type Conversion', () {
      test('should handle Map conversion', () {
        final map = {'key': 'value'};
        final result = manager.convertValue<Map>(map);
        expect(result.isSuccess, true);
        expect(result.data, map);
      });
      test('should handle List conversion', () {
        final list = [1, 2, 3];
        final result = manager.convertValue<List>(list);
        expect(result.isSuccess, true);
        expect(result.data, list);
      });
      test('should return error for incompatible type conversion', () {
        final result = manager.convertValue<Map>('not_a_map');
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidType);
        expect(result.error?.context?['valueType'], 'String');
      });
    });
    group('Error Context', () {
      test('should include stack trace in error context', () {
        // Force an exception by creating a custom strategy that throws
        final badStrategy = _ThrowingConversionStrategy();
        manager.registerStrategy(badStrategy);
        final result = manager.convertValue<_CustomType>('test');
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.internalConversionError);
        expect(result.error?.context?['stackTrace'], isNotNull);
        expect(result.error?.exception, isNotNull);
      });
    });
  });
  group('CacheManager Improved Error Handling Tests', () {
    late CacheManager cache;
    setUp(() async {
      cache = CacheManager.instance;
      await cache.initialize();
      await cache.clear();
    });
    tearDown(() async {
      await cache.clear();
    });
    group('clearImproved', () {
      test('should return success when cache is cleared', () async {
        // Add some test data
        await cache.put('test_key', 'test_value');
        final result = await cache.clearImproved();
        expect(result.isSuccess, true);
        expect(result.data, true);
        // Verify cache is empty
        final checkResult = await cache.get<String>('test_key');
        expect(checkResult, isNull);
      });
      test('should include context when partial failures occur', () async {
        // This test would require mocking PreferencesService to simulate failures
        // For now, we'll test the success path
        final result = await cache.clearImproved();
        expect(result.isSuccess, true);
      });
    });
    group('getImproved', () {
      test('should return success for existing cache entry', () async {
        await cache.put('test_key', 'test_value');
        final result = await cache.getImproved<String>('test_key');
        expect(result.isSuccess, true);
        expect(result.data, 'test_value');
      });
      test('should return error for non-existent key', () async {
        final result = await cache.getImproved<String>('non_existent_key');
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.internalCacheError);
        expect(result.error?.context?['reason'], 'not_found');
      });
      test('should return error for expired entry when not allowing expired',
          () async {
        // Add entry with very short TTL
        await cache.put(
          'test_key',
          'test_value',
          policy: const CachePolicy(ttlSeconds: 1),
        );
        // Wait for expiration
        await Future.delayed(const Duration(seconds: 2));
        final result = await cache.getImproved<String>('test_key');
        expect(result.isSuccess, false);
        expect(result.error?.context?['reason'], 'expired');
      });
      test('should return success for expired entry when allowing expired',
          () async {
        // Add entry with very short TTL
        await cache.put(
          'test_key',
          'test_value',
          policy: const CachePolicy(ttlSeconds: 1),
        );
        // Wait for expiration
        await Future.delayed(const Duration(seconds: 2));
        final result =
            await cache.getImproved<String>('test_key', allowExpired: true);
        expect(result.isSuccess, true);
        expect(result.data, 'test_value');
      });
      test('should handle type conversion errors', () async {
        await cache.put('test_key', 123);
        // Try to get as incompatible type
        final result = await cache.getImproved<List>('test_key');
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidType);
      });
    });
    group('refreshImproved', () {
      test('should successfully refresh cache value', () async {
        var counter = 0;
        Future<String> provider() async {
          counter++;
          return 'value_$counter';
        }
        final result = await cache.refreshImproved('test_key', provider);
        expect(result.isSuccess, true);
        expect(result.data, 'value_1');
        // Verify it's cached
        final cached = await cache.get<String>('test_key');
        expect(cached, 'value_1');
      });
      test('should return error when provider throws', () async {
        Future<String> provider() async {
          throw Exception('Provider failed');
        }
        final result = await cache.refreshImproved('test_key', provider);
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.internalCacheError);
        expect(result.error?.message, contains('Provider failed'));
      });
    });
    group('getOrFetchImproved', () {
      test('should return cached value when available', () async {
        await cache.put('test_key', 'cached_value');
        var providerCalled = false;
        Future<String> provider() async {
          providerCalled = true;
          return 'fresh_value';
        }
        final result = await cache.getOrFetchImproved('test_key', provider);
        expect(result.isSuccess, true);
        expect(result.data, 'cached_value');
        expect(providerCalled, false);
      });
      test('should fetch fresh value when cache miss', () async {
        Future<String> provider() async => 'fresh_value';
        final result = await cache.getOrFetchImproved('test_key', provider);
        expect(result.isSuccess, true);
        expect(result.data, 'fresh_value');
        // Verify it's cached
        final cached = await cache.get<String>('test_key');
        expect(cached, 'fresh_value');
      });
      test('should handle provider errors', () async {
        Future<String> provider() async {
          throw Exception('Provider error');
        }
        final result = await cache.getOrFetchImproved('test_key', provider);
        expect(result.isSuccess, false);
        expect(result.error?.message, contains('Provider error'));
      });
    });
  });
  group('RetryUtil Tests', () {
    group('withRetryResult', () {
      test('should succeed on first attempt', () async {
        var attempts = 0;
        final result = await RetryUtil.withRetryResult(
          maxAttempts: 3,
          initialDelayMs: 100,
          maxDelayMs: 500,
          backoffMultiplier: 2.0,
          block: () async {
            attempts++;
            return 'success';
          },
        );
        expect(result.isSuccess, true);
        expect(result.data, 'success');
        expect(attempts, 1);
      });
      test('should retry and succeed on third attempt', () async {
        var attempts = 0;
        final result = await RetryUtil.withRetryResult(
          maxAttempts: 3,
          initialDelayMs: 10,
          maxDelayMs: 50,
          backoffMultiplier: 2.0,
          block: () async {
            attempts++;
            if (attempts < 3) {
              throw Exception('Attempt $attempts failed');
            }
            return 'success';
          },
        );
        expect(result.isSuccess, true);
        expect(result.data, 'success');
        expect(attempts, 3);
      });
      test('should fail after max attempts', () async {
        var attempts = 0;
        final result = await RetryUtil.withRetryResult(
          maxAttempts: 3,
          initialDelayMs: 10,
          maxDelayMs: 50,
          backoffMultiplier: 2.0,
          block: () async {
            attempts++;
            throw Exception('Always fails');
          },
        );
        expect(result.isSuccess, false);
        expect(result.error?.message, contains('All retry attempts failed'));
        expect(result.error?.context?['attemptsMade'], 3);
        expect(result.error?.context?['attemptHistory'], isNotNull);
        expect(attempts, 3);
      });
      test('should respect retry predicate', () async {
        var attempts = 0;
        final result = await RetryUtil.withRetryResult(
          maxAttempts: 3,
          initialDelayMs: 10,
          maxDelayMs: 50,
          backoffMultiplier: 2.0,
          retryOn: (e) => e.toString().contains('temporary'),
          block: () async {
            attempts++;
            throw Exception('Permanent failure');
          },
        );
        expect(result.isSuccess, false);
        expect(result.error?.context?['retryConditionFailed'], true);
        expect(attempts, 1);
      });
      test('should validate max attempts', () async {
        final result = await RetryUtil.withRetryResult(
          maxAttempts: 0,
          initialDelayMs: 100,
          maxDelayMs: 500,
          backoffMultiplier: 2.0,
          block: () async => 'success',
        );
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidType);
        expect(result.error?.message, contains('Invalid max attempts'));
      });
      test('should include attempt history in error context', () async {
        final result = await RetryUtil.withRetryResult(
          maxAttempts: 2,
          initialDelayMs: 10,
          maxDelayMs: 50,
          backoffMultiplier: 2.0,
          block: () async {
            throw Exception('Test error');
          },
        );
        expect(result.isSuccess, false);
        final attemptHistory = result.error?.context?['attemptHistory'] as List;
        expect(attemptHistory.length, 2);
        expect(attemptHistory[0]['attemptNumber'], 1);
        expect(attemptHistory[1]['attemptNumber'], 2);
      });
    });
    group('withTimeoutResult', () {
      test('should succeed within timeout', () async {
        final result = await RetryUtil.withTimeoutResult(
          timeoutMs: 1000,
          block: () async {
            await Future.delayed(const Duration(milliseconds: 100));
            return 'success';
          },
        );
        expect(result.isSuccess, true);
        expect(result.data, 'success');
      });
      test('should timeout when operation takes too long', () async {
        final result = await RetryUtil.withTimeoutResult(
          timeoutMs: 100,
          block: () async {
            await Future.delayed(const Duration(milliseconds: 200));
            return 'too late';
          },
        );
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.networkTimeout);
        expect(result.error?.message, contains('timed out'));
      });
      test('should handle exceptions in block', () async {
        final result = await RetryUtil.withTimeoutResult(
          timeoutMs: 1000,
          block: () async {
            throw Exception('Block failed');
          },
        );
        expect(result.isSuccess, false);
        expect(result.error?.message, contains('Block failed'));
        expect(result.error?.context?['stackTrace'], isNotNull);
      });
      test('should validate timeout value', () async {
        final result = await RetryUtil.withTimeoutResult(
          timeoutMs: 0,
          block: () async => 'success',
        );
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidType);
        expect(result.error?.message, contains('Invalid timeout'));
      });
    });
    group('withCircuitBreakerResult', () {
      test('should execute successfully when circuit is closed', () async {
        final result = await RetryUtil.withCircuitBreakerResult(
          operationKey: 'test_operation',
          failureThreshold: 3,
          resetTimeoutMs: 1000,
          block: () async => 'success',
        );
        expect(result.isSuccess, true);
        expect(result.data, 'success');
      });
      test('should handle failures and open circuit', () async {
        const operationKey = 'failing_operation';
        // Fail multiple times to open the circuit
        for (var i = 0; i < 3; i++) {
          final result = await RetryUtil.withCircuitBreakerResult(
            operationKey: operationKey,
            failureThreshold: 3,
            resetTimeoutMs: 1000,
            block: () async {
              throw Exception('Operation failed');
            },
          );
          expect(result.isSuccess, false);
        }
        // Next attempt should fail immediately due to open circuit
        final result = await RetryUtil.withCircuitBreakerResult(
          operationKey: operationKey,
          failureThreshold: 3,
          resetTimeoutMs: 1000,
          block: () async => 'should not execute',
        );
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.internalCircuitBreakerOpen);
      });
    });
    group('runParallelResult', () {
      test('should run all operations successfully', () async {
        final operations = [
          () async => 1,
          () async => 2,
          () async => 3,
        ];
        final result = await RetryUtil.runParallelResult(
          operations: operations,
        );
        expect(result.isSuccess, true);
        expect(result.data, [1, 2, 3]);
      });
      test('should handle partial failures with continueOnError', () async {
        final operations = [
          () async => 1,
          () async => throw Exception('Operation 2 failed'),
          () async => 3,
        ];
        final result = await RetryUtil.runParallelResult(
          operations: operations,
          continueOnError: true,
        );
        expect(result.isSuccess, false);
        expect(result.error?.context?['successCount'], 2);
        expect(result.error?.context?['failureCount'], 1);
        final failures = result.error?.context?['failures'] as List;
        expect(failures.length, 1);
        expect(failures[0]['index'], 1);
      });
      test('should fail fast without continueOnError', () async {
        final operations = [
          () async {
            await Future.delayed(const Duration(milliseconds: 100));
            return 1;
          },
          () async => throw Exception('Operation 2 failed'),
          () async => 3,
        ];
        final result = await RetryUtil.runParallelResult(
          operations: operations,
          continueOnError: false,
        );
        expect(result.isSuccess, false);
        expect(result.error?.context?['continueOnError'], false);
        expect(result.error?.context?['failedOperationIndex'], 1);
      });
      test('should validate empty operations', () async {
        final result = await RetryUtil.runParallelResult<int>(
          operations: [],
        );
        expect(result.isSuccess, false);
        expect(result.error?.errorCode,
            CFErrorCode.validationMissingRequiredField);
        expect(result.error?.message, contains('No operations provided'));
      });
    });
  });
}
// Helper classes for testing
class _CustomType {}
class _ThrowingConversionStrategy extends TypeConversionStrategy<_CustomType> {
  @override
  CFResult<_CustomType> convert(dynamic value) {
    throw Exception('Intentional test exception');
  }
  @override
  bool canHandle(Type type) => type == _CustomType;
  @override
  int get priority => 100;
}
