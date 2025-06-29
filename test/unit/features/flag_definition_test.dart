import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/features/typed_flags.dart';
import 'package:customfit_ai_flutter_sdk/src/features/flag_provider.dart';
// Test enum for EnumFlag tests
enum TestTheme { light, dark, auto }
// Test flag provider
class TestFlagProvider implements FlagProvider {
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
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FlagDefinition', () {
    late TestFlagProvider provider;
    setUp(() {
      provider = TestFlagProvider();
    });
    tearDown(() {
      provider.dispose();
    });
    test('BooleanFlag validates and parses correctly', () {
      final flag = BooleanFlag(
        provider: provider,
        key: 'test_bool',
        defaultValue: false,
        description: 'Test boolean flag',
        tags: {'test', 'boolean'},
      );
      // Test metadata
      expect(flag.key, 'test_bool');
      expect(flag.defaultValue, false);
      expect(flag.description, 'Test boolean flag');
      expect(flag.tags, {'test', 'boolean'});
      // Test validation
      expect(flag.isValidValue(true), true);
      expect(flag.isValidValue(false), true);
      expect(flag.isValidValue('string'), false);
      expect(flag.isValidValue(123), false);
      expect(flag.isValidValue(null), false);
      // Test parsing
      expect(flag.parseValue(true), true);
      expect(flag.parseValue(false), false);
      expect(flag.parseValue('true'), true);
      expect(flag.parseValue('True'), true);
      expect(flag.parseValue('TRUE'), true);
      expect(flag.parseValue('false'), false);
      expect(flag.parseValue('False'), false);
      expect(flag.parseValue('invalid'), false); // Returns default
      expect(flag.parseValue(null), false); // Returns default
    });
    test('StringFlag validates and parses correctly', () {
      final flag = StringFlag(
        provider: provider,
        key: 'test_string',
        defaultValue: 'default',
        description: 'Test string flag',
      );
      // Test validation
      expect(flag.isValidValue('test'), true);
      expect(flag.isValidValue(''), true);
      expect(flag.isValidValue(123), false);
      expect(flag.isValidValue(true), false);
      expect(flag.isValidValue(null), false);
      // Test parsing
      expect(flag.parseValue('test'), 'test');
      expect(flag.parseValue(''), '');
      expect(flag.parseValue(123), '123');
      expect(flag.parseValue(true), 'true');
      expect(flag.parseValue(null), 'default');
    });
    test('NumberFlag validates and parses with constraints', () {
      final flag = NumberFlag(
        provider: provider,
        key: 'test_number',
        defaultValue: 50.0,
        min: 0.0,
        max: 100.0,
        description: 'Test number flag with constraints',
      );
      // Test validation
      expect(flag.isValidValue(50.0), true);
      expect(flag.isValidValue(0.0), true);
      expect(flag.isValidValue(100.0), true);
      expect(flag.isValidValue(-1.0), false); // Below min
      expect(flag.isValidValue(101.0), false); // Above max
      expect(flag.isValidValue('50'), false); // Wrong type
      expect(flag.isValidValue(null), false);
      // Test parsing with clamping
      expect(flag.parseValue(50.0), 50.0);
      expect(flag.parseValue(150.0), 100.0); // Clamped to max
      expect(flag.parseValue(-10.0), 0.0); // Clamped to min
      expect(flag.parseValue('75.5'), 75.5); // String parsing
      expect(flag.parseValue('invalid'), 50.0); // Returns default
      expect(flag.parseValue(null), 50.0); // Returns default
    });
    test('NumberFlag without constraints', () {
      final flag = NumberFlag(
        provider: provider,
        key: 'test_number_no_constraints',
        defaultValue: 0.0,
      );
      // Test validation without constraints
      expect(flag.isValidValue(999999.0), true);
      expect(flag.isValidValue(-999999.0), true);
      // Test parsing without constraints
      expect(flag.parseValue(999999.0), 999999.0);
      expect(flag.parseValue(-999999.0), -999999.0);
    });
    test('EnumFlag validates and parses correctly', () {
      final flag = EnumFlag<TestTheme>(
        provider: provider,
        key: 'test_enum',
        defaultValue: TestTheme.light,
        values: TestTheme.values,
        description: 'Test enum flag',
      );
      // Test validation
      expect(flag.isValidValue('light'), true);
      expect(flag.isValidValue('dark'), true);
      expect(flag.isValidValue('auto'), true);
      expect(flag.isValidValue('invalid'), false);
      expect(flag.isValidValue(123), false);
      expect(flag.isValidValue(null), false);
      // Test parsing
      expect(flag.parseValue('light'), TestTheme.light);
      expect(flag.parseValue('dark'), TestTheme.dark);
      expect(flag.parseValue('auto'), TestTheme.auto);
      expect(flag.parseValue('invalid'), TestTheme.light); // Returns default
      expect(flag.parseValue(TestTheme.dark), TestTheme.dark); // Direct enum
      expect(flag.parseValue(null), TestTheme.light); // Returns default
    });
    test('JsonFlag validates and parses correctly', () {
      final flag = JsonFlag<Map<String, dynamic>>(
        provider: provider,
        key: 'test_json',
        defaultValue: {'default': true},
        description: 'Test JSON flag',
      );
      // Test validation with properly typed maps
      expect(flag.isValidValue(<String, dynamic>{'key': 'value'}), true);
      expect(flag.isValidValue(<String, dynamic>{}), true);
      expect(flag.isValidValue('string'), false);
      expect(flag.isValidValue(123), false);
      expect(flag.isValidValue(null), false);
      // Test parsing with properly typed maps
      expect(
          flag.parseValue(<String, dynamic>{'key': 'value'}), {'key': 'value'});
      expect(flag.parseValue(<String, dynamic>{}), {});
      expect(flag.parseValue('invalid'), {'default': true}); // Returns default
      expect(flag.parseValue(null), {'default': true}); // Returns default
    });
    test('JsonFlag with custom parser', () {
      final flag = JsonFlag<String>(
        provider: provider,
        key: 'test_json_custom',
        defaultValue: 'default',
        parser: (json) => json['value'] as String,
        serializer: (value) => {'value': value},
      );
      // Test parsing with custom parser
      expect(flag.parseValue({'value': 'test'}), 'test');
      expect(flag.parseValue({'other': 'test'}), 'default'); // Parser fails
      expect(flag.parseValue(null), 'default');
    });
  });
}
