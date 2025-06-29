// test/unit/core/model/context_type_test.dart
//
// Tests for ContextType enum - covers all values and conversion methods
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/context_type.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ContextType', () {
    group('Enum Values', () {
      test('should have all expected enum values', () {
        expect(ContextType.values, hasLength(6));
        expect(ContextType.values, contains(ContextType.user));
        expect(ContextType.values, contains(ContextType.device));
        expect(ContextType.values, contains(ContextType.app));
        expect(ContextType.values, contains(ContextType.session));
        expect(ContextType.values, contains(ContextType.organization));
        expect(ContextType.values, contains(ContextType.custom));
      });
      test('should have correct enum order', () {
        final expectedOrder = [
          ContextType.user,
          ContextType.device,
          ContextType.app,
          ContextType.session,
          ContextType.organization,
          ContextType.custom,
        ];
        expect(ContextType.values, equals(expectedOrder));
      });
    });
    group('toValue Method', () {
      test('should convert user to correct string', () {
        expect(ContextType.user.toValue(), equals('user'));
      });
      test('should convert device to correct string', () {
        expect(ContextType.device.toValue(), equals('device'));
      });
      test('should convert app to correct string', () {
        expect(ContextType.app.toValue(), equals('app'));
      });
      test('should convert session to correct string', () {
        expect(ContextType.session.toValue(), equals('session'));
      });
      test('should convert organization to correct string', () {
        expect(ContextType.organization.toValue(), equals('organization'));
      });
      test('should convert custom to correct string', () {
        expect(ContextType.custom.toValue(), equals('custom'));
      });
      test('should return consistent string values', () {
        for (final contextType in ContextType.values) {
          final stringValue = contextType.toValue();
          expect(stringValue, isA<String>());
          expect(stringValue, isNotEmpty);
          expect(stringValue, equals(stringValue.toLowerCase()));
        }
      });
    });
    group('fromString Method', () {
      test('should parse user from string', () {
        expect(ContextType.fromString('user'), equals(ContextType.user));
      });
      test('should parse device from string', () {
        expect(ContextType.fromString('device'), equals(ContextType.device));
      });
      test('should parse app from string', () {
        expect(ContextType.fromString('app'), equals(ContextType.app));
      });
      test('should parse session from string', () {
        expect(ContextType.fromString('session'), equals(ContextType.session));
      });
      test('should parse organization from string', () {
        expect(ContextType.fromString('organization'),
            equals(ContextType.organization));
      });
      test('should parse custom from string', () {
        expect(ContextType.fromString('custom'), equals(ContextType.custom));
      });
      test('should handle uppercase strings', () {
        expect(ContextType.fromString('USER'), equals(ContextType.user));
        expect(ContextType.fromString('DEVICE'), equals(ContextType.device));
        expect(ContextType.fromString('APP'), equals(ContextType.app));
        expect(ContextType.fromString('SESSION'), equals(ContextType.session));
        expect(ContextType.fromString('ORGANIZATION'),
            equals(ContextType.organization));
        expect(ContextType.fromString('CUSTOM'), equals(ContextType.custom));
      });
      test('should handle mixed case strings', () {
        expect(ContextType.fromString('User'), equals(ContextType.user));
        expect(ContextType.fromString('Device'), equals(ContextType.device));
        expect(ContextType.fromString('App'), equals(ContextType.app));
        expect(ContextType.fromString('Session'), equals(ContextType.session));
        expect(ContextType.fromString('Organization'),
            equals(ContextType.organization));
        expect(ContextType.fromString('Custom'), equals(ContextType.custom));
      });
      test('should handle camelCase strings', () {
        expect(ContextType.fromString('uSeR'), equals(ContextType.user));
        expect(ContextType.fromString('dEvIcE'), equals(ContextType.device));
        expect(ContextType.fromString('aPp'), equals(ContextType.app));
        expect(ContextType.fromString('sEsSiOn'), equals(ContextType.session));
        expect(ContextType.fromString('oRgAnIzAtIoN'),
            equals(ContextType.organization));
        expect(ContextType.fromString('cUsToM'), equals(ContextType.custom));
      });
      test('should return null for unknown strings', () {
        expect(ContextType.fromString('unknown'), isNull);
        expect(ContextType.fromString('invalid'), isNull);
        expect(ContextType.fromString('not_a_context'), isNull);
        expect(ContextType.fromString(''), isNull);
        expect(ContextType.fromString('123'), isNull);
      });
      test('should return null for strings with extra characters', () {
        expect(ContextType.fromString('user123'), isNull);
        expect(ContextType.fromString('user '), isNull);
        expect(ContextType.fromString(' user'), isNull);
        expect(ContextType.fromString('user-type'), isNull);
        expect(ContextType.fromString('user_type'), isNull);
      });
      test('should handle special characters', () {
        expect(ContextType.fromString('user@'), isNull);
        expect(ContextType.fromString('device#'), isNull);
        expect(ContextType.fromString('app\$'), isNull);
        expect(ContextType.fromString('session%'), isNull);
      });
    });
    group('Round-trip Conversion', () {
      test('should maintain consistency in round-trip conversion', () {
        for (final contextType in ContextType.values) {
          final stringValue = contextType.toValue();
          final parsedType = ContextType.fromString(stringValue);
          expect(parsedType, equals(contextType));
        }
      });
      test('should handle round-trip with case variations', () {
        for (final contextType in ContextType.values) {
          final stringValue = contextType.toValue();
          // Test uppercase round-trip
          final upperParsed = ContextType.fromString(stringValue.toUpperCase());
          expect(upperParsed, equals(contextType));
          // Test title case round-trip
          final titleCase =
              stringValue[0].toUpperCase() + stringValue.substring(1);
          final titleParsed = ContextType.fromString(titleCase);
          expect(titleParsed, equals(contextType));
        }
      });
    });
    group('Edge Cases', () {
      test('should handle empty string', () {
        expect(ContextType.fromString(''), isNull);
      });
      test('should handle whitespace strings', () {
        expect(ContextType.fromString(' '), isNull);
        expect(ContextType.fromString('  '), isNull);
        expect(ContextType.fromString('\t'), isNull);
        expect(ContextType.fromString('\n'), isNull);
      });
      test('should handle strings with leading/trailing whitespace', () {
        expect(ContextType.fromString(' user'), isNull);
        expect(ContextType.fromString('user '), isNull);
        expect(ContextType.fromString(' user '), isNull);
        expect(ContextType.fromString('\tdevice\t'), isNull);
      });
      test('should handle null-like strings', () {
        expect(ContextType.fromString('null'), isNull);
        expect(ContextType.fromString('undefined'), isNull);
        expect(ContextType.fromString('none'), isNull);
      });
      test('should handle numeric strings', () {
        expect(ContextType.fromString('0'), isNull);
        expect(ContextType.fromString('1'), isNull);
        expect(ContextType.fromString('-1'), isNull);
        expect(ContextType.fromString('3.14'), isNull);
      });
      test('should handle boolean-like strings', () {
        expect(ContextType.fromString('true'), isNull);
        expect(ContextType.fromString('false'), isNull);
        expect(ContextType.fromString('yes'), isNull);
        expect(ContextType.fromString('no'), isNull);
      });
    });
    group('Type Safety', () {
      test('should be strongly typed enum', () {
        expect(ContextType.user, isA<ContextType>());
        expect(ContextType.device, isA<ContextType>());
        expect(ContextType.app, isA<ContextType>());
        expect(ContextType.session, isA<ContextType>());
        expect(ContextType.organization, isA<ContextType>());
        expect(ContextType.custom, isA<ContextType>());
      });
      test('should support switch statements', () {
        String getDescription(ContextType type) {
          switch (type) {
            case ContextType.user:
              return 'User-specific targeting';
            case ContextType.device:
              return 'Device-specific targeting';
            case ContextType.app:
              return 'Application-specific targeting';
            case ContextType.session:
              return 'Session-specific targeting';
            case ContextType.organization:
              return 'Organization-specific targeting';
            case ContextType.custom:
              return 'Custom targeting rules';
          }
        }
        expect(getDescription(ContextType.user),
            equals('User-specific targeting'));
        expect(getDescription(ContextType.device),
            equals('Device-specific targeting'));
        expect(getDescription(ContextType.app),
            equals('Application-specific targeting'));
        expect(getDescription(ContextType.session),
            equals('Session-specific targeting'));
        expect(getDescription(ContextType.organization),
            equals('Organization-specific targeting'));
        expect(getDescription(ContextType.custom),
            equals('Custom targeting rules'));
      });
      test('should support equality comparison', () {
        expect(ContextType.user == ContextType.user, isTrue);
        expect(ContextType.user == ContextType.device, isFalse);
        expect(ContextType.device != ContextType.app, isTrue);
      });
      test('should support set operations', () {
        final contextSet = {
          ContextType.user,
          ContextType.device,
        };
        expect(contextSet, hasLength(2));
        expect(contextSet, contains(ContextType.user));
        expect(contextSet, contains(ContextType.device));
        expect(contextSet, isNot(contains(ContextType.app)));
      });
      test('should support list operations', () {
        final contextList = [
          ContextType.user,
          ContextType.device,
          ContextType.app
        ];
        expect(contextList, hasLength(3));
        expect(contextList.first, equals(ContextType.user));
        expect(contextList.last, equals(ContextType.app));
        expect(contextList.contains(ContextType.session), isFalse);
      });
    });
    group('Performance', () {
      test('should handle repeated conversions efficiently', () {
        // Test that repeated calls don't cause performance issues
        for (int i = 0; i < 1000; i++) {
          for (final contextType in ContextType.values) {
            final stringValue = contextType.toValue();
            final parsedType = ContextType.fromString(stringValue);
            expect(parsedType, equals(contextType));
          }
        }
      });
      test('should handle case conversion efficiently', () {
        const testStrings = [
          'USER',
          'device',
          'App',
          'SESSION',
          'organization',
          'CUSTOM'
        ];
        for (int i = 0; i < 1000; i++) {
          for (final testString in testStrings) {
            final result = ContextType.fromString(testString);
            expect(result, isNotNull);
          }
        }
      });
    });
  });
}
