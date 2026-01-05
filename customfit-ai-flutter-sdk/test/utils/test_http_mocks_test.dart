import 'package:flutter_test/flutter_test.dart';
import 'test_http_mocks.dart';
import '../utils/mock_factory.dart';
void main() {
  group('TestHttpMocks', () {
    test('should provide correct SDK settings response', () {
      // Test SDK settings response
      const expectedResponse = TestHttpMocks.sdkSettingsResponse;
      expect(expectedResponse['cf_account_enabled'], equals(true));
      expect(expectedResponse['cf_intelligent_code_enabled'], equals(false));
      expect(expectedResponse['cf_skip_sdk'], equals(false));
      expect(expectedResponse['rule_events'], equals([]));
      expect(expectedResponse['_inbound'], equals(false));
      expect(expectedResponse['_outbound'], equals(false));
    });
    test('should provide HEAD API response headers', () {
      const headResponse = TestHttpMocks.defaultHeadResponse;
      expect(headResponse['Last-Modified'], isNotEmpty);
      expect(headResponse['ETag'], isNotEmpty);
      expect(headResponse['Content-Type'], equals('application/json'));
      expect(headResponse['Cache-Control'], equals('max-age=3600'));
    });
    test('should create configured mock client', () {
      final config = MockFactory.createTestConfig();
      final mockClient = TestHttpMocks.createConfiguredMock(config);
      expect(mockClient, isNotNull);
      expect(mockClient.getBaseUrl(), equals('https://api.customfit.com'));
    });
    test('should create error mock client', () {
      final config = MockFactory.createTestConfig();
      final mockClient = TestHttpMocks.createErrorMock(config);
      expect(mockClient, isNotNull);
    });
    test('should create offline mock client', () {
      final config = MockFactory.createTestConfig();
      final mockClient = TestHttpMocks.createOfflineMock(config);
      expect(mockClient, isNotNull);
    });
    test('should provide test scenarios data', () {
      expect(TestScenarios.userWithPremiumFeatures, isNotNull);
      expect(TestScenarios.anonymousUser, isNotNull);
      expect(TestScenarios.organizationUser, isNotNull);
      expect(TestScenarios.largeEventBatch, isNotNull);
      expect(TestScenarios.featureFlagsWithOverrides, isNotNull);
    });
  });
}
