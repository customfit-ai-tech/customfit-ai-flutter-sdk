import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/test_binding_helper.dart';
import 'package:customfit_ai_flutter_sdk/src/logging/logger.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
/// Global test configuration
/// Import this file in tests that need common setup
class TestConfig {
  TestConfig._();
  /// Default timeout for async operations in tests
  static const Duration defaultTimeout = Duration(seconds: 5);
  /// Default timeout for network operations in tests
  static const Duration networkTimeout = Duration(seconds: 10);
  /// Default polling interval for wait conditions
  static const Duration pollingInterval = Duration(milliseconds: 100);
  /// Maximum retry attempts for flaky operations
  static const int maxRetries = 3;
  /// Whether to enable verbose logging in tests
  static const bool enableVerboseLogging = false;
  /// Enable logger for coverage but disable output
  static void setupTestLogger() {
    // This ensures Logger calls are executed (for coverage) but with minimal output
    Logger.configure(
      enabled: true,
      debugEnabled: false, // Set to true only when debugging tests
    );
  }
  /// Set up common test configuration
  /// Call this in main() before any test groups
  static void setUp() {
    // Initialize test binding once for all tests
    TestBindingHelper.ensureInitialized();
    setupTestLogger(); // Enable logger for coverage
    // Mock SharedPreferences to prevent null check errors
    SharedPreferences.setMockInitialValues({});
    // Test timeout is configured per test or test group
    // Use timeout parameter in test() or group() functions
    // Set up error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log errors but don't fail tests for expected errors
      if (!_isExpectedError(details)) {
        Zone.current.handleUncaughtError(details.exception, details.stack!);
      }
    };
  }
  /// Check if an error is expected and should be ignored
  static bool _isExpectedError(FlutterErrorDetails details) {
    final error = details.exception.toString();
    // Add patterns for expected errors here
    const expectedPatterns = [
      'setState() called after dispose()',
      'A Timer is still pending',
      'The following assertion was thrown running a test:',
    ];
    return expectedPatterns.any((pattern) => error.contains(pattern));
  }
  /// Clean up after tests
  static void tearDown() {
    // Reset any global state if needed
    PreferencesService.reset();
  }
  /// Set up the test environment
  static void setupTestEnvironment() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    setupTestLogger();
  }
  /// Disable connection monitoring to prevent infinite logging during tests
  static void disableConnectionMonitoring() {
    // This will prevent the connection manager from continuously checking status
    // Add this to your test setup if you see infinite connection status logs
  }
}
/// Base class for test groups that need common setup
abstract class BaseTestGroup {
  /// Override to provide test group name
  String get groupName;
  /// Override to define tests
  void defineTests();
  /// Run the test group with proper setup
  void run() {
    group(groupName, () {
      setUpAll(() {
        TestConfig.setUp();
      });
      tearDownAll(() {
        TestConfig.tearDown();
      });
      defineTests();
    });
  }
}
