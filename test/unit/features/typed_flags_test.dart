// test/unit/features/typed_flags_test.dart
//
// Comprehensive test suite for TypedFlags covering all functionality
// Consolidated from multiple test files to eliminate duplication while maintaining complete coverage
//
// Original files consolidated:
// - typed_flags_test.dart (main tests)
// - typed_flags_comprehensive_test.dart (advanced coverage)
// - typed_flags_coverage_test.dart (additional coverage)
// - typed_flags_standalone_test.dart (standalone tests)
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_core.dart';

// Test enums for EnumFlag tests
enum TestExperiment { control, variantA, variantB }

enum TestStatus { pending, active, completed, cancelled }

enum Priority { low, medium, high }

// Test models for JsonFlag tests
class TestConfig {
  final String name;
  final int value;
  final bool enabled;
  TestConfig({
    required this.name,
    required this.value,
    required this.enabled,
  });
  factory TestConfig.fromJson(Map<String, dynamic> json) {
    return TestConfig(
      name: json['name'] as String? ?? 'default',
      value: json['value'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'enabled': enabled,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestConfig &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value == other.value &&
          enabled == other.enabled;
  @override
  int get hashCode => name.hashCode ^ value.hashCode ^ enabled.hashCode;
}

class TestSettings {
  final String theme;
  final int maxRetries;
  final bool notifications;
  TestSettings({
    required this.theme,
    required this.maxRetries,
    required this.notifications,
  });
  factory TestSettings.fromJson(Map<String, dynamic> json) {
    return TestSettings(
      theme: json['theme'] as String? ?? 'light',
      maxRetries: json['maxRetries'] as int? ?? 3,
      notifications: json['notifications'] as bool? ?? true,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'maxRetries': maxRetries,
      'notifications': notifications,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestSettings &&
          runtimeType == other.runtimeType &&
          theme == other.theme &&
          maxRetries == other.maxRetries &&
          notifications == other.notifications;
  @override
  int get hashCode =>
      theme.hashCode ^ maxRetries.hashCode ^ notifications.hashCode;
}

// Enhanced test flag provider with error simulation
class EnhancedTestFlagProvider implements FlagProvider {
  final Map<String, dynamic> _flags = {};
  final Map<String, StreamController<dynamic>> _controllers = {};
  bool _simulateErrors = false;
  @override
  dynamic getFlag(String key) {
    if (_simulateErrors) {
      throw StateError('Simulated flag provider error');
    }
    return _flags[key];
  }

  @override
  Map<String, dynamic> getAllFlags() => Map.unmodifiable(_flags);
  @override
  bool flagExists(String key) => _flags.containsKey(key);
  @override
  Stream<dynamic> flagChanges(String key) {
    _controllers[key] ??= StreamController<dynamic>.broadcast();
    return _controllers[key]!.stream;
  }

  void setFlag(String key, dynamic value) {
    _flags[key] = value;
    _controllers[key]?.add(value);
  }

  void simulateErrors(bool enabled) {
    _simulateErrors = enabled;
  }

  @override
  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _flags.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('TypedFlags Comprehensive Tests', () {
    group('1. BooleanFlag Tests', () {
      late EnhancedTestFlagProvider provider;
      setUp(() {
        provider = EnhancedTestFlagProvider();
      });
      tearDown(() {
        provider.dispose();
      });
      test('should return default value when flag not set', () {
        final flag = BooleanFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: true,
          description: 'Test boolean flag',
        );
        expect(flag.value, true);
      });
      test('should get value from provider when set', () {
        provider.setFlag('test_flag', false);
        final flag = BooleanFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: true,
        );
        expect(flag.value, false);
      });
      test('should validate boolean values correctly', () {
        final flag = BooleanFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: false,
        );
        expect(flag.isValidValue(true), true);
        expect(flag.isValidValue(false), true);
        expect(flag.isValidValue('true'), false);
        expect(flag.isValidValue(1), false);
        expect(flag.isValidValue(null), false);
      });
      test('should parse values correctly', () {
        final flag = BooleanFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: false,
        );
        expect(flag.parseValue(true), true);
        expect(flag.parseValue(false), false);
        expect(flag.parseValue('true'), true);
        expect(flag.parseValue('false'), false);
        expect(flag.parseValue('TRUE'), true);
        expect(flag.parseValue('yes'), true);
        expect(flag.parseValue('1'), true);
        expect(flag.parseValue('invalid'), false);
        expect(flag.parseValue(null), false);
      });
      test('should parse numeric values correctly', () {
        final flag = BooleanFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: false,
        );
        expect(flag.parseValue(0), equals(false));
        expect(flag.parseValue(1), equals(true));
        expect(flag.parseValue(2), equals(true));
        expect(flag.parseValue(-1), equals(true));
        expect(flag.parseValue(0.0), equals(false));
        expect(flag.parseValue(0.1), equals(true));
        expect(flag.parseValue(1.0), equals(true));
        expect(flag.parseValue(-1.0), equals(true));
      });
      test('should handle edge string cases', () {
        final flag = BooleanFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: false,
        );
        expect(flag.parseValue('YES'), equals(true));
        expect(flag.parseValue('no'), equals(false));
        expect(flag.parseValue('NO'), equals(false));
        expect(flag.parseValue('0'), equals(false));
        expect(flag.parseValue(''), equals(false));
        expect(flag.parseValue(' '), equals(false));
      });
      test('should emit value changes', () async {
        final flag = BooleanFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: false,
        );
        final values = <bool>[];
        final subscription = flag.changes.listen(values.add);
        provider.setFlag('test_flag', false);
        await Future.delayed(const Duration(milliseconds: 10));
        provider.setFlag('test_flag', true);
        await Future.delayed(const Duration(milliseconds: 10));
        expect(values, [false, true]);
        await subscription.cancel();
      });
      test('should handle dispose method', () {
        final flag = BooleanFlag(
          provider: provider,
          key: 'bool_flag',
          defaultValue: false,
        );
        expect(() => flag.dispose(), returnsNormally);
        expect(() => flag.dispose(), returnsNormally);
      });
      test('should handle null values', () {
        provider.setFlag('test_flag', null);
        final flag = BooleanFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: true,
        );
        expect(flag.value, true);
      });
    });
    group('2. StringFlag Tests', () {
      late EnhancedTestFlagProvider provider;
      setUp(() {
        provider = EnhancedTestFlagProvider();
      });
      tearDown(() {
        provider.dispose();
      });
      test('should get value from provider', () {
        provider.setFlag('theme', 'dark');
        final flag = StringFlag(
          provider: provider,
          key: 'theme',
          defaultValue: 'light',
          description: 'App theme',
        );
        expect(flag.value, 'dark');
      });
      test('should validate string values correctly', () {
        final flag = StringFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 'default',
        );
        expect(flag.isValidValue('test'), true);
        expect(flag.isValidValue(''), true);
        expect(flag.isValidValue(123), false);
        expect(flag.isValidValue(true), false);
        expect(flag.isValidValue(null), false);
      });
      test('should enforce allowed values when specified', () {
        final flag = StringFlag(
          provider: provider,
          key: 'env',
          defaultValue: 'production',
          allowedValues: ['development', 'staging', 'production'],
        );
        expect(flag.isValidValue('production'), true);
        expect(flag.isValidValue('staging'), true);
        expect(flag.isValidValue('invalid'), false);
      });
      test('should parse values correctly', () {
        final flag = StringFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 'default',
        );
        expect(flag.parseValue('test'), 'test');
        expect(flag.parseValue(123), '123');
        expect(flag.parseValue(true), 'true');
        expect(flag.parseValue(null), 'default');
      });
      test('should enforce allowed values during parsing', () {
        final flag = StringFlag(
          provider: provider,
          key: 'env',
          defaultValue: 'production',
          allowedValues: ['development', 'staging', 'production'],
        );
        expect(flag.parseValue('staging'), 'staging');
        expect(flag.parseValue('invalid'), 'production');
      });
      test('should handle null allowed values list', () {
        final flag = StringFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 'default',
          allowedValues: null,
        );
        expect(flag.isValidValue('any_value'), isTrue);
        expect(flag.parseValue('any_value'), equals('any_value'));
      });
      test('should handle empty allowed values list', () {
        final flag = StringFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 'default',
          allowedValues: [],
        );
        expect(flag.isValidValue('any_value'), isFalse);
        expect(flag.parseValue('any_value'), equals('default'));
      });
      test('should handle complex data type conversion', () {
        final flag = StringFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 'default',
        );
        expect(flag.parseValue({'key': 'value'}), equals('{key: value}'));
        expect(flag.parseValue([1, 2, 3]), equals('[1, 2, 3]'));
        expect(flag.parseValue(42), equals('42'));
        expect(flag.parseValue(3.14), equals('3.14'));
        expect(flag.parseValue(true), equals('true'));
        expect(flag.parseValue(false), equals('false'));
      });
      test('should handle dispose method', () {
        final flag = StringFlag(
          provider: provider,
          key: 'string_flag',
          defaultValue: 'default',
        );
        expect(() => flag.dispose(), returnsNormally);
        expect(() => flag.dispose(), returnsNormally);
      });
    });
    group('3. NumberFlag Tests', () {
      late EnhancedTestFlagProvider provider;
      setUp(() {
        provider = EnhancedTestFlagProvider();
      });
      tearDown(() {
        provider.dispose();
      });
      test('should get value from provider', () {
        provider.setFlag('timeout', 3000.0);
        final flag = NumberFlag(
          provider: provider,
          key: 'timeout',
          defaultValue: 5000.0,
          min: 1000.0,
          max: 10000.0,
        );
        expect(flag.value, 3000.0);
      });
      test('should validate number values with constraints', () {
        final flag = NumberFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 50.0,
          min: 0.0,
          max: 100.0,
        );
        expect(flag.isValidValue(50.0), true);
        expect(flag.isValidValue(0.0), true);
        expect(flag.isValidValue(100.0), true);
        expect(flag.isValidValue(-1.0), false);
        expect(flag.isValidValue(101.0), false);
        expect(flag.isValidValue('50'), false);
        expect(flag.isValidValue(null), false);
      });
      test('should parse and clamp values', () {
        final flag = NumberFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 50.0,
          min: 0.0,
          max: 100.0,
        );
        expect(flag.parseValue(50.0), 50.0);
        expect(flag.parseValue(150.0), 100.0);
        expect(flag.parseValue(-10.0), 0.0);
        expect(flag.parseValue('75.5'), 75.5);
        expect(flag.parseValue('invalid'), 50.0);
        expect(flag.parseValue(null), 50.0);
      });
      test('should handle integer values', () {
        final flag = NumberFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 50.0,
        );
        expect(flag.parseValue(42), 42.0);
        expect(flag.isValidValue(42), true);
      });
      test('should handle min-only constraints', () {
        final flag = NumberFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 50.0,
          min: 10.0,
          max: null,
        );
        expect(flag.isValidValue(15.0), isTrue);
        expect(flag.isValidValue(5.0), isFalse);
        expect(flag.parseValue(5.0), equals(10.0));
        expect(flag.parseValue(1000.0), equals(1000.0));
      });
      test('should handle max-only constraints', () {
        final flag = NumberFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 50.0,
          min: null,
          max: 100.0,
        );
        expect(flag.isValidValue(95.0), isTrue);
        expect(flag.isValidValue(105.0), isFalse);
        expect(flag.parseValue(105.0), equals(100.0));
        expect(flag.parseValue(-50.0), equals(-50.0));
      });
      test('should handle edge case with min equals max', () {
        final flag = NumberFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 42.0,
          min: 42.0,
          max: 42.0,
        );
        expect(flag.isValidValue(42.0), isTrue);
        expect(flag.isValidValue(41.9), isFalse);
        expect(flag.isValidValue(42.1), isFalse);
        expect(flag.parseValue(100.0), equals(42.0));
        expect(flag.parseValue(0.0), equals(42.0));
      });
      test('should test parseValue with string numbers edge cases', () {
        final flag = NumberFlag(
          provider: provider,
          key: 'number_flag',
          defaultValue: 0.0,
        );
        expect(flag.parseValue('3.14159'), equals(3.14159));
        expect(flag.parseValue('-42.5'), equals(-42.5));
        expect(flag.parseValue('0'), equals(0.0));
        expect(flag.parseValue('0.0'), equals(0.0));
        expect(flag.parseValue('1e3'), equals(1000.0));
        expect(flag.parseValue('1.5e2'), equals(150.0));
        expect(flag.parseValue('not_a_number'), equals(0.0));
        expect(flag.parseValue(''), equals(0.0));
        expect(flag.parseValue('3.14.15'), equals(0.0));
      });
      test('should test constraint clamping edge cases', () {
        final flag = NumberFlag(
          provider: provider,
          key: 'number_flag',
          defaultValue: 50.0,
          min: 0.0,
          max: 100.0,
        );
        expect(flag.parseValue(double.infinity), equals(100.0));
        expect(flag.parseValue(double.negativeInfinity), equals(0.0));
        expect(flag.parseValue(double.nan), equals(50.0));
        expect(flag.parseValue(1e10), equals(100.0));
        expect(flag.parseValue(-1e10), equals(0.0));
      });
      test('should handle dispose method', () {
        final flag = NumberFlag(
          provider: provider,
          key: 'number_flag',
          defaultValue: 0.0,
        );
        expect(() => flag.dispose(), returnsNormally);
        expect(() => flag.dispose(), returnsNormally);
      });
    });
    group('4. JsonFlag Tests', () {
      late EnhancedTestFlagProvider provider;
      setUp(() {
        provider = EnhancedTestFlagProvider();
      });
      tearDown(() {
        provider.dispose();
      });
      test('should get JSON value from provider', () {
        final jsonValue = {'name': 'test', 'value': 42, 'enabled': true};
        provider.setFlag('config', jsonValue);
        final flag = JsonFlag<Map<String, dynamic>>(
          provider: provider,
          key: 'config',
          defaultValue: <String, dynamic>{},
        );
        expect(flag.value, jsonValue);
      });
      test('should parse JSON to custom type', () {
        final jsonValue = {'name': 'test', 'value': 42, 'enabled': true};
        provider.setFlag('config', jsonValue);
        final flag = JsonFlag<TestConfig>(
          provider: provider,
          key: 'config',
          defaultValue: TestConfig(name: 'default', value: 0, enabled: false),
          parser: (json) => TestConfig.fromJson(json),
          serializer: (config) => config.toJson(),
        );
        final value = flag.value;
        expect(value.name, 'test');
        expect(value.value, 42);
        expect(value.enabled, true);
      });
      test('should handle parser errors gracefully', () {
        final invalidJson = {'invalid': 'data'};
        provider.setFlag('config', invalidJson);
        final defaultConfig =
            TestConfig(name: 'default', value: 0, enabled: false);
        final flag = JsonFlag<TestConfig>(
          provider: provider,
          key: 'config',
          defaultValue: defaultConfig,
          parser: (json) {
            if (!json.containsKey('name') || !json.containsKey('value')) {
              throw const FormatException('Invalid JSON structure');
            }
            return TestConfig.fromJson(json);
          },
        );
        expect(flag.value, defaultConfig);
      });
      test('should validate JSON values', () {
        final flag = JsonFlag<Map<String, dynamic>>(
          provider: provider,
          key: 'config',
          defaultValue: <String, dynamic>{},
        );
        expect(flag.isValidValue({'key': 'value'}), true);
        expect(flag.isValidValue('not a map'), false);
        expect(flag.isValidValue(123), false);
        expect(flag.isValidValue(null), false);
      });
      test('should handle parser validation throwing exceptions', () {
        final flag = JsonFlag<TestSettings>(
          provider: provider,
          key: 'test_flag',
          defaultValue: TestSettings(
              theme: 'default', maxRetries: 0, notifications: false),
          parser: (json) {
            if (json['theme'] == 'invalid') {
              throw ArgumentError('Invalid theme');
            }
            return TestSettings.fromJson(json);
          },
        );
        expect(
            flag.isValidValue(
                {'theme': 'dark', 'maxRetries': 3, 'notifications': true}),
            isTrue);
        expect(flag.isValidValue({'theme': 'invalid'}), isFalse);
      });
      test('should handle complex nested JSON structures', () {
        final flag = JsonFlag<Map<String, dynamic>>(
          provider: provider,
          key: 'test_flag',
          defaultValue: {},
        );
        final complexJson = {
          'level1': {
            'level2': {
              'level3': ['item1', 'item2'],
              'numbers': [1, 2, 3.14],
              'mixed': {'string': 'value', 'number': 42, 'bool': true}
            }
          }
        };
        expect(flag.isValidValue(complexJson), isTrue);
        expect(flag.parseValue(complexJson), equals(complexJson));
      });
      test('should handle parser returning null', () {
        final flag = JsonFlag<TestSettings?>(
          provider: provider,
          key: 'test_flag',
          defaultValue: null,
          parser: (json) {
            if (json.isEmpty) {
              return null;
            }
            return TestSettings.fromJson(json);
          },
        );
        provider.setFlag('test_flag', {});
        expect(flag.value, isNull);
      });
      test('should handle dispose method', () {
        final flag = JsonFlag<Map<String, dynamic>>(
          provider: provider,
          key: 'json_flag',
          defaultValue: {},
        );
        expect(() => flag.dispose(), returnsNormally);
        expect(() => flag.dispose(), returnsNormally);
      });

      test('should test parsing with custom parser exceptions', () {
        final flag = JsonFlag<Map<String, dynamic>>(
          provider: provider,
          key: 'json_flag',
          defaultValue: {'default': true},
          parser: (json) {
            if (json.containsKey('throw_error')) {
              throw ArgumentError('Simulated parser error');
            }
            return json;
          },
        );
        provider.setFlag('json_flag', {'valid': 'data'});
        expect(flag.value, equals({'valid': 'data'}));
        provider.setFlag('json_flag', {'throw_error': true});
        expect(flag.value, equals({'default': true}));
      });
    });
    group('5. EnumFlag Tests', () {
      late EnhancedTestFlagProvider provider;
      setUp(() {
        provider = EnhancedTestFlagProvider();
      });
      tearDown(() {
        provider.dispose();
      });
      test('should get enum value from provider', () {
        provider.setFlag('experiment', 'variantA');
        final flag = EnumFlag<TestExperiment>(
          provider: provider,
          key: 'experiment',
          defaultValue: TestExperiment.control,
          values: TestExperiment.values,
        );
        expect(flag.value, TestExperiment.variantA);
      });
      test('should validate enum values correctly', () {
        final flag = EnumFlag<TestExperiment>(
          provider: provider,
          key: 'experiment',
          defaultValue: TestExperiment.control,
          values: TestExperiment.values,
        );
        expect(flag.isValidValue('control'), true);
        expect(flag.isValidValue('variantA'), true);
        expect(flag.isValidValue('variantB'), true);
        expect(flag.isValidValue('invalid'), false);
        expect(flag.isValidValue(123), false);
        expect(flag.isValidValue(null), false);
      });
      test('should parse enum values', () {
        final flag = EnumFlag<TestExperiment>(
          provider: provider,
          key: 'experiment',
          defaultValue: TestExperiment.control,
          values: TestExperiment.values,
        );
        expect(flag.parseValue('variantA'), TestExperiment.variantA);
        expect(flag.parseValue('variantB'), TestExperiment.variantB);
        expect(flag.parseValue('invalid'), TestExperiment.control);
        expect(
            flag.parseValue(TestExperiment.variantB), TestExperiment.variantB);
        expect(flag.parseValue(null), TestExperiment.control);
      });
      test('should handle case-sensitive parsing correctly', () {
        final flag = EnumFlag<TestExperiment>(
          provider: provider,
          key: 'experiment',
          defaultValue: TestExperiment.control,
          values: TestExperiment.values,
        );
        expect(flag.parseValue('variantA'), TestExperiment.variantA);
        expect(flag.parseValue('control'), TestExperiment.control);
      });
      test('should handle empty values list', () {
        final flag = EnumFlag<TestStatus>(
          provider: provider,
          key: 'test_flag',
          defaultValue: TestStatus.pending,
          values: [],
        );
        expect(flag.parseValue('active'), equals(TestStatus.pending));
        expect(flag.isValidValue('active'), isFalse);
      });
      test('should handle enum parsing with exception in firstWhere', () {
        final flag = EnumFlag<TestStatus>(
          provider: provider,
          key: 'test_flag',
          defaultValue: TestStatus.pending,
          values: TestStatus.values,
        );
        expect(flag.parseValue('nonexistent_enum_value'),
            equals(TestStatus.pending));
        expect(flag.parseValue(123), equals(TestStatus.pending));
        expect(flag.parseValue([]), equals(TestStatus.pending));
      });
      test('should handle direct enum value assignment', () {
        final flag = EnumFlag<TestStatus>(
          provider: provider,
          key: 'test_flag',
          defaultValue: TestStatus.pending,
          values: TestStatus.values,
        );
        expect(flag.parseValue(TestStatus.completed),
            equals(TestStatus.completed));
        expect(flag.isValidValue('completed'), isTrue);
      });
      test('should handle dispose method', () {
        final flag = EnumFlag<Priority>(
          provider: provider,
          key: 'enum_flag',
          defaultValue: Priority.medium,
          values: Priority.values,
        );
        expect(() => flag.dispose(), returnsNormally);
        expect(() => flag.dispose(), returnsNormally);
      });

      test('should test validation edge cases', () {
        final flag = EnumFlag<Priority>(
          provider: provider,
          key: 'enum_flag',
          defaultValue: Priority.medium,
          values: Priority.values,
        );
        expect(flag.isValidValue('low'), isTrue);
        expect(flag.isValidValue('medium'), isTrue);
        expect(flag.isValidValue('high'), isTrue);
        expect(flag.isValidValue('invalid'), isFalse);
        expect(flag.isValidValue(''), isFalse);
        expect(flag.isValidValue(null), isFalse);
        expect(flag.isValidValue(123), isFalse);
        expect(flag.isValidValue(true), isFalse);
        expect(flag.isValidValue([]), isFalse);
        expect(flag.isValidValue({}), isFalse);
      });
      test('should test parseValue edge cases', () {
        final flag = EnumFlag<Priority>(
          provider: provider,
          key: 'enum_flag',
          defaultValue: Priority.medium,
          values: Priority.values,
        );
        expect(flag.parseValue(Priority.high), equals(Priority.high));
        expect(flag.parseValue(Priority.low), equals(Priority.low));
        expect(flag.parseValue(null), equals(Priority.medium));
        expect(flag.parseValue(123), equals(Priority.medium));
        expect(flag.parseValue(true), equals(Priority.medium));
        expect(flag.parseValue([]), equals(Priority.medium));
        expect(flag.parseValue({}), equals(Priority.medium));
        expect(flag.parseValue('invalid_priority'), equals(Priority.medium));
        expect(flag.parseValue('HIGH'), equals(Priority.medium));
        expect(flag.parseValue('Low'), equals(Priority.medium));
      });
    });
    group('6. Stream & Subscription Management', () {
      late EnhancedTestFlagProvider provider;
      setUp(() {
        provider = EnhancedTestFlagProvider();
      });
      tearDown(() {
        provider.dispose();
      });
      test('should test BooleanFlag changes stream', () async {
        final flag = BooleanFlag(
          provider: provider,
          key: 'bool_flag',
          defaultValue: false,
        );
        final receivedValues = <bool>[];
        final subscription = flag.changes.listen(receivedValues.add);
        provider.setFlag('bool_flag', true);
        await Future.delayed(const Duration(milliseconds: 10));
        provider.setFlag('bool_flag', false);
        await Future.delayed(const Duration(milliseconds: 10));
        expect(receivedValues, equals([true, false]));
        await subscription.cancel();
      });
      test('should test StringFlag changes stream', () async {
        final flag = StringFlag(
          provider: provider,
          key: 'string_flag',
          defaultValue: 'default',
        );
        final receivedValues = <String>[];
        final subscription = flag.changes.listen(receivedValues.add);
        provider.setFlag('string_flag', 'value1');
        await Future.delayed(const Duration(milliseconds: 10));
        provider.setFlag('string_flag', 'value2');
        await Future.delayed(const Duration(milliseconds: 10));
        expect(receivedValues, equals(['value1', 'value2']));
        await subscription.cancel();
      });
      test('should test NumberFlag changes stream', () async {
        final flag = NumberFlag(
          provider: provider,
          key: 'number_flag',
          defaultValue: 0.0,
        );
        final receivedValues = <double>[];
        final subscription = flag.changes.listen(receivedValues.add);
        provider.setFlag('number_flag', 1.5);
        await Future.delayed(const Duration(milliseconds: 10));
        provider.setFlag('number_flag', 2.5);
        await Future.delayed(const Duration(milliseconds: 10));
        expect(receivedValues, equals([1.5, 2.5]));
        await subscription.cancel();
      });
      test('should test JsonFlag changes stream', () async {
        final flag = JsonFlag<Map<String, dynamic>>(
          provider: provider,
          key: 'json_flag',
          defaultValue: {},
        );
        final receivedValues = <Map<String, dynamic>>[];
        final subscription = flag.changes.listen(receivedValues.add);
        provider.setFlag('json_flag', {'key1': 'value1'});
        await Future.delayed(const Duration(milliseconds: 10));
        provider.setFlag('json_flag', {'key2': 'value2'});
        await Future.delayed(const Duration(milliseconds: 10));
        expect(
            receivedValues,
            equals([
              {'key1': 'value1'},
              {'key2': 'value2'}
            ]));
        await subscription.cancel();
      });
      test('should test EnumFlag changes stream', () async {
        final flag = EnumFlag<Priority>(
          provider: provider,
          key: 'enum_flag',
          defaultValue: Priority.medium,
          values: Priority.values,
        );
        final receivedValues = <Priority>[];
        final subscription = flag.changes.listen(receivedValues.add);
        provider.setFlag('enum_flag', 'high');
        await Future.delayed(const Duration(milliseconds: 10));
        provider.setFlag('enum_flag', 'low');
        await Future.delayed(const Duration(milliseconds: 10));
        expect(receivedValues, equals([Priority.high, Priority.low]));
        await subscription.cancel();
      });
    });
    group('7. Error Handling and Provider Errors', () {
      late EnhancedTestFlagProvider provider;
      setUp(() {
        provider = EnhancedTestFlagProvider();
      });
      tearDown(() {
        provider.dispose();
      });
      test('should handle provider errors gracefully', () {
        final flag = BooleanFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: true,
        );
        provider.simulateErrors(true);
        expect(flag.value, equals(true));
      });
      test('should handle stream errors gracefully', () async {
        final flag = StringFlag(
          provider: provider,
          key: 'test_flag',
          defaultValue: 'default',
        );
        final values = <String>[];
        final errors = <dynamic>[];
        final subscription = flag.changes.listen(
          values.add,
          onError: errors.add,
        );
        provider.setFlag('test_flag', 'value1');
        await Future.delayed(const Duration(milliseconds: 10));
        provider.simulateErrors(true);
        provider.setFlag('test_flag', 'value2');
        await Future.delayed(const Duration(milliseconds: 10));
        expect(values, isNotEmpty);
        await subscription.cancel();
      });
    });
    group('8. Performance and Edge Cases', () {
      late EnhancedTestFlagProvider provider;
      setUp(() {
        provider = EnhancedTestFlagProvider();
      });
      tearDown(() {
        provider.dispose();
      });
      test('should handle rapid flag changes efficiently', () async {
        final flag = BooleanFlag(
          provider: provider,
          key: 'rapid_flag',
          defaultValue: false,
        );
        final values = <bool>[];
        final subscription = flag.changes.listen(values.add);
        for (int i = 0; i < 100; i++) {
          provider.setFlag('rapid_flag', i % 2 == 0);
        }
        await Future.delayed(const Duration(milliseconds: 50));
        expect(values.length, equals(100));
        await subscription.cancel();
      });
      test('should handle multiple subscribers efficiently', () async {
        final flag = StringFlag(
          provider: provider,
          key: 'multi_flag',
          defaultValue: 'default',
        );
        final values1 = <String>[];
        final values2 = <String>[];
        final values3 = <String>[];
        final sub1 = flag.changes.listen(values1.add);
        final sub2 = flag.changes.listen(values2.add);
        final sub3 = flag.changes.listen(values3.add);
        provider.setFlag('multi_flag', 'broadcast');
        await Future.delayed(const Duration(milliseconds: 10));
        expect(values1, equals(['broadcast']));
        expect(values2, equals(['broadcast']));
        expect(values3, equals(['broadcast']));
        await sub1.cancel();
        await sub2.cancel();
        await sub3.cancel();
      });
    });
  });
}
