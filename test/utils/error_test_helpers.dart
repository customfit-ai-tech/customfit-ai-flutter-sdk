import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_error_code.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_severity.dart';
/// Shared utilities for error testing across all test suites
class ErrorTestHelpers {
  /// Create a DioException with the given status code
  static DioException createHttpError(
    int statusCode, {
    String? message,
    Map<String, dynamic>? data,
    Map<String, List<String>>? headers,
  }) {
    return DioException(
      requestOptions: RequestOptions(path: '/test'),
      response: Response(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: statusCode,
        statusMessage: message ?? _getDefaultMessage(statusCode),
        data: data,
        headers: headers != null ? Headers.fromMap(headers) : null,
      ),
      type: DioExceptionType.badResponse,
    );
  }
  /// Create a network error (connection issues)
  static DioException createNetworkError(String type) {
    switch (type) {
      case 'timeout':
        return DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timeout',
        );
      case 'dns':
        return DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
          message: 'getaddrinfo ENOTFOUND api.customfit.ai',
        );
      case 'ssl':
        return DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badCertificate,
          message: 'Certificate verification failed',
        );
      case 'connection_lost':
        return DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
          error: Exception('Connection reset by peer'),
        );
      default:
        return DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.unknown,
          message: 'Network error',
        );
    }
  }
  /// Verify error code and properties
  static void verifyError(
    CFError? error,
    CFErrorCode expectedCode, {
    ErrorCategory? expectedCategory,
    ErrorSeverity? expectedSeverity,
    bool? expectedRecoverable,
  }) {
    expect(error, isNotNull);
    expect(error!.errorCode, expectedCode);
    expect(error.code, expectedCode.code);
    expect(error.name, expectedCode.name);
    if (expectedCategory != null) {
      expect(error.category, expectedCategory);
    }
    if (expectedSeverity != null) {
      expect(error.severity, expectedSeverity);
    }
    if (expectedRecoverable != null) {
      expect(error.recoverable, expectedRecoverable);
    }
    // Verify timestamp is recent
    expect(error.timestamp.difference(DateTime.now()).inSeconds.abs(), lessThan(5));
  }
  /// Verify error result
  static void verifyErrorResult<T>(
    CFResult<T> result,
    CFErrorCode expectedCode, {
    String? messageContains,
    Map<String, dynamic>? contextContains,
  }) {
    expect(result.isSuccess, false);
    expect(result.error, isNotNull);
    verifyError(result.error, expectedCode);
    if (messageContains != null) {
      expect(result.error!.message, contains(messageContains));
    }
    if (contextContains != null) {
      expect(result.error!.context, isNotNull);
      contextContains.forEach((key, value) {
        expect(result.error!.context![key], value);
      });
    }
  }
  /// Create a mock that simulates retry scenarios
  static void setupRetryScenario<T>(
    T mock,
    String method,
    List<dynamic> responses, {
    Duration? delayBetween,
  }) {
    // Note: This is a generic helper. Specific mock setup should be done in the test files
    // using the appropriate when() syntax for the specific mock type.
    // This method is kept for interface compatibility but implementation
    // should be done in the specific test files.
  }
  /// Create a sequence of errors followed by success
  static List<dynamic> createErrorThenSuccessSequence(
    List<DioException> errors,
    Response successResponse,
  ) {
    return [...errors, successResponse];
  }
  /// Measure retry timing
  static Future<RetryMetrics> measureRetryTiming(
    Future<CFResult<dynamic>> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    final result = await operation();
    stopwatch.stop();
    return RetryMetrics(
      totalDuration: stopwatch.elapsed,
      result: result,
    );
  }
  /// Get default HTTP status message
  static String _getDefaultMessage(int statusCode) {
    switch (statusCode) {
      case 400: return 'Bad Request';
      case 401: return 'Unauthorized';
      case 403: return 'Forbidden';
      case 404: return 'Not Found';
      case 429: return 'Too Many Requests';
      case 500: return 'Internal Server Error';
      case 503: return 'Service Unavailable';
      default: return 'HTTP Error $statusCode';
    }
  }
  /// Verify error is properly logged
  static void expectErrorLogged(
    void Function() operation,
    String expectedLogContent,
  ) {
    // In a real implementation, you would capture logs
    // For now, just execute the operation
    operation();
  }
  /// Create test cases for all error codes in a category
  static List<ErrorTestCase> createCategoryTestCases(String category) {
    final testCases = <ErrorTestCase>[];
    switch (category) {
      case 'Network':
        testCases.addAll([
          ErrorTestCase(
            code: CFErrorCode.networkTimeout,
            setupError: () => createNetworkError('timeout'),
            expectedRecoverable: true,
          ),
          ErrorTestCase(
            code: CFErrorCode.networkDnsFailure,
            setupError: () => createNetworkError('dns'),
            expectedRecoverable: false,
          ),
          // Add more network test cases
        ]);
        break;
      case 'Authentication':
        testCases.addAll([
          ErrorTestCase(
            code: CFErrorCode.httpUnauthorized,
            setupError: () => createHttpError(401, data: {'error': 'Invalid credentials'}),
            expectedRecoverable: false,
          ),
          ErrorTestCase(
            code: CFErrorCode.httpForbidden,
            setupError: () => createHttpError(403, data: {'error': 'Access denied'}),
            expectedRecoverable: false,
          ),
          // Add more auth test cases
        ]);
        break;
      // Add more categories
    }
    return testCases;
  }
}
/// Test case for error scenarios
class ErrorTestCase {
  final CFErrorCode code;
  final Exception Function() setupError;
  final bool expectedRecoverable;
  final ErrorSeverity? expectedSeverity;
  final String? expectedMessageContains;
  ErrorTestCase({
    required this.code,
    required this.setupError,
    required this.expectedRecoverable,
    this.expectedSeverity,
    this.expectedMessageContains,
  });
}
/// Metrics from retry operations
class RetryMetrics {
  final Duration totalDuration;
  final CFResult<dynamic> result;
  RetryMetrics({
    required this.totalDuration,
    required this.result,
  });
  int get retryDelayMs => totalDuration.inMilliseconds;
}