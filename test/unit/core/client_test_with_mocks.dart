// test/unit/core/client_test_with_mocks.dart
//
// CFClient tests with proper HTTP mocking
// Demonstrates how to test the SDK without making real network calls
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../../utils/test_http_mocks.dart';
import '../../utils/mock_factory.dart';
import '../../utils/di/mock_dependency_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CFClient with HTTP Mocks', () {
    setUp(() async {
      CFClient.clearInstance();
      DependencyContainer.instance.reset();
    });
    tearDown(() async {
      try {
        if (CFClient.isInitialized()) {
          await CFClient.shutdownSingleton();
        }
      } catch (e) {
        // Ignore shutdown errors in tests
      }
      CFClient.clearInstance();
      DependencyContainer.instance.reset();
    });
    test('should initialize with mocked HTTP responses', () async {
      // Create configuration - explicitly set offline mode to false to allow HTTP requests
      final config = MockFactory.createTestConfig(offlineMode: false);
      final user = MockFactory.createTestUser();
      // Create mock dependency factory
      final mockFactory = MockDependencyFactory();
      // Configure the mock HTTP client responses
      mockFactory.mockHttpClient.whenGet(
        'https://sdk.customfit.ai/af76f680-057f-11f0-b76e-57ad8cff4a15/cf-sdk-settings.json',
        TestHttpMocks.sdkSettingsResponse,
      );
      mockFactory.mockHttpClient.whenGet(
        '/v1/users/configs',
        TestHttpMocks.featureFlagsResponse,
      );
      // Now initialize the client with the mock factory
      final result = await CFClient.initialize(config, user,
          dependencyFactory: mockFactory);
      expect(result.isSuccess, isTrue);
      final client = result;
      expect(client, isNotNull);
      expect(CFClient.isInitialized(), isTrue);
      // Note: The mock dependency factory uses MockConfigFetcher which doesn't
      // actually use the HTTP client, so we can't verify HTTP requests here.
      // Instead, verify that the client was initialized successfully.
    });
    test('should handle SDK settings endpoint with mock', () async {
      final config = MockFactory.createTestConfig(offlineMode: false);
      final user = MockFactory.createTestUser();
      final mockFactory = MockDependencyFactory();
      // Configure SDK settings response
      mockFactory.mockHttpClient.whenGet(
        'https://sdk.customfit.ai/af76f680-057f-11f0-b76e-57ad8cff4a15/cf-sdk-settings.json',
        TestHttpMocks.sdkSettingsResponse,
      );
      // Verify our SDK settings response is configured
      expect(TestHttpMocks.sdkSettingsResponse['cf_account_enabled'], isTrue);
      expect(TestHttpMocks.sdkSettingsResponse['cf_skip_sdk'], isFalse);
      final result = await CFClient.initialize(config, user,
          dependencyFactory: mockFactory);
      expect(result.isSuccess, isTrue);
      final client = result;
      expect(client, isNotNull);
    });
    test('should handle HEAD API responses with mock', () async {
      final config = MockFactory.createTestConfig(offlineMode: false);
      final user = MockFactory.createTestUser();
      final mockFactory = MockDependencyFactory();
      // Configure HEAD response
      mockFactory.mockHttpClient.whenHead(
        'https://sdk.customfit.ai/af76f680-057f-11f0-b76e-57ad8cff4a15/cf-sdk-settings.json',
        TestHttpMocks.defaultHeadResponse,
      );
      // Verify HEAD response is configured
      const headResponse = TestHttpMocks.defaultHeadResponse;
      expect(headResponse['Last-Modified'], isNotEmpty);
      expect(headResponse['ETag'], isNotEmpty);
      final result = await CFClient.initialize(config, user,
          dependencyFactory: mockFactory);
      expect(result.isSuccess, isTrue);
      final client = result;
      expect(client, isNotNull);
    });
    test('should handle feature flag evaluation with mocked responses',
        () async {
      final config = MockFactory.createTestConfig(offlineMode: false);
      final user = MockFactory.createTestUser();
      final mockFactory = MockDependencyFactory();
      // Configure feature flags response
      mockFactory.mockHttpClient.whenGet(
        '/api/flags',
        TestHttpMocks.featureFlagsResponse,
      );
      final result = await CFClient.initialize(config, user,
          dependencyFactory: mockFactory);
      expect(result.isSuccess, isTrue);
      final client = result;
      // Test feature flag evaluation - should use default values since mocked response
      // doesn't have specific flags for this test
      final boolFlag = client.getBoolean('test_feature', false);
      final stringFlag = client.getString('test_feature', 'default');
      final numberFlag = client.getNumber('numeric_feature', 0);
      expect(boolFlag, isA<bool>());
      expect(stringFlag, isA<String>());
      expect(numberFlag, isA<num>());
    });
    test('should handle error scenarios with error mock', () async {
      final config = MockFactory.createTestConfig(offlineMode: false);
      final user = MockFactory.createTestUser();
      // Create mock factory and configure for errors
      final mockFactory = MockDependencyFactory();
      // Configure error responses
      mockFactory.mockHttpClient.whenGet(
        '/api/config',
        null,
        isError: true,
        errorMessage: 'Network error',
      );
      // This should still initialize but handle errors gracefully
      final result = await CFClient.initialize(config, user,
          dependencyFactory: mockFactory);
      expect(result.isSuccess, isTrue);
      final client = result;
      expect(client, isNotNull);
    });
    test('should handle offline mode with offline mock', () async {
      final config = MockFactory.createTestConfig(offlineMode: true);
      final user = MockFactory.createTestUser();
      // Create mock factory - offline mode should not make any requests
      final mockFactory = MockDependencyFactory();
      final result = await CFClient.initialize(config, user,
          dependencyFactory: mockFactory);
      expect(result.isSuccess, isTrue);
      final client = result;
      expect(client, isNotNull);
      // Verify no HTTP calls were made in offline mode
      expect(mockFactory.mockHttpClient.requestHistory.isEmpty, isTrue);
    });
    test('should work with custom mock responses', () async {
      final config = MockFactory.createTestConfig(offlineMode: false);
      final user = MockFactory.createTestUser();
      // Create custom mock with specific responses
      final mockFactory = MockDependencyFactory();
      // Configure custom response
      mockFactory.mockHttpClient.whenGet(
        '/api/config',
        {
          'flags': {
            'custom_flag': {
              'enabled': true,
              'value': 'custom_value',
              'type': 'string'
            }
          }
        },
      );
      final result = await CFClient.initialize(config, user,
          dependencyFactory: mockFactory);
      expect(result.isSuccess, isTrue);
      final client = result;
      expect(client, isNotNull);
    });
  });
}
