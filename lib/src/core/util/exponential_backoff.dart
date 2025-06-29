import 'dart:async';
import 'dart:math';

import '../../logging/logger.dart';
import '../error/cf_error_code.dart';
import '../error/cf_result.dart';

/// Exponential backoff retry configuration
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final double jitterFactor;
  final Set<CFErrorCode> retryableErrors;

  static Set<CFErrorCode> get defaultRetryableErrors => {
        CFErrorCode.networkTimeout,
        CFErrorCode.networkConnectionLost,
        CFErrorCode.httpTooManyRequests,
        CFErrorCode.httpServiceUnavailable,
        CFErrorCode.httpGatewayTimeout,
        CFErrorCode.httpInternalServerError,
        CFErrorCode.httpBadGateway,
      };

  RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 100),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.jitterFactor = 0.1,
    Set<CFErrorCode>? retryableErrors,
  }) : retryableErrors = retryableErrors ?? defaultRetryableErrors;
}

/// Exponential backoff retry utility
class ExponentialBackoff {
  static final _random = Random();

  /// Execute operation with exponential backoff retry
  static Future<CFResult<T>> retry<T>({
    required Future<CFResult<T>> Function() operation,
    required String operationName,
    RetryConfig? config,
  }) async {
    config ??= RetryConfig();
    int attempt = 0;
    Duration nextDelay = config.initialDelay;

    while (attempt < config.maxAttempts) {
      attempt++;

      try {
        // Only log retry attempts (not the first attempt)
        if (attempt > 1) {
          Logger.d('$operationName - Retry attempt $attempt of ${config.maxAttempts}');
        }

        final result = await operation();

        if (result.isSuccess) {
          if (attempt > 1) {
            Logger.i('$operationName - Succeeded after $attempt attempts');
          }
          return result;
        }

        // Check if error is retryable
        final error = result.error;
        if (error == null ||
            !config.retryableErrors.contains(error.errorCode)) {
          // Enhanced logging for non-retryable errors
          if (error != null) {
            Logger.w(
                '$operationName - Non-retryable error: ${error.errorCode.name}');

            // Log additional context for better debugging
            if (error.context != null && error.context!.isNotEmpty) {
              Logger.w('$operationName - Error context: ${error.context}');

              // Special handling for HTTP errors with response body
              if (error.context!.containsKey('response')) {
                Logger.e(
                    '$operationName - Server response: ${error.context!['response']}');
              }
            }

            if (error.message != null && error.message!.isNotEmpty) {
              Logger.w('$operationName - Error message: ${error.message}');
            }
          }
          return result;
        }

        // Don't retry if this was the last attempt
        if (attempt >= config.maxAttempts) {
          Logger.e('$operationName - Failed after $attempt attempts');
          return result;
        }

        // Calculate delay with jitter
        final jitter = (nextDelay.inMilliseconds *
                config.jitterFactor *
                (2 * _random.nextDouble() - 1))
            .round();
        final delayWithJitter =
            Duration(milliseconds: nextDelay.inMilliseconds + jitter);

        Logger.d(
            '$operationName - Retrying after ${delayWithJitter.inMilliseconds}ms (attempt $attempt failed with ${error.name})');

        // Special handling for rate limiting
        if (error.errorCode == CFErrorCode.httpTooManyRequests) {
          // For 429 errors, use a longer delay
          const rateLimitDelay = Duration(seconds: 60);
          Logger.w(
              '$operationName - Rate limited, waiting ${rateLimitDelay.inSeconds}s before retry');
          await Future.delayed(rateLimitDelay);
        } else {
          await Future.delayed(delayWithJitter);
        }

        // Calculate next delay with exponential backoff
        nextDelay = Duration(
          milliseconds: min(
            (nextDelay.inMilliseconds * config.backoffMultiplier).round(),
            config.maxDelay.inMilliseconds,
          ),
        );
      } catch (e) {
        Logger.e(
            '$operationName - Unexpected error during attempt $attempt: $e');

        if (attempt >= config.maxAttempts) {
          return CFResult.error(
            'Operation failed after $attempt attempts: $e',
            exception: e,
            errorCode: CFErrorCode.internalUnknownError,
          );
        }

        // Wait before retry for unexpected errors
        await Future.delayed(nextDelay);

        // Calculate next delay
        nextDelay = Duration(
          milliseconds: min(
            (nextDelay.inMilliseconds * config.backoffMultiplier).round(),
            config.maxDelay.inMilliseconds,
          ),
        );
      }
    }

    // Should not reach here, but just in case
    return CFResult.error(
      '$operationName failed after ${config.maxAttempts} attempts',
      errorCode: CFErrorCode.internalUnknownError,
    );
  }

  /// Execute operation with simple retry (no backoff)
  static Future<CFResult<T>> retrySimple<T>({
    required Future<CFResult<T>> Function() operation,
    required String operationName,
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    return retry(
      operation: operation,
      operationName: operationName,
      config: RetryConfig(
        maxAttempts: maxAttempts,
        initialDelay: delay,
        backoffMultiplier: 1.0, // No backoff
        maxDelay: delay,
        jitterFactor: 0.0, // No jitter
      ),
    );
  }
}
