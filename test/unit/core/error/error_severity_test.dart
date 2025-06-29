import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_severity.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ErrorSeverity Tests', () {
    group('Enum Values', () {
      test('should have all expected severity levels', () {
        expect(ErrorSeverity.values, hasLength(4));
        expect(ErrorSeverity.values, contains(ErrorSeverity.high));
        expect(ErrorSeverity.values, contains(ErrorSeverity.medium));
        expect(ErrorSeverity.values, contains(ErrorSeverity.low));
        expect(ErrorSeverity.values, contains(ErrorSeverity.critical));
      });
    });
    group('toValue() Extension Method', () {
      test('should convert high severity to string', () {
        expect(ErrorSeverity.high.toValue(), equals('high'));
      });
      test('should convert medium severity to string', () {
        expect(ErrorSeverity.medium.toValue(), equals('medium'));
      });
      test('should convert low severity to string', () {
        expect(ErrorSeverity.low.toValue(), equals('low'));
      });
      test('should convert critical severity to string', () {
        expect(ErrorSeverity.critical.toValue(), equals('critical'));
      });
      test('should handle all enum values in toValue()', () {
        for (final severity in ErrorSeverity.values) {
          final stringValue = severity.toValue();
          expect(stringValue, isNotEmpty);
          expect(stringValue, isA<String>());
        }
      });
    });
    group('fromValue() Extension Method', () {
      test('should create high severity from string', () {
        expect(ErrorSeverityExtension.fromValue('high'),
            equals(ErrorSeverity.high));
      });
      test('should create medium severity from string', () {
        expect(ErrorSeverityExtension.fromValue('medium'),
            equals(ErrorSeverity.medium));
      });
      test('should create low severity from string', () {
        expect(
            ErrorSeverityExtension.fromValue('low'), equals(ErrorSeverity.low));
      });
      test('should create critical severity from string', () {
        expect(ErrorSeverityExtension.fromValue('critical'),
            equals(ErrorSeverity.critical));
      });
      test('should handle uppercase strings', () {
        expect(ErrorSeverityExtension.fromValue('HIGH'),
            equals(ErrorSeverity.high));
        expect(ErrorSeverityExtension.fromValue('MEDIUM'),
            equals(ErrorSeverity.medium));
        expect(
            ErrorSeverityExtension.fromValue('LOW'), equals(ErrorSeverity.low));
        expect(ErrorSeverityExtension.fromValue('CRITICAL'),
            equals(ErrorSeverity.critical));
      });
      test('should handle mixed case strings', () {
        expect(ErrorSeverityExtension.fromValue('HiGh'),
            equals(ErrorSeverity.high));
        expect(ErrorSeverityExtension.fromValue('MeDiUm'),
            equals(ErrorSeverity.medium));
        expect(
            ErrorSeverityExtension.fromValue('LoW'), equals(ErrorSeverity.low));
        expect(ErrorSeverityExtension.fromValue('CrItIcAl'),
            equals(ErrorSeverity.critical));
      });
      test('should return medium as default for invalid strings', () {
        expect(ErrorSeverityExtension.fromValue('invalid'),
            equals(ErrorSeverity.medium));
        expect(
            ErrorSeverityExtension.fromValue(''), equals(ErrorSeverity.medium));
        expect(ErrorSeverityExtension.fromValue('unknown'),
            equals(ErrorSeverity.medium));
        expect(ErrorSeverityExtension.fromValue('123'),
            equals(ErrorSeverity.medium));
      });
      test('should handle null values by returning medium', () {
        expect(ErrorSeverityExtension.fromValue(null),
            equals(ErrorSeverity.medium));
      });
      test('should handle whitespace strings', () {
        // The implementation doesn't trim whitespace, so these return medium (default)
        expect(ErrorSeverityExtension.fromValue('  high  '),
            equals(ErrorSeverity.medium));
        expect(ErrorSeverityExtension.fromValue(' medium '),
            equals(ErrorSeverity.medium));
        expect(ErrorSeverityExtension.fromValue('\tlow\t'),
            equals(ErrorSeverity.medium));
        expect(ErrorSeverityExtension.fromValue('\ncritical\n'),
            equals(ErrorSeverity.medium));
      });
    });
    group('Round-trip Conversion', () {
      test('should maintain consistency between toValue and fromValue', () {
        for (final severity in ErrorSeverity.values) {
          final stringValue = severity.toValue();
          final reconstructed = ErrorSeverityExtension.fromValue(stringValue);
          expect(reconstructed, equals(severity));
        }
      });
    });
    group('Edge Cases', () {
      test('should handle special characters in fromValue', () {
        expect(ErrorSeverityExtension.fromValue('high!'),
            equals(ErrorSeverity.medium));
        expect(ErrorSeverityExtension.fromValue('medium@'),
            equals(ErrorSeverity.medium));
        expect(ErrorSeverityExtension.fromValue('low#'),
            equals(ErrorSeverity.medium));
        expect(ErrorSeverityExtension.fromValue('critical\$'),
            equals(ErrorSeverity.medium));
      });
      test('should handle numeric strings', () {
        expect(ErrorSeverityExtension.fromValue('1'),
            equals(ErrorSeverity.medium));
        expect(ErrorSeverityExtension.fromValue('2'),
            equals(ErrorSeverity.medium));
        expect(ErrorSeverityExtension.fromValue('3'),
            equals(ErrorSeverity.medium));
        expect(ErrorSeverityExtension.fromValue('4'),
            equals(ErrorSeverity.medium));
      });
      test('should handle very long strings', () {
        final longString = 'high' * 100;
        expect(ErrorSeverityExtension.fromValue(longString),
            equals(ErrorSeverity.medium));
      });
    });
    group('Severity Ordering', () {
      test('should have logical ordering', () {
        // The enum order is: high(0), medium(1), low(2), critical(3)
        // So critical has the highest index
        expect(ErrorSeverity.critical.index, equals(3));
        expect(ErrorSeverity.high.index, equals(0));
        expect(ErrorSeverity.medium.index, equals(1));
        expect(ErrorSeverity.low.index, equals(2));
      });
    });
    group('Use Cases', () {
      test('should be usable in switch statements', () {
        String getSeverityMessage(ErrorSeverity severity) {
          switch (severity) {
            case ErrorSeverity.critical:
              return 'Critical error - immediate attention required';
            case ErrorSeverity.high:
              return 'High severity error';
            case ErrorSeverity.medium:
              return 'Medium severity error';
            case ErrorSeverity.low:
              return 'Low severity error';
          }
        }
        expect(
            getSeverityMessage(ErrorSeverity.critical), contains('Critical'));
        expect(getSeverityMessage(ErrorSeverity.high), contains('High'));
        expect(getSeverityMessage(ErrorSeverity.medium), contains('Medium'));
        expect(getSeverityMessage(ErrorSeverity.low), contains('Low'));
      });
      test('should be comparable', () {
        const severity1 = ErrorSeverity.high;
        const severity2 = ErrorSeverity.high;
        const severity3 = ErrorSeverity.low;
        expect(severity1, equals(severity2));
        expect(severity1, isNot(equals(severity3)));
      });
      test('should work in collections', () {
        final severities = <ErrorSeverity>{
          ErrorSeverity.high,
          ErrorSeverity.medium,
          ErrorSeverity.low,
          ErrorSeverity.critical,
        };
        expect(severities.length, equals(4));
        expect(severities.contains(ErrorSeverity.high), isTrue);
        expect(severities.contains(ErrorSeverity.critical), isTrue);
      });
    });
  });
}
