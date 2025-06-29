import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/config/validation/cf_config_validator.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/constants/cf_constants.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CFConfigValidator', () {
    group('Client Key Validation', () {
      test('should reject empty client key', () {
        // The Builder validates keys during build(), not in constructor
        expect(
          () => CFConfig.builder('').build().getOrThrow(),
          throwsA(isA<CFException>()),
        );
      });
      test('should reject short client key', () {
        // The Builder validates keys during build()
        expect(
          () => CFConfig.builder('short').build().getOrThrow(),
          throwsA(isA<CFException>()),
        );
      });
      test('should reject client key with invalid characters', () {
        // The Builder validates JWT format during build()
        expect(
          () => CFConfig.builder('invalid@key#special!').build().getOrThrow(),
          throwsA(isA<CFException>()),
        );
      });
      test('should warn about test keys', () {
        // Create a properly formatted JWT-like test key
        const testKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJ0ZXN0IjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InRlc3QtZGltZW5zaW9uIn0.test_signature_123456789';
        final config = CFConfig.builder(testKey).build().getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(result.warnings.any((w) => w.contains('test/development key')),
            true);
      });
      test('should accept valid production key', () {
        // Create a properly formatted JWT-like production key
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey).build().getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(result.warnings.any((w) => w.contains('test/development key')),
            false);
      });
    });
    group('Timeout Validation', () {
      test('should reject connection timeout below minimum', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setNetworkConnectionTimeoutMs(500)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, false);
        expect(
            result.errors.any((e) => e.contains('Connection timeout too low')),
            true);
      });
      test('should warn about very high connection timeout', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setNetworkConnectionTimeoutMs(90000)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings
                .any((w) => w.contains('Connection timeout very high')),
            true);
      });
      test('should warn if read timeout less than connection timeout', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setNetworkConnectionTimeoutMs(10000)
            .setNetworkReadTimeoutMs(5000)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings.any((w) => w.contains(
                'Read timeout should be greater than or equal to connection timeout')),
            true);
      });
    });
    group('Flush Interval Validation', () {
      test('should warn about very low flush intervals', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setEventsFlushIntervalMs(1000)
            .setSummariesFlushIntervalMs(1000)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings.any(
                (w) => w.contains('very low') && w.contains('battery life')),
            true);
      });
      test('should warn about very high flush intervals', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setEventsFlushIntervalMs(400000)
            .setSummariesFlushIntervalMs(400000)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings
                .any((w) => w.contains('very high') && w.contains('delayed')),
            true);
      });
      test('should warn if summaries flush more frequently than events', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setEventsFlushIntervalMs(30000)
            .setSummariesFlushIntervalMs(10000)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings.any((w) => w.contains(
                'Summaries flush interval is less than events flush interval')),
            true);
      });
    });
    group('Queue Size Validation', () {
      test('should reject queue sizes below minimum', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setEventsQueueSize(5)
            .setSummariesQueueSize(5)
            .setMaxStoredEvents(5)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, false);
        expect(result.errors.any((e) => e.contains('too small')), true);
      });
      test('should warn about very large queue sizes', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lobl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setEventsQueueSize(20000)
            .setSummariesQueueSize(20000)
            .setMaxStoredEvents(20000)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(result.warnings.any((w) => w.contains('very large')), true);
      });
    });
    group('Retry Settings Validation', () {
      test('should reject negative retry attempts', () {
        // The Builder itself rejects negative retry attempts
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        expect(
          () => CFConfig.builder(prodKey).setMaxRetryAttempts(-1),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              'Max retry attempts cannot be negative')),
        );
      });
      test('should warn about very high retry attempts', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setMaxRetryAttempts(15)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings
                .any((w) => w.contains('very high') && w.contains('delays')),
            true);
      });
      test('should warn if max delay less than initial delay', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setRetryInitialDelayMs(5000)
            .setRetryMaxDelayMs(2000)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings.any((w) => w.contains(
                'Retry max delay should be greater than or equal to initial delay')),
            true);
      });
    });
    group('Feature Toggle Validation', () {
      test('should warn about offline mode', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config =
            CFConfig.builder(prodKey).setOfflineMode(true).build().getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(result.warnings.any((w) => w.contains('offline mode')), true);
      });
      test('should warn about debug logging in production', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setEnvironment(CFEnvironment.production)
            .setDebugLoggingEnabled(true)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings.any(
                (w) => w.contains('Debug logging is enabled in production')),
            true);
      });
      test('should warn about disabled background polling in offline mode', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setOfflineMode(true)
            .setDisableBackgroundPolling(true)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings.any((w) => w.contains(
                'Background polling is disabled while in offline mode')),
            true);
      });
      test('should warn about debug logging with general logging disabled', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setLoggingEnabled(false)
            .setDebugLoggingEnabled(true)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings.any((w) => w.contains(
                'Debug logging is enabled but general logging is disabled')),
            true);
      });
    });
    group('Environment Validation', () {
      test('should warn about staging environment with production-like key',
          () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setEnvironment(CFEnvironment.staging)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings.any((w) => w.contains(
                'staging environment but client key does not appear to be a staging key')),
            true);
      });
      test('should not warn about staging environment with staging key', () {
        const stageKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJzdGFnZSI6InRydWUiLCJkaW1lbnNpb25faWQiOiJzdGFnZS1kaW1lbnNpb24ifQ.stage_signature_123456789';
        final config = CFConfig.builder(stageKey)
            .setEnvironment(CFEnvironment.staging)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(
            result.warnings.any((w) => w.contains(
                'staging environment but client key does not appear to be a staging key')),
            false);
      });
    });
    group('SDK Settings Interval Validation', () {
      test('should warn about very frequent SDK settings checks', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setSdkSettingsCheckIntervalMs(10000)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(result.warnings.any((w) => w.contains('very frequent')), true);
      });
      test('should warn about very infrequent SDK settings checks', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.builder(prodKey)
            .setSdkSettingsCheckIntervalMs(90000000)
            .build()
            .getOrThrow();
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        expect(result.warnings.any((w) => w.contains('very infrequent')), true);
      });
    });
    group('validateOrThrow', () {
      test('should throw ConfigValidationException on invalid config', () {
        // Use a valid JWT but with very low timeouts to trigger errors
        final config = CFConfig.builder(
                'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c')
            .setNetworkConnectionTimeoutMs(500) // Too low
            .setEventsQueueSize(5) // Too low
            .build()
            .getOrThrow();
        expect(
          () => CFConfigValidator.validateOrThrow(config),
          throwsA(isA<ConfigValidationException>()),
        );
      });
      test('should not throw on valid config', () {
        final config = CFConfig.builder(
                'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c')
            .build()
            .getOrThrow();
        // Should not throw
        CFConfigValidator.validateOrThrow(config);
      });
      test('should include errors in exception', () {
        try {
          final config = CFConfig.builder(
                  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c')
              .setNetworkConnectionTimeoutMs(500) // Too low
              .build()
              .getOrThrow();
          CFConfigValidator.validateOrThrow(config);
          fail('Should have thrown ConfigValidationException');
        } on ConfigValidationException catch (e) {
          expect(e.errors.isNotEmpty, true);
          expect(e.message, contains('Invalid configuration'));
        }
      });
    });
    group('ValidationResult', () {
      test('should indicate perfect validation when no warnings', () {
        const result = ValidationResult(
          isValid: true,
          errors: [],
          warnings: [],
        );
        expect(result.isPerfect, true);
      });
      test('should not be perfect with warnings', () {
        const result = ValidationResult(
          isValid: true,
          errors: [],
          warnings: ['Some warning'],
        );
        expect(result.isPerfect, false);
      });
      test('should format summary correctly', () {
        const result = ValidationResult(
          isValid: false,
          errors: ['Error 1', 'Error 2'],
          warnings: ['Warning 1', 'Warning 2'],
        );
        final summary = result.summary;
        expect(summary.contains('Errors:'), true);
        expect(summary.contains('- Error 1'), true);
        expect(summary.contains('- Error 2'), true);
        expect(summary.contains('Warnings:'), true);
        expect(summary.contains('- Warning 1'), true);
        expect(summary.contains('- Warning 2'), true);
      });
    });
    group('Predefined Configuration Profiles', () {
      test('development profile should have appropriate settings', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJkZXYiOiJ0cnVlIiwiZGltZW5zaW9uX2lkIjoiZGV2LWRpbWVuc2lvbiJ9.dev_signature_123456789';
        final config = CFConfig.development(prodKey);
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        // Development profile should have debug logging enabled
        expect(config.debugLoggingEnabled, true);
        // Should have fast flush intervals
        expect(config.eventsFlushIntervalMs, 1000);
      });
      test('production profile should have appropriate settings', () {
        const prodKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
        final config = CFConfig.production(prodKey);
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        // Production profile should have debug logging disabled
        expect(config.debugLoggingEnabled, false);
        // Should have conservative flush intervals
        expect(config.eventsFlushIntervalMs, 30000);
      });
      test('testing profile should have appropriate settings', () {
        const testKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJ0ZXN0IjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InRlc3QtZGltZW5zaW9uIn0.test_signature_123456789';
        final config = CFConfig.testing(testKey);
        final result = CFConfigValidator.validate(config);
        expect(result.isValid, true);
        // Testing profile should have minimal logging
        expect(config.loggingEnabled, false);
        // Should have very fast flush intervals
        expect(config.eventsFlushIntervalMs, 100);
      });
    });
  });
}
