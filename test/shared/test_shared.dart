// test/shared/test_shared.dart
//
// Central export file for all shared test utilities.
// Import this file to access all test infrastructure components.
//
// This file is part of the CustomFit SDK for Flutter test suite.
// Export all mocks
export 'mocks/mock_http_client.dart';
export 'mocks/test_storage.dart';
// Export all fixtures
export 'fixtures/api_fixtures.dart';
// Export all helpers
export 'helpers/config_builder_helper.dart';
export 'helpers/test_helpers.dart';
// Re-export commonly used test utilities
export 'package:flutter_test/flutter_test.dart';
export 'package:mockito/mockito.dart';
// Re-export SDK components commonly used in tests
export 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart' show
  CFClient,
  CFConfig,
  CFUser,
  CFResult,
  LogLevel;
export 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart' show
  CFException;
// Re-export constants and enums
export 'package:customfit_ai_flutter_sdk/src/constants/cf_constants.dart' show
  CFEnvironment;
// Re-export error types for testing
export 'package:customfit_ai_flutter_sdk/src/core/error/cf_error_code.dart';
export 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
export 'package:customfit_ai_flutter_sdk/src/core/error/error_severity.dart';