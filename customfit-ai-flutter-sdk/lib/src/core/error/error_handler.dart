// lib/src/core/error/simplified_error_handler.dart
//
// Simplified error handling utility with basic categorization.
// Provides consistent error handling across the SDK.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'error_category.dart';
import 'error_severity.dart';

/// Simplified error information
class ErrorInfo {
  final String message;
  final ErrorCategory category;
  final ErrorSeverity severity;
  final dynamic exception;

  ErrorInfo({
    required this.message,
    required this.category,
    required this.severity,
    this.exception,
  });
}

/// Simplified error handling utility
class ErrorHandler {
  static final Map<String, int> _errorCounts = {};
  static const int _maxLogRate = 5;

  /// Handles and logs an exception
  static ErrorInfo handleExceptionWithRecovery(
    dynamic exception,
    String message, {
    String source = 'unknown',
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    final category = _categorizeException(exception);
    final enhanced = '[$source] [$severity] [$category] $message';

    final key = '${exception.runtimeType}:$source';
    final count = (_errorCounts[key] ?? 0) + 1;
    _errorCounts[key] = count;

    if (count <= _maxLogRate) {
      _logBySeverity(enhanced, severity);
    }

    return ErrorInfo(
      message: message,
      category: category,
      severity: severity,
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

  /// Handles and logs an error without an exception
  static void handleError(
    String message, {
    String source = 'unknown',
    ErrorCategory category = ErrorCategory.unknown,
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    final enhanced = '[$source] [$severity] [$category] $message';
    final key = '$source:$category';
    final count = (_errorCounts[key] ?? 0) + 1;
    _errorCounts[key] = count;

    if (count <= _maxLogRate) {
      _logBySeverity(enhanced, severity);
    }
  }

  /// Clears all rate-limit counters
  static void resetErrorCounts() => _errorCounts.clear();

  //—— Internal Helpers ——//

  static ErrorCategory _categorizeException(dynamic e) {
    if (e is TimeoutException) return ErrorCategory.network;
    if (e is FormatException) return ErrorCategory.validation;
    if (e is ArgumentError || e is StateError) return ErrorCategory.validation;

    final typeName = e.runtimeType.toString();
    if (typeName.contains('SocketException') ||
        typeName.contains('HttpException') ||
        typeName.contains('NetworkException')) {
      return ErrorCategory.network;
    }
    return ErrorCategory.internal;
  }

  static void _logBySeverity(String msg, ErrorSeverity sev) {
    if (const bool.fromEnvironment('FLUTTER_TEST')) {
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
}
