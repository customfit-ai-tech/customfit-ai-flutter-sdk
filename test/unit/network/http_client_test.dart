// test/unit/network/http_client_test.dart
//
// Simplified tests for HttpClient after SDK simplification
// Tests basic HTTP client functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/infrastructure/network/internal/http_client_impl.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HttpClient (Simplified)', () {
    late CFConfig testConfig;
    late HttpClientImpl httpClient;

    setUp(() {
      testConfig = CFConfig.builder(
              'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0LWNsaWVudC1rZXkiLCJpYXQiOjE2MzQ1Njc4OTB9.test-signature')
          .setNetworkConnectionTimeoutMs(5000)
          .setNetworkReadTimeoutMs(10000)
          .build()
          .getOrThrow();

      httpClient = HttpClientImpl(testConfig);
    });

    tearDown(() {
      httpClient.close();
    });

    group('Initialization', () {
      test('should initialize with default configuration', () {
        expect(httpClient, isNotNull);
      });

      test('should initialize with custom timeouts', () {
        final customConfig = CFConfig.builder(
                'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0LWNsaWVudC1rZXkiLCJpYXQiOjE2MzQ1Njc4OTB9.test-signature')
            .setNetworkConnectionTimeoutMs(15000)
            .setNetworkReadTimeoutMs(30000)
            .build()
            .getOrThrow();

        final customHttpClient = HttpClientImpl(customConfig);
        expect(customHttpClient, isNotNull);
        customHttpClient.close();
      });
    });

    group('GET Requests', () {
      test('should handle GET request timeout gracefully', () async {
        // This will timeout due to invalid URL
        final result = await httpClient.get<Map<String, dynamic>>('/invalid-endpoint');
        
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), isNotEmpty);
      });

      test('should handle GET request with query parameters', () async {
        final result = await httpClient.get<Map<String, dynamic>>(
          '/test',
          queryParameters: {'key': 'value'},
        );
        
        // Should fail but not crash
        expect(result.isSuccess, isFalse);
      });

      test('should handle GET request with custom headers', () async {
        final result = await httpClient.get<Map<String, dynamic>>(
          '/test',
          headers: {'X-Custom': 'test'},
        );
        
        // Should fail but not crash
        expect(result.isSuccess, isFalse);
      });
    });

    group('POST Requests', () {
      test('should handle POST request with data', () async {
        final result = await httpClient.post<Map<String, dynamic>>(
          '/test',
          data: {'key': 'value'},
        );
        
        // Should fail but not crash
        expect(result.isSuccess, isFalse);
      });

      test('should handle POST request with query parameters', () async {
        final result = await httpClient.post<Map<String, dynamic>>(
          '/test',
          queryParameters: {'param': 'value'},
        );
        
        // Should fail but not crash
        expect(result.isSuccess, isFalse);
      });

      test('should handle POST request with custom headers', () async {
        final result = await httpClient.post<Map<String, dynamic>>(
          '/test',
          headers: {'X-Custom': 'test'},
        );
        
        // Should fail but not crash
        expect(result.isSuccess, isFalse);
      });
    });

    group('HEAD Requests', () {
      test('should handle HEAD request', () async {
        final result = await httpClient.headResponse('/test');
        
        // Should fail but not crash
        expect(result.isSuccess, isFalse);
      });

      test('should handle HEAD request with headers', () async {
        final result = await httpClient.headResponse(
          '/test',
          headers: {'X-Custom': 'test'},
        );
        
        // Should fail but not crash
        expect(result.isSuccess, isFalse);
      });
    });

    group('Metadata Requests', () {
      test('should handle metadata fetch', () async {
        final result = await httpClient.fetchMetadata('/test');
        
        // Should fail but not crash
        expect(result.isSuccess, isFalse);
      });

      test('should handle metadata fetch with headers', () async {
        final result = await httpClient.fetchMetadata(
          '/test',
          headers: {'X-Custom': 'test'},
        );
        
        // Should fail but not crash
        expect(result.isSuccess, isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        final result = await httpClient.get<String>('invalid-url');
        
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), isNotEmpty);
      });

      test('should handle malformed URLs', () async {
        final result = await httpClient.post<String>('');
        
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), isNotEmpty);
      });
    });

    group('Resource Management', () {
      test('should close properly', () {
        expect(() => httpClient.close(), returnsNormally);
      });
    });
  });
}