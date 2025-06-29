import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/json_parser.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('JsonParser Unit Tests', () {
    setUp(() {
      // Clear cache before each test
    SharedPreferences.setMockInitialValues({});
      JsonParser.clearCache();
    });
    tearDown(() {
      // Clean up after each test
    PreferencesService.reset();
      JsonParser.clearCache();
    });
    group('Object Parsing', () {
      test('should parse simple JSON object', () {
        const json = '{"name": "John", "age": 30}';
        final result = JsonParser.parseObject(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull()!;
        expect(data['name'], equals('John'));
        expect(data['age'], equals(30));
      });
      test('should handle empty JSON object', () {
        const json = '{}';
        final result = JsonParser.parseObject(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull()!;
        expect(data.isEmpty, isTrue);
      });
      test('should handle nested objects', () {
        const json = '{"user": {"id": 1, "profile": {"name": "John"}}}';
        final result = JsonParser.parseObject(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull()!;
        expect(data['user']['id'], equals(1));
        expect(data['user']['profile']['name'], equals('John'));
      });
      test('should reject empty string', () {
        final result = JsonParser.parseObject('');
        expect(!result.isSuccess, isTrue);
        expect(result.getErrorMessage(), contains('empty'));
      });
      test('should reject non-object JSON', () {
        const json = '[1, 2, 3]';
        final result = JsonParser.parseObject(json);
        expect(!result.isSuccess, isTrue);
        expect(result.getErrorMessage(), contains('not an object'));
      });
      test('should handle malformed JSON', () {
        const json = '{"invalid": json}';
        final result = JsonParser.parseObject(json);
        expect(!result.isSuccess, isTrue);
        expect(result.getErrorMessage(), contains('JSON'));
      });
      test('should use cache when provided', () {
        const json = '{"cached": true}';
        const cacheKey = 'test-cache';
        // First parse
        var result = JsonParser.parseObject(json, cacheKey: cacheKey);
        expect(result.isSuccess, isTrue);
        // Second parse should use cache
        result = JsonParser.parseObject(json, cacheKey: cacheKey);
        expect(result.isSuccess, isTrue);
        final stats = JsonParser.getCacheStats();
        expect(stats['size'], greaterThan(0));
      });
      test('should respect max depth limit', () {
        // Create deeply nested object
        var json = '{';
        for (int i = 0; i < 25; i++) {
          json += '"level$i":{';
        }
        json += '"value":"deep"';
        for (int i = 0; i < 26; i++) {
          json += '}';
        }
        final result = JsonParser.parseObject(json, maxDepth: 20);
        expect(!result.isSuccess, isTrue);
        expect(result.getErrorMessage(), contains('depth'));
      });
      test('should handle custom max depth', () {
        const json = '{"a":{"b":{"c":"value"}}}';
        var result = JsonParser.parseObject(json, maxDepth: 2);
        expect(!result.isSuccess, isTrue);
        result = JsonParser.parseObject(json, maxDepth: 5);
        expect(result.isSuccess, isTrue);
      });
    });
    group('Array Parsing', () {
      test('should parse simple JSON array', () {
        const json = '[1, 2, 3, 4, 5]';
        final result = JsonParser.parseArray(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull()!;
        expect(data.length, equals(5));
        expect(data, equals([1, 2, 3, 4, 5]));
      });
      test('should handle empty array', () {
        const json = '[]';
        final result = JsonParser.parseArray(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull()!;
        expect(data.isEmpty, isTrue);
      });
      test('should parse mixed type array', () {
        const json = '[1, "text", true, null, {"key": "value"}]';
        final result = JsonParser.parseArray(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull()!;
        expect(data[0], equals(1));
        expect(data[1], equals('text'));
        expect(data[2], equals(true));
        expect(data[3], isNull);
        expect(data[4], isA<Map<String, dynamic>>());
      });
      test('should reject non-array JSON', () {
        const json = '{"key": "value"}';
        final result = JsonParser.parseArray(json);
        expect(!result.isSuccess, isTrue);
        expect(result.getErrorMessage(), contains('not an array'));
      });
      test('should handle nested arrays', () {
        const json = '[[1, 2], [3, 4], [5, 6]]';
        final result = JsonParser.parseArray(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull()!;
        expect(data[0], equals([1, 2]));
        expect(data[1], equals([3, 4]));
        expect(data[2], equals([5, 6]));
      });
      test('should use cache for arrays', () {
        const json = '[1, 2, 3]';
        const cacheKey = 'array-cache';
        var result = JsonParser.parseArray(json, cacheKey: cacheKey);
        expect(result.isSuccess, isTrue);
        result = JsonParser.parseArray(json, cacheKey: cacheKey);
        expect(result.isSuccess, isTrue);
        final stats = JsonParser.getCacheStats();
        expect(stats['size'], greaterThan(0));
      });
    });
    group('Auto-Type Detection', () {
      test('should detect and parse object', () {
        const json = '{"type": "object"}';
        final result = JsonParser.parseAny(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data, isA<Map<String, dynamic>>());
        expect(data['type'], equals('object'));
      });
      test('should detect and parse array', () {
        const json = '[1, 2, 3]';
        final result = JsonParser.parseAny(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data, isA<List<dynamic>>());
        expect(data.length, equals(3));
      });
      test('should detect and parse string', () {
        const json = '"Hello World"';
        final result = JsonParser.parseAny(json);
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals('Hello World'));
      });
      test('should detect and parse number', () {
        const json = '42.5';
        final result = JsonParser.parseAny(json);
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(42.5));
      });
      test('should detect and parse boolean', () {
        var result = JsonParser.parseAny('true');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(true));
        result = JsonParser.parseAny('false');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(false));
      });
      test('should detect and parse null', () {
        const json = 'null';
        final result = JsonParser.parseAny(json);
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), isNull);
      });
      test('should handle invalid JSON in parseAny', () {
        const json = '{invalid}';
        final result = JsonParser.parseAny(json);
        expect(!result.isSuccess, isTrue);
        expect(result.getErrorMessage(), contains('JSON'));
      });
    });
    group('JSON Serialization', () {
      test('should serialize simple object', () {
        final object = {'name': 'John', 'age': 30, 'active': true};
        final result = JsonParser.stringify(object);
        expect(result.isSuccess, isTrue);
        final json = result.getOrNull()!;
        expect(json, contains('"name":"John"'));
        expect(json, contains('"age":30'));
        expect(json, contains('"active":true'));
      });
      test('should serialize with pretty print', () {
        final object = {'name': 'John', 'age': 30};
        final result = JsonParser.stringify(object, prettyPrint: true);
        expect(result.isSuccess, isTrue);
        final json = result.getOrNull()!;
        expect(json, contains('\n'));
        expect(json, contains('  '));
      });
      test('should serialize arrays', () {
        final array = [1, 'text', true, null];
        final result = JsonParser.stringify(array);
        expect(result.isSuccess, isTrue);
        final json = result.getOrNull()!;
        expect(json, equals('[1,"text",true,null]'));
      });
      test('should handle serialization errors', () {
        // Create object with circular reference
        final map = <String, dynamic>{};
        map['self'] = map;
        final result = JsonParser.stringify(map);
        expect(!result.isSuccess, isTrue);
        expect(result.getErrorMessage(), contains('Failed to serialize'));
      });
      test('should serialize nested structures', () {
        final object = {
          'user': {
            'name': 'John',
            'tags': ['admin', 'user'],
            'settings': {'theme': 'dark'}
          }
        };
        final result = JsonParser.stringify(object);
        expect(result.isSuccess, isTrue);
        final json = result.getOrNull()!;
        expect(json, contains('"name":"John"'));
        expect(json, contains('["admin","user"]'));
        expect(json, contains('"theme":"dark"'));
      });
    });
    group('Byte Parsing', () {
      test('should parse JSON from UTF-8 bytes', () {
        const json = '{"message": "Hello World"}';
        final bytes = Uint8List.fromList(utf8.encode(json));
        final result = JsonParser.parseFromBytes(bytes);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data['message'], equals('Hello World'));
      });
      test('should handle empty byte array', () {
        final bytes = Uint8List(0);
        final result = JsonParser.parseFromBytes(bytes);
        expect(!result.isSuccess, isTrue);
        expect(result.getErrorMessage(), contains('empty'));
      });
      test('should parse Unicode from bytes', () {
        const json = '{"emoji": "🎉", "text": "Hello 世界"}';
        final bytes = Uint8List.fromList(utf8.encode(json));
        final result = JsonParser.parseFromBytes(bytes);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data['emoji'], equals('🎉'));
        expect(data['text'], equals('Hello 世界'));
      });
      test('should handle malformed bytes', () {
        // Invalid UTF-8 sequence
        final bytes = Uint8List.fromList([0xFF, 0xFE, 0xFD]);
        final result = JsonParser.parseFromBytes(bytes);
        expect(!result.isSuccess, isTrue);
        expect(result.getErrorMessage(), contains('Failed to parse'));
      });
      test('should use cache for byte parsing', () {
        const json = '{"cached": "bytes"}';
        final bytes = Uint8List.fromList(utf8.encode(json));
        const cacheKey = 'bytes-cache';
        var result = JsonParser.parseFromBytes(bytes, cacheKey: cacheKey);
        expect(result.isSuccess, isTrue);
        result = JsonParser.parseFromBytes(bytes, cacheKey: cacheKey);
        expect(result.isSuccess, isTrue);
        final stats = JsonParser.getCacheStats();
        expect(stats['size'], greaterThan(0));
      });
    });
    group('Cache Management', () {
      test('should cache results with auto-generated keys', () {
        const json = '{"auto": "cache"}';
        JsonParser.parseObject(json);
        JsonParser.parseObject(json); // Should use cache
        final stats = JsonParser.getCacheStats();
        expect(stats['size'], equals(1));
      });
      test('should implement LRU cache eviction', () {
        // Fill cache beyond capacity
        for (int i = 0; i < 105; i++) {
          JsonParser.parseObject('{"item": $i}');
        }
        final stats = JsonParser.getCacheStats();
        expect(stats['size'], equals(100)); // Should be capped at max size
      });
      test('should clear cache completely', () {
        JsonParser.parseObject('{"test": "data"}');
        var stats = JsonParser.getCacheStats();
        expect(stats['size'], greaterThan(0));
        JsonParser.clearCache();
        stats = JsonParser.getCacheStats();
        expect(stats['size'], equals(0));
        expect(stats['keys'], isEmpty);
      });
      test('should provide cache statistics', () {
        JsonParser.parseObject('{"test": 1}');
        JsonParser.parseArray('[1, 2, 3]');
        final stats = JsonParser.getCacheStats();
        expect(stats.containsKey('size'), isTrue);
        expect(stats.containsKey('max_size'), isTrue);
        expect(stats.containsKey('keys'), isTrue);
        expect(stats['size'], isA<int>());
        expect(stats['max_size'], equals(100));
        expect(stats['keys'], isA<List>());
      });
      test('should handle cache key collisions', () {
        // Use same cache key for different content
        const cacheKey = 'collision-test';
        var result =
            JsonParser.parseObject('{"first": "data"}', cacheKey: cacheKey);
        expect(result.getOrNull()!['first'], equals('data'));
        // Same key, different content - should override
        result =
            JsonParser.parseObject('{"second": "data"}', cacheKey: cacheKey);
        expect(result.getOrNull()!['first'],
            equals('data')); // Should still be cached first result
      });
    });
    group('Error Handling', () {
      test('should provide detailed error messages', () {
        const json = '{"key": "value", invalid}';
        final result = JsonParser.parseObject(json);
        expect(!result.isSuccess, isTrue);
        final error = result.getErrorMessage()!;
        expect(error, contains('JSON'));
        expect(error, contains('Preview:'));
      });
      test('should handle various malformed JSON', () {
        final invalidJsons = [
          '{key: "value"}', // Missing quotes on key
          "{'key': 'value'}", // Single quotes
          '{"key": undefined}', // Undefined value
          '{"key": NaN}', // NaN value
          '{,}', // Empty with comma
          '{"a":1,}', // Trailing comma
        ];
        for (final json in invalidJsons) {
          final result = JsonParser.parseObject(json);
          expect(!result.isSuccess, isTrue, reason: 'Should fail for: $json');
        }
      });
      test('should validate JSON structure', () {
        final testCases = [
          ('{}', true),
          ('[]', true),
          ('"string"', true),
          ('123', true),
          ('true', true),
          ('null', true),
          ('', false),
          ('{', false),
          ('}', false),
          ('[}', false),
        ];
        for (final (json, shouldSucceed) in testCases) {
          final result = JsonParser.parseAny(json);
          expect(result.isSuccess, equals(shouldSucceed),
              reason: 'JSON: $json');
        }
      });
      test('should handle FormatException specifically', () {
        const json = '{"incomplete": ';
        final result = JsonParser.parseObject(json);
        expect(!result.isSuccess, isTrue);
        final error = result.getErrorMessage()!;
        expect(error, contains('JSON'));
      });
      test('should truncate long JSON in error messages', () {
        final longJson = '{"data": "${'x' * 200}"}';
        final result = JsonParser.parseObject(longJson);
        if (!result.isSuccess) {
          final error = result.getErrorMessage()!;
          expect(error.length, lessThan(longJson.length));
          expect(error, contains('...'));
        }
      });
    });
    group('Edge Cases', () {
      test('should handle special characters', () {
        const json =
            r'{"quote": "\"Hello\"", "newline": "Line1\nLine2", "tab": "Col1\tCol2"}';
        final result = JsonParser.parseObject(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull()!;
        expect(data['quote'], equals('"Hello"'));
        expect(data['newline'], equals('Line1\nLine2'));
        expect(data['tab'], equals('Col1\tCol2'));
      });
      test('should handle Unicode characters', () {
        const json = '{"emoji": "🎉", "chinese": "你好", "arabic": "مرحبا"}';
        final result = JsonParser.parseObject(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull()!;
        expect(data['emoji'], equals('🎉'));
        expect(data['chinese'], equals('你好'));
        expect(data['arabic'], equals('مرحبا'));
      });
      test('should handle large numbers', () {
        const json = '{"big": 9007199254740992, "decimal": 3.141592653589793}';
        final result = JsonParser.parseObject(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull()!;
        expect(data['big'], equals(9007199254740992));
        expect(data['decimal'], equals(3.141592653589793));
      });
      test('should handle whitespace variations', () {
        const json = '''
        {
          "key1"  :  "value1"  ,
          "key2"  :  42  ,
          "key3"  :  [  1  ,  2  ,  3  ]
        }
        ''';
        final result = JsonParser.parseObject(json);
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull()!;
        expect(data['key1'], equals('value1'));
        expect(data['key2'], equals(42));
        expect(data['key3'], equals([1, 2, 3]));
      });
      test('should handle very deep nesting within limits', () {
        // Create nested object within default depth limit
        var json = '{';
        for (int i = 0; i < 10; i++) {
          json += '"level$i":{';
        }
        json += '"value":"deep"';
        for (int i = 0; i < 11; i++) {
          json += '}';
        }
        final result = JsonParser.parseObject(json);
        expect(result.isSuccess, isTrue);
        // Navigate to deep value
        var current = result.getOrNull()!;
        for (int i = 0; i < 10; i++) {
          current = current['level$i'] as Map<String, dynamic>;
        }
        expect(current['value'], equals('deep'));
      });
    });
    group('Integration Tests', () {
      test('should handle complete parse-serialize cycle', () {
        final originalData = {
          'user': {
            'id': 123,
            'name': 'John Doe',
            'active': true,
            'tags': ['admin', 'user'],
            'metadata': {
              'created': '2023-01-01T00:00:00Z',
              'updated': null,
            }
          }
        };
        // Serialize to JSON
        final stringifyResult = JsonParser.stringify(originalData);
        expect(stringifyResult.isSuccess, isTrue);
        final json = stringifyResult.getOrNull()!;
        // Parse back to object
        final parseResult = JsonParser.parseObject(json);
        expect(parseResult.isSuccess, isTrue);
        final parsedData = parseResult.getOrNull()!;
        // Verify data integrity
        expect(parsedData['user']['id'], equals(123));
        expect(parsedData['user']['name'], equals('John Doe'));
        expect(parsedData['user']['active'], equals(true));
        expect(parsedData['user']['tags'], equals(['admin', 'user']));
        expect(parsedData['user']['metadata']['created'],
            equals('2023-01-01T00:00:00Z'));
        expect(parsedData['user']['metadata']['updated'], isNull);
      });
      test('should work with different parsing methods', () {
        const objectJson = '{"type": "object", "value": 42}';
        const arrayJson = '[1, 2, 3]';
        const stringJson = '"hello"';
        // Parse as object
        final objectResult = JsonParser.parseObject(objectJson);
        expect(objectResult.isSuccess, isTrue);
        expect(objectResult.getOrNull()!['type'], equals('object'));
        // Parse as array
        final arrayResult = JsonParser.parseArray(arrayJson);
        expect(arrayResult.isSuccess, isTrue);
        expect((arrayResult.getOrNull()!).length, equals(3));
        // Parse with auto-detection
        var anyResult = JsonParser.parseAny(objectJson);
        expect(anyResult.isSuccess, isTrue);
        expect(anyResult.getOrNull(), isA<Map<String, dynamic>>());
        anyResult = JsonParser.parseAny(arrayJson);
        expect(anyResult.isSuccess, isTrue);
        expect(anyResult.getOrNull(), isA<List<dynamic>>());
        anyResult = JsonParser.parseAny(stringJson);
        expect(anyResult.isSuccess, isTrue);
        expect(anyResult.getOrNull(), equals('hello'));
      });
    });
  });
}
