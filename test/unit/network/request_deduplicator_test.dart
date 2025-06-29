// test/unit/network/request_deduplicator_test.dart
//
// Comprehensive tests for RequestDeduplicator class
// Critical component for preventing duplicate network requests
// Merged with comprehensive tests for complete coverage
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/network/request_deduplicator.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('RequestDeduplicator Tests', () {
    late RequestDeduplicator deduplicator;
    setUp(() {
      deduplicator = RequestDeduplicator();
    });
    tearDown(() {
      // Clean up any pending requests
    });
    group('Basic Functionality', () {
      test('should execute single request normally', () async {
        var callCount = 0;
        final result = await deduplicator.execute<String>(
          'test-key',
          () async {
            callCount++;
            return CFResult.success('result');
          },
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('result'));
        expect(callCount, equals(1));
      });
      test('should deduplicate concurrent identical requests', () async {
        var callCount = 0;
        // Create a function that takes time to complete
        Future<CFResult<String>> slowFunction() async {
          await Future.delayed(const Duration(milliseconds: 100));
          callCount++;
          return CFResult.success('result-$callCount');
        }
        // Start multiple concurrent requests with the same key
        final futures = List.generate(
            5, (_) => deduplicator.execute<String>('same-key', slowFunction));
        final results = await Future.wait(futures);
        // All should succeed with the same result
        for (final result in results) {
          expect(result.isSuccess, isTrue);
          expect(result.data, equals('result-1'));
        }
        // Should only call the function once
        expect(callCount, equals(1));
      });
      test('should not deduplicate requests with different keys', () async {
        var callCount = 0;
        Future<CFResult<String>> testFunction(String suffix) async {
          callCount++;
          return CFResult.success('result-$suffix');
        }
        // Start requests with different keys
        final future1 =
            deduplicator.execute<String>('key-1', () => testFunction('A'));
        final future2 =
            deduplicator.execute<String>('key-2', () => testFunction('B'));
        final results = await Future.wait([future1, future2]);
        expect(results[0].isSuccess, isTrue);
        expect(results[0].data, equals('result-A'));
        expect(results[1].isSuccess, isTrue);
        expect(results[1].data, equals('result-B'));
        expect(callCount, equals(2));
      });
      test('should execute different requests independently', () async {
        int callCount1 = 0;
        int callCount2 = 0;
        final future1 = deduplicator.execute<String>(
          'key-1',
          () async {
            callCount1++;
            await Future.delayed(const Duration(milliseconds: 50));
            return CFResult.success('result-1');
          },
        );
        final future2 = deduplicator.execute<String>(
          'key-2',
          () async {
            callCount2++;
            await Future.delayed(const Duration(milliseconds: 50));
            return CFResult.success('result-2');
          },
        );
        final results = await Future.wait([future1, future2]);
        expect(results[0].data, 'result-1');
        expect(results[1].data, 'result-2');
        expect(callCount1, 1);
        expect(callCount2, 1);
      });
      test('should allow sequential requests with same key', () async {
        int callCount = 0;
        // First request
        final result1 = await deduplicator.execute<int>(
          'sequential-key',
          () async {
            callCount++;
            return CFResult.success(callCount);
          },
        );
        // Second request (after first completes)
        final result2 = await deduplicator.execute<int>(
          'sequential-key',
          () async {
            callCount++;
            return CFResult.success(callCount);
          },
        );
        expect(result1.data, 1);
        expect(result2.data, 2);
        expect(callCount, 2);
      });
    });
    group('Error Handling', () {
      test('should propagate errors to all waiting requests', () async {
        var callCount = 0;
        Future<CFResult<String>> failingFunction() async {
          await Future.delayed(const Duration(milliseconds: 50));
          callCount++;
          return CFResult.error('Test error');
        }
        // Start multiple concurrent requests
        final futures = List.generate(3,
            (_) => deduplicator.execute<String>('error-key', failingFunction));
        final results = await Future.wait(futures);
        // All should fail with the same error
        for (final result in results) {
          expect(result.isSuccess, isFalse);
          expect(result.getErrorMessage(), equals('Test error'));
        }
        // Should only call the function once
        expect(callCount, equals(1));
      });
      test('should handle exceptions in request function', () async {
        Future<CFResult<String>> throwingFunction() async {
          await Future.delayed(const Duration(milliseconds: 50));
          throw Exception('Test exception');
        }
        final result = await deduplicator.execute<String>(
            'exception-key', throwingFunction);
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Test exception'));
      });
      test('should propagate errors with category to all waiting requests',
          () async {
        int callCount = 0;
        Future<CFResult<String>> makeFailingRequest() {
          return deduplicator.execute<String>(
            'error-key',
            () async {
              callCount++;
              await Future.delayed(const Duration(milliseconds: 50));
              return CFResult.error(
                'Request failed',
                category: ErrorCategory.network,
              );
            },
          );
        }
        final futures = [
          makeFailingRequest(),
          makeFailingRequest(),
          makeFailingRequest(),
        ];
        final results = await Future.wait(futures);
        expect(results.every((r) => !r.isSuccess), true);
        expect(
            results.every((r) => r.error?.message == 'Request failed'), true);
        expect(callCount, 1);
      });
      test('should handle exceptions in request function with multiple waiters',
          () async {
        int callCount = 0;
        Future<CFResult<String>> makeThrowingRequest() {
          return deduplicator.execute<String>(
            'exception-key',
            () async {
              callCount++;
              await Future.delayed(const Duration(milliseconds: 20));
              throw Exception('Unexpected error');
            },
          );
        }
        final futures = [
          makeThrowingRequest(),
          makeThrowingRequest(),
        ];
        final results = await Future.wait(futures);
        expect(results.every((r) => !r.isSuccess), true);
        expect(
            results.every(
                (r) => r.error?.message?.contains('Request failed') ?? false),
            true);
        expect(callCount, 1);
      });
      test('should handle type casting errors', () async {
        // Request returns String but we expect int
        final result = await deduplicator.execute<int>(
          'type-error-key',
          () async {
            return CFResult.success('not-an-int') as CFResult<int>;
          },
        );
        // This would normally cause a runtime error, but the deduplicator
        // should handle it gracefully
        expect(!result.isSuccess || result.data is int, true);
      });
      test('should clean up after errors', () async {
        // First request fails
        await deduplicator.execute<String>(
          'cleanup-key',
          () async {
            throw Exception('Error');
          },
        );
        // Second request should execute, not be deduplicated
        int secondCallCount = 0;
        final result = await deduplicator.execute<String>(
          'cleanup-key',
          () async {
            secondCallCount++;
            return CFResult.success('success');
          },
        );
        expect(result.isSuccess, true);
        expect(secondCallCount, 1);
      });
      test('should handle mixed success and error scenarios', () async {
        var successCallCount = 0;
        var errorCallCount = 0;
        // First request succeeds
        final successResult =
            await deduplicator.execute<String>('success-key', () async {
          successCallCount++;
          return CFResult.success('success');
        });
        // Second request fails
        final errorResult =
            await deduplicator.execute<String>('error-key', () async {
          errorCallCount++;
          return CFResult.error('error');
        });
        expect(successResult.isSuccess, isTrue);
        expect(successResult.data, equals('success'));
        expect(errorResult.isSuccess, isFalse);
        expect(errorResult.getErrorMessage(), equals('error'));
        expect(successCallCount, equals(1));
        expect(errorCallCount, equals(1));
      });
    });
    group('Request Lifecycle', () {
      test('should allow new requests after completion', () async {
        var callCount = 0;
        Future<CFResult<String>> countingFunction() async {
          callCount++;
          return CFResult.success('call-$callCount');
        }
        // First request
        final result1 = await deduplicator.execute<String>(
            'lifecycle-key', countingFunction);
        expect(result1.data, equals('call-1'));
        // Second request with same key (should not be deduplicated since first completed)
        final result2 = await deduplicator.execute<String>(
            'lifecycle-key', countingFunction);
        expect(result2.data, equals('call-2'));
        expect(callCount, equals(2));
      });
      test('should handle rapid sequential requests', () async {
        var callCount = 0;
        Future<CFResult<String>> fastFunction() async {
          callCount++;
          return CFResult.success('fast-$callCount');
        }
        // Make many sequential requests quickly
        final results = <CFResult<String>>[];
        for (int i = 0; i < 10; i++) {
          final result =
              await deduplicator.execute<String>('sequential-$i', fastFunction);
          results.add(result);
        }
        // All should succeed
        for (int i = 0; i < results.length; i++) {
          expect(results[i].isSuccess, isTrue);
          expect(results[i].data, equals('fast-${i + 1}'));
        }
        expect(callCount, equals(10));
      });
      test('should handle rapid successive requests', () async {
        final results = <CFResult<int>>[];
        int callCount = 0;
        for (int i = 0; i < 10; i++) {
          results.add(
            await deduplicator.execute<int>(
              'rapid-key-$i',
              () async {
                callCount++;
                return CFResult.success(i);
              },
            ),
          );
        }
        expect(results.length, 10);
        expect(callCount, 10);
        for (int i = 0; i < 10; i++) {
          expect(results[i].data, i);
        }
      });
    });
    group('Cancel and Cleanup', () {
      test('should cancel all in-flight requests', () async {
        final futures = <Future<CFResult<String>>>[];
        // Start several long-running requests
        for (int i = 0; i < 5; i++) {
          futures.add(
            deduplicator.execute<String>(
              'cancel-key-$i',
              () async {
                await Future.delayed(const Duration(seconds: 1));
                return CFResult.success('should-not-complete');
              },
            ),
          );
        }
        // Cancel all requests
        deduplicator.cancelAll();
        // Verify in-flight count is zero
        expect(deduplicator.inFlightCount, 0);
      });
      test('should report correct in-flight count', () async {
        expect(deduplicator.inFlightCount, 0);
        // Start multiple requests
        final completer1 = Completer<CFResult<String>>();
        final completer2 = Completer<CFResult<String>>();
        final completer3 = Completer<CFResult<String>>();
        final future1 =
            deduplicator.execute<String>('count-1', () => completer1.future);
        final future2 =
            deduplicator.execute<String>('count-2', () => completer2.future);
        final future3 =
            deduplicator.execute<String>('count-3', () => completer3.future);
        // Allow time for requests to register
        await Future.delayed(const Duration(milliseconds: 10));
        expect(deduplicator.inFlightCount, 3);
        // Complete one request
        completer1.complete(CFResult.success('result1'));
        await future1;
        expect(deduplicator.inFlightCount, 2);
        // Complete remaining requests
        completer2.complete(CFResult.success('result2'));
        completer3.complete(CFResult.success('result3'));
        await Future.wait([future2, future3]);
        expect(deduplicator.inFlightCount, 0);
      });
    });
    group('Concurrency Scenarios', () {
      test('should handle mixed concurrent and sequential requests', () async {
        var callCount = 0;
        Future<CFResult<String>> mixedFunction(String id) async {
          await Future.delayed(const Duration(milliseconds: 50));
          callCount++;
          return CFResult.success('mixed-$id-$callCount');
        }
        // Start some concurrent requests
        final concurrent1 =
            deduplicator.execute<String>('mixed-key', () => mixedFunction('A'));
        final concurrent2 =
            deduplicator.execute<String>('mixed-key', () => mixedFunction('B'));
        // Wait for them to complete
        final concurrentResults = await Future.wait([concurrent1, concurrent2]);
        // Then make a sequential request
        final sequential = await deduplicator.execute<String>(
            'mixed-key', () => mixedFunction('C'));
        // Concurrent requests should be deduplicated
        expect(concurrentResults[0].data, equals(concurrentResults[1].data));
        expect(concurrentResults[0].data, equals('mixed-A-1'));
        // Sequential request should be separate
        expect(sequential.data, equals('mixed-C-2'));
        expect(callCount, equals(2));
      });
      test('should handle high concurrency load', () async {
        var callCount = 0;
        Future<CFResult<String>> loadTestFunction() async {
          await Future.delayed(const Duration(milliseconds: 100));
          callCount++;
          return CFResult.success('load-test-$callCount');
        }
        // Start many concurrent requests
        final futures = List.generate(
            50,
            (_) => deduplicator.execute<String>(
                'load-test-key', loadTestFunction));
        final results = await Future.wait(futures);
        // All should succeed with the same result
        for (final result in results) {
          expect(result.isSuccess, isTrue);
          expect(result.data, equals('load-test-1'));
        }
        // Should only call the function once despite high load
        expect(callCount, equals(1));
      });
      test('should handle mixed success and failure', () async {
        int attemptCount = 0;
        final futures = <Future<CFResult<String>>>[];
        for (int i = 0; i < 6; i++) {
          futures.add(
            deduplicator.execute<String>(
              'mixed-key-${i % 3}', // Keys 0, 1, 2 repeated
              () async {
                attemptCount++;
                await Future.delayed(const Duration(milliseconds: 50));
                if (i % 3 == 1) {
                  return CFResult.error('Error for key 1');
                }
                return CFResult.success('Success for key ${i % 3}');
              },
            ),
          );
        }
        final results = await Future.wait(futures);
        // Should have made 3 attempts (one for each unique key)
        expect(attemptCount, 3);
        // Check results
        expect(results[0].isSuccess, true); // key-0
        expect(results[1].isSuccess, false); // key-1
        expect(results[2].isSuccess, true); // key-2
        expect(results[3].isSuccess, true); // key-0 (deduplicated)
        expect(results[4].isSuccess, false); // key-1 (deduplicated)
        expect(results[5].isSuccess, true); // key-2 (deduplicated)
      });
    });
    group('Different Data Types', () {
      test('should handle different return types', () async {
        // String type
        final stringResult =
            await deduplicator.execute<String>('string-key', () async {
          return CFResult.success('string-value');
        });
        expect(stringResult.data, equals('string-value'));
        // Integer type
        final intResult = await deduplicator.execute<int>('int-key', () async {
          return CFResult.success(42);
        });
        expect(intResult.data, equals(42));
        // Map type
        final mapResult = await deduplicator
            .execute<Map<String, dynamic>>('map-key', () async {
          return CFResult.success({'key': 'value', 'number': 123});
        });
        expect(mapResult.data!['key'], equals('value'));
        expect(mapResult.data!['number'], equals(123));
        // List type
        final listResult =
            await deduplicator.execute<List<String>>('list-key', () async {
          return CFResult.success(['item1', 'item2', 'item3']);
        });
        expect(listResult.data!.length, equals(3));
        expect(listResult.data![0], equals('item1'));
      });
      test('should handle null and empty results', () async {
        // Null result
        final nullResult =
            await deduplicator.execute<String?>('null-key', () async {
          return CFResult.success(null);
        });
        expect(nullResult.isSuccess, isTrue);
        expect(nullResult.data, isNull);
        // Empty string
        final emptyResult =
            await deduplicator.execute<String>('empty-key', () async {
          return CFResult.success('');
        });
        expect(emptyResult.isSuccess, isTrue);
        expect(emptyResult.data, equals(''));
        // Empty map
        final emptyMapResult = await deduplicator
            .execute<Map<String, dynamic>>('empty-map-key', () async {
          return CFResult.success(<String, dynamic>{});
        });
        expect(emptyMapResult.isSuccess, isTrue);
        expect(emptyMapResult.data!.isEmpty, isTrue);
      });
    });
    group('Edge Cases', () {
      test('should handle very long request keys', () async {
        final longKey = 'x' * 1000; // Very long key
        final result = await deduplicator.execute<String>(longKey, () async {
          return CFResult.success('long-key-result');
        });
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('long-key-result'));
      });
      test('should handle very long keys', () async {
        final longKey = 'a' * 10000;
        final result = await deduplicator.execute<String>(
          longKey,
          () async => CFResult.success('success'),
        );
        expect(result.isSuccess, true);
      });
      test('should handle empty request keys', () async {
        final result = await deduplicator.execute<String>('', () async {
          return CFResult.success('empty-key-result');
        });
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('empty-key-result'));
      });
      test('should handle special characters in keys', () async {
        const specialKey = 'key-with-!@#\$%^&*()_+-=[]{}|;:,.<>?';
        final result = await deduplicator.execute<String>(specialKey, () async {
          return CFResult.success('special-key-result');
        });
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('special-key-result'));
      });
      test('should handle unicode characters in keys', () async {
        const unicodeKey = 'key-with-🎉-unicode-中文-characters';
        final result = await deduplicator.execute<String>(unicodeKey, () async {
          return CFResult.success('unicode-key-result');
        });
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('unicode-key-result'));
      });
    });
    group('Performance', () {
      test('should complete quickly with many different keys', () async {
        final startTime = DateTime.now();
        // Create many requests with different keys
        final futures = List.generate(
            100,
            (i) => deduplicator.execute<String>('perf-key-$i', () async {
                  return CFResult.success('result-$i');
                }));
        final results = await Future.wait(futures);
        final duration = DateTime.now().difference(startTime);
        // All should succeed
        for (int i = 0; i < results.length; i++) {
          expect(results[i].isSuccess, isTrue);
          expect(results[i].data, equals('result-$i'));
        }
        // Should complete reasonably quickly
        expect(duration.inMilliseconds, lessThan(1000));
      });
      test('should handle timeout scenarios gracefully', () async {
        Future<CFResult<String>> timeoutFunction() async {
          await Future.delayed(const Duration(seconds: 2)); // Long delay
          return CFResult.success('timeout-result');
        }
        // Start a request that will take a while
        final slowFuture =
            deduplicator.execute<String>('timeout-key', timeoutFunction);
        // Start another request with the same key immediately
        final fastFuture =
            deduplicator.execute<String>('timeout-key', () async {
          return CFResult.success('should-not-execute');
        });
        // Both should eventually complete with the same result
        final results = await Future.wait([slowFuture, fastFuture]);
        for (final result in results) {
          expect(result.isSuccess, isTrue);
          expect(result.data, equals('timeout-result'));
        }
      });
    });
  });
  group('RequestCoalescer Comprehensive Tests', () {
    late RequestCoalescer<String> coalescer;
    setUp(() {
      coalescer = RequestCoalescer<String>(
        windowMs: 100,
        maxBatchSize: 5,
      );
    });
    group('Basic Coalescing', () {
      test('should coalesce requests within time window', () async {
        int executionCount = 0;
        final futures = <Future<CFResult<String>>>[];
        Future<CFResult<String>> executor(int batchSize) async {
          executionCount++;
          await Future.delayed(const Duration(milliseconds: 50));
          return CFResult.success('batch-result-$batchSize');
        }
        // Add multiple requests quickly (without await)
        for (int i = 0; i < 3; i++) {
          futures.add(coalescer.coalesce(executor));
        }
        // Wait for all to complete
        final results = await Future.wait(futures);
        // Should execute once for all 3 requests
        expect(executionCount, 1);
        expect(results.every((r) => r.data == 'batch-result-3'), true);
      });
      test('should execute immediately when max batch size reached', () async {
        int executionCount = 0;
        final futures = <Future<CFResult<String>>>[];
        Future<CFResult<String>> executor(int batchSize) async {
          executionCount++;
          return CFResult.success('batch-$batchSize');
        }
        // Add exactly maxBatchSize requests
        for (int i = 0; i < 5; i++) {
          futures.add(coalescer.coalesce(executor));
        }
        // Should execute immediately without waiting for window
        await Future.delayed(const Duration(milliseconds: 10));
        expect(executionCount, 1);
        final results = await Future.wait(futures);
        expect(results.every((r) => r.data == 'batch-5'), true);
      });
      test('should handle requests across multiple windows', () async {
        int executionCount = 0;
        Future<CFResult<String>> executor(int batchSize) async {
          executionCount++;
          return CFResult.success('batch-$executionCount-size-$batchSize');
        }
        // First batch - make requests concurrently
        final batch1Futures = [
          coalescer.coalesce(executor),
          coalescer.coalesce(executor),
        ];
        final batch1Results = await Future.wait(batch1Futures);
        // Wait for window to expire
        await Future.delayed(const Duration(milliseconds: 150));
        // Second batch
        final result3 = await coalescer.coalesce(executor);
        expect(executionCount, 2);
        expect(batch1Results[0].data, 'batch-1-size-2');
        expect(batch1Results[1].data, 'batch-1-size-2');
        expect(result3.data, 'batch-2-size-1');
      });
    });
    group('Error Handling', () {
      test('should propagate errors to all requests in batch', () async {
        final futures = <Future<CFResult<String>>>[];
        Future<CFResult<String>> failingExecutor(int batchSize) async {
          await Future.delayed(const Duration(milliseconds: 20));
          return CFResult.error('Batch execution failed');
        }
        for (int i = 0; i < 3; i++) {
          futures.add(coalescer.coalesce(failingExecutor));
        }
        final results = await Future.wait(futures);
        expect(results.every((r) => !r.isSuccess), true);
        expect(
            results.every((r) => r.error?.message == 'Batch execution failed'),
            true);
      });
      test('should handle executor exceptions', () async {
        final futures = <Future<CFResult<String>>>[];
        Future<CFResult<String>> throwingExecutor(int batchSize) async {
          throw Exception('Executor error');
        }
        for (int i = 0; i < 2; i++) {
          futures.add(coalescer.coalesce(throwingExecutor));
        }
        final results = await Future.wait(futures);
        expect(results.every((r) => !r.isSuccess), true);
        expect(
            results.every((r) => r.error?.message == 'Batch execution failed'),
            true);
      });
    });
    group('Cancellation', () {
      test('should cancel all pending requests', () async {
        final futures = <Future<CFResult<String>>>[];
        Future<CFResult<String>> slowExecutor(int batchSize) async {
          await Future.delayed(const Duration(seconds: 1));
          return CFResult.success('should-not-complete');
        }
        // Add requests but don't wait
        for (int i = 0; i < 3; i++) {
          futures.add(coalescer.coalesce(slowExecutor));
        }
        // Cancel before they execute
        coalescer.cancelAll();
        // Should be able to add new requests after cancellation
        final newResult = await coalescer.coalesce((batchSize) async {
          return CFResult.success('new-request');
        });
        expect(newResult.isSuccess, true);
        expect(newResult.data, 'new-request');
      });
    });
  });
}
