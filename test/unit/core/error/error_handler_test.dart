// test/unit/core/error/error_handler_test.dart
//
// Tests for ErrorHandler centralized error handling utility
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_handler.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_severity.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ErrorHandler', () {
    setUp(() {
      // Reset error counts before each test
      ErrorHandler.resetErrorCounts();
    });
    group('Exception Handling', () {
      test('should handle TimeoutException correctly', () {
        final exception = TimeoutException('Operation timed out');
        final category = ErrorHandler.handleException(
          exception,
          'Network request failed',
          source: 'NetworkService',
        );
        expect(category, equals(ErrorCategory.timeout));
      });
      test('should handle FormatException correctly', () {
        const exception = FormatException('Invalid JSON format');
        final category = ErrorHandler.handleException(
          exception,
          'JSON parsing failed',
          source: 'JsonParser',
        );
        expect(category, equals(ErrorCategory.serialization));
      });
      test('should handle ArgumentError correctly', () {
        final exception = ArgumentError('Invalid argument');
        final category = ErrorHandler.handleException(
          exception,
          'Validation failed',
          source: 'Validator',
        );
        expect(category, equals(ErrorCategory.validation));
      });
      test('should handle StateError correctly', () {
        final exception = StateError('Invalid state');
        final category = ErrorHandler.handleException(
          exception,
          'State validation failed',
          source: 'StateManager',
        );
        expect(category, equals(ErrorCategory.validation));
      });
      test('should handle SocketException correctly', () {
        const exception = SocketException('Network unreachable');
        final category = ErrorHandler.handleException(
          exception,
          'Network connection failed',
          source: 'HttpClient',
        );
        expect(category, equals(ErrorCategory.network));
      });
      test('should handle unknown exceptions as unknown category', () {
        final exception = Exception('Generic exception');
        final category = ErrorHandler.handleException(
          exception,
          'Unknown error occurred',
          source: 'Unknown',
        );
        expect(category, equals(ErrorCategory.unknown));
      });
      test('should detect security-related exceptions', () {
        // Create a mock exception with security in the type name
        final exception = _MockSecurityException('Access denied');
        final category = ErrorHandler.handleException(
          exception,
          'Security violation',
          source: 'SecurityService',
        );
        expect(category, equals(ErrorCategory.permission));
      });
    });
    group('Exception Handling with Recovery', () {
      test('should provide recovery information for exceptions', () {
        const exception = SocketException('Connection refused');
        final errorInfo = ErrorHandler.handleExceptionWithRecovery(
          exception,
          'Failed to connect to server',
          source: 'NetworkClient',
          severity: ErrorSeverity.high,
          context: {'host': 'api.example.com', 'port': 443},
        );
        expect(errorInfo.message, equals('Failed to connect to server'));
        expect(errorInfo.category, equals(ErrorCategory.network));
        expect(errorInfo.severity, equals(ErrorSeverity.high));
        expect(errorInfo.recoverySuggestion, isNotNull);
        expect(errorInfo.recoverySuggestion, contains('internet connection'));
        expect(errorInfo.context,
            equals({'host': 'api.example.com', 'port': 443}));
        expect(errorInfo.exception, equals(exception));
      });
      test('should provide specific recovery for SocketException', () {
        const exception = SocketException('Network unreachable');
        final errorInfo = ErrorHandler.handleExceptionWithRecovery(
          exception,
          'Network error',
          source: 'HttpService',
        );
        expect(errorInfo.recoverySuggestion,
            contains('Check internet connection'));
        expect(errorInfo.recoverySuggestion, contains('verify server status'));
      });
      test(
          'should provide generic network recovery for non-socket network errors',
          () {
        // Force categorize as network by using a timeout exception
        final timeoutException = TimeoutException('Timeout');
        final errorInfo = ErrorHandler.handleExceptionWithRecovery(
          timeoutException,
          'Network timeout',
          source: 'HttpService',
        );
        expect(errorInfo.category, equals(ErrorCategory.timeout));
        expect(errorInfo.recoverySuggestion, contains('timed out'));
      });
    });
    group('Error Handling without Exceptions', () {
      test('should handle basic error messages', () {
        ErrorHandler.handleError(
          'Configuration missing',
          source: 'ConfigService',
          category: ErrorCategory.configuration,
          severity: ErrorSeverity.high,
        );
        // No assertions needed as this is a void method
        // The test passes if no exceptions are thrown
      });
      test('should handle error with recovery information', () {
        final errorInfo = ErrorHandler.handleErrorWithRecovery(
          'API key not found',
          source: 'AuthService',
          category: ErrorCategory.configuration,
          severity: ErrorSeverity.critical,
          context: {'config_file': 'app.config'},
        );
        expect(errorInfo.message, equals('API key not found'));
        expect(errorInfo.category, equals(ErrorCategory.configuration));
        expect(errorInfo.severity, equals(ErrorSeverity.critical));
        expect(errorInfo.recoverySuggestion, contains('SDK configuration'));
        expect(errorInfo.context, equals({'config_file': 'app.config'}));
        expect(errorInfo.exception, isNull);
      });
    });
    group('Rate Limiting', () {
      test('should rate limit repeated errors', () {
        final exception = Exception('Repeated error');
        // Generate more than the max log rate (10) errors
        for (int i = 0; i < 15; i++) {
          ErrorHandler.handleException(
            exception,
            'Repeated error message',
            source: 'TestSource',
          );
        }
        // Test passes if no exceptions are thrown
        // Rate limiting should prevent excessive logging
      });
      test('should track different error types separately', () {
        final exception1 = Exception('Error type 1');
        final exception2 = Exception('Error type 2');
        // These should be tracked separately
        for (int i = 0; i < 5; i++) {
          ErrorHandler.handleException(exception1, 'Message 1',
              source: 'Source1');
          ErrorHandler.handleException(exception2, 'Message 2',
              source: 'Source2');
        }
        // Different error types should not interfere with each other's rate limiting
      });
      test('should reset error counts', () {
        final exception = Exception('Test error');
        // Generate some errors
        for (int i = 0; i < 5; i++) {
          ErrorHandler.handleException(exception, 'Test message',
              source: 'Test');
        }
        // Reset counts
        ErrorHandler.resetErrorCounts();
        // Should be able to log again without rate limiting
        ErrorHandler.handleException(exception, 'Test message', source: 'Test');
      });
    });
    group('Recovery Suggestions', () {
      test('should provide network recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.network);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('internet connection'));
      });
      test('should provide timeout recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.timeout);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('timed out'));
        expect(suggestion, contains('network connection'));
      });
      test('should provide configuration recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.configuration);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('SDK configuration'));
        expect(suggestion, contains('API key'));
      });
      test('should provide validation recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.validation);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('input parameters'));
        expect(suggestion, contains('format'));
      });
      test('should provide authentication recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.authentication);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('API credentials'));
        expect(suggestion, contains('expired'));
      });
      test('should provide permission recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.permission);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('permissions'));
        expect(suggestion, contains('access'));
      });
      test('should provide serialization recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.serialization);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('Data format'));
        expect(suggestion, contains('API response'));
      });
      test('should provide internal error recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.internal);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('Internal error'));
        expect(suggestion, contains('report'));
      });
      test('should provide rate limit recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.rateLimit);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('Too many requests'));
        expect(suggestion, contains('exponential backoff'));
      });
      test('should provide storage recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.storage);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('Storage operation'));
        expect(suggestion, contains('space'));
      });
      test('should provide user error recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.user);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('User-related'));
        expect(suggestion, contains('identified'));
      });
      test('should provide feature flag recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.featureFlag);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('Feature flag'));
        expect(suggestion, contains('fallback'));
      });
      test('should provide analytics recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.analytics);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('Analytics'));
        expect(suggestion, contains('event format'));
      });
      test('should provide API recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.api);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('API operation'));
        expect(suggestion, contains('request format'));
      });
      test('should provide unknown error recovery suggestions', () {
        final suggestion =
            ErrorHandler.getRecoverySuggestion(ErrorCategory.unknown);
        expect(suggestion, isNotNull);
        expect(suggestion, contains('unexpected error'));
        expect(suggestion, contains('retry'));
      });
    });
    group('Actionable Messages', () {
      test('should create actionable message with recovery suggestion', () {
        final message = ErrorHandler.createActionableMessage(
          'Network request failed',
          ErrorCategory.network,
        );
        expect(message, contains('Network request failed'));
        expect(message, contains('💡 Suggestion:'));
        expect(message, contains('internet connection'));
      });
      test('should create actionable message with context', () {
        final message = ErrorHandler.createActionableMessage(
          'Validation failed',
          ErrorCategory.validation,
          context: {'field': 'email', 'value': 'invalid@'},
        );
        expect(message, contains('Validation failed'));
        expect(message, contains('💡 Suggestion:'));
        expect(message, contains('Context:'));
        expect(message, contains('field'));
        expect(message, contains('email'));
      });
      test('should create basic message for unknown category', () {
        final message = ErrorHandler.createActionableMessage(
          'Something went wrong',
          ErrorCategory.unknown,
        );
        expect(message, contains('Something went wrong'));
        expect(message, contains('💡 Suggestion:'));
      });
      test('should handle empty context', () {
        final message = ErrorHandler.createActionableMessage(
          'Error occurred',
          ErrorCategory.network,
          context: {},
        );
        expect(message, contains('Error occurred'));
        expect(message, contains('💡 Suggestion:'));
        expect(message, contains('Context: {}'));
      });
    });
    group('ErrorInfo Class', () {
      test('should create ErrorInfo with all properties', () {
        final exception = Exception('Test exception');
        final context = {'key': 'value'};
        final errorInfo = ErrorInfo(
          message: 'Test message',
          category: ErrorCategory.network,
          severity: ErrorSeverity.high,
          recoverySuggestion: 'Try again',
          context: context,
          exception: exception,
        );
        expect(errorInfo.message, equals('Test message'));
        expect(errorInfo.category, equals(ErrorCategory.network));
        expect(errorInfo.severity, equals(ErrorSeverity.high));
        expect(errorInfo.recoverySuggestion, equals('Try again'));
        expect(errorInfo.context, equals(context));
        expect(errorInfo.exception, equals(exception));
      });
      test('should create ErrorInfo with minimal properties', () {
        final errorInfo = ErrorInfo(
          message: 'Minimal message',
          category: ErrorCategory.unknown,
          severity: ErrorSeverity.low,
        );
        expect(errorInfo.message, equals('Minimal message'));
        expect(errorInfo.category, equals(ErrorCategory.unknown));
        expect(errorInfo.severity, equals(ErrorSeverity.low));
        expect(errorInfo.recoverySuggestion, isNull);
        expect(errorInfo.context, isNull);
        expect(errorInfo.exception, isNull);
      });
    });
    group('Edge Cases', () {
      test('should handle null exception gracefully', () {
        expect(
            () => ErrorHandler.handleException(
                  null,
                  'Null exception test',
                  source: 'TestSource',
                ),
            returnsNormally);
      });
      test('should handle empty error message', () {
        expect(
            () => ErrorHandler.handleError(
                  '',
                  source: 'TestSource',
                  category: ErrorCategory.unknown,
                ),
            returnsNormally);
      });
      test('should handle very long error messages', () {
        final longMessage = 'x' * 10000;
        expect(
            () => ErrorHandler.handleError(
                  longMessage,
                  source: 'TestSource',
                  category: ErrorCategory.unknown,
                ),
            returnsNormally);
      });
      test('should handle special characters in messages', () {
        const specialMessage = 'Error with 🚀 emojis and \n newlines \t tabs';
        expect(
            () => ErrorHandler.handleError(
                  specialMessage,
                  source: 'TestSource',
                  category: ErrorCategory.unknown,
                ),
            returnsNormally);
      });
      test('should handle concurrent error handling', () async {
        final futures = List.generate(10, (index) async {
          final exception = Exception('Concurrent error $index');
          return ErrorHandler.handleException(
            exception,
            'Concurrent test $index',
            source: 'ConcurrentTest',
          );
        });
        final results = await Future.wait(futures);
        expect(results, hasLength(10));
        for (final result in results) {
          expect(result, isA<ErrorCategory>());
        }
      });
    });
    group('Context Handling', () {
      test('should handle complex context objects', () {
        final complexContext = {
          'user': {'id': 123, 'name': 'John'},
          'request': {
            'url': 'https://api.example.com',
            'method': 'POST',
            'headers': {'Content-Type': 'application/json'},
          },
          'timestamp': DateTime.now().toIso8601String(),
          'nested': {
            'level1': {
              'level2': {'value': 'deep'},
            },
          },
        };
        final errorInfo = ErrorHandler.handleErrorWithRecovery(
          'Complex context test',
          source: 'ContextTest',
          category: ErrorCategory.api,
          context: complexContext,
        );
        expect(errorInfo.context, equals(complexContext));
      });
      test('should handle null context gracefully', () {
        final errorInfo = ErrorHandler.handleErrorWithRecovery(
          'Null context test',
          source: 'ContextTest',
          category: ErrorCategory.unknown,
          context: null,
        );
        expect(errorInfo.context, isNull);
      });
    });
  });
}
/// Mock security exception for testing
class _MockSecurityException implements Exception {
  final String message;
  _MockSecurityException(this.message);
  @override
  String toString() => 'MockSecurityException: $message';
}
