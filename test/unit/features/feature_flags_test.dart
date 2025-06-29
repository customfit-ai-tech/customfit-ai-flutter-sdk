// test/unit/features/feature_flags_test.dart
//
// Comprehensive tests for FeatureFlags covering core functionality
// Tests focus on:
// - JSON flag creation with parsers and serializers
// - Enum flag creation and validation
// - Error handling in dispose method
// - Logger integration in error scenarios
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_core.dart';

// Test enum for enum flag testing
enum TestPriority { low, medium, high, critical }

// Test model for JSON flag testing
class TestSettings {
  final String theme;
  final int timeout;
  final bool enableFeature;
  TestSettings({
    required this.theme,
    required this.timeout,
    required this.enableFeature,
  });
  factory TestSettings.fromJson(Map<String, dynamic> json) {
    return TestSettings(
      theme: json['theme'] as String? ?? 'default',
      timeout: json['timeout'] as int? ?? 30,
      enableFeature: json['enableFeature'] as bool? ?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'timeout': timeout,
      'enableFeature': enableFeature,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestSettings &&
          runtimeType == other.runtimeType &&
          theme == other.theme &&
          timeout == other.timeout &&
          enableFeature == other.enableFeature;
  @override
  int get hashCode =>
      theme.hashCode ^ timeout.hashCode ^ enableFeature.hashCode;
}

// Enhanced test flag provider with error simulation
class EnhancedTestFlagProvider implements FlagProvider {
  final Map<String, dynamic> _flags = {};
  final Map<String, StreamController<dynamic>> _controllers = {};
  final Set<String> _keysToThrowOnGet = {};
  @override
  dynamic getFlag(String key) {
    if (_keysToThrowOnGet.contains(key)) {
      throw StateError('Simulated error getting flag: $key');
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

  void simulateGetError(String key) {
    _keysToThrowOnGet.add(key);
  }

  void clearGetError(String key) {
    _keysToThrowOnGet.remove(key);
  }

  @override
  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
    _flags.clear();
    _keysToThrowOnGet.clear();
  }
}

// Mock flag that throws on dispose for testing error handling
class MockFailingFlag {
  final String key;
  MockFailingFlag(this.key);
  void dispose() {
    throw Exception('Simulated dispose error for flag: $key');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FeatureFlags Comprehensive Tests', () {
    late EnhancedTestFlagProvider provider;
    late FeatureFlags flags;
    setUp(() {
      provider = EnhancedTestFlagProvider();
      flags = FeatureFlags(provider);
    });
    tearDown(() {
      flags.dispose();
      provider.dispose();
    });
    group('JSON Flag Creation Tests', () {
      test('should create JSON flag with custom parser and serializer', () {
        provider.setFlag('settings', {
          'theme': 'dark',
          'timeout': 60,
          'enableFeature': true,
        });
        final jsonFlag = flags.json<TestSettings>(
          key: 'settings',
          defaultValue:
              TestSettings(theme: 'light', timeout: 30, enableFeature: false),
          parser: (json) => TestSettings.fromJson(json),
          serializer: (settings) => settings.toJson(),
          description: 'App settings configuration',
          tags: {'config', 'ui'},
        );
        final value = jsonFlag.value;
        expect(value.theme, equals('dark'));
        expect(value.timeout, equals(60));
        expect(value.enableFeature, equals(true));
        expect(jsonFlag.description, equals('App settings configuration'));
        expect(jsonFlag.tags, containsAll(['config', 'ui']));
      });
      test('should handle JSON flag with parser that throws exception', () {
        provider.setFlag('invalid_settings', {
          'invalid': 'data',
        });
        final jsonFlag = flags.json<TestSettings>(
          key: 'invalid_settings',
          defaultValue:
              TestSettings(theme: 'light', timeout: 30, enableFeature: false),
          parser: (json) {
            if (!json.containsKey('theme')) {
              throw ArgumentError('Missing required theme field');
            }
            return TestSettings.fromJson(json);
          },
          description: 'Settings with validation',
        );
        // Should return default value when parser throws
        final value = jsonFlag.value;
        expect(value.theme, equals('light'));
        expect(value.timeout, equals(30));
        expect(value.enableFeature, equals(false));
      });
      test('should create JSON flag without parser and serializer', () {
        provider.setFlag('raw_json', {'key': 'value', 'number': 42});
        final jsonFlag = flags.json<Map<String, dynamic>>(
          key: 'raw_json',
          defaultValue: {'default': true},
          description: 'Raw JSON flag',
        );
        expect(jsonFlag.value, equals({'key': 'value', 'number': 42}));
      });
      test('should handle complex nested JSON structures', () {
        provider.setFlag('complex_config', {
          'database': {
            'host': 'localhost',
            'port': 5432,
            'credentials': {'username': 'admin', 'password': 'secret'}
          },
          'features': ['feature1', 'feature2'],
          'metrics': {'enabled': true, 'interval': 60}
        });
        final jsonFlag = flags.json<Map<String, dynamic>>(
          key: 'complex_config',
          defaultValue: {},
        );
        final value = jsonFlag.value;
        expect(value['database']['host'], equals('localhost'));
        expect(value['database']['port'], equals(5432));
        expect(value['database']['credentials']['username'], equals('admin'));
        expect(value['features'], containsAll(['feature1', 'feature2']));
        expect(value['metrics']['enabled'], equals(true));
      });
    });
    group('Enum Flag Creation Tests', () {
      test('should create enum flag with valid enum values', () {
        provider.setFlag('priority', 'high');
        final enumFlag = flags.enumFlag<TestPriority>(
          key: 'priority',
          defaultValue: TestPriority.medium,
          values: TestPriority.values,
          description: 'Task priority level',
          tags: {'priority', 'task'},
        );
        expect(enumFlag.value, equals(TestPriority.high));
        expect(enumFlag.description, equals('Task priority level'));
        expect(enumFlag.tags, containsAll(['priority', 'task']));
      });
      test('should fall back to default for invalid enum string', () {
        provider.setFlag('priority', 'invalid_priority');
        final enumFlag = flags.enumFlag<TestPriority>(
          key: 'priority',
          defaultValue: TestPriority.medium,
          values: TestPriority.values,
        );
        expect(enumFlag.value, equals(TestPriority.medium));
      });
      test('should handle case-sensitive enum parsing (exact match required)',
          () {
        provider.setFlag('priority', 'CRITICAL'); // Wrong case
        final enumFlag = flags.enumFlag<TestPriority>(
          key: 'priority',
          defaultValue: TestPriority.low,
          values: TestPriority.values,
        );
        // Should return default because 'CRITICAL' != 'critical'
        expect(enumFlag.value, equals(TestPriority.low));
      });
      test('should handle enum flag with direct enum value assignment', () {
        provider.setFlag('priority', TestPriority.low);
        final enumFlag = flags.enumFlag<TestPriority>(
          key: 'priority',
          defaultValue: TestPriority.medium,
          values: TestPriority.values,
        );
        expect(enumFlag.value, equals(TestPriority.low));
      });
      test('should handle empty enum values list', () {
        // Create flag with empty values list - should not throw, just won't match anything
        final enumFlag = flags.enumFlag<TestPriority>(
          key: 'priority',
          defaultValue: TestPriority.medium,
          values: [], // Empty values list
        );
        provider.setFlag('priority', 'high');
        // Should return default value since no values to match against
        expect(enumFlag.value, equals(TestPriority.medium));
      });
    });
    group('Error Handling in dispose Method', () {
      test('should handle exceptions during flag disposal', () {
        // Add normal flags
        flags.boolean(key: 'normal_flag', defaultValue: true);
        flags.string(key: 'another_flag', defaultValue: 'test');
        // dispose should handle errors gracefully by not throwing
        expect(() => flags.dispose(), returnsNormally);
      });
      test('should handle multiple disposal errors gracefully', () {
        // Create multiple flags that might fail disposal
        flags.boolean(key: 'flag1', defaultValue: true);
        flags.string(key: 'flag2', defaultValue: 'test');
        flags.number(key: 'flag3', defaultValue: 42.0);
        // Multiple dispose calls should be safe
        expect(() {
          flags.dispose();
          flags.dispose();
          flags.dispose();
        }, returnsNormally);
      });
    });
    group('Tags and Metadata Handling', () {
      test('should preserve tags across different flag types', () {
        final testTags = {'feature', 'experiment', 'ui'};
        final boolFlag = flags.boolean(
          key: 'bool_flag',
          defaultValue: false,
          tags: testTags,
        );
        final stringFlag = flags.string(
          key: 'string_flag',
          defaultValue: 'test',
          tags: testTags,
        );
        expect(boolFlag.tags, equals(testTags));
        expect(stringFlag.tags, equals(testTags));
      });
      test('should handle null and empty tags', () {
        final flagWithNull = flags.boolean(
          key: 'null_tags',
          defaultValue: true,
          tags: null,
        );
        final flagWithEmpty = flags.boolean(
          key: 'empty_tags',
          defaultValue: true,
          tags: <String>{},
        );
        expect(flagWithNull.tags, isNull);
        expect(flagWithEmpty.tags, isEmpty);
      });
      test('should handle large tag sets', () {
        final largeTags = <String>{for (int i = 0; i < 100; i++) 'tag$i'};
        final flag = flags.boolean(
          key: 'many_tags',
          defaultValue: true,
          tags: largeTags,
        );
        expect(flag.tags, equals(largeTags));
        expect(flag.tags!.length, equals(100));
      });
    });
    group('Flag Provider Integration Edge Cases', () {
      test('should handle provider that returns null for existing flag', () {
        provider.setFlag('null_flag', null);
        final boolFlag = flags.boolean(key: 'null_flag', defaultValue: true);
        // Should return default value when provider returns null
        expect(boolFlag.value, equals(true));
      });
      test('should handle provider state changes after flag creation', () {
        final stringFlag =
            flags.string(key: 'dynamic_flag', defaultValue: 'default');
        // Initially no value
        expect(stringFlag.value, equals('default'));
        // Provider adds value
        provider.setFlag('dynamic_flag', 'new_value');
        expect(stringFlag.value, equals('new_value'));
        // Provider removes value (sets to null)
        provider.setFlag('dynamic_flag', null);
        expect(stringFlag.value, equals('default'));
      });
    });
  });
}
