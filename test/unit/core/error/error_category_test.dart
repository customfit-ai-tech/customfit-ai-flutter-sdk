import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ErrorCategory Tests', () {
    group('Static Constants Tests', () {
      test('should have all defined error categories', () {
        expect(ErrorCategory.network.name, equals('NETWORK'));
        expect(ErrorCategory.internal.name, equals('INTERNAL'));
        expect(ErrorCategory.serialization.name, equals('SERIALIZATION'));
        expect(ErrorCategory.validation.name, equals('VALIDATION'));
        expect(ErrorCategory.storage.name, equals('STORAGE'));
        expect(ErrorCategory.permission.name, equals('PERMISSION'));
        expect(ErrorCategory.authentication.name, equals('AUTHENTICATION'));
        expect(ErrorCategory.configuration.name, equals('CONFIGURATION'));
        expect(ErrorCategory.timeout.name, equals('TIMEOUT'));
        expect(ErrorCategory.state.name, equals('STATE'));
        expect(ErrorCategory.api.name, equals('API'));
        expect(ErrorCategory.rateLimit.name, equals('RATE_LIMIT'));
        expect(ErrorCategory.circuitBreaker.name, equals('CIRCUIT_BREAKER'));
        expect(ErrorCategory.concurrency.name, equals('CONCURRENCY'));
        expect(ErrorCategory.user.name, equals('USER'));
        expect(ErrorCategory.analytics.name, equals('ANALYTICS'));
        expect(ErrorCategory.featureFlag.name, equals('FEATURE_FLAG'));
        expect(ErrorCategory.session.name, equals('SESSION'));
        expect(ErrorCategory.unknown.name, equals('UNKNOWN'));
      });
      test('should have consistent naming pattern', () {
        final categories = [
          ErrorCategory.network,
          ErrorCategory.internal,
          ErrorCategory.serialization,
          ErrorCategory.validation,
          ErrorCategory.storage,
          ErrorCategory.permission,
          ErrorCategory.authentication,
          ErrorCategory.configuration,
          ErrorCategory.timeout,
          ErrorCategory.state,
          ErrorCategory.api,
          ErrorCategory.rateLimit,
          ErrorCategory.circuitBreaker,
          ErrorCategory.concurrency,
          ErrorCategory.user,
          ErrorCategory.analytics,
          ErrorCategory.featureFlag,
          ErrorCategory.session,
          ErrorCategory.unknown,
        ];
        for (final category in categories) {
          expect(category.name, isNotEmpty);
          expect(category.name, equals(category.name.toUpperCase()));
          expect(category.name, isA<String>());
        }
      });
      test('should have unique names', () {
        final categories = [
          ErrorCategory.network,
          ErrorCategory.internal,
          ErrorCategory.serialization,
          ErrorCategory.validation,
          ErrorCategory.storage,
          ErrorCategory.permission,
          ErrorCategory.authentication,
          ErrorCategory.configuration,
          ErrorCategory.timeout,
          ErrorCategory.state,
          ErrorCategory.api,
          ErrorCategory.rateLimit,
          ErrorCategory.circuitBreaker,
          ErrorCategory.concurrency,
          ErrorCategory.user,
          ErrorCategory.analytics,
          ErrorCategory.featureFlag,
          ErrorCategory.session,
          ErrorCategory.unknown,
        ];
        final names = categories.map((c) => c.name).toSet();
        expect(names.length, equals(categories.length));
      });
    });
    group('toString() Method Tests', () {
      test('should return name for all categories', () {
        expect(ErrorCategory.network.toString(), equals('NETWORK'));
        expect(ErrorCategory.internal.toString(), equals('INTERNAL'));
        expect(ErrorCategory.validation.toString(), equals('VALIDATION'));
        expect(ErrorCategory.unknown.toString(), equals('UNKNOWN'));
      });
      test('should be consistent with name property', () {
        final categories = [
          ErrorCategory.network,
          ErrorCategory.serialization,
          ErrorCategory.authentication,
          ErrorCategory.rateLimit,
        ];
        for (final category in categories) {
          expect(category.toString(), equals(category.name));
        }
      });
    });
    group('fromString() Method Tests', () {
      test('should convert exact uppercase strings correctly', () {
        expect(
            ErrorCategory.fromString('NETWORK'), equals(ErrorCategory.network));
        expect(ErrorCategory.fromString('INTERNAL'),
            equals(ErrorCategory.internal));
        expect(ErrorCategory.fromString('SERIALIZATION'),
            equals(ErrorCategory.serialization));
        expect(ErrorCategory.fromString('VALIDATION'),
            equals(ErrorCategory.validation));
        expect(
            ErrorCategory.fromString('STORAGE'), equals(ErrorCategory.storage));
        expect(ErrorCategory.fromString('PERMISSION'),
            equals(ErrorCategory.permission));
        expect(ErrorCategory.fromString('AUTHENTICATION'),
            equals(ErrorCategory.authentication));
        expect(ErrorCategory.fromString('CONFIGURATION'),
            equals(ErrorCategory.configuration));
        expect(
            ErrorCategory.fromString('TIMEOUT'), equals(ErrorCategory.timeout));
        expect(ErrorCategory.fromString('STATE'), equals(ErrorCategory.state));
        expect(ErrorCategory.fromString('API'), equals(ErrorCategory.api));
        expect(ErrorCategory.fromString('RATE_LIMIT'),
            equals(ErrorCategory.rateLimit));
        expect(ErrorCategory.fromString('CIRCUIT_BREAKER'),
            equals(ErrorCategory.circuitBreaker));
        expect(ErrorCategory.fromString('CONCURRENCY'),
            equals(ErrorCategory.concurrency));
        expect(ErrorCategory.fromString('USER'), equals(ErrorCategory.user));
        expect(ErrorCategory.fromString('ANALYTICS'),
            equals(ErrorCategory.analytics));
        expect(ErrorCategory.fromString('FEATURE_FLAG'),
            equals(ErrorCategory.featureFlag));
        expect(
            ErrorCategory.fromString('SESSION'), equals(ErrorCategory.session));
        expect(
            ErrorCategory.fromString('UNKNOWN'), equals(ErrorCategory.unknown));
      });
      test('should handle case insensitive conversion', () {
        expect(
            ErrorCategory.fromString('network'), equals(ErrorCategory.network));
        expect(
            ErrorCategory.fromString('Network'), equals(ErrorCategory.network));
        expect(
            ErrorCategory.fromString('NETWORK'), equals(ErrorCategory.network));
        expect(ErrorCategory.fromString('validation'),
            equals(ErrorCategory.validation));
        expect(ErrorCategory.fromString('Validation'),
            equals(ErrorCategory.validation));
        expect(ErrorCategory.fromString('VALIDATION'),
            equals(ErrorCategory.validation));
        expect(ErrorCategory.fromString('rate_limit'),
            equals(ErrorCategory.rateLimit));
        expect(ErrorCategory.fromString('Rate_Limit'),
            equals(ErrorCategory.rateLimit));
        expect(ErrorCategory.fromString('RATE_LIMIT'),
            equals(ErrorCategory.rateLimit));
      });
      test('should default to unknown for invalid strings', () {
        expect(
            ErrorCategory.fromString('invalid'), equals(ErrorCategory.unknown));
        expect(ErrorCategory.fromString(''), equals(ErrorCategory.unknown));
        expect(ErrorCategory.fromString('nonexistent'),
            equals(ErrorCategory.unknown));
        expect(
            ErrorCategory.fromString('test123'), equals(ErrorCategory.unknown));
        expect(ErrorCategory.fromString('INVALID_CATEGORY'),
            equals(ErrorCategory.unknown));
      });
      test('should handle edge case strings', () {
        expect(ErrorCategory.fromString('   NETWORK   '),
            equals(ErrorCategory.unknown)); // whitespace
        expect(ErrorCategory.fromString('NET WORK'),
            equals(ErrorCategory.unknown)); // space
        expect(ErrorCategory.fromString('NETWORK_'),
            equals(ErrorCategory.unknown)); // extra underscore
        expect(ErrorCategory.fromString('_NETWORK'),
            equals(ErrorCategory.unknown)); // leading underscore
      });
    });
    group('Round Trip Conversion Tests', () {
      test('should maintain consistency in round trip conversion', () {
        final categories = [
          ErrorCategory.network,
          ErrorCategory.internal,
          ErrorCategory.serialization,
          ErrorCategory.validation,
          ErrorCategory.storage,
          ErrorCategory.permission,
          ErrorCategory.authentication,
          ErrorCategory.configuration,
          ErrorCategory.timeout,
          ErrorCategory.state,
          ErrorCategory.api,
          ErrorCategory.rateLimit,
          ErrorCategory.circuitBreaker,
          ErrorCategory.concurrency,
          ErrorCategory.user,
          ErrorCategory.analytics,
          ErrorCategory.featureFlag,
          ErrorCategory.session,
          ErrorCategory.unknown,
        ];
        for (final category in categories) {
          final name = category.name;
          final convertedBack = ErrorCategory.fromString(name);
          expect(convertedBack, equals(category));
        }
      });
      test('should handle case insensitive round trip', () {
        final categories = [
          ErrorCategory.network,
          ErrorCategory.validation,
          ErrorCategory.authentication,
          ErrorCategory.rateLimit,
        ];
        for (final category in categories) {
          final lowercaseName = category.name.toLowerCase();
          final convertedBack = ErrorCategory.fromString(lowercaseName);
          expect(convertedBack, equals(category));
        }
      });
    });
    group('Object Identity Tests', () {
      test('should have consistent object identity', () {
        expect(ErrorCategory.network, same(ErrorCategory.network));
        expect(ErrorCategory.internal, same(ErrorCategory.internal));
        expect(ErrorCategory.unknown, same(ErrorCategory.unknown));
      });
      test('should have different identities for different categories', () {
        expect(ErrorCategory.network, isNot(same(ErrorCategory.internal)));
        expect(ErrorCategory.validation, isNot(same(ErrorCategory.storage)));
        expect(ErrorCategory.unknown, isNot(same(ErrorCategory.network)));
      });
      test('should maintain identity through fromString', () {
        expect(
            ErrorCategory.fromString('NETWORK'), same(ErrorCategory.network));
        expect(ErrorCategory.fromString('VALIDATION'),
            same(ErrorCategory.validation));
        expect(
            ErrorCategory.fromString('invalid'), same(ErrorCategory.unknown));
      });
    });
    group('Functional Category Groups Tests', () {
      test('should have network-related categories', () {
        final networkRelated = [
          ErrorCategory.network,
          ErrorCategory.timeout,
          ErrorCategory.rateLimit,
          ErrorCategory.circuitBreaker,
        ];
        for (final category in networkRelated) {
          expect(category.name, isNotEmpty);
        }
      });
      test('should have security-related categories', () {
        final securityRelated = [
          ErrorCategory.permission,
          ErrorCategory.authentication,
        ];
        for (final category in securityRelated) {
          expect(category.name, isNotEmpty);
        }
      });
      test('should have data-related categories', () {
        final dataRelated = [
          ErrorCategory.serialization,
          ErrorCategory.storage,
          ErrorCategory.validation,
        ];
        for (final category in dataRelated) {
          expect(category.name, isNotEmpty);
        }
      });
      test('should have application-related categories', () {
        final appRelated = [
          ErrorCategory.internal,
          ErrorCategory.configuration,
          ErrorCategory.state,
          ErrorCategory.concurrency,
        ];
        for (final category in appRelated) {
          expect(category.name, isNotEmpty);
        }
      });
      test('should have feature-specific categories', () {
        final featureSpecific = [
          ErrorCategory.user,
          ErrorCategory.analytics,
          ErrorCategory.featureFlag,
          ErrorCategory.session,
          ErrorCategory.api,
        ];
        for (final category in featureSpecific) {
          expect(category.name, isNotEmpty);
        }
      });
    });
    group('Error Category Semantics Tests', () {
      test('should have meaningful category names', () {
        expect(ErrorCategory.network.name, contains('NETWORK'));
        expect(ErrorCategory.authentication.name, contains('AUTHENTICATION'));
        expect(ErrorCategory.rateLimit.name, contains('RATE'));
        expect(ErrorCategory.circuitBreaker.name, contains('CIRCUIT'));
        expect(ErrorCategory.featureFlag.name, contains('FEATURE'));
      });
      test('should use consistent naming conventions', () {
        // Multi-word categories should use underscores
        expect(ErrorCategory.rateLimit.name, equals('RATE_LIMIT'));
        expect(ErrorCategory.circuitBreaker.name, equals('CIRCUIT_BREAKER'));
        expect(ErrorCategory.featureFlag.name, equals('FEATURE_FLAG'));
        // Single word categories should be simple
        expect(ErrorCategory.network.name, equals('NETWORK'));
        expect(ErrorCategory.storage.name, equals('STORAGE'));
        expect(ErrorCategory.validation.name, equals('VALIDATION'));
      });
    });
    group('Error Category Coverage Tests', () {
      test('should cover all major error domains', () {
        final allCategories = [
          ErrorCategory.network,
          ErrorCategory.internal,
          ErrorCategory.serialization,
          ErrorCategory.validation,
          ErrorCategory.storage,
          ErrorCategory.permission,
          ErrorCategory.authentication,
          ErrorCategory.configuration,
          ErrorCategory.timeout,
          ErrorCategory.state,
          ErrorCategory.api,
          ErrorCategory.rateLimit,
          ErrorCategory.circuitBreaker,
          ErrorCategory.concurrency,
          ErrorCategory.user,
          ErrorCategory.analytics,
          ErrorCategory.featureFlag,
          ErrorCategory.session,
          ErrorCategory.unknown,
        ];
        expect(allCategories.length, equals(19)); // Comprehensive coverage
        // Verify all are non-null
        for (final category in allCategories) {
          expect(category, isNotNull);
          expect(category.name, isNotEmpty);
        }
      });
    });
  });
}
