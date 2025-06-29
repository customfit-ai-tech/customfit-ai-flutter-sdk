import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/circuit_breaker.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CircuitBreaker Tests', () {
    late CircuitBreaker circuitBreaker;
    const String testOperationKey = 'test_operation';
    const int failureThreshold = 3;
    const int resetTimeoutMs = 1000;
    setUp(() {
      // Reset all circuit breakers before each test
    SharedPreferences.setMockInitialValues({});
      CircuitBreaker.resetAll();
      circuitBreaker = CircuitBreaker.getInstance(
        testOperationKey,
        failureThreshold,
        resetTimeoutMs,
      );
    });
    tearDown(() {
      CircuitBreaker.resetAll();
    PreferencesService.reset();
    });
    group('Initialization Tests', () {
      test('should create circuit breaker instance', () {
        expect(circuitBreaker, isNotNull);
      });
      test('should return same instance for same operation key', () {
        final circuitBreaker1 = CircuitBreaker.getInstance(
          testOperationKey,
          failureThreshold,
          resetTimeoutMs,
        );
        final circuitBreaker2 = CircuitBreaker.getInstance(
          testOperationKey,
          failureThreshold,
          resetTimeoutMs,
        );
        expect(circuitBreaker1, same(circuitBreaker2));
      });
      test('should create different instances for different operation keys',
          () {
        final circuitBreaker1 = CircuitBreaker.getInstance(
          'operation1',
          failureThreshold,
          resetTimeoutMs,
        );
        final circuitBreaker2 = CircuitBreaker.getInstance(
          'operation2',
          failureThreshold,
          resetTimeoutMs,
        );
        expect(circuitBreaker1, isNot(same(circuitBreaker2)));
      });
    });
    group('Closed State Tests', () {
      test('should execute function successfully when circuit is closed',
          () async {
        String? result;
        await circuitBreaker.executeWithCircuitBreaker(() async {
          result = 'success';
          return 'success';
        });
        expect(result, equals('success'));
      });
      test('should handle exceptions without opening circuit below threshold',
          () async {
        // Execute 2 failing operations (below threshold of 3)
        for (int i = 0; i < 2; i++) {
          try {
            await circuitBreaker.executeWithCircuitBreaker(() async {
              throw Exception('Test error $i');
            });
          } catch (e) {
            expect(e.toString(), contains('Test error $i'));
          }
        }
        // Circuit should still be closed, so this should execute
        String? result;
        await circuitBreaker.executeWithCircuitBreaker(() async {
          result = 'still working';
          return 'still working';
        });
        expect(result, equals('still working'));
      });
      test('should open circuit after reaching failure threshold', () async {
        // Execute 3 failing operations to reach threshold
        for (int i = 0; i < failureThreshold; i++) {
          try {
            await circuitBreaker.executeWithCircuitBreaker(() async {
              throw Exception('Test error $i');
            });
          } catch (e) {
            expect(e.toString(), contains('Test error $i'));
          }
        }
        // Next call should fail with CircuitOpenException
        expect(
          () => circuitBreaker.executeWithCircuitBreaker(() async {
            return 'should not execute';
          }),
          throwsA(isA<CircuitOpenException>()),
        );
      });
    });
    group('Open State Tests', () {
      Future<void> openCircuit() async {
        // Force circuit to open by causing failures
        for (int i = 0; i < failureThreshold; i++) {
          try {
            await circuitBreaker.executeWithCircuitBreaker(() async {
              throw Exception('Force open');
            });
          } catch (e) {
            // Expected
          }
        }
      }
      test('should throw CircuitOpenException when circuit is open', () async {
        await openCircuit();
        expect(
          () => circuitBreaker.executeWithCircuitBreaker(() async {
            return 'should not execute';
          }),
          throwsA(isA<CircuitOpenException>()),
        );
      });
      test('should use fallback when circuit is open and fallback provided',
          () async {
        await openCircuit();
        final result = await circuitBreaker.executeWithCircuitBreaker(
          () async {
            return 'should not execute';
          },
          fallback: 'fallback value',
        );
        expect(result, equals('fallback value'));
      });
      test('should transition to half-open after timeout', () async {
        await openCircuit();
        // Wait for reset timeout
        await Future.delayed(const Duration(milliseconds: resetTimeoutMs + 100));
        // This should now execute (half-open state)
        String? result;
        await circuitBreaker.executeWithCircuitBreaker(() async {
          result = 'half-open test';
          return 'half-open test';
        });
        expect(result, equals('half-open test'));
      });
    });
    group('Half-Open State Tests', () {
      Future<void> openAndWaitForHalfOpen() async {
        // Open circuit
        for (int i = 0; i < failureThreshold; i++) {
          try {
            await circuitBreaker.executeWithCircuitBreaker(() async {
              throw Exception('Force open');
            });
          } catch (e) {
            // Expected
          }
        }
        // Wait for reset timeout to enter half-open state
        await Future.delayed(const Duration(milliseconds: resetTimeoutMs + 100));
      }
      test('should close circuit on successful operation in half-open state',
          () async {
        await openAndWaitForHalfOpen();
        // First call should succeed and close circuit
        await circuitBreaker.executeWithCircuitBreaker(() async {
          return 'success';
        });
        // Second call should also succeed (circuit is now closed)
        String? result;
        await circuitBreaker.executeWithCircuitBreaker(() async {
          result = 'circuit closed';
          return 'circuit closed';
        });
        expect(result, equals('circuit closed'));
      });
      test('should reopen circuit on failure in half-open state', () async {
        await openAndWaitForHalfOpen();
        // First call fails, should reopen circuit
        try {
          await circuitBreaker.executeWithCircuitBreaker(() async {
            throw Exception('Half-open failure');
          });
        } catch (e) {
          expect(e.toString(), contains('Half-open failure'));
        }
        // Next call should immediately fail with CircuitOpenException
        expect(
          () => circuitBreaker.executeWithCircuitBreaker(() async {
            return 'should not execute';
          }),
          throwsA(isA<CircuitOpenException>()),
        );
      });
    });
    group('Fallback Handling Tests', () {
      test('should use fallback on failure when circuit is closed', () async {
        final result = await circuitBreaker.executeWithCircuitBreaker(
          () async {
            throw Exception('Test failure');
          },
          fallback: 'fallback used',
        );
        expect(result, equals('fallback used'));
      });
      test('should use fallback on circuit open', () async {
        // Open circuit
        for (int i = 0; i < failureThreshold; i++) {
          try {
            await circuitBreaker.executeWithCircuitBreaker(() async {
              throw Exception('Force open');
            });
          } catch (e) {
            // Expected
          }
        }
        final result = await circuitBreaker.executeWithCircuitBreaker(
          () async {
            return 'should not execute';
          },
          fallback: 'circuit open fallback',
        );
        expect(result, equals('circuit open fallback'));
      });
      test('should handle null fallback correctly', () async {
        expect(
          () => circuitBreaker.executeWithCircuitBreaker(() async {
            throw Exception('Test failure');
          }),
          throwsA(isA<Exception>()),
        );
      });
    });
    group('Reset Functionality Tests', () {
      test('should reset circuit state manually', () async {
        // Open circuit
        for (int i = 0; i < failureThreshold; i++) {
          try {
            await circuitBreaker.executeWithCircuitBreaker(() async {
              throw Exception('Force open');
            });
          } catch (e) {
            // Expected
          }
        }
        // Verify circuit is open
        expect(
          () => circuitBreaker.executeWithCircuitBreaker(() async {
            return 'should not execute';
          }),
          throwsA(isA<CircuitOpenException>()),
        );
        // Reset circuit
        circuitBreaker.reset();
        // Should now work
        String? result;
        await circuitBreaker.executeWithCircuitBreaker(() async {
          result = 'reset successful';
          return 'reset successful';
        });
        expect(result, equals('reset successful'));
      });
      test('should reset all circuit breakers', () async {
        final cb1 = CircuitBreaker.getInstance('op1', 2, 1000);
        final cb2 = CircuitBreaker.getInstance('op2', 2, 1000);
        // Open both circuits
        for (final cb in [cb1, cb2]) {
          for (int i = 0; i < 2; i++) {
            try {
              await cb.executeWithCircuitBreaker(() async {
                throw Exception('Force open');
              });
            } catch (e) {
              // Expected
            }
          }
        }
        // Reset all
        CircuitBreaker.resetAll();
        // Get new instances (old ones should be cleared)
        final newCb1 = CircuitBreaker.getInstance('op1', 2, 1000);
        final newCb2 = CircuitBreaker.getInstance('op2', 2, 1000);
        // Both should work
        for (final cb in [newCb1, newCb2]) {
          String? result;
          await cb.executeWithCircuitBreaker(() async {
            result = 'reset all successful';
            return 'reset all successful';
          });
          expect(result, equals('reset all successful'));
        }
      });
    });
    group('Error Handling Tests', () {
      test('should handle different exception types', () async {
        final exceptions = [
          Exception('Standard exception'),
          ArgumentError('Argument error'),
          StateError('State error'),
          const FormatException('Format exception'),
        ];
        for (final exception in exceptions) {
          expect(
            () => circuitBreaker.executeWithCircuitBreaker(() async {
              throw exception;
            }),
            throwsA(same(exception)),
          );
        }
      });
      test('should handle async exceptions correctly', () async {
        expect(
          () => circuitBreaker.executeWithCircuitBreaker(() async {
            await Future.delayed(const Duration(milliseconds: 10));
            throw Exception('Async exception');
          }),
          throwsA(isA<Exception>()),
        );
      });
      test('should handle timeout scenarios', () async {
        // This test ensures the circuit breaker doesn't interfere with timeouts
        expect(
          () => circuitBreaker.executeWithCircuitBreaker(() async {
            await Future.delayed(const Duration(milliseconds: 100));
            throw TimeoutException('Operation timed out', const Duration(seconds: 1));
          }),
          throwsA(isA<TimeoutException>()),
        );
      });
    });
    group('Concurrent Access Tests', () {
      test('should handle concurrent operations correctly', () async {
        final futures = <Future>[];
        // Launch multiple concurrent operations
        for (int i = 0; i < 10; i++) {
          futures.add(
            circuitBreaker.executeWithCircuitBreaker(() async {
              await Future.delayed(const Duration(milliseconds: 10));
              return 'concurrent-$i';
            }),
          );
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(10));
        for (int i = 0; i < 10; i++) {
          expect(results[i], equals('concurrent-$i'));
        }
      });
      test('should handle concurrent failures correctly', () async {
        final futures = <Future>[];
        // Launch multiple concurrent failing operations
        for (int i = 0; i < 5; i++) {
          futures.add(
            circuitBreaker.executeWithCircuitBreaker(
              () async {
                await Future.delayed(const Duration(milliseconds: 10));
                throw Exception('Concurrent failure $i');
              },
              fallback: 'fallback-$i',
            ),
          );
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(5));
        for (int i = 0; i < 5; i++) {
          expect(results[i], equals('fallback-$i'));
        }
      });
    });
    group('Edge Cases Tests', () {
      test('should handle zero failure threshold', () async {
        final zeroThresholdCB = CircuitBreaker.getInstance(
          'zero_threshold',
          0,
          1000,
        );
        // Should immediately open on first failure
        expect(
          () => zeroThresholdCB.executeWithCircuitBreaker(() async {
            throw Exception('First failure');
          }),
          throwsA(isA<Exception>()),
        );
        // Execute the first failure to open the circuit
        try {
          await zeroThresholdCB.executeWithCircuitBreaker(() async {
            throw Exception('First failure');
          });
        } catch (e) {
          // Expected
        }
        // Next call should be circuit open
        expect(
          () => zeroThresholdCB.executeWithCircuitBreaker(() async {
            return 'should not execute';
          }),
          throwsA(isA<CircuitOpenException>()),
        );
      });
      test('should handle very short reset timeout', () async {
        final shortTimeoutCB = CircuitBreaker.getInstance(
          'short_timeout',
          2,
          1, // 1ms timeout
        );
        // Open circuit
        for (int i = 0; i < 2; i++) {
          try {
            await shortTimeoutCB.executeWithCircuitBreaker(() async {
              throw Exception('Force open');
            });
          } catch (e) {
            // Expected
          }
        }
        // Wait minimal time
        await Future.delayed(const Duration(milliseconds: 10));
        // Should be able to execute
        String? result;
        await shortTimeoutCB.executeWithCircuitBreaker(() async {
          result = 'short timeout test';
          return 'short timeout test';
        });
        expect(result, equals('short timeout test'));
      });
      test('should handle operations returning different types', () async {
        // String return type
        final stringResult =
            await circuitBreaker.executeWithCircuitBreaker(() async {
          return 'string result';
        });
        expect(stringResult, equals('string result'));
        // Integer return type
        final intResult =
            await circuitBreaker.executeWithCircuitBreaker(() async {
          return 42;
        });
        expect(intResult, equals(42));
        // Map return type
        final mapResult =
            await circuitBreaker.executeWithCircuitBreaker(() async {
          return {'key': 'value'};
        });
        expect(mapResult, equals({'key': 'value'}));
        // List return type
        final listResult =
            await circuitBreaker.executeWithCircuitBreaker(() async {
          return [1, 2, 3];
        });
        expect(listResult, equals([1, 2, 3]));
      });
      test('should handle null return values', () async {
        final result = await circuitBreaker.executeWithCircuitBreaker(() async {
          return null;
        });
        expect(result, isNull);
      });
    });
    group('CircuitOpenException Tests', () {
      test('should create exception with message', () {
        const message = 'Test circuit open message';
        final exception = CircuitOpenException(message);
        expect(exception.message, equals(message));
        expect(exception.toString(), equals(message));
      });
      test('should be throwable and catchable', () {
        const message = 'Circuit is open';
        expect(
          () => throw CircuitOpenException(message),
          throwsA(
            allOf(
              isA<CircuitOpenException>(),
              predicate<CircuitOpenException>((e) => e.message == message),
            ),
          ),
        );
      });
    });
  });
}
