// lib/src/core/error/error_handler.dart
//
// Centralized error handling utility with categorization, rate-limiting, and reporting.
// Provides consistent error handling across the SDK with severity levels,
// error categorization, and rate limiting to prevent log spam.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'error_category.dart';
import 'error_severity.dart';

/// Enhanced error information with recovery suggestions
class ErrorInfo {
  final String message;
  final ErrorCategory category;
  final ErrorSeverity severity;
  final String? recoverySuggestion;
  final Map<String, dynamic>? context;
  final dynamic exception;

  ErrorInfo({
    required this.message,
    required this.category,
    required this.severity,
    this.recoverySuggestion,
    this.context,
    this.exception,
  });
}

/// Centralized error handling utility with
/// categorization, rate-limiting, and reporting.
class ErrorHandler {
  static final Map<String, int> _errorCounts = {};
  static const int _maxLogRate = 10;

  /// Handles and logs an exception with actionable recovery suggestions
  static ErrorInfo handleExceptionWithRecovery(
    dynamic exception,
    String message, {
    String source = 'unknown',
    ErrorSeverity severity = ErrorSeverity.medium,
    Map<String, dynamic>? context,
  }) {
    final category = _categorizeException(exception);
    final recoverySuggestion = _getRecoverySuggestion(category, exception);
    final enhanced = _buildEnhancedErrorMessage(
        message, source, severity, category, recoverySuggestion);

    final key = '${exception.runtimeType}:$source:$message';
    final count = (_errorCounts[key] ?? 0) + 1;
    _errorCounts[key] = count;

    if (count <= _maxLogRate) {
      _logBySeverity(enhanced, severity);
    } else if (count == _maxLogRate + 1) {
      debugPrint(
          'WARN: Rate limiting similar error: $key. Further occurrences won\'t be logged.');
    }

    return ErrorInfo(
      message: message,
      category: category,
      severity: severity,
      recoverySuggestion: recoverySuggestion,
      context: context,
      exception: exception,
    );
  }

  /// Handles and logs an exception, returns its ErrorCategory.
  static ErrorCategory handleException(
    dynamic exception,
    String message, {
    String source = 'unknown',
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    final errorInfo = handleExceptionWithRecovery(
      exception,
      message,
      source: source,
      severity: severity,
    );
    return errorInfo.category;
  }

  /// Handles and logs an error without an exception with recovery suggestions.
  static ErrorInfo handleErrorWithRecovery(
    String message, {
    String source = 'unknown',
    ErrorCategory category = ErrorCategory.unknown,
    ErrorSeverity severity = ErrorSeverity.medium,
    Map<String, dynamic>? context,
  }) {
    final recoverySuggestion = _getRecoverySuggestion(category, null);
    final enhanced = _buildEnhancedErrorMessage(
        message, source, severity, category, recoverySuggestion);

    final key = '$source:$message:$category';
    final count = (_errorCounts[key] ?? 0) + 1;
    _errorCounts[key] = count;

    if (count <= _maxLogRate) {
      _logBySeverity(enhanced, severity);
    } else if (count == _maxLogRate + 1) {
      debugPrint(
          'WARN: Rate limiting similar error: $key. Further occurrences won\'t be logged.');
    }

    return ErrorInfo(
      message: message,
      category: category,
      severity: severity,
      recoverySuggestion: recoverySuggestion,
      context: context,
    );
  }

  /// Handles and logs an error without an exception.
  static void handleError(
    String message, {
    String source = 'unknown',
    ErrorCategory category = ErrorCategory.unknown,
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    handleErrorWithRecovery(
      message,
      source: source,
      category: category,
      severity: severity,
    );
  }

  /// Creates actionable error messages for users
  static String createActionableMessage(
    String baseMessage,
    ErrorCategory category, {
    Map<String, dynamic>? context,
  }) {
    final recovery = _getRecoverySuggestion(category, null);
    final contextInfo = context != null ? ' Context: $context' : '';

    return recovery != null
        ? '$baseMessage\n💡 Suggestion: $recovery$contextInfo'
        : '$baseMessage$contextInfo';
  }

  /// Get specific error recovery suggestion
  static String? getRecoverySuggestion(ErrorCategory category) {
    return _getRecoverySuggestion(category, null);
  }

  /// Clears all rate-limit counters.
  static void resetErrorCounts() => _errorCounts.clear();

  //—— Internal Helpers ——//

  static ErrorCategory _categorizeException(dynamic e) {
    if (e is TimeoutException) return ErrorCategory.timeout;
    if (e is FormatException) return ErrorCategory.serialization;
    if (e is ArgumentError || e is StateError) return ErrorCategory.validation;
    // Dart doesn't have a built-in SecurityException; customize as needed:
    if (e.runtimeType.toString().toLowerCase().contains('security')) {
      return ErrorCategory.permission;
    }
    if (e is SocketException) return ErrorCategory.network;
    return ErrorCategory.unknown;
  }

  static String _buildEnhancedErrorMessage(
    String message,
    String source,
    ErrorSeverity severity,
    ErrorCategory category,
    String? recovery,
  ) {
    final base = '[$source] [$severity] [$category] $message';
    return recovery != null ? '$base\n💡 Recovery: $recovery' : base;
  }

  static String? _getRecoverySuggestion(
      ErrorCategory category, dynamic exception) {
    switch (category) {
      case ErrorCategory.network:
        if (exception is SocketException) {
          return 'Check internet connection and retry. If problem persists, verify server status.';
        }
        return 'Check internet connection and try again.';

      case ErrorCategory.timeout:
        return 'Operation timed out. Check network connection or increase timeout value.';

      case ErrorCategory.configuration:
        return 'Verify SDK configuration. Check API key, base URL, and initialization parameters.';

      case ErrorCategory.validation:
        return 'Check input parameters for correct format and required fields.';

      case ErrorCategory.authentication:
        return 'Verify API credentials and ensure they have not expired.';

      case ErrorCategory.permission:
        return 'Check app permissions and ensure necessary access is granted.';

      case ErrorCategory.serialization:
        return 'Data format issue detected. Check API response format or input data structure.';

      case ErrorCategory.internal:
        return 'Internal error occurred. Please report this issue with error details.';

      case ErrorCategory.rateLimit:
        return 'Too many requests. Implement exponential backoff or reduce request frequency.';

      case ErrorCategory.storage:
        return 'Storage operation failed. Check available space and write permissions.';

      case ErrorCategory.user:
        return 'User-related error. Ensure user is properly identified and has valid credentials.';

      case ErrorCategory.featureFlag:
        return 'Feature flag evaluation failed. Check flag configuration and fallback values.';

      case ErrorCategory.analytics:
        return 'Analytics tracking failed. Verify event format and network connectivity.';

      case ErrorCategory.api:
        return 'API operation failed. Check request format and service availability.';

      case ErrorCategory.unknown:
      default:
        return 'An unexpected error occurred. Please retry the operation.';
    }
  }

  static void _logBySeverity(String msg, ErrorSeverity sev) {
    // Skip logging during tests to prevent memory pressure and segfaults
    // when running with coverage enabled
    if (_isInTestEnvironment()) {
      return;
    }

    switch (sev) {
      case ErrorSeverity.low:
        debugPrint('DEBUG: $msg');
        break;
      case ErrorSeverity.medium:
        debugPrint('WARN: $msg');
        break;
      case ErrorSeverity.high:
        debugPrint('ERROR: $msg');
        break;
      case ErrorSeverity.critical:
        debugPrint('CRITICAL: $msg');
        break;
    }
  }

  /// Detects if we're running in a test environment
  static bool _isInTestEnvironment() {
    // Check for test environment indicators - use efficient checks only
    return const bool.fromEnvironment('FLUTTER_TEST') ||
        Platform.environment.containsKey('FLUTTER_TEST');
  }
}
