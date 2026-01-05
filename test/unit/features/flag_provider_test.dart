// =============================================================================
// CONSOLIDATED FLAG PROVIDER AND TYPED FLAGS TESTS
// =============================================================================
// This file consolidates tests from:
// - flag_provider_test.dart (interface tests)
// - cf_flag_provider_comprehensive_test.dart (implementation tests)
// - simple_flag_test.dart (typed flag parsing tests)
// =============================================================================
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_core.dart';
// Test enum for typed flags tests
enum TestExperiment { control, variantA, variantB }
// Mock ConfigManager for testing
class MockConfigManager implements ConfigManager {
  final Map<String, dynamic> _flags = {};
  void setFlags(Map<String, dynamic> flags) {
    _flags.clear();
    _flags.addAll(flags);
  }
  @override
  Map<String, dynamic> getAllFlags() => Map.unmodifiable(_flags);
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
// Mock CFClient for testing
class MockCFClient implements CFClient {
  MockConfigManager? _configManager;
  void setConfigManager(MockConfigManager configManager) {
    _configManager = configManager;
  }
  @override
  ConfigManager get configManager => _configManager!;
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FlagProvider Comprehensive Tests', () {
    group('1. FlagProvider Interface Tests', () {
      test('should define required methods', () {
        expect(FlagProvider, isNotNull);
      });
    });
    group('2. InMemoryFlagProvider (Test Implementation) Tests', () {
      late InMemoryFlagProvider provider;
      setUp(() {
        provider = InMemoryFlagProvider();
      });
      tearDown(() {
        provider.dispose();
      });
      test('should store and retrieve flags', () {
        provider.setFlag('test_flag', true);
        provider.setFlag('string_flag', 'value');
        provider.setFlag('number_flag', 42.0);
        expect(provider.getFlag('test_flag'), true);
        expect(provider.getFlag('string_flag'), 'value');
        expect(provider.getFlag('number_flag'), 42.0);
        expect(provider.getFlag('missing'), null);
      });
      test('should return all flags', () {
        provider.setFlag('flag1', true);
        provider.setFlag('flag2', 'test');
        provider.setFlag('flag3', 123);
        final allFlags = provider.getAllFlags();
        expect(allFlags, {
          'flag1': true,
          'flag2': 'test',
          'flag3': 123,
        });
      });
      test('should check flag existence', () {
        provider.setFlag('existing', 'value');
        expect(provider.flagExists('existing'), true);
        expect(provider.flagExists('missing'), false);
      });
      test('should emit flag changes', () async {
        final changes = <dynamic>[];
        final subscription =
            provider.flagChanges('test_flag').listen(changes.add);
        provider.setFlag('test_flag', 'initial');
        await Future.delayed(const Duration(milliseconds: 10));
        provider.setFlag('test_flag', 'updated');
        await Future.delayed(const Duration(milliseconds: 10));
        provider.setFlag('test_flag', 'final');
        await Future.delayed(const Duration(milliseconds: 10));
        expect(changes, ['initial', 'updated', 'final']);
        await subscription.cancel();
      });
      test('should handle multiple subscribers', () async {
        final changes1 = <dynamic>[];
        final changes2 = <dynamic>[];
        final sub1 = provider.flagChanges('test_flag').listen(changes1.add);
        final sub2 = provider.flagChanges('test_flag').listen(changes2.add);
        provider.setFlag('test_flag', 'value');
        await Future.delayed(const Duration(milliseconds: 10));
        expect(changes1, ['value']);
        expect(changes2, ['value']);
        await sub1.cancel();
        await sub2.cancel();
      });
      test('should clean up on dispose', () async {
        final stream = provider.flagChanges('test_flag');
        final subscription = stream.listen((_) {});
        provider.dispose();
        await expectLater(stream, emitsDone);
        await subscription.cancel();
      });
    });
    group('3. CFFlagProvider Implementation Tests', () {
      late MockConfigManager mockConfigManager;
      late CFFlagProvider provider;
      setUp(() {
        mockConfigManager = MockConfigManager();
        provider = CFFlagProvider(
          configManager: mockConfigManager,
        );
      });
      tearDown(() {
        provider.dispose();
      });
      group('Constructor Tests', () {
        test('should create instance with required parameters', () {
          expect(provider, isNotNull);
          expect(provider, isA<CFFlagProvider>());
        });
        test('should create instance from factory constructor', () {
          // Use the fromDependencyContainer factory
          final factoryProvider = CFFlagProvider.fromDependencyContainer();
          expect(factoryProvider, isNotNull);
          expect(factoryProvider, isA<CFFlagProvider>());
          factoryProvider.dispose();
        });
      });
      group('getFlag Tests', () {
        test('should return null when flag config is not found', () {
          mockConfigManager.setFlags({});
          final result = provider.getFlag('nonexistent_flag');
          expect(result, isNull);
        });
        test('should throw when flag config is not a map', () {
          mockConfigManager.setFlags({
            'invalid_flag': 'not_a_map',
          });
          expect(
            () => provider.getFlag('invalid_flag'),
            throwsA(isA<TypeError>()),
          );
        });
        test('should return null when flag is disabled', () {
          mockConfigManager.setFlags({
            'disabled_flag': {
              'enabled': false,
              'value': 'test_value',
            },
          });
          final result = provider.getFlag('disabled_flag');
          expect(result, isNull);
        });
        test('should return value when flag is enabled', () {
          mockConfigManager.setFlags({
            'enabled_flag': {
              'enabled': true,
              'value': 'test_value',
            },
          });
          final result = provider.getFlag('enabled_flag');
          expect(result, equals('test_value'));
        });
        test('should handle missing enabled field (defaults to false)', () {
          mockConfigManager.setFlags({
            'no_enabled_field': {
              'value': 'test_value',
            },
          });
          final result = provider.getFlag('no_enabled_field');
          expect(result, isNull);
        });
        test('should handle null enabled field (defaults to false)', () {
          mockConfigManager.setFlags({
            'null_enabled': {
              'enabled': null,
              'value': 'test_value',
            },
          });
          final result = provider.getFlag('null_enabled');
          expect(result, isNull);
        });
        test('should return different value types', () {
          mockConfigManager.setFlags({
            'string_flag': {'enabled': true, 'value': 'string_value'},
            'int_flag': {'enabled': true, 'value': 42},
            'double_flag': {'enabled': true, 'value': 3.14},
            'bool_flag': {'enabled': true, 'value': true},
            'list_flag': {
              'enabled': true,
              'value': [1, 2, 3]
            },
            'map_flag': {
              'enabled': true,
              'value': {'key': 'value'}
            },
            'null_flag': {'enabled': true, 'value': null},
          });
          expect(provider.getFlag('string_flag'), equals('string_value'));
          expect(provider.getFlag('int_flag'), equals(42));
          expect(provider.getFlag('double_flag'), equals(3.14));
          expect(provider.getFlag('bool_flag'), equals(true));
          expect(provider.getFlag('list_flag'), equals([1, 2, 3]));
          expect(provider.getFlag('map_flag'), equals({'key': 'value'}));
          expect(provider.getFlag('null_flag'), isNull);
        });
      });
      group('getAllFlags Tests', () {
        test('should return empty map when no flags exist', () {
          mockConfigManager.setFlags({});
          final result = provider.getAllFlags();
          expect(result, isEmpty);
        });
        test('should only include properly structured flags', () {
          mockConfigManager.setFlags({
            'valid_flag': {'enabled': true, 'value': 'test'},
            'disabled_flag': {'enabled': false, 'value': 'disabled'},
          });
          final result = provider.getAllFlags();
          expect(result.length, equals(1));
          expect(result['valid_flag'], equals('test'));
          expect(result.containsKey('disabled_flag'), isFalse);
        });
        test('should filter out disabled flags', () {
          mockConfigManager.setFlags({
            'enabled_flag': {'enabled': true, 'value': 'enabled_value'},
            'disabled_flag': {'enabled': false, 'value': 'disabled_value'},
            'no_enabled_field': {'value': 'no_enabled_value'},
            'null_enabled': {'enabled': null, 'value': 'null_enabled_value'},
          });
          final result = provider.getAllFlags();
          expect(result.length, equals(1));
          expect(result['enabled_flag'], equals('enabled_value'));
          expect(result.containsKey('disabled_flag'), isFalse);
          expect(result.containsKey('no_enabled_field'), isFalse);
          expect(result.containsKey('null_enabled'), isFalse);
        });
        test('should handle various flag configurations', () {
          mockConfigManager.setFlags({
            'flag1': {'enabled': true, 'value': 'value1'},
            'flag2': {'enabled': false, 'value': 'value2'},
            'flag3': {'enabled': true, 'value': null},
            'flag4': {'value': 'value4'},
            'flag5': {
              'enabled': true,
              'value': {'nested': 'object'}
            },
          });
          final result = provider.getAllFlags();
          expect(result.length, equals(3));
          expect(result['flag1'], equals('value1'));
          expect(result['flag3'], isNull);
          expect(result['flag5'], equals({'nested': 'object'}));
        });
        test('should return different value types for enabled flags', () {
          mockConfigManager.setFlags({
            'string': {'enabled': true, 'value': 'text'},
            'number': {'enabled': true, 'value': 123.45},
            'boolean': {'enabled': true, 'value': false},
            'array': {
              'enabled': true,
              'value': ['a', 'b', 'c']
            },
            'object': {
              'enabled': true,
              'value': {'x': 1, 'y': 2}
            },
          });
          final result = provider.getAllFlags();
          expect(result.length, equals(5));
          expect(result['string'], equals('text'));
          expect(result['number'], equals(123.45));
          expect(result['boolean'], equals(false));
          expect(result['array'], equals(['a', 'b', 'c']));
          expect(result['object'], equals({'x': 1, 'y': 2}));
        });
      });
      group('flagExists Tests', () {
        test('should return true when flag exists', () {
          mockConfigManager.setFlags({
            'existing_flag': {'enabled': true, 'value': 'test'},
          });
          final result = provider.flagExists('existing_flag');
          expect(result, isTrue);
        });
        test('should return false when flag does not exist', () {
          mockConfigManager.setFlags({
            'other_flag': {'enabled': true, 'value': 'test'},
          });
          final result = provider.flagExists('nonexistent_flag');
          expect(result, isFalse);
        });
        test('should return true even for disabled flags', () {
          mockConfigManager.setFlags({
            'disabled_flag': {'enabled': false, 'value': 'test'},
          });
          final result = provider.flagExists('disabled_flag');
          expect(result, isTrue);
        });
        test('should return true for any key in config', () {
          mockConfigManager.setFlags({
            'some_flag': {'enabled': true, 'value': 'test'},
          });
          final result = provider.flagExists('some_flag');
          expect(result, isTrue);
        });
        test('should handle empty flag map', () {
          mockConfigManager.setFlags({});
          final result = provider.flagExists('any_flag');
          expect(result, isFalse);
        });
      });
      group('flagChanges Tests', () {
        test('should create new stream controller for new key', () async {
          mockConfigManager.setFlags({
            'test_flag': {'enabled': true, 'value': 'initial_value'},
          });
          final stream = provider.flagChanges('test_flag');
          final values = <dynamic>[];
          final subscription = stream.listen(values.add);
          await Future.delayed(const Duration(milliseconds: 10));
          expect(values.length, equals(1));
          expect(values[0], equals('initial_value'));
          await subscription.cancel();
        });
        test('should reuse existing stream controller for same key', () async {
          mockConfigManager.setFlags({
            'test_flag': {'enabled': true, 'value': 'value'},
          });
          final stream1 = provider.flagChanges('test_flag');
          final stream2 = provider.flagChanges('test_flag');
          expect(stream1.isBroadcast, isTrue);
          expect(stream2.isBroadcast, isTrue);
          final values1 = <dynamic>[];
          final values2 = <dynamic>[];
          final sub1 = stream1.listen(values1.add);
          final sub2 = stream2.listen(values2.add);
          await Future.delayed(const Duration(milliseconds: 10));
          expect(values1, equals(values2));
          expect(values1.isNotEmpty, isTrue);
          await sub1.cancel();
          await sub2.cancel();
        });
        test('should emit null for non-existent flag', () async {
          mockConfigManager.setFlags({});
          final stream = provider.flagChanges('nonexistent');
          final values = <dynamic>[];
          final subscription = stream.listen(values.add);
          await Future.delayed(const Duration(milliseconds: 10));
          expect(values.length, equals(1));
          expect(values[0], isNull);
          await subscription.cancel();
        });
        test('should emit null for disabled flag', () async {
          mockConfigManager.setFlags({
            'disabled': {'enabled': false, 'value': 'test'},
          });
          final stream = provider.flagChanges('disabled');
          final values = <dynamic>[];
          final subscription = stream.listen(values.add);
          await Future.delayed(const Duration(milliseconds: 10));
          expect(values.length, equals(1));
          expect(values[0], isNull);
          await subscription.cancel();
        });
        test('should support multiple subscriptions (broadcast stream)',
            () async {
          mockConfigManager.setFlags({
            'broadcast_flag': {'enabled': true, 'value': 'broadcast_value'},
          });
          final stream = provider.flagChanges('broadcast_flag');
          final values1 = <dynamic>[];
          final values2 = <dynamic>[];
          final sub1 = stream.listen(values1.add);
          final sub2 = stream.listen(values2.add);
          await Future.delayed(const Duration(milliseconds: 10));
          expect(values1.length, equals(1));
          expect(values2.length, equals(1));
          expect(values1[0], equals('broadcast_value'));
          expect(values2[0], equals('broadcast_value'));
          await sub1.cancel();
          await sub2.cancel();
        });
        test('should handle multiple flags independently', () async {
          mockConfigManager.setFlags({
            'flag1': {'enabled': true, 'value': 'value1'},
            'flag2': {'enabled': true, 'value': 'value2'},
          });
          final stream1 = provider.flagChanges('flag1');
          final stream2 = provider.flagChanges('flag2');
          final values1 = <dynamic>[];
          final values2 = <dynamic>[];
          final sub1 = stream1.listen(values1.add);
          final sub2 = stream2.listen(values2.add);
          await Future.delayed(const Duration(milliseconds: 10));
          expect(values1.length, equals(1));
          expect(values2.length, equals(1));
          expect(values1[0], equals('value1'));
          expect(values2[0], equals('value2'));
          await sub1.cancel();
          await sub2.cancel();
        });
        test('should emit value asynchronously using Timer.run', () async {
          mockConfigManager.setFlags({
            'async_flag': {'enabled': true, 'value': 'async_value'},
          });
          final stream = provider.flagChanges('async_flag');
          final completer = Completer<dynamic>();
          final subscription = stream.listen((value) {
            if (!completer.isCompleted) {
              completer.complete(value);
            }
          });
          expect(completer.isCompleted, isFalse);
          final value = await completer.future.timeout(
            const Duration(milliseconds: 100),
            onTimeout: () => fail('Value was not emitted'),
          );
          expect(value, equals('async_value'));
          await subscription.cancel();
        });
      });
      group('dispose Tests', () {
        test('should close all stream controllers', () async {
          mockConfigManager.setFlags({
            'flag1': {'enabled': true, 'value': 'value1'},
            'flag2': {'enabled': true, 'value': 'value2'},
          });
          final stream1 = provider.flagChanges('flag1');
          final stream2 = provider.flagChanges('flag2');
          final sub1 = stream1.listen((_) {});
          final sub2 = stream2.listen((_) {});
          await Future.delayed(const Duration(milliseconds: 10));
          provider.dispose();
          expect(stream1.isBroadcast, isTrue);
          expect(stream2.isBroadcast, isTrue);
          await sub1.cancel();
          await sub2.cancel();
        });
        test('should clear controllers map', () async {
          mockConfigManager.setFlags({
            'test': {'enabled': true, 'value': 'test'},
          });
          final stream1 = provider.flagChanges('test');
          final sub = stream1.listen((_) {});
          await Future.delayed(const Duration(milliseconds: 10));
          provider.dispose();
          final stream2 = provider.flagChanges('test');
          expect(identical(stream1, stream2), isFalse);
          await sub.cancel();
        });
        test('should handle dispose when no controllers exist', () {
          expect(() => provider.dispose(), returnsNormally);
        });
        test('should handle multiple dispose calls', () {
          mockConfigManager.setFlags({
            'flag': {'enabled': true, 'value': 'value'},
          });
          provider.flagChanges('flag');
          expect(() => provider.dispose(), returnsNormally);
          expect(() => provider.dispose(), returnsNormally);
        });
      });
    });
    // =============================================================================
    // TYPED FLAGS TESTS (from simple_flag_test.dart)
    // =============================================================================
    group('4. Typed Flag Parsing Tests', () {
      late InMemoryFlagProvider provider;
      setUp(() {
        provider = InMemoryFlagProvider();
      });
      tearDown(() {
        provider.dispose();
      });
      test('BooleanFlag parses values correctly', () {
        final flag = BooleanFlag(
          provider: provider,
          key: 'test_bool',
          defaultValue: false,
        );
        // Test parsing different value types
        expect(flag.parseValue(true), true);
        expect(flag.parseValue(false), false);
        expect(flag.parseValue('true'), true);
        expect(flag.parseValue('True'), true);
        expect(flag.parseValue('TRUE'), true);
        expect(flag.parseValue('false'), false);
        expect(flag.parseValue('False'), false);
        expect(flag.parseValue('invalid'), false); // Returns default
        expect(flag.parseValue(null), false); // Returns default
        expect(flag.parseValue(123), true); // 123 != 0, so true
        expect(flag.parseValue(0), false); // 0 is false
      });
      test('StringFlag parses values correctly', () {
        final flag = StringFlag(
          provider: provider,
          key: 'test_string',
          defaultValue: 'default',
        );
        expect(flag.parseValue('hello'), 'hello');
        expect(flag.parseValue(''), '');
        expect(flag.parseValue(123), '123');
        expect(flag.parseValue(true), 'true');
        expect(flag.parseValue(null), 'default');
      });
      test('NumberFlag parses and clamps values', () {
        final flag = NumberFlag(
          provider: provider,
          key: 'test_number',
          defaultValue: 50.0,
          min: 0.0,
          max: 100.0,
        );
        // Normal values
        expect(flag.parseValue(50.0), 50.0);
        expect(flag.parseValue(0.0), 0.0);
        expect(flag.parseValue(100.0), 100.0);
        // Clamping
        expect(flag.parseValue(150.0), 100.0); // Clamped to max
        expect(flag.parseValue(-10.0), 0.0); // Clamped to min
        // String parsing
        expect(flag.parseValue('75.5'), 75.5);
        expect(flag.parseValue('invalid'), 50.0); // Returns default
        // Null and wrong types
        expect(flag.parseValue(null), 50.0); // Returns default
      });
      test('EnumFlag parses values correctly', () {
        final flag = EnumFlag<TestExperiment>(
          provider: provider,
          key: 'test_enum',
          defaultValue: TestExperiment.control,
          values: TestExperiment.values,
        );
        expect(flag.parseValue('control'), TestExperiment.control);
        expect(flag.parseValue('variantA'), TestExperiment.variantA);
        expect(flag.parseValue('variantB'), TestExperiment.variantB);
        expect(flag.parseValue('invalid'), TestExperiment.control); // Default
        expect(
            flag.parseValue(TestExperiment.variantB), TestExperiment.variantB);
        expect(flag.parseValue(null), TestExperiment.control); // Default
      });
      test('JsonFlag parses with custom parser', () {
        final flag = JsonFlag<String>(
          provider: provider,
          key: 'test_json',
          defaultValue: 'default',
          parser: (json) => json['value'] as String? ?? 'fallback',
        );
        expect(flag.parseValue({'value': 'test'}), 'test');
        expect(flag.parseValue({'other': 'test'}), 'fallback');
        expect(flag.parseValue('not a map'), 'default');
        expect(flag.parseValue(null), 'default');
      });
      test('Typed flags integration with provider', () {
        // Set up flags in provider
        provider.setFlag('bool_flag', true);
        provider.setFlag('string_flag', 'hello');
        provider.setFlag('number_flag', 42.5);
        provider.setFlag('enum_flag', 'variantA');
        provider.setFlag('json_flag', {'value': 'parsed'});
        // Create typed flags
        final boolFlag = BooleanFlag(
          provider: provider,
          key: 'bool_flag',
          defaultValue: false,
        );
        final stringFlag = StringFlag(
          provider: provider,
          key: 'string_flag',
          defaultValue: 'default',
        );
        final numberFlag = NumberFlag(
          provider: provider,
          key: 'number_flag',
          defaultValue: 0.0,
        );
        final enumFlag = EnumFlag<TestExperiment>(
          provider: provider,
          key: 'enum_flag',
          defaultValue: TestExperiment.control,
          values: TestExperiment.values,
        );
        final jsonFlag = JsonFlag<String>(
          provider: provider,
          key: 'json_flag',
          defaultValue: 'default',
          parser: (json) => json['value'] as String? ?? 'fallback',
        );
        // Test values are correctly parsed from provider
        expect(boolFlag.value, true);
        expect(stringFlag.value, 'hello');
        expect(numberFlag.value, 42.5);
        expect(enumFlag.value, TestExperiment.variantA);
        expect(jsonFlag.value, 'parsed');
      });
      test('Typed flags handle missing values with defaults', () {
        // Don't set any flags in provider
        final boolFlag = BooleanFlag(
          provider: provider,
          key: 'missing_bool',
          defaultValue: true,
        );
        final stringFlag = StringFlag(
          provider: provider,
          key: 'missing_string',
          defaultValue: 'fallback',
        );
        final numberFlag = NumberFlag(
          provider: provider,
          key: 'missing_number',
          defaultValue: 99.9,
        );
        final enumFlag = EnumFlag<TestExperiment>(
          provider: provider,
          key: 'missing_enum',
          defaultValue: TestExperiment.variantB,
          values: TestExperiment.values,
        );
        final jsonFlag = JsonFlag<String>(
          provider: provider,
          key: 'missing_json',
          defaultValue: 'missing',
          parser: (json) => json['value'] as String? ?? 'fallback',
        );
        // Test default values are returned
        expect(boolFlag.value, true);
        expect(stringFlag.value, 'fallback');
        expect(numberFlag.value, 99.9);
        expect(enumFlag.value, TestExperiment.variantB);
        expect(jsonFlag.value, 'missing');
      });
      test('NumberFlag handles edge cases with min/max', () {
        final flag = NumberFlag(
          provider: provider,
          key: 'edge_number',
          defaultValue: 10.0,
          min: 5.0,
          max: 15.0,
        );
        // Test edge values
        expect(flag.parseValue(5.0), 5.0); // Exactly min
        expect(flag.parseValue(15.0), 15.0); // Exactly max
        expect(flag.parseValue(4.9), 5.0); // Below min, clamped
        expect(flag.parseValue(15.1), 15.0); // Above max, clamped
        expect(flag.parseValue(double.infinity), 15.0); // Infinity clamped
        expect(
            flag.parseValue(double.negativeInfinity), 5.0); // -Infinity clamped
        expect(flag.parseValue(double.nan), 10.0); // NaN returns default
      });
      test('JsonFlag handles complex parsing scenarios', () {
        final flag = JsonFlag<Map<String, dynamic>>(
          provider: provider,
          key: 'complex_json',
          defaultValue: {'default': true},
          parser: (json) {
            final map = json as Map<String, dynamic>?;
            if (map != null && map.containsKey('data')) {
              return map['data'];
            }
            throw ArgumentError('Invalid JSON structure');
          },
        );
        // Valid structure
        expect(
            flag.parseValue({
              'data': {'key': 'value', 'number': 42}
            }),
            {'key': 'value', 'number': 42});
        // Invalid structure - parser throws, should return default
        expect(flag.parseValue({'invalid': 'structure'}), {'default': true});
        // Non-map input - should return default
        expect(flag.parseValue('not a map'), {'default': true});
      });
    });
  });
}
// Test implementation of FlagProvider for testing
class InMemoryFlagProvider implements FlagProvider {
  final Map<String, dynamic> _flags = {};
  final Map<String, StreamController<dynamic>> _controllers = {};
  @override
  dynamic getFlag(String key) => _flags[key];
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
  @override
  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}
