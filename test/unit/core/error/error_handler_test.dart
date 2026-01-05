// test/unit/core/error/error_handler_test.dart
//
// Simplified tests for ErrorHandler after SDK simplification
// Tests basic error handling functionality

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_handler.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_severity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('ErrorHandler (Simplified)', () {
    setUp(() {
      // Reset error counts before each test
      ErrorHandler.resetErrorCounts();
    });

    group('handleExceptionWithRecovery', () {
      test('should handle TimeoutException correctly', () {
        final exception = TimeoutException('Operation timed out');
        final errorInfo = ErrorHandler.handleExceptionWithRecovery(
          exception,
          'Network request failed',
          source: 'NetworkService',
          severity: ErrorSeverity.high,
        );

        expect(errorInfo.message, equals('Network request failed'));
        expect(errorInfo.category, equals(ErrorCategory.network));
        expect(errorInfo.severity, equals(ErrorSeverity.high));
        expect(errorInfo.exception, equals(exception));
      });

      test('should handle FormatException correctly', () {
        const exception = FormatException('Invalid JSON format');
        final errorInfo = ErrorHandler.handleExceptionWithRecovery(
          exception,
          'Failed to parse response',
          source: 'ConfigManager',
        );

        expect(errorInfo.category, equals(ErrorCategory.validation));
        expect(errorInfo.severity, equals(ErrorSeverity.medium));
      });

      test('should handle SocketException correctly', () {
        final exception = const SocketException('Network unreachable');
        final errorInfo = ErrorHandler.handleExceptionWithRecovery(
          exception,
          'Connection failed',
          source: 'HttpClient',
        );

        expect(errorInfo.category, equals(ErrorCategory.network));
      });

      test('should handle generic Exception correctly', () {
        final exception = Exception('Something went wrong');
        final errorInfo = ErrorHandler.handleExceptionWithRecovery(
          exception,
          'Unknown error',
          source: 'Unknown',
        );

        expect(errorInfo.category, equals(ErrorCategory.internal));
      });
    });

    group('handleError', () {
      test('should handle simple error', () {
        // Test handleError method (returns void)
        expect(() {
          ErrorHandler.handleError(
            'Simple error message',
            category: ErrorCategory.validation,
            severity: ErrorSeverity.low,
          );
        }, returnsNormally);
      });
    });

    group('handleException (category only)', () {
      test('should categorize TimeoutException', () {
        final exception = TimeoutException('Timeout');
        final category = ErrorHandler.handleException(
          exception,
          'Timeout occurred',
          source: 'TestService',
        );

        expect(category, equals(ErrorCategory.network));
      });

      test('should categorize FormatException', () {
        const exception = FormatException('Invalid format');
        final category = ErrorHandler.handleException(
          exception,
          'Parse error',
          source: 'TestService',
        );

        expect(category, equals(ErrorCategory.validation));
      });
    });

    group('resetErrorCounts', () {
      test('should reset error counts', () {
        // Generate some errors
        ErrorHandler.handleExceptionWithRecovery(
          Exception('Test'),
          'Test error',
          source: 'TestService',
        );

        // Reset counts (void method)
        expect(() {
          ErrorHandler.resetErrorCounts();
        }, returnsNormally);
      });
    });
  });
}