import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:customfit_ai_flutter_sdk/src/network/http_client.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import '../../utils/test_constants.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Certificate Pinning Tests', () {
    late CFConfig config;
    late CFConfig configWithPinning;
    late HttpClient httpClient;
    setUp(() {
      // Basic config without certificate pinning
      config = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(true)
          .build().getOrThrow();
      // Config with certificate pinning enabled
      configWithPinning = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(true)
          .setCertificatePinningEnabled(true)
          .setPinnedCertificates([
            'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
            'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB='
          ])
          .build().getOrThrow();
    });
    test('certificate pinning is disabled by default', () {
      expect(config.certificatePinningEnabled, false);
      expect(config.pinnedCertificates, isEmpty);
      expect(config.allowSelfSignedCertificates, false);
    });
    test('certificate pinning can be enabled with configuration', () {
      expect(configWithPinning.certificatePinningEnabled, true);
      expect(configWithPinning.pinnedCertificates.length, 2);
      expect(configWithPinning.pinnedCertificates[0], 
          'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=');
      expect(configWithPinning.pinnedCertificates[1], 
          'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=');
    });
    test('HttpClient initializes without errors when pinning is disabled', () async {
      httpClient = HttpClient(config);
      expect(httpClient, isNotNull);
    });
    test('HttpClient initializes without errors when pinning is enabled', () async {
      httpClient = HttpClient(configWithPinning);
      expect(httpClient, isNotNull);
    });
    test('can add certificates incrementally', () {
      final builder = CFConfig.builder(TestConstants.validJwtToken)
          .setCertificatePinningEnabled(true)
          .addPinnedCertificate('sha256/CERT1=')
          .addPinnedCertificate('sha256/CERT2=')
          .addPinnedCertificate('sha256/CERT1='); // Duplicate should not be added
      final builtConfig = builder.build().getOrThrow();
      expect(builtConfig.pinnedCertificates.length, 2);
      expect(builtConfig.pinnedCertificates, contains('sha256/CERT1='));
      expect(builtConfig.pinnedCertificates, contains('sha256/CERT2='));
    });
    test('can allow self-signed certificates for development', () {
      final devConfig = CFConfig.builder(TestConstants.validJwtToken)
          .setCertificatePinningEnabled(true)
          .setAllowSelfSignedCertificates(true)
          .build().getOrThrow();
      expect(devConfig.certificatePinningEnabled, true);
      expect(devConfig.allowSelfSignedCertificates, true);
    });
    test('certificate pinning configuration is immutable', () {
      final pinnedCerts = configWithPinning.pinnedCertificates;
      // Try to modify the list - this should throw an error
      try {
        pinnedCerts.add('sha256/NEWCERT=');
        fail('Expected UnsupportedError when trying to modify immutable list');
      } catch (e) {
        expect(e, isA<UnsupportedError>());
      }
    });
    test('HttpClient with injected Dio works with certificate pinning config', () async {
      // Create a real Dio instance for testing
      final testDio = Dio();
      httpClient = HttpClient.withDio(configWithPinning, testDio);
      expect(httpClient, isNotNull);
    });
    group('Production vs Development Configuration', () {
      test('production config has certificate pinning disabled by default', () {
        final prodConfig = CFConfig.production(TestConstants.validJwtToken);
        expect(prodConfig.certificatePinningEnabled, false);
      });
      test('development config has certificate pinning disabled by default', () {
        final devConfig = CFConfig.development(TestConstants.validJwtToken);
        expect(devConfig.certificatePinningEnabled, false);
      });
      test('testing config has certificate pinning disabled by default', () {
        final testConfig = CFConfig.testing(TestConstants.validJwtToken);
        expect(testConfig.certificatePinningEnabled, false);
      });
    });
  });
}
// Mock adapter for testing
class MockHttpClientAdapter extends Mock implements IOHttpClientAdapter {}