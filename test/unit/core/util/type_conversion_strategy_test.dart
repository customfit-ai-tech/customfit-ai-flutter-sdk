// test/unit/core/util/type_conversion_strategy_test.dart
//
// Tests for the type conversion strategy pattern implementation.
// Validates that the strategy pattern provides extensible and testable
// type conversion logic for the cache system.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/type_conversion_strategy.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_error_code.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Type Conversion Strategy Tests', () {
    late TypeConversionManager manager;
    setUp(() {
      manager = TypeConversionManager();
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      PreferencesService.reset();
    });
    group('String Conversion Strategy', () {
      test('should convert various types to string with CFResult', () {
        final intResult = manager.convertValue<String>(42);
        expect(intResult.isSuccess, true);
        expect(intResult.data, '42');
        final doubleResult = manager.convertValue<String>(3.14);
        expect(doubleResult.isSuccess, true);
        expect(doubleResult.data, '3.14');
        final boolResult = manager.convertValue<String>(true);
        expect(boolResult.isSuccess, true);
        expect(boolResult.data, 'true');
        final stringResult = manager.convertValue<String>('hello');
        expect(stringResult.isSuccess, true);
        expect(stringResult.data, 'hello');
      });
      test('should return error for null conversion to String', () {
        final result = manager.convertValue<String>(null);
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidType);
        expect(result.error?.category, ErrorCategory.validation);
        expect(
            result.error?.message, contains('Cannot convert null to String'));
      });
    });
    group('Int Conversion Strategy', () {
      test('should convert string to int with CFResult', () {
        final result1 = manager.convertValue<int>('42');
        expect(result1.isSuccess, true);
        expect(result1.data, 42);
        final result2 = manager.convertValue<int>('0');
        expect(result2.isSuccess, true);
        expect(result2.data, 0);
        final result3 = manager.convertValue<int>('-123');
        expect(result3.isSuccess, true);
        expect(result3.data, -123);
      });
      test('should convert double to int with precision check', () {
        final result1 = manager.convertValue<int>(42.0);
        expect(result1.isSuccess, true);
        expect(result1.data, 42);
        final result2 = manager.convertValue<int>(42.7);
        expect(result2.isSuccess, false);
        expect(result2.error?.errorCode, CFErrorCode.validationInvalidType);
        expect(result2.error?.message, contains('without loss of precision'));
      });
      test('should return error for invalid string', () {
        final result = manager.convertValue<int>('not_a_number');
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidFormat);
        expect(result.error?.message, contains('Failed to parse'));
      });
      test('should return error for null', () {
        final result = manager.convertValue<int>(null);
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidType);
      });
    });
    group('Double Conversion Strategy', () {
      test('should convert string to double with CFResult', () {
        final result1 = manager.convertValue<double>('3.14');
        expect(result1.isSuccess, true);
        expect(result1.data, 3.14);
        final result2 = manager.convertValue<double>('0.0');
        expect(result2.isSuccess, true);
        expect(result2.data, 0.0);
        final result3 = manager.convertValue<double>('-123.45');
        expect(result3.isSuccess, true);
        expect(result3.data, -123.45);
      });
      test('should convert int to double', () {
        final result1 = manager.convertValue<double>(42);
        expect(result1.isSuccess, true);
        expect(result1.data, 42.0);
        final result2 = manager.convertValue<double>(0);
        expect(result2.isSuccess, true);
        expect(result2.data, 0.0);
      });
      test('should return error for invalid string', () {
        final result = manager.convertValue<double>('not_a_number');
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidFormat);
      });
    });
    group('Bool Conversion Strategy', () {
      test('should convert string to bool with CFResult', () {
        final result1 = manager.convertValue<bool>('true');
        expect(result1.isSuccess, true);
        expect(result1.data, isTrue);
        final result2 = manager.convertValue<bool>('TRUE');
        expect(result2.isSuccess, true);
        expect(result2.data, isTrue);
        final result3 = manager.convertValue<bool>('1');
        expect(result3.isSuccess, true);
        expect(result3.data, isTrue);
        final result4 = manager.convertValue<bool>('false');
        expect(result4.isSuccess, true);
        expect(result4.data, isFalse);
        final result5 = manager.convertValue<bool>('FALSE');
        expect(result5.isSuccess, true);
        expect(result5.data, isFalse);
        final result6 = manager.convertValue<bool>('0');
        expect(result6.isSuccess, true);
        expect(result6.data, isFalse);
      });
      test('should convert int to bool', () {
        final result1 = manager.convertValue<bool>(1);
        expect(result1.isSuccess, true);
        expect(result1.data, isTrue);
        final result2 = manager.convertValue<bool>(42);
        expect(result2.isSuccess, true);
        expect(result2.data, isTrue);
        final result3 = manager.convertValue<bool>(0);
        expect(result3.isSuccess, true);
        expect(result3.data, isFalse);
      });
      test('should return error for invalid string', () {
        final result = manager.convertValue<bool>('maybe');
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidFormat);
        expect(result.error?.message, contains('expected true/false/1/0'));
      });
    });
    group('Collection Conversion Strategies', () {
      test('should handle Map conversion with CFResult', () {
        final map = {'key': 'value'};
        final result = manager.convertValue<Map>(map);
        expect(result.isSuccess, true);
        expect(result.data, equals(map));
      });
      test('should handle List conversion with CFResult', () {
        final list = [1, 2, 3];
        final result = manager.convertValue<List>(list);
        expect(result.isSuccess, true);
        expect(result.data, equals(list));
      });
      test('should return error for incompatible conversions', () {
        final result1 = manager.convertValue<Map>('not_a_map');
        expect(result1.isSuccess, false);
        expect(result1.error?.errorCode, CFErrorCode.validationInvalidType);
        final result2 = manager.convertValue<List>('not_a_list');
        expect(result2.isSuccess, false);
        expect(result2.error?.errorCode, CFErrorCode.validationInvalidType);
      });
    });
    group('Custom Strategy Registration', () {
      test('should allow registering custom strategies', () {
        // Create a custom DateTime conversion strategy
        final customStrategy = _DateTimeConversionStrategy();
        manager.registerStrategy(customStrategy);
        const dateString = '2024-01-01T00:00:00.000Z';
        final result = manager.convertValue<DateTime>(dateString);
        expect(result.isSuccess, true);
        expect(result.data, isA<DateTime>());
        expect(result.data?.year, 2024);
      });
      test('should allow removing strategies', () {
        manager.removeStrategy<StringConversionStrategy>();
        // String conversion should now fail
        final result = manager.convertValue<String>(42);
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.validationInvalidType);
        expect(result.error?.message,
            contains('No conversion strategy available'));
      });
    });
    group('Strategy Priority', () {
      test('should use strategies in priority order', () {
        // Register a high-priority strategy that always returns 'CUSTOM'
        final highPriorityStrategy = _CustomStringStrategy();
        manager.registerStrategy(highPriorityStrategy);
        final result = manager.convertValue<String>(42);
        expect(result.isSuccess, true);
        expect(result.data, 'CUSTOM');
      });
    });
    group('Type Checking', () {
      test('should report available strategies', () {
        expect(manager.hasStrategyFor(String), isTrue);
        expect(manager.hasStrategyFor(int), isTrue);
        expect(manager.hasStrategyFor(DateTime), isFalse);
      });
      test('should list registered strategies', () {
        final strategies = manager.getStrategies();
        expect(strategies, isNotEmpty);
        expect(strategies.any((s) => s is StringConversionStrategy), isTrue);
      });
    });
    group('Error Context and Handling', () {
      test('should include context in error results', () {
        final result = manager.convertValue<int>('not_a_number');
        expect(result.isSuccess, false);
        expect(result.error?.context, isNotNull);
        expect(result.error?.context?['value'], 'not_a_number');
      });
      test('should handle strategy exceptions', () {
        // Register a strategy that throws
        final throwingStrategy = _ThrowingConversionStrategy();
        manager.registerStrategy(throwingStrategy);
        final result = manager.convertValue<_CustomType>('test');
        expect(result.isSuccess, false);
        expect(result.error?.errorCode, CFErrorCode.internalConversionError);
        expect(result.error?.exception, isNotNull);
      });
    });
  });
}
/// Custom DateTime conversion strategy for testing
class _DateTimeConversionStrategy extends TypeConversionStrategy<DateTime> {
  @override
  CFResult<DateTime> convert(dynamic value) {
    try {
      if (value == null) {
        return CFResult.error(
          'Cannot convert null to DateTime',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidType,
        );
      }
      if (value is DateTime) return CFResult.success(value);
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return CFResult.success(parsed);
        }
        return CFResult.error(
          'Failed to parse "$value" as DateTime',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidFormat,
          context: {'value': value},
        );
      }
      return CFResult.error(
        'Cannot convert ${value.runtimeType} to DateTime',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidType,
        context: {'valueType': value.runtimeType.toString()},
      );
    } catch (e, stackTrace) {
      return CFResult.error(
        'Failed to convert value to DateTime: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalConversionError,
        context: {
          'valueType': value.runtimeType.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }
  @override
  bool canHandle(Type type) => type == DateTime;
  @override
  int get priority => 15;
}
/// Custom high-priority string strategy for testing
class _CustomStringStrategy extends TypeConversionStrategy<String> {
  @override
  CFResult<String> convert(dynamic value) => CFResult.success('CUSTOM');
  @override
  bool canHandle(Type type) => type == String;
  @override
  int get priority => 100; // Very high priority
}
/// Custom type for testing
class _CustomType {}
/// Strategy that throws for testing error handling
class _ThrowingConversionStrategy extends TypeConversionStrategy<_CustomType> {
  @override
  CFResult<_CustomType> convert(dynamic value) {
    throw Exception('Intentional test exception');
  }
  @override
  bool canHandle(Type type) => type == _CustomType;
  @override
  int get priority => 100;
}
