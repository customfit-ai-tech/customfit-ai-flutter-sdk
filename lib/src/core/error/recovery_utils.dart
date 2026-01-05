// lib/src/core/error/simplified_recovery_utils.dart
//
// Simplified utilities for recovery operations.
// Provides basic error handling utilities without complex caching.
//
// This file is part of the CustomFit SDK for Flutter.

import '../../infrastructure/logging/logger.dart';
import 'cf_result.dart';
import 'error_category.dart';

/// Simplified recovery utilities
class RecoveryUtils {
  /// Standard error result creation
  static CFResult<T> createErrorResult<T>(
    String message,
    String source,
    ErrorCategory category, {
    dynamic exception,
  }) {
    Logger.e('$source: $message');
    return CFResult.error(
      message,
      exception:
          exception is Exception ? exception : Exception(exception.toString()),
      category: category,
    );
  }
}

/// Basic recovery exception
class RecoveryException implements Exception {
  final String message;
  RecoveryException(this.message);

  @override
  String toString() => 'RecoveryException: $message';
}

/// Network exception
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
