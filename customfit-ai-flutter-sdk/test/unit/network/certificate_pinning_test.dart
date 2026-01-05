// test/unit/network/certificate_pinning_test.dart
//
// Simplified tests for certificate pinning after SDK simplification
// Tests basic certificate pinning functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/infrastructure/network/internal/http_client_impl.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Certificate Pinning (Simplified)', () {
    group('Configuration Tests', () {
      test('should create HttpClient with certificate pinning enabled', () {
        final config = CFConfig.builder(
                'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0LWNsaWVudC1rZXkiLCJpYXQiOjE2MzQ1Njc4OTB9.test-signature')
            .setCertificatePinningEnabled(true)
            .setPinnedCertificates(['sha256/test-fingerprint'])
            .build()
            .getOrThrow();

        final httpClient = HttpClientImpl(config);
        expect(httpClient, isNotNull);
        httpClient.close();
      });

      test('should create HttpClient with certificate pinning disabled', () {
        final config = CFConfig.builder(
                'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0LWNsaWVudC1rZXkiLCJpYXQiOjE2MzQ1Njc4OTB9.test-signature')
            .setCertificatePinningEnabled(false)
            .build()
            .getOrThrow();

        final httpClient = HttpClientImpl(config);
        expect(httpClient, isNotNull);
        httpClient.close();
      });

      test('should handle self-signed certificates in development', () {
        final config = CFConfig.builder(
                'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0LWNsaWVudC1rZXkiLCJpYXQiOjE2MzQ1Njc4OTB9.test-signature')
            .setAllowSelfSignedCertificates(true)
            .build()
            .getOrThrow();

        final httpClient = HttpClientImpl(config);
        expect(httpClient, isNotNull);
        httpClient.close();
      });
    });

    group('Request Tests', () {
      test('should handle requests with pinned certificates', () async {
        final config = CFConfig.builder(
                'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0LWNsaWVudC1rZXkiLCJpYXQiOjE2MzQ1Njc4OTB9.test-signature')
            .setCertificatePinningEnabled(true)
            .setPinnedCertificates(['sha256/test-fingerprint'])
            .build()
            .getOrThrow();

        final httpClient = HttpClientImpl(config);
        
        // This will fail due to invalid URL but should not crash
        final result = await httpClient.get<String>('/test');
        expect(result.isSuccess, isFalse);
        
        httpClient.close();
      });

      test('should handle requests without certificate pinning', () async {
        final config = CFConfig.builder(
                'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0LWNsaWVudC1rZXkiLCJpYXQiOjE2MzQ1Njc4OTB9.test-signature')
            .setCertificatePinningEnabled(false)
            .build()
            .getOrThrow();

        final httpClient = HttpClientImpl(config);
        
        // This will fail due to invalid URL but should not crash
        final result = await httpClient.get<String>('/test');
        expect(result.isSuccess, isFalse);
        
        httpClient.close();
      });
    });
  });
}