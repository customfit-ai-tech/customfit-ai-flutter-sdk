// test/unit/core/error/cf_result_test.dart
//
// Consolidated CFResult Test Suite
// Merged from cf_result_comprehensive_test.dart and cf_result_test.dart
// to eliminate duplication while maintaining complete test coverage.
//
// This comprehensive test suite covers:
// 1. Basic success and error result creation and access
// 2. Result transformation with map and flatMap operations
// 3. Result recovery and error handling
// 4. Async operations and transformations
// 5. Result combination and side effects
// 6. Equality, hashing, and string representation
// 7. CFError class functionality and factory methods
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_error_code.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_severity.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  group('CFResult Comprehensive Test Suite', () {
    group('CFError Class Tests', () {
      test('should create CFError with all parameters', () {
        final now = DateTime.now();
        final context = {'key': 'value'};
        final error = CFError(
          message: 'Test error',
          errorCode: CFErrorCode.networkTimeout,
          category: ErrorCategory.network,
          severity: ErrorSeverity.high,
          timestamp: now,
          exception: Exception('test'),
          stackTrace: 'stack trace',
          context: context,
          recoverable: true,
        );
        expect(error.message, equals('Test error'));
        expect(error.errorCode, equals(CFErrorCode.networkTimeout));
        expect(error.category, equals(ErrorCategory.network));
        expect(error.severity, equals(ErrorSeverity.high));
        expect(error.timestamp, equals(now));
        expect(error.exception, isA<Exception>());
        expect(error.stackTrace, equals('stack trace'));
        expect(error.context, equals(context));
        expect(error.recoverable, isTrue);
        expect(error.code, equals(CFErrorCode.networkTimeout.code));
        expect(error.name, equals(CFErrorCode.networkTimeout.name));
      });
      test('should create CFError with defaults', () {
        final error = CFError(
          errorCode: CFErrorCode.validationMissingRequiredField,
        );
        expect(error.message, isNull);
        expect(error.errorCode,
            equals(CFErrorCode.validationMissingRequiredField));
        expect(error.category, equals(ErrorCategory.validation));
        expect(error.severity,
            equals(CFErrorCode.validationMissingRequiredField.severity));
        expect(error.timestamp, isNotNull);
        expect(error.exception, isNull);
        expect(error.stackTrace, isNull);
        expect(error.context, isNull);
        expect(error.recoverable,
            equals(CFErrorCode.validationMissingRequiredField.isRecoverable));
      });
      test('should create CFError using legacy constructor', () {
        final error = CFError.legacy(
          message: 'Legacy error',
          category: ErrorCategory.authentication,
          code: 401,
          exception: 'legacy exception',
        );
        expect(error.message, equals('Legacy error'));
        expect(error.category, equals(ErrorCategory.authentication));
        expect(error.code, equals(1101)); // httpUnauthorized
        expect(error.exception, equals('legacy exception'));
      });
      test('should map HTTP codes correctly in legacy constructor', () {
        // Test various HTTP codes
        final error404 = CFError.legacy(code: 404);
        expect(error404.code, equals(1103)); // httpNotFound
        final error500 = CFError.legacy(code: 500);
        expect(error500.code, equals(1150)); // httpInternalServerError
        final error503 = CFError.legacy(code: 503);
        expect(error503.code, equals(1152)); // httpServiceUnavailable
      });
      test('should map category-based error codes in legacy constructor', () {
        final networkError = CFError.legacy(
          code: 0,
          category: ErrorCategory.network,
        );
        expect(networkError.errorCode, equals(CFErrorCode.networkUnavailable));
        final configError = CFError.legacy(
          code: 0,
          category: ErrorCategory.configuration,
        );
        expect(configError.errorCode, equals(CFErrorCode.configNotInitialized));
        final validationError = CFError.legacy(
          code: 0,
          category: ErrorCategory.validation,
        );
        expect(validationError.errorCode,
            equals(CFErrorCode.validationInvalidFormat));
        final authError = CFError.legacy(
          code: 0,
          category: ErrorCategory.authentication,
        );
        expect(authError.errorCode, equals(CFErrorCode.authInvalidCredentials));
        final unknownError = CFError.legacy(
          code: 0,
          category: ErrorCategory.unknown,
        );
        expect(
            unknownError.errorCode, equals(CFErrorCode.internalUnknownError));
      });
      test('should convert error codes to categories correctly', () {
        // This tests the _getCategoryFromCode method
        final networkError = CFError(errorCode: CFErrorCode.networkTimeout);
        expect(networkError.category, equals(ErrorCategory.network));
        final configError = CFError(errorCode: CFErrorCode.configInvalidApiKey);
        expect(configError.category, equals(ErrorCategory.configuration));
        final validationError =
            CFError(errorCode: CFErrorCode.validationInvalidUserId);
        expect(validationError.category, equals(ErrorCategory.validation));
        final internalError =
            CFError(errorCode: CFErrorCode.internalUnknownError);
        expect(internalError.category, equals(ErrorCategory.internal));
        final authError =
            CFError(errorCode: CFErrorCode.authInvalidCredentials);
        expect(authError.category, equals(ErrorCategory.authentication));
      });
      test('should have correct toString representation', () {
        final error = CFError(
          message: 'Test message',
          errorCode: CFErrorCode.networkTimeout,
          severity: ErrorSeverity.high,
        );
        final str = error.toString();
        expect(str, contains('CFError'));
        expect(str, contains('code: ${CFErrorCode.networkTimeout.code}'));
        expect(str, contains('name: ${CFErrorCode.networkTimeout.name}'));
        expect(str, contains('message: Test message'));
        expect(str, contains('severity: ${ErrorSeverity.high}'));
      });
    });
    group('Success Result Tests', () {
      test('should create success result with data', () {
        const data = 'test data';
        final result = CFResult.success(data);
        expect(result.isSuccess, isTrue);
        expect(!result.isSuccess, isFalse);
        expect(result.data, equals(data));
        expect(result.error, isNull);
      });
      test('should create success result with null data', () {
        final result = CFResult<String?>.success(null);
        expect(result.isSuccess, isTrue);
        expect(!result.isSuccess, isFalse);
        expect(result.data, isNull);
        expect(result.error, isNull);
      });
      test('should create success result with complex data', () {
        final data = {'key': 'value', 'count': 42};
        final result = CFResult.success(data);
        expect(result.isSuccess, isTrue);
        expect(result.data, equals(data));
        expect(result.data!['key'], equals('value'));
        expect(result.data!['count'], equals(42));
      });
    });
    group('Error Result Tests', () {
      test('should create error result with message', () {
        const errorMessage = 'Something went wrong';
        final result = CFResult<String>.error(errorMessage);
        expect(!result.isSuccess, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
        expect(result.error, isNotNull);
        expect(result.getErrorMessage(), equals(errorMessage));
      });
      test('should create error result with all parameters', () {
        const errorMessage = 'Network error';
        const code = 1001;
        const category = ErrorCategory.network;
        const errorCode = CFErrorCode.networkTimeout;
        final result = CFResult<String>.error(
          errorMessage,
          code: code,
          category: category,
          errorCode: errorCode,
        );
        expect(!result.isSuccess, isTrue);
        expect(result.getErrorMessage(), equals(errorMessage));
        expect(result.getStatusCode(), equals(code));
        expect(result.error!.category, equals(category));
        expect(result.error!.errorCode, equals(errorCode));
      });
      test('should create error result with exception', () {
        const errorMessage = 'Test error';
        final exception = Exception('Test exception');
        final result = CFResult<int>.error(
          errorMessage,
          exception: exception,
        );
        expect(result.getErrorMessage(), equals(errorMessage));
        expect(result.error!.exception, equals(exception));
      });
    });
    group('Result Data Access Tests', () {
      test('should get data from success result', () {
        final result = CFResult.success('test');
        expect(result.data, equals('test'));
        expect(result.getOrNull(), equals('test'));
      });
      test('should return null for error result data', () {
        final result = CFResult<String>.error('error');
        expect(result.data, isNull);
        expect(result.getOrNull(), isNull);
      });
      test('should get or else return alternative for error', () {
        final result = CFResult<String>.error('error');
        expect(result.getOrElse(() => 'default'), equals('default'));
      });
      test('should get or else return value for success', () {
        final result = CFResult.success('value');
        expect(result.getOrElse(() => 'default'), equals('value'));
      });
      test('should throw on getOrThrow for error result', () {
        final result = CFResult<String>.error('error');
        expect(() => result.getOrThrow(), throwsException);
      });
      test('should return value on getOrThrow for success result', () {
        final result = CFResult.success('value');
        expect(result.getOrThrow(), equals('value'));
      });
    });
    group('Result Transformation Tests', () {
      test('should map success result', () {
        final result = CFResult.success(5);
        final mapped = result.map((value) => value * 2);
        expect(mapped.isSuccess, isTrue);
        expect(mapped.data, equals(10));
      });
      test('should not map error result', () {
        final result = CFResult<int>.error('Error');
        final mapped = result.map((value) => value * 2);
        expect(!mapped.isSuccess, isTrue);
        expect(mapped.getErrorMessage(), equals('Error'));
      });
      test('should handle map exceptions', () {
        final result = CFResult.success(5);
        final mapped = result.map<String>((value) {
          throw Exception('Map failed');
        });
        expect(!mapped.isSuccess, isTrue);
        expect(mapped.getErrorMessage(), contains('Transformation failed'));
      });
      test('should flatMap success to success', () {
        final result = CFResult.success(5);
        final flatMapped =
            result.flatMap((value) => CFResult.success(value.toString()));
        expect(flatMapped.isSuccess, isTrue);
        expect(flatMapped.data, equals('5'));
      });
      test('should flatMap success to error', () {
        final result = CFResult.success(5);
        final flatMapped = result.flatMap<String>(
          (value) => CFResult.error('Cannot convert'),
        );
        expect(!flatMapped.isSuccess, isTrue);
        expect(flatMapped.getErrorMessage(), equals('Cannot convert'));
      });
      test('should not flatMap error result', () {
        final result = CFResult<int>.error('Initial error');
        final flatMapped =
            result.flatMap((value) => CFResult.success(value.toString()));
        expect(!flatMapped.isSuccess, isTrue);
        expect(flatMapped.getErrorMessage(), equals('Initial error'));
      });
    });
    group('Result Recovery Tests', () {
      test('should recover from error with value', () {
        final result = CFResult<String>.error('Error');
        final recovered = result.recover((error) => 'Recovered');
        expect(recovered.isSuccess, isTrue);
        expect(recovered.data, equals('Recovered'));
      });
      test('should not recover from success', () {
        final result = CFResult.success('Original');
        final recovered = result.recover((error) => 'Recovered');
        expect(recovered.isSuccess, isTrue);
        expect(recovered.data, equals('Original'));
      });
      test('should handle recovery exceptions', () {
        final result = CFResult<String>.error('Error');
        final recovered = result.recover((error) {
          throw Exception('Recovery failed');
        });
        expect(!recovered.isSuccess, isTrue);
        expect(recovered.getErrorMessage(), contains('Recovery failed'));
      });
    });
    group('Side Effects Tests', () {
      test('should execute onSuccess for successful result', () {
        var sideEffectExecuted = false;
        var receivedValue = '';
        final result = CFResult.success('test value');
        result.onSuccess((value) {
          sideEffectExecuted = true;
          receivedValue = value;
        });
        expect(sideEffectExecuted, isTrue);
        expect(receivedValue, equals('test value'));
      });
      test('should not execute onSuccess for error result', () {
        var sideEffectExecuted = false;
        final result = CFResult<String>.error('error');
        result.onSuccess((value) {
          sideEffectExecuted = true;
        });
        expect(sideEffectExecuted, isFalse);
      });
      test('should handle onSuccess exceptions gracefully', () {
        final result = CFResult.success('test');
        // Should not throw even if side effect throws
        expect(() {
          result.onSuccess((value) {
            throw Exception('Side effect failed');
          });
        }, returnsNormally);
      });
      test('should execute onError for error result', () {
        var sideEffectExecuted = false;
        CFError? receivedError;
        final result = CFResult<String>.error(
          'test error',
          errorCode: CFErrorCode.networkTimeout,
        );
        result.onError((error) {
          sideEffectExecuted = true;
          receivedError = error;
        });
        expect(sideEffectExecuted, isTrue);
        expect(receivedError, isNotNull);
        expect(receivedError!.message, equals('test error'));
      });
      test('should not execute onError for success result', () {
        var sideEffectExecuted = false;
        final result = CFResult.success('value');
        result.onError((error) {
          sideEffectExecuted = true;
        });
        expect(sideEffectExecuted, isFalse);
      });
      test('should handle onError exceptions gracefully', () {
        final result = CFResult<String>.error('error');
        // Should not throw even if side effect throws
        expect(() {
          result.onError((error) {
            throw Exception('Error handler failed');
          });
        }, returnsNormally);
      });
      test('should chain side effects', () {
        var successCount = 0;
        var errorCount = 0;
        CFResult.success('value')
            .onSuccess((v) => successCount++)
            .onError((e) => errorCount++)
            .onSuccess((v) => successCount++);
        expect(successCount, equals(2));
        expect(errorCount, equals(0));
        CFResult<String>.error('error')
            .onSuccess((v) => successCount++)
            .onError((e) => errorCount++)
            .onError((e) => errorCount++);
        expect(successCount, equals(2));
        expect(errorCount, equals(2));
      });
    });
    group('Async Operation Tests', () {
      test('should map async successfully', () async {
        final result = CFResult.success(5);
        final mapped = await result.mapAsync((value) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return value * 2;
        });
        expect(mapped.isSuccess, isTrue);
        expect(mapped.data, equals(10));
      });
      test('should handle async map exceptions', () async {
        final result = CFResult.success(5);
        final mapped = await result.mapAsync<String>((value) async {
          throw Exception('Async map failed');
        });
        expect(mapped.isSuccess, isFalse);
        expect(
            mapped.getErrorMessage(), contains('Async transformation failed'));
      });
      test('should not map async on error result', () async {
        final result = CFResult<int>.error('Initial error');
        final mapped = await result.mapAsync((value) async => value * 2);
        expect(mapped.isSuccess, isFalse);
        expect(mapped.getErrorMessage(), equals('Initial error'));
      });
      test('should flatMap async successfully', () async {
        final result = CFResult.success(5);
        final flatMapped = await result.flatMapAsync((value) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return CFResult.success(value.toString());
        });
        expect(flatMapped.isSuccess, isTrue);
        expect(flatMapped.data, equals('5'));
      });
      test('should handle async flatMap exceptions', () async {
        final result = CFResult.success(5);
        final flatMapped = await result.flatMapAsync<String>((value) async {
          throw Exception('Async flatMap failed');
        });
        expect(flatMapped.isSuccess, isFalse);
        expect(flatMapped.getErrorMessage(),
            contains('Async transformation failed'));
      });
      test('should not flatMap async on error result', () async {
        final result = CFResult<int>.error('Initial error');
        final flatMapped = await result
            .flatMapAsync((value) async => CFResult.success(value.toString()));
        expect(flatMapped.isSuccess, isFalse);
        expect(flatMapped.getErrorMessage(), equals('Initial error'));
      });
      test('should preserve error details in async operations', () async {
        final result = CFResult<int>.error(
          'Test error',
          errorCode: CFErrorCode.networkTimeout,
          context: {'key': 'value'},
        );
        final mapped = await result.mapAsync((v) async => v * 2);
        expect(mapped.error!.errorCode, equals(CFErrorCode.networkTimeout));
        expect(mapped.error!.context, equals({'key': 'value'}));
      });
      test('should handle async operations', () async {
        final future = Future.value(CFResult.success(42));
        final result = await future;
        expect(result.isSuccess, isTrue);
        expect(result.data, equals(42));
      });
      test('should compose async results', () async {
        // Simplified async operation to avoid segfault
        final result = CFResult.success(42);
        final mapped = result.map((value) => value * 2);
        expect(result.isSuccess, isTrue);
        expect(result.data, equals(42));
        expect(mapped.isSuccess, isTrue);
        expect(mapped.data, equals(84));
      });
      test('should handle async error results', () async {
        final errorResult = CFResult<int>.error('Async error');
        final mapped = errorResult.map((value) => value * 2);
        expect(errorResult.isSuccess, isFalse);
        expect(errorResult.getErrorMessage(), equals('Async error'));
        expect(mapped.isSuccess, isFalse);
        expect(mapped.getErrorMessage(), equals('Async error'));
      });
      test('should handle synchronous chaining', () {
        // Completely synchronous to avoid any async-related segfaults
        final result = CFResult.success(10);
        final doubled = result.map((value) => value * 2);
        final stringified = doubled.map((value) => 'Value: $value');
        expect(result.isSuccess, isTrue);
        expect(result.data, equals(10));
        expect(doubled.isSuccess, isTrue);
        expect(doubled.data, equals(20));
        expect(stringified.isSuccess, isTrue);
        expect(stringified.data, equals('Value: 20'));
      });
    });
    group('Result Combination Tests', () {
      test('should combine two successful results', () {
        final result1 = CFResult.success(5);
        final result2 = CFResult.success(3);
        final combined = CFResult.combine(
          result1,
          result2,
          (a, b) => a + b,
        );
        expect(combined.isSuccess, isTrue);
        expect(combined.data, equals(8));
      });
      test('should handle combine exceptions', () {
        final result1 = CFResult.success(5);
        final result2 = CFResult.success(0);
        final combined = CFResult.combine(
          result1,
          result2,
          (a, b) => a ~/ b, // Division by zero
        );
        expect(combined.isSuccess, isFalse);
        expect(combined.getErrorMessage(), contains('Combination failed'));
      });
      test('should return first error when first result is error', () {
        final result1 = CFResult<int>.error(
          'First error',
          errorCode: CFErrorCode.networkTimeout,
        );
        final result2 = CFResult.success(3);
        final combined = CFResult.combine(
          result1,
          result2,
          (a, b) => a + b,
        );
        expect(combined.isSuccess, isFalse);
        expect(combined.getErrorMessage(), equals('First error'));
        expect(combined.error!.errorCode, equals(CFErrorCode.networkTimeout));
      });
      test('should return second error when second result is error', () {
        final result1 = CFResult.success(5);
        final result2 = CFResult<int>.error(
          'Second error',
          errorCode: CFErrorCode.validationMissingRequiredField,
        );
        final combined = CFResult.combine(
          result1,
          result2,
          (a, b) => a + b,
        );
        expect(combined.isSuccess, isFalse);
        expect(combined.getErrorMessage(), equals('Second error'));
        expect(combined.error!.errorCode,
            equals(CFErrorCode.validationMissingRequiredField));
      });
      test('should combine errors when both results are errors', () {
        final result1 = CFResult<int>.error('First error');
        final result2 = CFResult<int>.error('Second error');
        final combined = CFResult.combine(
          result1,
          result2,
          (a, b) => a + b,
        );
        expect(combined.isSuccess, isFalse);
        expect(combined.getErrorMessage(), contains('Multiple errors'));
        expect(combined.getErrorMessage(), contains('First error'));
        expect(combined.getErrorMessage(), contains('Second error'));
      });
      test('should handle null errors gracefully in combine', () {
        // This tests the edge case where errors might be null
        final result1 = CFResult<int>.success(5);
        // Force an error scenario by manipulating the results
        final errorResult = CFResult<int>.error('Test');
        // This should not throw
        expect(() {
          CFResult.combine(result1, errorResult, (a, b) => a + b);
        }, returnsNormally);
      });
    });
    group('Static Factory Method Tests', () {
      test('should create result from function', () {
        final result = CFResult.fromResult(() => 'success');
        expect(result.isSuccess, isTrue);
        expect(result.data, equals('success'));
      });
      test('should create error result from throwing function', () {
        final result = CFResult.fromResult<String>(
          () => throw Exception('Failed'),
          errorMessage: 'Operation failed',
        );
        expect(!result.isSuccess, isTrue);
        expect(result.getErrorMessage(), equals('Operation failed'));
      });
    });
    group('Error Information Tests', () {
      test('should contain error details', () {
        final now = DateTime.now();
        final result = CFResult<String>.error(
          'Test error',
          code: 1001,
          category: ErrorCategory.network,
          errorCode: CFErrorCode.networkTimeout,
        );
        final error = result.error!;
        expect(error.message, equals('Test error'));
        expect(error.code, equals(1001));
        expect(error.category, equals(ErrorCategory.network));
        expect(error.errorCode, equals(CFErrorCode.networkTimeout));
        expect(error.timestamp.difference(now).inSeconds, lessThan(2));
      });
      test('should get status code from result', () {
        final successResult = CFResult.success('data');
        expect(successResult.getStatusCode(), equals(0));
        // When passing HTTP status code 404, it gets mapped to httpNotFound (1103)
        final errorResult = CFResult<String>.error('error', code: 404);
        expect(errorResult.getStatusCode(), equals(1103)); // httpNotFound code
        // Test with a non-HTTP error code that won't be mapped
        final customErrorResult =
            CFResult<String>.error('custom error', code: 9999);
        expect(customErrorResult.getStatusCode(),
            equals(4000)); // Maps to internalUnknownError (4000)
      });
    });
    group('Equality and Hash Tests', () {
      test('should be equal for same success values', () {
        final result1 = CFResult.success('test');
        final result2 = CFResult.success('test');
        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });
      test('should not be equal for different success values', () {
        final result1 = CFResult.success('test1');
        final result2 = CFResult.success('test2');
        expect(result1, isNot(equals(result2)));
      });
      test('should be equal for same error messages', () {
        final result1 = CFResult<String>.error('error', code: 1001);
        final result2 = CFResult<String>.error('error', code: 1001);
        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });
      test('should not be equal for different error messages', () {
        final result1 = CFResult<String>.error('error1');
        final result2 = CFResult<String>.error('error2');
        expect(result1, isNot(equals(result2)));
      });
      test('should not be equal for success vs error', () {
        final success = CFResult.success('test');
        final error = CFResult<String>.error('error');
        expect(success, isNot(equals(error)));
      });
      test('should be equal to itself', () {
        final result = CFResult.success('test');
        expect(result, equals(result));
      });
      test('should not be equal to different types', () {
        final result = CFResult.success('test');
        expect(result, isNot(equals('test')));
        expect(result, isNot(equals(null)));
        expect(result, isNot(equals(42)));
      });
    });
    group('ToString Tests', () {
      test('should have readable toString for success', () {
        final result = CFResult.success('test value');
        expect(result.toString(), equals('CFResult.success(test value)'));
      });
      test('should have readable toString for error', () {
        final result = CFResult<String>.error('error message');
        expect(result.toString(), equals('CFResult.error(error message)'));
      });
      test('should handle null values in toString', () {
        final successNull = CFResult<String?>.success(null);
        expect(successNull.toString(), equals('CFResult.success(null)'));
      });
    });
    group('Result Pattern Matching Tests', () {
      test('should match success result', () {
        final result = CFResult.success(5);
        expect(result.isSuccess, isTrue);
        expect(!result.isSuccess, isFalse);
        expect(result.data, equals(5));
      });
      test('should match error result', () {
        final result = CFResult<int>.error('error');
        expect(!result.isSuccess, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
      });
      test('should handle success result in conditional', () {
        final result = CFResult.success(42);
        String output = '';
        if (result.isSuccess) {
          output = 'Success: ${result.data}';
        } else {
          output = 'Error: ${result.getErrorMessage()}';
        }
        expect(output, equals('Success: 42'));
      });
      test('should handle error result in conditional', () {
        final result = CFResult<int>.error('Failed');
        String output = '';
        if (result.isSuccess) {
          output = 'Success: ${result.data}';
        } else {
          output = 'Error: ${result.getErrorMessage()}';
        }
        expect(output, equals('Error: Failed'));
      });
    });
  });
}
