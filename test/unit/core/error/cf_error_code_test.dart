import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_error_code.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_severity.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CFErrorCode Tests', () {
    group('Error Code Range Tests', () {
      test('should have correct code ranges for each category', () {
        // Network errors (1000-1999)
        expect(
            CFErrorCode.networkUnavailable.code, inInclusiveRange(1000, 1999));
        expect(CFErrorCode.networkTimeout.code, inInclusiveRange(1000, 1999));
        expect(CFErrorCode.networkConnectionLost.code,
            inInclusiveRange(1000, 1999));
        expect(
            CFErrorCode.networkDnsFailure.code, inInclusiveRange(1000, 1999));
        expect(CFErrorCode.networkSslError.code, inInclusiveRange(1000, 1999));
        expect(CFErrorCode.httpBadRequest.code, inInclusiveRange(1000, 1999));
        expect(CFErrorCode.httpUnauthorized.code, inInclusiveRange(1000, 1999));
        expect(CFErrorCode.httpForbidden.code, inInclusiveRange(1000, 1999));
        expect(CFErrorCode.httpNotFound.code, inInclusiveRange(1000, 1999));
        expect(
            CFErrorCode.httpTooManyRequests.code, inInclusiveRange(1000, 1999));
        expect(CFErrorCode.httpInternalServerError.code,
            inInclusiveRange(1000, 1999));
        expect(CFErrorCode.httpServiceUnavailable.code,
            inInclusiveRange(1000, 1999));
        // Configuration errors (2000-2999)
        expect(
            CFErrorCode.configMissingApiKey.code, inInclusiveRange(2000, 2999));
        expect(
            CFErrorCode.configInvalidApiKey.code, inInclusiveRange(2000, 2999));
        expect(CFErrorCode.configMissingEnvironment.code,
            inInclusiveRange(2000, 2999));
        expect(CFErrorCode.configInvalidEnvironment.code,
            inInclusiveRange(2000, 2999));
        expect(
            CFErrorCode.configMissingUser.code, inInclusiveRange(2000, 2999));
        expect(CFErrorCode.configInvalidUrl.code, inInclusiveRange(2000, 2999));
        expect(CFErrorCode.configInitializationFailed.code,
            inInclusiveRange(2000, 2999));
        expect(CFErrorCode.configAlreadyInitialized.code,
            inInclusiveRange(2000, 2999));
        expect(CFErrorCode.configNotInitialized.code,
            inInclusiveRange(2000, 2999));
        expect(CFErrorCode.configCacheError.code, inInclusiveRange(2000, 2999));
        // Validation errors (3000-3999)
        expect(CFErrorCode.validationInvalidUserId.code,
            inInclusiveRange(3000, 3999));
        expect(CFErrorCode.validationInvalidFlagKey.code,
            inInclusiveRange(3000, 3999));
        expect(CFErrorCode.validationInvalidPropertyKey.code,
            inInclusiveRange(3000, 3999));
        expect(CFErrorCode.validationInvalidPropertyValue.code,
            inInclusiveRange(3000, 3999));
        expect(CFErrorCode.validationInvalidEventName.code,
            inInclusiveRange(3000, 3999));
        expect(CFErrorCode.validationInvalidFormat.code,
            inInclusiveRange(3000, 3999));
        expect(CFErrorCode.validationExceededLimit.code,
            inInclusiveRange(3000, 3999));
        // Internal errors (4000-4999)
        expect(CFErrorCode.internalStorageError.code,
            inInclusiveRange(4000, 4999));
        expect(CFErrorCode.internalSerializationError.code,
            inInclusiveRange(4000, 4999));
        expect(
            CFErrorCode.internalThreadError.code, inInclusiveRange(4000, 4999));
        expect(
            CFErrorCode.internalMemoryError.code, inInclusiveRange(4000, 4999));
        expect(CFErrorCode.internalUnknownError.code,
            inInclusiveRange(4000, 4999));
        // Authentication errors (5000-5999)
        expect(CFErrorCode.authInvalidCredentials.code,
            inInclusiveRange(5000, 5999));
        expect(CFErrorCode.authExpiredToken.code, inInclusiveRange(5000, 5999));
        expect(CFErrorCode.authInvalidToken.code, inInclusiveRange(5000, 5999));
        expect(CFErrorCode.authMissingToken.code, inInclusiveRange(5000, 5999));
        expect(CFErrorCode.authInsufficientPermissions.code,
            inInclusiveRange(5000, 5999));
      });
    });
    group('Error Code Properties Tests', () {
      test('should have correct names for network errors', () {
        expect(
            CFErrorCode.networkUnavailable.name, equals('NETWORK_UNAVAILABLE'));
        expect(CFErrorCode.networkTimeout.name, equals('NETWORK_TIMEOUT'));
        expect(CFErrorCode.networkConnectionLost.name,
            equals('NETWORK_CONNECTION_LOST'));
        expect(CFErrorCode.httpBadRequest.name, equals('HTTP_BAD_REQUEST'));
        expect(CFErrorCode.httpUnauthorized.name, equals('HTTP_UNAUTHORIZED'));
        expect(CFErrorCode.httpTooManyRequests.name,
            equals('HTTP_TOO_MANY_REQUESTS'));
      });
      test('should have correct names for configuration errors', () {
        expect(CFErrorCode.configMissingApiKey.name,
            equals('CONFIG_MISSING_API_KEY'));
        expect(CFErrorCode.configInvalidApiKey.name,
            equals('CONFIG_INVALID_API_KEY'));
        expect(CFErrorCode.configMissingEnvironment.name,
            equals('CONFIG_MISSING_ENVIRONMENT'));
        expect(CFErrorCode.configNotInitialized.name,
            equals('CONFIG_NOT_INITIALIZED'));
      });
      test('should have correct names for validation errors', () {
        expect(CFErrorCode.validationInvalidUserId.name,
            equals('VALIDATION_INVALID_USER_ID'));
        expect(CFErrorCode.validationInvalidFlagKey.name,
            equals('VALIDATION_INVALID_FLAG_KEY'));
        expect(CFErrorCode.validationInvalidPropertyKey.name,
            equals('VALIDATION_INVALID_PROPERTY_KEY'));
        expect(CFErrorCode.validationInvalidFormat.name,
            equals('VALIDATION_INVALID_FORMAT'));
      });
      test('should have correct names for internal errors', () {
        expect(CFErrorCode.internalStorageError.name,
            equals('INTERNAL_STORAGE_ERROR'));
        expect(CFErrorCode.internalSerializationError.name,
            equals('INTERNAL_SERIALIZATION_ERROR'));
        expect(CFErrorCode.internalThreadError.name,
            equals('INTERNAL_THREAD_ERROR'));
        expect(CFErrorCode.internalUnknownError.name,
            equals('INTERNAL_UNKNOWN_ERROR'));
      });
      test('should have correct names for authentication errors', () {
        expect(CFErrorCode.authInvalidCredentials.name,
            equals('AUTH_INVALID_CREDENTIALS'));
        expect(CFErrorCode.authExpiredToken.name, equals('AUTH_EXPIRED_TOKEN'));
        expect(CFErrorCode.authInvalidToken.name, equals('AUTH_INVALID_TOKEN'));
        expect(CFErrorCode.authMissingToken.name, equals('AUTH_MISSING_TOKEN'));
      });
    });
    group('Error Code Categories Tests', () {
      test('should have correct categories for error codes', () {
        // Network errors
        expect(CFErrorCode.networkUnavailable.category, equals('Network'));
        expect(CFErrorCode.networkTimeout.category, equals('Network'));
        expect(CFErrorCode.httpBadRequest.category, equals('Network'));
        // Configuration errors
        expect(
            CFErrorCode.configMissingApiKey.category, equals('Configuration'));
        expect(
            CFErrorCode.configInvalidApiKey.category, equals('Configuration'));
        expect(
            CFErrorCode.configNotInitialized.category, equals('Configuration'));
        // Validation errors
        expect(
            CFErrorCode.validationInvalidUserId.category, equals('Validation'));
        expect(CFErrorCode.validationInvalidFlagKey.category,
            equals('Validation'));
        expect(
            CFErrorCode.validationInvalidFormat.category, equals('Validation'));
        // Internal errors
        expect(CFErrorCode.internalStorageError.category, equals('Internal'));
        expect(CFErrorCode.internalSerializationError.category,
            equals('Internal'));
        expect(CFErrorCode.internalUnknownError.category, equals('Internal'));
        // Authentication errors
        expect(CFErrorCode.authInvalidCredentials.category,
            equals('Authentication'));
        expect(CFErrorCode.authExpiredToken.category, equals('Authentication'));
        expect(CFErrorCode.authInvalidToken.category, equals('Authentication'));
      });
    });
    group('Error Severity Tests', () {
      test('should have critical severity for essential errors', () {
        expect(CFErrorCode.configMissingApiKey.severity,
            equals(ErrorSeverity.critical));
        expect(CFErrorCode.configNotInitialized.severity,
            equals(ErrorSeverity.critical));
        expect(CFErrorCode.authInvalidCredentials.severity,
            equals(ErrorSeverity.critical));
        expect(CFErrorCode.authApiKeyRevoked.severity,
            equals(ErrorSeverity.critical));
      });
      test('should have high severity for authentication and memory errors',
          () {
        expect(
            CFErrorCode.authExpiredToken.severity, equals(ErrorSeverity.high));
        expect(
            CFErrorCode.authInvalidToken.severity, equals(ErrorSeverity.high));
        expect(CFErrorCode.configInitializationFailed.severity,
            equals(ErrorSeverity.high));
        expect(CFErrorCode.internalMemoryError.severity,
            equals(ErrorSeverity.high));
      });
      test('should have medium severity for network and validation errors', () {
        expect(CFErrorCode.networkUnavailable.severity,
            equals(ErrorSeverity.medium));
        expect(
            CFErrorCode.networkTimeout.severity, equals(ErrorSeverity.medium));
        expect(CFErrorCode.httpUnauthorized.severity,
            equals(ErrorSeverity.medium));
        expect(CFErrorCode.validationInvalidUserId.severity,
            equals(ErrorSeverity.medium));
        expect(CFErrorCode.validationInvalidFlagKey.severity,
            equals(ErrorSeverity.medium));
      });
      test('should have low severity for other internal errors', () {
        expect(CFErrorCode.internalStorageError.severity,
            equals(ErrorSeverity.low));
        expect(CFErrorCode.internalSerializationError.severity,
            equals(ErrorSeverity.low));
      });
    });
    group('Error Code Uniqueness Tests', () {
      test('should have unique error codes', () {
        final allCodes = [
          // Network
          CFErrorCode.networkUnavailable,
          CFErrorCode.networkTimeout,
          CFErrorCode.networkConnectionLost,
          CFErrorCode.networkDnsFailure,
          CFErrorCode.networkSslError,
          CFErrorCode.httpBadRequest,
          CFErrorCode.httpUnauthorized,
          CFErrorCode.httpForbidden,
          CFErrorCode.httpNotFound,
          CFErrorCode.httpMethodNotAllowed,
          CFErrorCode.httpConflict,
          CFErrorCode.httpGone,
          CFErrorCode.httpUnprocessable,
          CFErrorCode.httpTooManyRequests,
          CFErrorCode.httpProxyAuthRequired,
          CFErrorCode.httpInternalServerError,
          CFErrorCode.httpBadGateway,
          CFErrorCode.httpServiceUnavailable,
          CFErrorCode.httpGatewayTimeout,
          // Configuration
          CFErrorCode.configMissingApiKey,
          CFErrorCode.configInvalidApiKey,
          CFErrorCode.configMissingEnvironment,
          CFErrorCode.configInvalidEnvironment,
          CFErrorCode.configMissingUser,
          CFErrorCode.configInvalidUrl,
          CFErrorCode.configInitializationFailed,
          CFErrorCode.configAlreadyInitialized,
          CFErrorCode.configNotInitialized,
          CFErrorCode.configInvalidSettings,
          CFErrorCode.configCacheError,
          CFErrorCode.configPollingError,
          // Validation
          CFErrorCode.validationInvalidUserId,
          CFErrorCode.validationInvalidFlagKey,
          CFErrorCode.validationInvalidPropertyKey,
          CFErrorCode.validationInvalidPropertyValue,
          CFErrorCode.validationMissingRequiredField,
          CFErrorCode.validationInvalidEventName,
          CFErrorCode.validationInvalidContext,
          CFErrorCode.validationExceededLimit,
          CFErrorCode.validationInvalidType,
          CFErrorCode.validationInvalidFormat,
          CFErrorCode.validationDuplicateKey,
          // Internal
          CFErrorCode.internalUnknownError,
          CFErrorCode.internalSerializationError,
          CFErrorCode.internalStorageError,
          CFErrorCode.internalThreadError,
          CFErrorCode.internalMemoryError,
          CFErrorCode.internalEvaluationError,
          CFErrorCode.internalCircuitBreakerOpen,
          CFErrorCode.internalQueueFull,
          CFErrorCode.internalLifecycleError,
          CFErrorCode.internalPlatformError,
          CFErrorCode.internalDependencyError,
          // Authentication
          CFErrorCode.authInvalidCredentials,
          CFErrorCode.authExpiredToken,
          CFErrorCode.authInvalidToken,
          CFErrorCode.authMissingToken,
          CFErrorCode.authInsufficientPermissions,
          CFErrorCode.authAccountSuspended,
          CFErrorCode.authAccountNotFound,
          CFErrorCode.authSessionExpired,
          CFErrorCode.authRateLimited,
          CFErrorCode.authMfaRequired,
          CFErrorCode.authApiKeyRevoked,
        ];
        final codeSet = <int>{};
        for (final errorCode in allCodes) {
          expect(codeSet.add(errorCode.code), isTrue,
              reason:
                  'Duplicate error code found: ${errorCode.code} (${errorCode.name})');
        }
      });
    });
    group('Error Code toString Tests', () {
      test('should have proper string representation', () {
        expect(CFErrorCode.networkUnavailable.toString(),
            equals('NETWORK_UNAVAILABLE (1000)'));
        expect(CFErrorCode.configMissingApiKey.toString(),
            equals('CONFIG_MISSING_API_KEY (2000)'));
        expect(CFErrorCode.validationInvalidUserId.toString(),
            equals('VALIDATION_INVALID_USER_ID (3000)'));
        expect(CFErrorCode.internalStorageError.toString(),
            equals('INTERNAL_STORAGE_ERROR (4002)'));
        expect(CFErrorCode.authInvalidCredentials.toString(),
            equals('AUTH_INVALID_CREDENTIALS (5000)'));
      });
    });
    group('Error Code Name Consistency Tests', () {
      test('should have consistent naming patterns', () {
        // Network errors should start with NETWORK_ or HTTP_
        expect(CFErrorCode.networkUnavailable.name, startsWith('NETWORK_'));
        expect(CFErrorCode.httpBadRequest.name, startsWith('HTTP_'));
        // Config errors should start with CONFIG_
        expect(CFErrorCode.configMissingApiKey.name, startsWith('CONFIG_'));
        expect(CFErrorCode.configInvalidApiKey.name, startsWith('CONFIG_'));
        // Validation errors should start with VALIDATION_
        expect(CFErrorCode.validationInvalidUserId.name,
            startsWith('VALIDATION_'));
        expect(CFErrorCode.validationInvalidFlagKey.name,
            startsWith('VALIDATION_'));
        // Internal errors should start with INTERNAL_
        expect(CFErrorCode.internalStorageError.name, startsWith('INTERNAL_'));
        expect(CFErrorCode.internalSerializationError.name,
            startsWith('INTERNAL_'));
        // Auth errors should start with AUTH_
        expect(CFErrorCode.authInvalidCredentials.name, startsWith('AUTH_'));
        expect(CFErrorCode.authExpiredToken.name, startsWith('AUTH_'));
      });
    });
    group('HTTP Status Mapping Tests', () {
      test('should map HTTP status codes correctly', () {
        expect(CFErrorCode.fromHttpStatus(400),
            equals(CFErrorCode.httpBadRequest));
        expect(CFErrorCode.fromHttpStatus(401),
            equals(CFErrorCode.httpUnauthorized));
        expect(
            CFErrorCode.fromHttpStatus(403), equals(CFErrorCode.httpForbidden));
        expect(
            CFErrorCode.fromHttpStatus(404), equals(CFErrorCode.httpNotFound));
        expect(CFErrorCode.fromHttpStatus(405),
            equals(CFErrorCode.httpMethodNotAllowed));
        expect(
            CFErrorCode.fromHttpStatus(409), equals(CFErrorCode.httpConflict));
        expect(CFErrorCode.fromHttpStatus(410), equals(CFErrorCode.httpGone));
        expect(CFErrorCode.fromHttpStatus(422),
            equals(CFErrorCode.httpUnprocessable));
        expect(CFErrorCode.fromHttpStatus(429),
            equals(CFErrorCode.httpTooManyRequests));
        expect(CFErrorCode.fromHttpStatus(500),
            equals(CFErrorCode.httpInternalServerError));
        expect(CFErrorCode.fromHttpStatus(502),
            equals(CFErrorCode.httpBadGateway));
        expect(CFErrorCode.fromHttpStatus(503),
            equals(CFErrorCode.httpServiceUnavailable));
        expect(CFErrorCode.fromHttpStatus(504),
            equals(CFErrorCode.httpGatewayTimeout));
        expect(CFErrorCode.fromHttpStatus(200),
            isNull); // No mapping for success codes
        expect(CFErrorCode.fromHttpStatus(999),
            isNull); // No mapping for unknown codes
      });
    });
    group('Recoverability Tests', () {
      test('should identify recoverable errors', () {
        // Test recoverable network errors
        expect(CFErrorCode.networkTimeout.isRecoverable, isTrue);
        expect(CFErrorCode.networkConnectionLost.isRecoverable, isTrue);
        expect(CFErrorCode.networkUnavailable.isRecoverable, isTrue);
        expect(CFErrorCode.httpTooManyRequests.isRecoverable, isTrue);
        expect(CFErrorCode.httpServiceUnavailable.isRecoverable, isTrue);
        expect(CFErrorCode.httpGatewayTimeout.isRecoverable, isTrue);
        expect(CFErrorCode.internalCircuitBreakerOpen.isRecoverable, isTrue);
      });
      test('should identify non-recoverable errors', () {
        // Configuration errors are not recoverable
        expect(CFErrorCode.configMissingApiKey.isRecoverable, isFalse);
        expect(CFErrorCode.configInvalidApiKey.isRecoverable, isFalse);
        expect(CFErrorCode.configNotInitialized.isRecoverable, isFalse);
        // Authentication errors are not recoverable
        expect(CFErrorCode.authInvalidCredentials.isRecoverable, isFalse);
        expect(CFErrorCode.authExpiredToken.isRecoverable, isFalse);
        expect(CFErrorCode.authApiKeyRevoked.isRecoverable, isFalse);
        // Validation errors are not recoverable
        expect(CFErrorCode.validationInvalidUserId.isRecoverable, isFalse);
        expect(CFErrorCode.validationInvalidFlagKey.isRecoverable, isFalse);
        expect(CFErrorCode.validationInvalidFormat.isRecoverable, isFalse);
      });
      test('should handle all error categories for recoverability', () {
        // Test a sample from each category
        expect(CFErrorCode.networkDnsFailure.isRecoverable, isFalse);
        expect(CFErrorCode.configCacheError.isRecoverable, isFalse);
        expect(CFErrorCode.validationExceededLimit.isRecoverable, isFalse);
        expect(CFErrorCode.internalStorageError.isRecoverable, isFalse);
        expect(CFErrorCode.authSessionExpired.isRecoverable, isFalse);
      });
    });
    group('Equality and HashCode Tests', () {
      test('should be equal for same error codes', () {
        const error1 = CFErrorCode.networkUnavailable;
        const error2 = CFErrorCode.networkUnavailable;
        expect(error1, equals(error2));
        expect(error1.hashCode, equals(error2.hashCode));
      });
      test('should not be equal for different error codes', () {
        const error1 = CFErrorCode.networkUnavailable;
        const error2 = CFErrorCode.networkTimeout;
        expect(error1, isNot(equals(error2)));
        expect(error1.hashCode, isNot(equals(error2.hashCode)));
      });
      test('should handle equality with identical references', () {
        // Test that the same static instance is equal to itself
        const error1 = CFErrorCode.networkUnavailable;
        const error2 = CFErrorCode.networkUnavailable;
        expect(identical(error1, error2), isTrue);
        expect(error1, equals(error2));
        expect(error1.hashCode, equals(error2.hashCode));
      });
      test('should work in collections', () {
        final errorSet = <CFErrorCode>{
          CFErrorCode.networkUnavailable,
          CFErrorCode.networkTimeout,
        };
        // Add duplicate to test set behavior
        errorSet.add(CFErrorCode.networkUnavailable);
        expect(errorSet.length, equals(2)); // Duplicates not added
        expect(errorSet.contains(CFErrorCode.networkUnavailable), isTrue);
        expect(errorSet.contains(CFErrorCode.networkTimeout), isTrue);
      });
      test('should handle null comparison', () {
        // Testing for documentation/completeness
        // ignore: unnecessary_null_comparison
        expect(CFErrorCode.networkUnavailable == null, isFalse);
      });
    });
    group('Additional Error Code Tests', () {
      test('should test all HTTP proxy auth error', () {
        expect(CFErrorCode.httpProxyAuthRequired.code, equals(1109));
        expect(CFErrorCode.httpProxyAuthRequired.name,
            equals('HTTP_PROXY_AUTH_REQUIRED'));
        expect(CFErrorCode.httpProxyAuthRequired.category, equals('Network'));
      });
      test('should test validation error codes', () {
        expect(CFErrorCode.validationInvalidContext.code, equals(3006));
        expect(CFErrorCode.validationInvalidType.code, equals(3008));
        expect(CFErrorCode.validationDuplicateKey.code, equals(3010));
      });
      test('should test internal error codes', () {
        expect(CFErrorCode.internalEvaluationError.code, equals(4005));
        expect(CFErrorCode.internalQueueFull.code, equals(4007));
        expect(CFErrorCode.internalLifecycleError.code, equals(4008));
        expect(CFErrorCode.internalPlatformError.code, equals(4009));
        expect(CFErrorCode.internalDependencyError.code, equals(4010));
      });
      test('should test authentication error codes', () {
        expect(CFErrorCode.authAccountSuspended.code, equals(5005));
        expect(CFErrorCode.authAccountNotFound.code, equals(5006));
        expect(CFErrorCode.authSessionExpired.code, equals(5007));
        expect(CFErrorCode.authRateLimited.code, equals(5008));
        expect(CFErrorCode.authMfaRequired.code, equals(5009));
      });
    });
  });
}
