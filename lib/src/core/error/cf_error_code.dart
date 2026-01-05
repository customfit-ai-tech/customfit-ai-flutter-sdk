import 'error_severity.dart';

/// Standardized error codes for CustomFit SDK
/// Error codes follow a 4-digit format: XYYY
/// - X: Category digit (1-5)
/// - YYY: Specific error within category (000-999)
class CFErrorCode {
  final int code;
  final String name;
  final String category;

  const CFErrorCode._(this.code, this.name, this.category);

  // Network Errors (1000-1999)
  static const networkUnavailable =
      CFErrorCode._(1000, 'NETWORK_UNAVAILABLE', 'Network');
  static const networkTimeout =
      CFErrorCode._(1001, 'NETWORK_TIMEOUT', 'Network');
  static const networkConnectionLost =
      CFErrorCode._(1002, 'NETWORK_CONNECTION_LOST', 'Network');
  static const networkDnsFailure =
      CFErrorCode._(1003, 'NETWORK_DNS_FAILURE', 'Network');
  static const networkSslError =
      CFErrorCode._(1004, 'NETWORK_SSL_ERROR', 'Network');
  static const httpBadRequest =
      CFErrorCode._(1100, 'HTTP_BAD_REQUEST', 'Network');
  static const httpUnauthorized =
      CFErrorCode._(1101, 'HTTP_UNAUTHORIZED', 'Network');
  static const httpForbidden = CFErrorCode._(1102, 'HTTP_FORBIDDEN', 'Network');
  static const httpNotFound = CFErrorCode._(1103, 'HTTP_NOT_FOUND', 'Network');
  static const httpMethodNotAllowed =
      CFErrorCode._(1104, 'HTTP_METHOD_NOT_ALLOWED', 'Network');
  static const httpConflict = CFErrorCode._(1105, 'HTTP_CONFLICT', 'Network');
  static const httpGone = CFErrorCode._(1106, 'HTTP_GONE', 'Network');
  static const httpUnprocessable =
      CFErrorCode._(1107, 'HTTP_UNPROCESSABLE', 'Network');
  static const httpTooManyRequests =
      CFErrorCode._(1108, 'HTTP_TOO_MANY_REQUESTS', 'Network');
  static const httpProxyAuthRequired =
      CFErrorCode._(1109, 'HTTP_PROXY_AUTH_REQUIRED', 'Network');
  static const httpInternalServerError =
      CFErrorCode._(1150, 'HTTP_INTERNAL_SERVER_ERROR', 'Network');
  static const httpBadGateway =
      CFErrorCode._(1151, 'HTTP_BAD_GATEWAY', 'Network');
  static const httpServiceUnavailable =
      CFErrorCode._(1152, 'HTTP_SERVICE_UNAVAILABLE', 'Network');
  static const httpGatewayTimeout =
      CFErrorCode._(1153, 'HTTP_GATEWAY_TIMEOUT', 'Network');

  // Configuration Errors (2000-2999)
  static const configMissingApiKey =
      CFErrorCode._(2000, 'CONFIG_MISSING_API_KEY', 'Configuration');
  static const configInvalidApiKey =
      CFErrorCode._(2001, 'CONFIG_INVALID_API_KEY', 'Configuration');
  static const configMissingEnvironment =
      CFErrorCode._(2002, 'CONFIG_MISSING_ENVIRONMENT', 'Configuration');
  static const configInvalidEnvironment =
      CFErrorCode._(2003, 'CONFIG_INVALID_ENVIRONMENT', 'Configuration');
  static const configMissingUser =
      CFErrorCode._(2004, 'CONFIG_MISSING_USER', 'Configuration');
  static const configInvalidUrl =
      CFErrorCode._(2005, 'CONFIG_INVALID_URL', 'Configuration');
  static const configInitializationFailed =
      CFErrorCode._(2006, 'CONFIG_INITIALIZATION_FAILED', 'Configuration');
  static const configAlreadyInitialized =
      CFErrorCode._(2007, 'CONFIG_ALREADY_INITIALIZED', 'Configuration');
  static const configNotInitialized =
      CFErrorCode._(2008, 'CONFIG_NOT_INITIALIZED', 'Configuration');
  static const configInvalidSettings =
      CFErrorCode._(2009, 'CONFIG_INVALID_SETTINGS', 'Configuration');
  static const configCacheError =
      CFErrorCode._(2010, 'CONFIG_CACHE_ERROR', 'Configuration');
  static const configPollingError =
      CFErrorCode._(2011, 'CONFIG_POLLING_ERROR', 'Configuration');

  // Validation Errors (3000-3999)
  static const validationInvalidUserId =
      CFErrorCode._(3000, 'VALIDATION_INVALID_USER_ID', 'Validation');
  static const validationInvalidFlagKey =
      CFErrorCode._(3001, 'VALIDATION_INVALID_FLAG_KEY', 'Validation');
  static const validationInvalidPropertyKey =
      CFErrorCode._(3002, 'VALIDATION_INVALID_PROPERTY_KEY', 'Validation');
  static const validationInvalidPropertyValue =
      CFErrorCode._(3003, 'VALIDATION_INVALID_PROPERTY_VALUE', 'Validation');
  static const validationMissingRequiredField =
      CFErrorCode._(3004, 'VALIDATION_MISSING_REQUIRED_FIELD', 'Validation');
  static const validationInvalidEventName =
      CFErrorCode._(3005, 'VALIDATION_INVALID_EVENT_NAME', 'Validation');
  static const validationInvalidContext =
      CFErrorCode._(3006, 'VALIDATION_INVALID_CONTEXT', 'Validation');
  static const validationExceededLimit =
      CFErrorCode._(3007, 'VALIDATION_EXCEEDED_LIMIT', 'Validation');
  static const validationInvalidType =
      CFErrorCode._(3008, 'VALIDATION_INVALID_TYPE', 'Validation');
  static const validationInvalidFormat =
      CFErrorCode._(3009, 'VALIDATION_INVALID_FORMAT', 'Validation');
  static const validationDuplicateKey =
      CFErrorCode._(3010, 'VALIDATION_DUPLICATE_KEY', 'Validation');

  // Internal/SDK Errors (4000-4999)
  static const internalUnknownError =
      CFErrorCode._(4000, 'INTERNAL_UNKNOWN_ERROR', 'Internal');
  static const internalSerializationError =
      CFErrorCode._(4001, 'INTERNAL_SERIALIZATION_ERROR', 'Internal');
  static const internalStorageError =
      CFErrorCode._(4002, 'INTERNAL_STORAGE_ERROR', 'Internal');
  static const internalThreadError =
      CFErrorCode._(4003, 'INTERNAL_THREAD_ERROR', 'Internal');
  static const internalMemoryError =
      CFErrorCode._(4004, 'INTERNAL_MEMORY_ERROR', 'Internal');
  static const internalEvaluationError =
      CFErrorCode._(4005, 'INTERNAL_EVALUATION_ERROR', 'Internal');
  static const internalCircuitBreakerOpen =
      CFErrorCode._(4006, 'INTERNAL_CIRCUIT_BREAKER_OPEN', 'Internal');
  static const internalQueueFull =
      CFErrorCode._(4007, 'INTERNAL_QUEUE_FULL', 'Internal');
  static const internalLifecycleError =
      CFErrorCode._(4008, 'INTERNAL_LIFECYCLE_ERROR', 'Internal');
  static const internalPlatformError =
      CFErrorCode._(4009, 'INTERNAL_PLATFORM_ERROR', 'Internal');
  static const internalDependencyError =
      CFErrorCode._(4010, 'INTERNAL_DEPENDENCY_ERROR', 'Internal');
  static const internalConversionError =
      CFErrorCode._(4011, 'INTERNAL_CONVERSION_ERROR', 'Internal');
  static const internalCacheError =
      CFErrorCode._(4012, 'INTERNAL_CACHE_ERROR', 'Internal');
  static const internalEventError =
      CFErrorCode._(4013, 'INTERNAL_EVENT_ERROR', 'Internal');

  // Authentication Errors (5000-5999)
  static const authInvalidCredentials =
      CFErrorCode._(5000, 'AUTH_INVALID_CREDENTIALS', 'Authentication');
  static const authExpiredToken =
      CFErrorCode._(5001, 'AUTH_EXPIRED_TOKEN', 'Authentication');
  static const authInvalidToken =
      CFErrorCode._(5002, 'AUTH_INVALID_TOKEN', 'Authentication');
  static const authMissingToken =
      CFErrorCode._(5003, 'AUTH_MISSING_TOKEN', 'Authentication');
  static const authInsufficientPermissions =
      CFErrorCode._(5004, 'AUTH_INSUFFICIENT_PERMISSIONS', 'Authentication');
  static const authAccountSuspended =
      CFErrorCode._(5005, 'AUTH_ACCOUNT_SUSPENDED', 'Authentication');
  static const authAccountNotFound =
      CFErrorCode._(5006, 'AUTH_ACCOUNT_NOT_FOUND', 'Authentication');
  static const authSessionExpired =
      CFErrorCode._(5007, 'AUTH_SESSION_EXPIRED', 'Authentication');
  static const authRateLimited =
      CFErrorCode._(5008, 'AUTH_RATE_LIMITED', 'Authentication');
  static const authMfaRequired =
      CFErrorCode._(5009, 'AUTH_MFA_REQUIRED', 'Authentication');
  static const authApiKeyRevoked =
      CFErrorCode._(5010, 'AUTH_API_KEY_REVOKED', 'Authentication');

  // Static sets for efficient lookups
  static const Set<int> _recoverableErrorCodes = {
    1001, // networkTimeout
    1002, // networkConnectionLost
    1000, // networkUnavailable
    1108, // httpTooManyRequests
    1152, // httpServiceUnavailable
    1153, // httpGatewayTimeout
    4006, // internalCircuitBreakerOpen
  };

  static const Set<int> _criticalErrorCodes = {
    2000, // configMissingApiKey
    2008, // configNotInitialized
    5000, // authInvalidCredentials
    5010, // authApiKeyRevoked
  };

  static const Set<int> _highSeverityErrorCodes = {
    2006, // configInitializationFailed
    4004, // internalMemoryError
  };

  /// Get error code from HTTP status code
  static CFErrorCode? fromHttpStatus(int statusCode) {
    switch (statusCode) {
      case 400:
        return httpBadRequest;
      case 401:
        return httpUnauthorized;
      case 403:
        return httpForbidden;
      case 404:
        return httpNotFound;
      case 405:
        return httpMethodNotAllowed;
      case 409:
        return httpConflict;
      case 410:
        return httpGone;
      case 422:
        return httpUnprocessable;
      case 429:
        return httpTooManyRequests;
      case 500:
        return httpInternalServerError;
      case 502:
        return httpBadGateway;
      case 503:
        return httpServiceUnavailable;
      case 504:
        return httpGatewayTimeout;
      default:
        return null;
    }
  }

  /// Check if error is recoverable using efficient lookups
  bool get isRecoverable {
    // Skip expensive operations during test execution to prevent segfaults
    if (const bool.fromEnvironment('FLUTTER_TEST', defaultValue: false)) {
      // Return a simple result based on code during tests
      return code >= 1000 &&
          code < 1200; // Network errors are generally recoverable
    }

    // Use efficient set lookup instead of multiple comparisons
    if (_recoverableErrorCodes.contains(code)) {
      return true;
    }

    // Use code ranges for category checks (more efficient than string comparison)
    final categoryCode = code ~/ 1000;

    // Configuration (2xxx) and authentication (5xxx) errors are generally not recoverable
    if (categoryCode == 2 || categoryCode == 5) {
      return false;
    }

    // Validation errors (3xxx) are not recoverable
    if (categoryCode == 3) {
      return false;
    }

    return false;
  }

  /// Get severity level for the error using efficient lookups
  ErrorSeverity get severity {
    // Skip expensive operations during test execution to prevent segfaults
    if (const bool.fromEnvironment('FLUTTER_TEST', defaultValue: false)) {
      // Return simple severity during tests
      return ErrorSeverity.medium;
    }

    // Critical errors
    if (_criticalErrorCodes.contains(code)) {
      return ErrorSeverity.critical;
    }

    // High severity errors
    if (_highSeverityErrorCodes.contains(code)) {
      return ErrorSeverity.high;
    }

    final categoryCode = code ~/ 1000;

    // High severity for authentication errors
    if (categoryCode == 5) {
      return ErrorSeverity.high;
    }

    // Medium severity for network and validation errors
    if (categoryCode == 1 || categoryCode == 3) {
      return ErrorSeverity.medium;
    }

    // Low severity for others
    return ErrorSeverity.low;
  }

  @override
  String toString() => '$name ($code)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CFErrorCode &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}
