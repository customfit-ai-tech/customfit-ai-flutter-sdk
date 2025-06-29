// lib/src/core/error/cf_result_extensions.dart
//
// Extensions and utilities for CFResult to provide consistent error handling
// patterns throughout the SDK. This file provides helper methods for validation,
// exception handling, and error recovery integration.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'cf_result.dart';
import 'error_category.dart';
import 'cf_error_code.dart';
import '../validation/input_validator.dart';
import '../../logging/logger.dart';

/// Extensions for CFResult to provide additional utility methods
extension CFResultExtensions<T> on CFResult<T> {
  /// Safely execute an operation and convert any exceptions to CFResult
  static CFResult<T> catching<T>(
    T Function() operation, {
    String? errorMessage,
    ErrorCategory category = ErrorCategory.internal,
    CFErrorCode? errorCode,
  }) {
    try {
      final result = operation();
      return CFResult.success(result);
    } catch (e) {
      return CFResult.error(
        errorMessage ?? 'Operation failed: $e',
        exception: e,
        category: category,
        errorCode: errorCode ?? CFErrorCode.internalUnknownError,
      );
    }
  }

  /// Safely execute an async operation and convert any exceptions to CFResult
  static Future<CFResult<T>> catchingAsync<T>(
    Future<T> Function() operation, {
    String? errorMessage,
    ErrorCategory category = ErrorCategory.internal,
    CFErrorCode? errorCode,
  }) async {
    try {
      final result = await operation();
      return CFResult.success(result);
    } catch (e) {
      return CFResult.error(
        errorMessage ?? 'Async operation failed: $e',
        exception: e,
        category: category,
        errorCode: errorCode ?? CFErrorCode.internalUnknownError,
      );
    }
  }

  /// Create CFResult from validation result
  static CFResult<T> fromValidation<T>(
    T? value,
    String? errorMessage, {
    ErrorCategory category = ErrorCategory.validation,
    CFErrorCode? errorCode,
  }) {
    if (value != null) {
      return CFResult.success(value);
    } else {
      return CFResult.error(
        errorMessage ?? 'Validation failed',
        category: category,
        errorCode: errorCode ?? CFErrorCode.validationInvalidFormat,
      );
    }
  }

  /// Create CFResult from boolean condition
  static CFResult<T> fromCondition<T>(
    bool condition,
    T value,
    String errorMessage, {
    ErrorCategory category = ErrorCategory.validation,
    CFErrorCode? errorCode,
  }) {
    if (condition) {
      return CFResult.success(value);
    } else {
      return CFResult.error(
        errorMessage,
        category: category,
        errorCode: errorCode ?? CFErrorCode.validationInvalidFormat,
      );
    }
  }

  /// Convert nullable value to CFResult
  static CFResult<T> fromNullable<T>(
    T? value,
    String errorMessage, {
    ErrorCategory category = ErrorCategory.validation,
    CFErrorCode? errorCode,
  }) {
    if (value != null) {
      return CFResult.success(value);
    } else {
      return CFResult.error(
        errorMessage,
        category: category,
        errorCode: errorCode ?? CFErrorCode.validationInvalidFormat,
      );
    }
  }

  /// Chain multiple CFResult operations with early termination on error
  static CFResult<R> chain<T1, T2, R>(
    CFResult<T1> result1,
    CFResult<T2> Function(T1) operation2,
    R Function(T1, T2) combiner,
  ) {
    if (!result1.isSuccess) {
      return CFResult.error(
        result1.getErrorMessage() ?? 'Chain operation failed',
        category: result1.error?.category ?? ErrorCategory.internal,
        errorCode: result1.error?.errorCode,
      );
    }

    final result2 = operation2(result1.getOrThrow());
    if (!result2.isSuccess) {
      return CFResult.error(
        result2.getErrorMessage() ?? 'Chain operation failed',
        category: result2.error?.category ?? ErrorCategory.internal,
        errorCode: result2.error?.errorCode,
      );
    }

    try {
      final combined = combiner(result1.getOrThrow(), result2.getOrThrow());
      return CFResult.success(combined);
    } catch (e) {
      return CFResult.error(
        'Chain combiner failed: $e',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalUnknownError,
      );
    }
  }

  /// Execute operation with timeout and convert to CFResult
  static Future<CFResult<T>> withTimeout<T>(
    Future<T> Function() operation,
    Duration timeout, {
    String? timeoutMessage,
    ErrorCategory category = ErrorCategory.network,
  }) async {
    try {
      final result = await operation().timeout(timeout);
      return CFResult.success(result);
    } on TimeoutException catch (e) {
      return CFResult.error(
        timeoutMessage ?? 'Operation timed out after ${timeout.inSeconds}s',
        exception: e,
        category: category,
        errorCode: CFErrorCode.networkTimeout,
      );
    } catch (e) {
      return CFResult.error(
        'Operation failed: $e',
        exception: e,
        category: category,
        errorCode: CFErrorCode.internalUnknownError,
      );
    }
  }

  /// Log error details if result is failure
  CFResult<T> logOnError({
    String? prefix,
    String source = 'CFResult',
  }) {
    if (!isSuccess && error != null) {
      final errorPrefix = prefix != null ? '$prefix: ' : '';
      final message =
          '$source: $errorPrefix${error!.message ?? 'Unknown error'}';

      if (error!.exception != null) {
        Logger.exception(error!.exception!, message);
      } else {
        Logger.e(message);
      }
    }
    return this;
  }

  /// Convert to void result (useful for operations that don't return meaningful values)
  CFResult<void> toVoid() {
    if (isSuccess) {
      return CFResult.success(null);
    } else {
      return CFResult.error(
        getErrorMessage() ?? 'Operation failed',
        exception: error?.exception,
        category: error?.category ?? ErrorCategory.internal,
        errorCode: error?.errorCode,
      );
    }
  }

  /// Provide alternative error message if current message is null or empty
  CFResult<T> withDefaultErrorMessage(String defaultMessage) {
    if (!isSuccess && (getErrorMessage()?.isEmpty ?? true)) {
      return CFResult.error(
        defaultMessage,
        exception: error?.exception,
        category: error?.category ?? ErrorCategory.internal,
        errorCode: error?.errorCode,
      );
    }
    return this;
  }

  /// Retry operation on failure with exponential backoff
  static Future<CFResult<T>> withRetry<T>(
    Future<CFResult<T>> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 100),
    double backoffMultiplier = 2.0,
    bool Function(CFError)? shouldRetry,
  }) async {
    var delay = initialDelay;
    CFResult<T>? lastResult;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        lastResult = await operation();

        if (lastResult.isSuccess) {
          return lastResult;
        }

        // Check if we should retry this error
        if (shouldRetry != null &&
            lastResult.error != null &&
            !shouldRetry(lastResult.error!)) {
          break;
        }

        // Don't retry validation errors by default
        if (lastResult.error?.category == ErrorCategory.validation) {
          break;
        }

        // Don't delay on last attempt
        if (attempt < maxAttempts) {
          await Future.delayed(delay);
          delay = Duration(
            milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
          );
        }
      } catch (e) {
        lastResult = CFResult.error(
          'Retry operation failed: $e',
          exception: e,
          category: ErrorCategory.internal,
          errorCode: CFErrorCode.internalUnknownError,
        );

        if (attempt < maxAttempts) {
          await Future.delayed(delay);
          delay = Duration(
            milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
          );
        }
      }
    }

    return lastResult ??
        CFResult.error(
          'Retry operation failed after $maxAttempts attempts',
          category: ErrorCategory.internal,
          errorCode: CFErrorCode.internalUnknownError,
        );
  }
}

/// Validation utilities that return CFResult instead of throwing exceptions
class CFResultValidation {
  /// Validate property key and return CFResult
  static CFResult<String> validatePropertyKey(String? key) {
    return CFResultExtensions.catching(
      () {
        final result = InputValidator.validatePropertyKey(key ?? '');
        if (result.isSuccess) {
          return result.getOrThrow();
        } else {
          throw ArgumentError(result.getErrorMessage());
        }
      },
      errorMessage: 'Property key validation failed',
      category: ErrorCategory.validation,
      errorCode: CFErrorCode.validationInvalidFormat,
    );
  }

  /// Validate property value and return CFResult
  static CFResult<dynamic> validatePropertyValue(dynamic value) {
    return CFResultExtensions.catching(
      () {
        final result = InputValidator.validatePropertyValue(value);
        if (result.isSuccess) {
          return result.getOrThrow();
        } else {
          throw ArgumentError(result.getErrorMessage());
        }
      },
      errorMessage: 'Property value validation failed',
      category: ErrorCategory.validation,
      errorCode: CFErrorCode.validationInvalidFormat,
    );
  }

  /// Validate event name and return CFResult
  static CFResult<String> validateEventName(String? eventName) {
    return CFResultExtensions.catching(
      () {
        final result = InputValidator.validateEventName(eventName ?? '');
        if (result.isSuccess) {
          return result.getOrThrow();
        } else {
          throw ArgumentError(result.getErrorMessage());
        }
      },
      errorMessage: 'Event name validation failed',
      category: ErrorCategory.validation,
      errorCode: CFErrorCode.validationInvalidFormat,
    );
  }

  /// Validate user ID and return CFResult
  static CFResult<String> validateUserId(String? userId) {
    return CFResultExtensions.catching(
      () {
        final result = InputValidator.validateUserId(userId ?? '');
        if (result.isSuccess) {
          return result.getOrThrow();
        } else {
          throw ArgumentError(result.getErrorMessage());
        }
      },
      errorMessage: 'User ID validation failed',
      category: ErrorCategory.validation,
      errorCode: CFErrorCode.validationInvalidFormat,
    );
  }

  /// Validate feature flag key and return CFResult
  static CFResult<String> validateFeatureFlagKey(String? flagKey) {
    return CFResultExtensions.catching(
      () {
        final result = InputValidator.validateFeatureFlagKey(flagKey ?? '');
        if (result.isSuccess) {
          return result.getOrThrow();
        } else {
          throw ArgumentError(result.getErrorMessage());
        }
      },
      errorMessage: 'Feature flag key validation failed',
      category: ErrorCategory.validation,
      errorCode: CFErrorCode.validationInvalidFormat,
    );
  }

  /// Validate multiple properties and return CFResult
  static CFResult<Map<String, dynamic>> validateProperties(
    Map<String, dynamic>? properties,
  ) {
    return CFResultExtensions.catching(
      () {
        final result = InputValidator.validateProperties(properties ?? {});
        if (result.isSuccess) {
          return result.getOrThrow();
        } else {
          throw ArgumentError(result.getErrorMessage());
        }
      },
      errorMessage: 'Properties validation failed',
      category: ErrorCategory.validation,
      errorCode: CFErrorCode.validationInvalidFormat,
    );
  }
}

/// Error recovery coordinator for centralized error handling strategies
class ErrorRecoveryCoordinator {
  /// Execute operation with automatic recovery strategies
  static Future<CFResult<T>> withRecovery<T>(
    Future<CFResult<T>> Function() operation, {
    T? fallbackValue,
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 100),
    bool enableFallback = true,
    String? operationName,
  }) async {
    final opName = operationName ?? 'Operation';

    // Try with retry mechanism
    final result = await CFResultExtensions.withRetry(
      operation,
      maxAttempts: maxRetries,
      initialDelay: initialDelay,
      shouldRetry: (error) {
        // Don't retry validation or authentication errors
        return error.category != ErrorCategory.validation &&
            error.category != ErrorCategory.authentication;
      },
    );

    // If still failed and fallback is available
    if (!result.isSuccess && enableFallback && fallbackValue != null) {
      Logger.w(
        '$opName failed after retries, using fallback value: ${result.getErrorMessage()}',
      );
      return CFResult.success(fallbackValue);
    }

    return result;
  }

  /// Execute operation with circuit breaker pattern
  static Future<CFResult<T>> withCircuitBreaker<T>(
    Future<CFResult<T>> Function() operation, {
    required String circuitName,
    int failureThreshold = 5,
    Duration timeout = const Duration(seconds: 30),
    T? fallbackValue,
  }) async {
    // This is a simplified circuit breaker implementation
    // In a real implementation, you'd track failures per circuit name

    try {
      final result = await operation().timeout(timeout);
      return result;
    } on TimeoutException {
      if (fallbackValue != null) {
        Logger.w('Circuit breaker timeout for $circuitName, using fallback');
        return CFResult.success(fallbackValue);
      }
      return CFResult.error(
        'Circuit breaker timeout for $circuitName',
        category: ErrorCategory.network,
        errorCode: CFErrorCode.networkTimeout,
      );
    } catch (e) {
      if (fallbackValue != null) {
        Logger.w(
            'Circuit breaker failure for $circuitName, using fallback: $e');
        return CFResult.success(fallbackValue);
      }
      return CFResult.error(
        'Circuit breaker failure for $circuitName: $e',
        exception: e,
        category: ErrorCategory.network,
      );
    }
  }
}
