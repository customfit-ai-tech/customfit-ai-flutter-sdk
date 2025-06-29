// lib/src/core/error/cf_result.dart
//
// Result type for SDK operations providing success/error handling.
// Implements a functional approach to error handling with detailed error
// information, recovery suggestions, and comprehensive error categorization.
//
// This file is part of the CustomFit SDK for Flutter.

import 'error_category.dart';
import 'error_handler.dart';
import 'error_severity.dart';
import 'cf_error_code.dart';
import 'package:flutter/foundation.dart';

/// Error details for failed operations
class CFError {
  final String? message;
  final CFErrorCode errorCode;
  final ErrorCategory category;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final dynamic exception;
  final String? stackTrace;
  final Map<String, dynamic>? context;
  final bool recoverable;

  CFError({
    this.message,
    required this.errorCode,
    ErrorCategory? category,
    ErrorSeverity? severity,
    DateTime? timestamp,
    this.exception,
    this.stackTrace,
    this.context,
    bool? recoverable,
  })  : category = category ?? _getCategoryFromCode(errorCode),
        severity = severity ?? errorCode.severity,
        timestamp = timestamp ?? DateTime.now(),
        recoverable = recoverable ?? errorCode.isRecoverable;

  /// Legacy factory constructor for backward compatibility
  factory CFError.legacy({
    String? message,
    ErrorCategory category = ErrorCategory.unknown,
    int code = 0,
    dynamic exception,
  }) {
    final errorCode = _getErrorCodeFromLegacy(code, category);
    return CFError(
      message: message,
      errorCode: errorCode,
      category: category,
      exception: exception,
    );
  }

  int get code => errorCode.code;
  String get name => errorCode.name;

  static ErrorCategory _getCategoryFromCode(CFErrorCode code) {
    switch (code.category) {
      case 'Network':
        return ErrorCategory.network;
      case 'Configuration':
        return ErrorCategory.configuration;
      case 'Validation':
        return ErrorCategory.validation;
      case 'Internal':
        return ErrorCategory.internal;
      case 'Authentication':
        return ErrorCategory.authentication;
      default:
        return ErrorCategory.unknown;
    }
  }

  static CFErrorCode _getErrorCodeFromLegacy(int code, ErrorCategory category) {
    // Map legacy codes to new error codes
    if (code > 0) {
      // Try to find matching error code
      final httpCode = CFErrorCode.fromHttpStatus(code);
      if (httpCode != null) return httpCode;
    }

    // Default to category-based error codes
    switch (category) {
      case ErrorCategory.network:
        return CFErrorCode.networkUnavailable;
      case ErrorCategory.configuration:
        return CFErrorCode.configNotInitialized;
      case ErrorCategory.validation:
        return CFErrorCode.validationInvalidFormat;
      case ErrorCategory.internal:
        return CFErrorCode.internalUnknownError;
      case ErrorCategory.authentication:
        return CFErrorCode.authInvalidCredentials;
      default:
        return CFErrorCode.internalUnknownError;
    }
  }

  @override
  String toString() =>
      'CFError(code: ${errorCode.code}, name: ${errorCode.name}, message: $message, severity: $severity)';
}

/// Mirrors Kotlin's sealed CFResult with generic type T.
class CFResult<T> {
  final T? _value;
  final String? _errorMessage;
  final dynamic _exception;
  final int _code;
  final ErrorCategory _category;
  final CFErrorCode? _errorCode;
  final Map<String, dynamic>? _context;
  final bool isSuccess;

  CFResult._({
    T? value,
    String? errorMessage,
    dynamic exception,
    int code = 0,
    ErrorCategory category = ErrorCategory.unknown,
    CFErrorCode? errorCode,
    Map<String, dynamic>? context,
    required this.isSuccess,
  })  : _value = value,
        _errorMessage = errorMessage,
        _exception = exception,
        _code = code,
        _category = category,
        _errorCode = errorCode,
        _context = context;

  /// Successful result
  factory CFResult.success(T value) =>
      CFResult._(value: value, isSuccess: true);

  /// Error result (logs automatically, like Kotlin's companion.error)
  factory CFResult.error(
    String message, {
    dynamic exception,
    int code = 0,
    ErrorCategory category = ErrorCategory.unknown,
    CFErrorCode? errorCode,
    Map<String, dynamic>? context,
  }) {
    // Use provided error code or derive from legacy code/category
    final cfErrorCode =
        errorCode ?? CFError._getErrorCodeFromLegacy(code, category);

    // Skip error handling during tests to prevent memory pressure
    if (!_isInTestMode()) {
      if (exception != null) {
        ErrorHandler.handleException(
          exception,
          message,
          source: 'CFResult',
          severity: cfErrorCode.severity,
        );
      } else {
        ErrorHandler.handleError(
          message,
          source: 'CFResult',
          category: category,
          severity: cfErrorCode.severity,
        );
      }
    }

    return CFResult._(
      errorMessage: message,
      exception: exception,
      code: cfErrorCode.code,
      category: errorCode != null
          ? CFError._getCategoryFromCode(cfErrorCode)
          : category,
      errorCode: cfErrorCode,
      context: context,
      isSuccess: false,
    );
  }

  /// Checks if running in test mode to avoid expensive operations
  static bool _isInTestMode() {
    // Simple check using compile-time environment variable set by Flutter test runner
    return const bool.fromEnvironment('FLUTTER_TEST', defaultValue: false);
  }

  /// Wraps a block into a CFResult (like fromResult with generic type T)
  static CFResult<T> fromResult<T>(
    T Function() block, {
    String errorMessage = 'Operation failed',
  }) {
    try {
      return CFResult.success(block());
    } catch (e) {
      return CFResult.error(errorMessage, exception: e);
    }
  }

  /// Returns the value or null if error
  T? getOrNull() => isSuccess ? _value : null;

  /// Returns the error message or null if success
  String? getErrorMessage() => isSuccess ? null : _errorMessage;

  /// Returns the status code (e.g., HTTP status code) if available
  int getStatusCode() => _code;

  /// Getter for data
  T? get data => getOrNull();

  /// Getter for error
  CFError? get error => isSuccess
      ? null
      : CFError(
          message: _errorMessage,
          errorCode:
              _errorCode ?? CFError._getErrorCodeFromLegacy(_code, _category),
          category: _category,
          exception: _exception,
          context: _context,
        );

  /// Returns the value if success, null if error
  T? get valueOrNull => isSuccess ? _value : null;

  /// Returns value or throws if error
  T getOrThrow() {
    if (isSuccess) {
      return _value as T;
    } else {
      throw CFException(error!);
    }
  }

  /// Returns value or computes alternative
  T getOrElse(T Function() alternative) {
    return isSuccess ? _value as T : alternative();
  }

  /// Maps successful value to another type
  CFResult<R> map<R>(R Function(T) transform) {
    if (isSuccess) {
      try {
        return CFResult.success(transform(_value as T));
      } catch (e) {
        return CFResult.error(
          'Transformation failed: $e',
          exception: e,
          category: ErrorCategory.internal,
        );
      }
    } else {
      return CFResult.error(
        _errorMessage ?? 'Unknown error',
        exception: _exception,
        code: _code,
        category: _category,
        errorCode: _errorCode,
        context: _context,
      );
    }
  }

  /// Flat maps successful value to another CFResult
  CFResult<R> flatMap<R>(CFResult<R> Function(T) transform) {
    if (isSuccess) {
      try {
        return transform(_value as T);
      } catch (e) {
        return CFResult.error(
          'Transformation failed: $e',
          exception: e,
          category: ErrorCategory.internal,
        );
      }
    } else {
      return CFResult.error(
        _errorMessage ?? 'Unknown error',
        exception: _exception,
        code: _code,
        category: _category,
        errorCode: _errorCode,
        context: _context,
      );
    }
  }

  /// Executes side effect if successful
  CFResult<T> onSuccess(void Function(T) action) {
    if (isSuccess && _value != null) {
      try {
        action(_value as T);
      } catch (e) {
        // Log but don't fail the result
        debugPrint('Side effect failed: $e');
      }
    }
    return this;
  }

  /// Executes side effect if failed
  CFResult<T> onError(void Function(CFError) action) {
    if (!isSuccess && error != null) {
      try {
        action(error as CFError);
      } catch (e) {
        // Log but don't fail the result
        debugPrint('Error side effect failed: $e');
      }
    }
    return this;
  }

  /// Recovers from error with alternative value
  CFResult<T> recover(T Function(CFError) recovery) {
    if (!isSuccess && error != null) {
      try {
        final recoveredValue = recovery(error as CFError);
        return CFResult.success(recoveredValue);
      } catch (e) {
        return CFResult.error(
          'Recovery failed: $e',
          exception: e,
          category: ErrorCategory.internal,
        );
      }
    }
    return this;
  }

  /// Async transformation for chaining
  Future<CFResult<R>> mapAsync<R>(Future<R> Function(T) transform) async {
    if (isSuccess) {
      try {
        final result = await transform(_value as T);
        return CFResult.success(result);
      } catch (e) {
        return CFResult.error(
          'Async transformation failed: $e',
          exception: e,
          category: ErrorCategory.internal,
        );
      }
    } else {
      return CFResult.error(
        _errorMessage ?? 'Unknown error',
        exception: _exception,
        code: _code,
        category: _category,
        errorCode: _errorCode,
        context: _context,
      );
    }
  }

  /// Async flat map for chaining CFResults
  Future<CFResult<R>> flatMapAsync<R>(
      Future<CFResult<R>> Function(T) transform) async {
    if (isSuccess) {
      try {
        return await transform(_value as T);
      } catch (e) {
        return CFResult.error(
          'Async transformation failed: $e',
          exception: e,
          category: ErrorCategory.internal,
        );
      }
    } else {
      return CFResult.error(
        _errorMessage ?? 'Unknown error',
        exception: _exception,
        code: _code,
        category: _category,
        errorCode: _errorCode,
        context: _context,
      );
    }
  }

  /// Combines two results using provided combiner
  static CFResult<R> combine<A, B, R>(
    CFResult<A> resultA,
    CFResult<B> resultB,
    R Function(A, B) combiner,
  ) {
    if (resultA.isSuccess && resultB.isSuccess) {
      try {
        return CFResult.success(
            combiner(resultA._value as A, resultB._value as B));
      } catch (e) {
        return CFResult.error(
          'Combination failed: $e',
          exception: e,
          category: ErrorCategory.internal,
        );
      }
    } else {
      // Return first error or combine error messages
      final errorA = resultA.isSuccess ? null : resultA.error;
      final errorB = resultB.isSuccess ? null : resultB.error;

      if (errorA != null && errorB != null) {
        return CFResult.error(
          'Multiple errors: ${errorA.message}; ${errorB.message}',
          category: ErrorCategory.internal,
        );
      } else {
        final firstError = errorA ?? errorB;
        if (firstError != null) {
          return CFResult.error(
            firstError.message ?? 'Combined operation failed',
            exception: firstError.exception,
            code: firstError.code,
            category: firstError.category,
            errorCode: firstError.errorCode,
            context: firstError.context,
          );
        } else {
          return CFResult.error(
            'Combined operation failed',
            category: ErrorCategory.internal,
          );
        }
      }
    }
  }

  /// Debug representation
  @override
  String toString() {
    if (isSuccess) {
      return 'CFResult.success($_value)';
    } else {
      return 'CFResult.error($_errorMessage)';
    }
  }

  /// Equality check
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CFResult<T> &&
        other.isSuccess == isSuccess &&
        other._value == _value &&
        other._errorMessage == _errorMessage &&
        other._code == _code;
  }

  @override
  int get hashCode => Object.hash(isSuccess, _value, _errorMessage, _code);
}

/// Exception wrapper for CFError
class CFException implements Exception {
  final CFError error;

  CFException(this.error);

  @override
  String toString() => 'CFException: ${error.message}';
}
