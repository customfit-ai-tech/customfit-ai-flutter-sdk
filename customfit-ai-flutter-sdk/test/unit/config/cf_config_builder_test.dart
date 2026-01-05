// test/unit/config/cf_config_builder_test.dart
//
// Comprehensive tests for CFConfig builder pattern and validation.
// Tests builder pattern, required fields, defaults, immutability, and validation rules.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import '../../shared/test_shared.dart';
import '../../utils/test_constants.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CFConfig Builder Tests', () {
    group('Required Fields Validation', () {
      test('should_require_client_key', () {
        // Act & Assert
        expect(
          () => CFConfig.builder('').build().getOrThrow(),
          throwsA(
            allOf(
              isA<CFException>(),
              predicate((e) => e.toString().contains('Client key cannot be empty')),
            ),
          ),
        );
      });
      test('should_validate_jwt_format', () {
        // Arrange
        final invalidTokens = [
          'not-a-jwt',
          'only.two',
          'no-dots-at-all',
          '   ',
          'special!@#\$%^&*()chars',
        ];
        // Act & Assert
        for (final token in invalidTokens) {
          expect(
            () => CFConfig.builder(token).build().getOrThrow(),
            throwsA(
              allOf(
                isA<CFException>(),
                predicate((e) => e.toString().contains('valid JWT token')),
              ),
            ),
            reason: 'Token "$token" should be rejected',
          );
        }
      });
      test('should_accept_valid_jwt_format', () {
        // Arrange - Use a real JWT-like token that's long enough
        const validToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
        // Act
        final config = CFConfig.builder(validToken).build().getOrThrow();
        // Assert
        expect(config.clientKey, equals(validToken));
      });
    });
    group('Builder Pattern', () {
      test('should_support_fluent_api_chaining', () {
        // Act
        final config = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(true)
          .setOfflineMode(false)
          .setEventsFlushIntervalMs(5000)
          .setNetworkConnectionTimeoutMs(3000)
          .build().getOrThrow();
        // Assert
        expect(config.clientKey, equals(TestConstants.validJwtToken));
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.offlineMode, isFalse);
        expect(config.eventsFlushIntervalMs, equals(5000));
        expect(config.networkConnectionTimeoutMs, equals(3000));
      });
      test('should_create_multiple_configs_independently', () {
        // Act - Use longer JWT-like tokens to pass validation
        const token1 = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
        const token2 = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI5ODc2NTQzMjEwIiwibmFtZSI6IkphbmUgRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.cLr0gDBKNmEO3d0uJOaFQYOGN4zM9PkQ3VpH7K9IxHg';
        final config1 = CFConfig.builder(token1)
          .setDebugLoggingEnabled(true)
          .setOfflineMode(true)
          .build().getOrThrow();
        final config2 = CFConfig.builder(token2)
          .setDebugLoggingEnabled(false)
          .setOfflineMode(false)
          .build().getOrThrow();
        // Assert
        expect(config1.clientKey, equals(token1));
        expect(config1.debugLoggingEnabled, isTrue);
        expect(config1.offlineMode, isTrue);
        expect(config2.clientKey, equals(token2));
        expect(config2.debugLoggingEnabled, isFalse);
        expect(config2.offlineMode, isFalse);
      });
    });
    group('Default Values', () {
      test('should_use_sensible_defaults', () {
        // Act
        final config = CFConfig.builder(TestConstants.validJwtToken).build().getOrThrow();
        // Assert
        expect(config.debugLoggingEnabled, isFalse); // Default should be false
        expect(config.offlineMode, isFalse); // Default should be false
        expect(config.eventsFlushIntervalMs, equals(1000)); // 1 second (default)
        expect(config.networkConnectionTimeoutMs, equals(10000)); // 10 seconds
        expect(config.networkReadTimeoutMs, equals(10000)); // 10 seconds
      });
      test('should_allow_overriding_defaults', () {
        // Act
        final config = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(true)
          .setOfflineMode(true)
          .setEventsFlushIntervalMs(60000)
          .setNetworkConnectionTimeoutMs(5000)
          .build().getOrThrow();
        // Assert
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.offlineMode, isTrue);
        expect(config.eventsFlushIntervalMs, equals(60000));
        expect(config.networkConnectionTimeoutMs, equals(5000));
      });
    });
    group('Validation Rules', () {
      test('should_allow_zero_and_negative_timeout_values', () {
        // Note: The SDK doesn't validate timeout values currently
        // This test documents the current behavior
        // Arrange
        final builder = CFConfig.builder(TestConstants.validJwtToken);
        // Act - Zero values (allowed but not recommended)
        final config1 = builder.setNetworkConnectionTimeoutMs(0).build().getOrThrow();
        expect(config1.networkConnectionTimeoutMs, equals(0));
        final config2 = builder.setEventsFlushIntervalMs(0).build().getOrThrow();
        expect(config2.eventsFlushIntervalMs, equals(0));
        // Negative values (allowed but will cause issues)
        final config3 = builder.setNetworkConnectionTimeoutMs(-1).build().getOrThrow();
        expect(config3.networkConnectionTimeoutMs, equals(-1));
        final config4 = builder.setEventsFlushIntervalMs(-1000).build().getOrThrow();
        expect(config4.eventsFlushIntervalMs, equals(-1000));
      });
      test('should_accept_valid_timeout_values', () {
        // Act
        final config = CFConfig.builder(TestConstants.validJwtToken)
          .setNetworkConnectionTimeoutMs(1)
          .setEventsFlushIntervalMs(1)
          .build().getOrThrow();
        // Assert
        expect(config.networkConnectionTimeoutMs, equals(1));
        expect(config.eventsFlushIntervalMs, equals(1));
      });
      test('should_handle_very_large_timeout_values', () {
        // Arrange
        const largeValue = 0x7FFFFFFF; // Max 32-bit int
        // Act
        final config = CFConfig.builder(TestConstants.validJwtToken)
          .setNetworkConnectionTimeoutMs(largeValue)
          .setEventsFlushIntervalMs(largeValue)
          .build().getOrThrow();
        // Assert
        expect(config.networkConnectionTimeoutMs, equals(largeValue));
        expect(config.eventsFlushIntervalMs, equals(largeValue));
      });
    });
    group('Immutability', () {
      test('should_be_immutable_after_build', () {
        // Arrange
        final config = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(true)
          .build().getOrThrow();
        // Act & Assert
        // Properties should be final
        expect(config.clientKey, equals(TestConstants.validJwtToken));
        expect(config.debugLoggingEnabled, isTrue);
        // Should not be able to modify through reflection or other means
        // The config object should not expose any setters
      });
      test('should_not_affect_builder_after_build', () {
        // Arrange
        final builder = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(true);
        // Act
        final config1 = builder.build().getOrThrow();
        builder.setDebugLoggingEnabled(false);
        final config2 = builder.build().getOrThrow();
        // Assert - Each build creates independent config
        expect(config1.debugLoggingEnabled, isTrue);
        expect(config2.debugLoggingEnabled, isFalse);
      });
    });
    group('Special Configurations', () {
      test('should_create_production_config', () {
        // Act
        final config = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(false)
          .setOfflineMode(false)
          .build().getOrThrow();
        // Assert
        expect(config.debugLoggingEnabled, isFalse);
        expect(config.offlineMode, isFalse);
      });
      test('should_create_development_config', () {
        // Act
        final config = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(true)
          .setOfflineMode(false)
          .setEventsFlushIntervalMs(5000) // Faster for dev
          .build().getOrThrow();
        // Assert
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.eventsFlushIntervalMs, equals(5000));
      });
      test('should_create_offline_testing_config', () {
        // Act
        final config = CFConfig.builder(TestConstants.validJwtToken)
          .setOfflineMode(true)
          .setDebugLoggingEnabled(true)
          .build().getOrThrow();
        // Assert
        expect(config.offlineMode, isTrue);
        expect(config.debugLoggingEnabled, isTrue);
      });
    });
    group('Edge Cases', () {
      test('should_handle_very_long_client_key', () {
        // Arrange
        final longKey = '${'a' * 100}.${'b' * 100}.${'c' * 100}';
        // Act
        final config = CFConfig.builder(longKey).build().getOrThrow();
        // Assert
        expect(config.clientKey, equals(longKey));
      });
      test('should_handle_unicode_in_client_key', () {
        // Arrange - Use a longer key with unicode that passes JWT validation (>100 chars)
        const unicodeKey = 'héaderpartwithunicodecharactersthatshouldbevalidforaJWTtoken.' 'paylöadpartwithunicodecharactersandmorecontenttomakethelengthvalid.' 'signaturépartwithevenmorecontenttomakesurewehaveenoughcharacters';
        // Act
        final config = CFConfig.builder(unicodeKey).build().getOrThrow();
        // Assert
        expect(config.clientKey, equals(unicodeKey));
      });
      test('should_handle_rapid_builder_reuse', () {
        // Arrange
        final builder = CFConfig.builder(TestConstants.validJwtToken);
        final configs = <CFConfig>[];
        // Act - Build many configs rapidly
        for (int i = 0; i < 100; i++) {
          configs.add(
            builder
              .setEventsFlushIntervalMs(i * 100)
              .setDebugLoggingEnabled(i % 2 == 0)
              .build().getOrThrow()
          );
        }
        // Assert - All configs should be valid and independent
        for (int i = 0; i < configs.length; i++) {
          expect(configs[i].eventsFlushIntervalMs, equals(i * 100));
          expect(configs[i].debugLoggingEnabled, equals(i % 2 == 0));
        }
      });
    });
    group('Computed Properties', () {
      test('should_calculate_read_timeout_correctly', () {
        // Act
        final config = CFConfig.builder(TestConstants.validJwtToken)
          .setNetworkConnectionTimeoutMs(5000)
          .build().getOrThrow();
        // Assert
        // Read timeout is typically same as connection timeout
        expect(config.networkReadTimeoutMs, equals(10000)); // Default
      });
      test('should_provide_all_timeout_values', () {
        // Act
        final config = CFConfig.builder(TestConstants.validJwtToken).build().getOrThrow();
        // Assert - All timeouts should be positive
        expect(config.networkConnectionTimeoutMs, greaterThan(0));
        expect(config.networkReadTimeoutMs, greaterThan(0));
        expect(config.eventsFlushIntervalMs, greaterThan(0));
      });
    });
  });
}