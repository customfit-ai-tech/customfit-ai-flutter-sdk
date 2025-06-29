// lib/src/core/util/retry_util_improved.dart
//
// Improved retry utility with CFResult error handling for the CustomFit SDK.
// Provides retry logic with exponential backoff, circuit breaker integration,
// and detailed error context propagation.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import '../../logging/logger.dart';
import '../error/cf_result.dart';
import '../error/error_category.dart';
import '../error/cf_error_code.dart';
import 'circuit_breaker.dart';

/// Information about retry attempts
class RetryAttemptInfo {
  final int attemptNumber;
  final DateTime attemptTime;
  final String? errorMessage;
  final int delayMs;

  RetryAttemptInfo({
    required this.attemptNumber,
    required this.attemptTime,
    this.errorMessage,
    required this.delayMs,
  });

  Map<String, dynamic> toJson() => {
        'attemptNumber': attemptNumber,
        'attemptTime': attemptTime.toIso8601String(),
        'errorMessage': errorMessage,
        'delayMs': delayMs,
      };
}

/// Improved retry utility with CFResult error handling
class RetryUtil {
  /// Executes [block] with retry logic and returns CFResult.
  ///
  /// - [maxAttempts]: Maximum number of attempts.
  /// - [initialDelayMs]: Initial delay between retries in milliseconds.
  /// - [maxDelayMs]: Maximum delay between retries in milliseconds.
  /// - [backoffMultiplier]: Multiplier for exponential backoff.
  /// - [retryOn]: Optional predicate to determine if retry should happen for an exception.
  /// - [block]: The asynchronous function to execute.
  ///
  /// Returns CFResult with either the successful value or detailed error information.
  static Future<CFResult<T>> withRetryResult<T>({
    required int maxAttempts,
    required int initialDelayMs,
    required int maxDelayMs,
    required double backoffMultiplier,
    bool Function(Exception)? retryOn,
    required Future<T> Function() block,
  }) async {
    if (maxAttempts <= 0) {
      return CFResult.error(
        'Invalid max attempts: $maxAttempts',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidType,
        context: {'maxAttempts': maxAttempts},
      );
    }

    int attempt = 0;
    int currentDelay = initialDelayMs;
    Exception? lastException;
    StackTrace? lastStackTrace;
    final attemptHistory = <RetryAttemptInfo>[];

    while (attempt < maxAttempts) {
      try {
        final result = await block();

        if (attempt > 0) {
          Logger.d('Retry succeeded on attempt ${attempt + 1}');
        }

        return CFResult.success(result);
      } catch (e, stackTrace) {
        final exception = e is Exception ? e : Exception(e.toString());
        lastException = exception;
        lastStackTrace = stackTrace;
        attempt++;

        attemptHistory.add(RetryAttemptInfo(
          attemptNumber: attempt,
          attemptTime: DateTime.now(),
          errorMessage: e.toString(),
          delayMs: attempt < maxAttempts ? currentDelay : 0,
        ));

        // Check if we should retry based on the predicate
        if (retryOn != null && !retryOn(exception)) {
          Logger.w(
              'Exception does not meet retry criteria, failing immediately: $e');

          return CFResult.error(
            'Operation failed: exception does not meet retry criteria',
            exception: exception,
            category: ErrorCategory.internal,
            errorCode: CFErrorCode.internalUnknownError,
            context: {
              'attemptsMade': attempt,
              'maxAttempts': maxAttempts,
              'retryConditionFailed': true,
              'attemptHistory': attemptHistory.map((a) => a.toJson()).toList(),
              'stackTrace': stackTrace.toString(),
            },
          );
        }

        if (attempt < maxAttempts) {
          Logger.w('Attempt $attempt failed, retrying in $currentDelay ms: $e');
          await Future.delayed(Duration(milliseconds: currentDelay));
          currentDelay = (currentDelay * backoffMultiplier).toInt();
          if (currentDelay > maxDelayMs) {
            currentDelay = maxDelayMs;
          }
        }
      }
    }

    // All attempts failed
    return CFResult.error(
      'All retry attempts failed: ${lastException?.toString() ?? "Unknown error"}',
      exception: lastException,
      category: ErrorCategory.internal,
      errorCode: CFErrorCode.internalUnknownError,
      context: {
        'attemptsMade': attempt,
        'maxAttempts': maxAttempts,
        'totalDelayMs':
            attemptHistory.fold<int>(0, (sum, a) => sum + a.delayMs),
        'attemptHistory': attemptHistory.map((a) => a.toJson()).toList(),
        'stackTrace': lastStackTrace?.toString(),
      },
    );
  }

  /// Executes [block] with timeout and returns CFResult.
  ///
  /// - [timeoutMs]: Timeout in milliseconds.
  /// - [block]: The asynchronous function to execute.
  ///
  /// Returns CFResult with either the successful value or timeout error.
  static Future<CFResult<T>> withTimeoutResult<T>({
    required int timeoutMs,
    required Future<T> Function() block,
  }) async {
    if (timeoutMs <= 0) {
      return CFResult.error(
        'Invalid timeout: $timeoutMs ms',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidType,
        context: {'timeoutMs': timeoutMs},
      );
    }

    try {
      final completer = Completer<CFResult<T>>();
      final startTime = DateTime.now();

      // Create a timeout timer
      final timer = Timer(Duration(milliseconds: timeoutMs), () {
        if (!completer.isCompleted) {
          final elapsed = DateTime.now().difference(startTime).inMilliseconds;
          Logger.w('Operation timed out after $elapsed ms');

          completer.complete(CFResult.error(
            'Operation timed out after $timeoutMs ms',
            category: ErrorCategory.network,
            errorCode: CFErrorCode.networkTimeout,
            context: {
              'timeoutMs': timeoutMs,
              'elapsedMs': elapsed,
              'startTime': startTime.toIso8601String(),
            },
          ));
        }
      });

      // Execute the block
      block().then((result) {
        if (!completer.isCompleted) {
          timer.cancel();
          final elapsed = DateTime.now().difference(startTime).inMilliseconds;

          Logger.d('Operation completed in $elapsed ms');
          completer.complete(CFResult.success(result));
        }
      }).catchError((e, stackTrace) {
        if (!completer.isCompleted) {
          timer.cancel();
          final elapsed = DateTime.now().difference(startTime).inMilliseconds;

          Logger.e('Operation failed after $elapsed ms: $e');
          completer.complete(CFResult.error(
            'Operation failed: ${e.toString()}',
            exception: e is Exception ? e : Exception(e.toString()),
            category: ErrorCategory.internal,
            errorCode: CFErrorCode.internalUnknownError,
            context: {
              'elapsedMs': elapsed,
              'startTime': startTime.toIso8601String(),
              'stackTrace': stackTrace.toString(),
            },
          ));
        }
      });

      return completer.future;
    } catch (e, stackTrace) {
      Logger.e('Error setting up timeout: $e');
      return CFResult.error(
        'Failed to set up timeout: ${e.toString()}',
        exception: e is Exception ? e : Exception(e.toString()),
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalUnknownError,
        context: {
          'operation': 'setup_timeout',
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  /// Executes a block with circuit breaker protection and returns CFResult.
  ///
  /// - [operationKey]: Unique identifier for this operation.
  /// - [failureThreshold]: Number of failures before opening circuit.
  /// - [resetTimeoutMs]: Time in ms before allowing retries when circuit open.
  /// - [block]: The asynchronous function to execute.
  ///
  /// Returns CFResult with either the successful value or circuit breaker error.
  static Future<CFResult<T>> withCircuitBreakerResult<T>({
    required String operationKey,
    required int failureThreshold,
    required int resetTimeoutMs,
    required Future<T> Function() block,
  }) async {
    try {
      final circuitBreaker = CircuitBreaker.getInstance(
        operationKey,
        failureThreshold,
        resetTimeoutMs,
      );

      try {
        final result = await circuitBreaker.executeWithCircuitBreaker(block);
        return CFResult.success(result);
      } catch (e, stackTrace) {
        // Check if it's a circuit open exception
        final isCircuitOpen = e is CircuitOpenException;

        return CFResult.error(
          'Operation failed: ${e.toString()}',
          exception: e is Exception ? e : Exception(e.toString()),
          category: ErrorCategory.internal,
          errorCode: isCircuitOpen
              ? CFErrorCode.internalCircuitBreakerOpen
              : CFErrorCode.internalUnknownError,
          context: {
            'operationKey': operationKey,
            'circuitOpen': isCircuitOpen,
            'failureThreshold': failureThreshold,
            'resetTimeoutMs': resetTimeoutMs,
            'stackTrace': stackTrace.toString(),
          },
        );
      }
    } catch (e, stackTrace) {
      Logger.e('Error in circuit breaker setup: $e');
      return CFResult.error(
        'Failed to set up circuit breaker: ${e.toString()}',
        exception: e is Exception ? e : Exception(e.toString()),
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalUnknownError,
        context: {
          'operation': 'setup_circuit_breaker',
          'operationKey': operationKey,
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  /// Runs multiple operations in parallel and returns CFResult.
  ///
  /// - [operations]: List of async operations to run in parallel.
  /// - [continueOnError]: Whether to continue if an operation fails.
  ///
  /// Returns CFResult with list of results (including partial failures if continueOnError is true).
  static Future<CFResult<List<T>>> runParallelResult<T>({
    required List<Future<T> Function()> operations,
    bool continueOnError = true,
  }) async {
    if (operations.isEmpty) {
      return CFResult.error(
        'No operations provided',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationMissingRequiredField,
        context: {'operationCount': 0},
      );
    }

    try {
      final futures = <Future<_OperationResult<T>>>[];
      final startTime = DateTime.now();

      for (var i = 0; i < operations.length; i++) {
        futures.add(
            _executeOperationWithResult(operations[i], i, continueOnError));
      }

      final results = await Future.wait(futures);
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      // Check if all operations succeeded
      final failures = results.where((r) => !r.isSuccess).toList();

      if (failures.isEmpty) {
        // All succeeded
        final values = results.map((r) => r.value!).toList();
        Logger.d(
            'All ${operations.length} parallel operations succeeded in $elapsed ms');
        return CFResult.success(values);
      }

      if (!continueOnError) {
        // Failed fast on first error
        final firstFailure = failures.first;
        return CFResult.error(
          'Parallel operation ${firstFailure.index} failed: ${firstFailure.error}',
          exception: firstFailure.exception,
          category: ErrorCategory.internal,
          errorCode: CFErrorCode.internalUnknownError,
          context: {
            'failedOperationIndex': firstFailure.index,
            'totalOperations': operations.length,
            'elapsedMs': elapsed,
            'continueOnError': false,
          },
        );
      }

      // Partial success/failure
      final successCount = results.where((r) => r.isSuccess).length;
      final failureDetails = failures
          .map((f) => {
                'index': f.index,
                'error': f.error,
              })
          .toList();

      return CFResult.error(
        '$failureDetails operations failed out of ${operations.length}',
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalUnknownError,
        context: {
          'totalOperations': operations.length,
          'successCount': successCount,
          'failureCount': failures.length,
          'failures': failureDetails,
          'elapsedMs': elapsed,
          'continueOnError': true,
          'partialResults': results
              .where((r) => r.isSuccess)
              .map((r) => {'index': r.index, 'success': true})
              .toList(),
        },
      );
    } catch (e, stackTrace) {
      Logger.e('Error running parallel operations: $e');
      // Try to determine which operation failed
      int? failedIndex;
      final errorMessage = e.toString();
      if (errorMessage.contains('Operation') &&
          errorMessage.contains('failed')) {
        // Extract operation number from error message like "Operation 2 failed"
        final match =
            RegExp(r'Operation (\d+) failed').firstMatch(errorMessage);
        if (match != null) {
          failedIndex = int.tryParse(match.group(1) ?? '') ?? 1;
          failedIndex = failedIndex - 1; // Convert to 0-based index
        }
      }

      return CFResult.error(
        'Failed to run parallel operations: ${e.toString()}',
        exception: e is Exception ? e : Exception(e.toString()),
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalUnknownError,
        context: {
          'operation': 'run_parallel',
          'operationCount': operations.length,
          'continueOnError': continueOnError,
          if (failedIndex != null) 'failedOperationIndex': failedIndex,
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  /// Helper to execute an operation and wrap in result
  static Future<_OperationResult<T>> _executeOperationWithResult<T>(
    Future<T> Function() operation,
    int index,
    bool continueOnError,
  ) async {
    try {
      final result = await operation();
      return _OperationResult.success(result, index);
    } catch (e) {
      if (!continueOnError) {
        rethrow;
      }
      return _OperationResult.failure(
        e.toString(),
        e is Exception ? e : Exception(e.toString()),
        index,
      );
    }
  }
}

/// Internal class for operation results
class _OperationResult<T> {
  final T? value;
  final String? error;
  final Exception? exception;
  final int index;
  final bool isSuccess;

  _OperationResult.success(this.value, this.index)
      : error = null,
        exception = null,
        isSuccess = true;

  _OperationResult.failure(this.error, this.exception, this.index)
      : value = null,
        isSuccess = false;
}
