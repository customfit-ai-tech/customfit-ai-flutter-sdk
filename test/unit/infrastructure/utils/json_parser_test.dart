// test/unit/core/util/json_parser_test.dart
//
// Simplified tests for JsonParser after SDK simplification
// Tests basic JSON parsing functionality using dart:convert

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/infrastructure/utils/json_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JsonParser (Simplified)', () {
    group('Object Parsing', () {
      test('should parse simple JSON object', () {
        const json = '{"name": "John", "age": 30}';
        final result = JsonParser.parseObject(json);
        
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data?['name'], equals('John'));
        expect(data?['age'], equals(30));
      });

      test('should handle empty JSON object', () {
        const json = '{}';
        final result = JsonParser.parseObject(json);
        
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data?.isEmpty, isTrue);
      });

      test('should handle nested objects', () {
        const json = '{"user": {"id": 1, "profile": {"name": "John"}}}';
        final result = JsonParser.parseObject(json);
        
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data?['user']['id'], equals(1));
        expect(data?['user']['profile']['name'], equals('John'));
      });

      test('should reject empty string', () {
        final result = JsonParser.parseObject('');
        
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('empty'));
      });

      test('should reject non-object JSON', () {
        const json = '[1, 2, 3]';
        final result = JsonParser.parseObject(json);
        
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('not an object'));
      });

      test('should handle malformed JSON', () {
        const json = '{"invalid": json}';
        final result = JsonParser.parseObject(json);
        
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), isNotEmpty);
      });
    });

    group('Array Parsing', () {
      test('should parse simple JSON array', () {
        const json = '[1, 2, 3]';
        final result = JsonParser.parseArray(json);
        
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data, equals([1, 2, 3]));
      });

      test('should handle empty JSON array', () {
        const json = '[]';
        final result = JsonParser.parseArray(json);
        
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data?.isEmpty, isTrue);
      });

      test('should reject non-array JSON', () {
        const json = '{"key": "value"}';
        final result = JsonParser.parseArray(json);
        
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('not an array'));
      });
    });

    group('Generic Parsing', () {
      test('should parse any valid JSON', () {
        const json = '{"key": "value"}';
        final result = JsonParser.parseAny(json);
        
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data?['key'], equals('value'));
      });

      test('should handle arrays in parseAny', () {
        const json = '[1, 2, 3]';
        final result = JsonParser.parseAny(json);
        
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data, equals([1, 2, 3]));
      });

      test('should handle primitives in parseAny', () {
        const json = '"hello"';
        final result = JsonParser.parseAny(json);
        
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data, equals('hello'));
      });
    });

    group('JSON Serialization', () {
      test('should stringify objects', () {
        final obj = {'name': 'John', 'age': 30};
        final result = JsonParser.stringify(obj);
        
        expect(result.isSuccess, isTrue);
        final json = result.getOrNull();
        expect(json, contains('"name":"John"'));
        expect(json, contains('"age":30'));
      });

      test('should stringify arrays', () {
        final array = [1, 2, 3];
        final result = JsonParser.stringify(array);
        
        expect(result.isSuccess, isTrue);
        final json = result.getOrNull();
        expect(json, equals('[1,2,3]'));
      });

      test('should handle null values', () {
        final result = JsonParser.stringify(null);
        
        expect(result.isSuccess, isTrue);
        final json = result.getOrNull();
        expect(json, equals('null'));
      });
    });

    group('Byte Parsing', () {
      test('should parse UTF-8 bytes', () {
        const json = '{"key": "value"}';
        final bytes = Uint8List.fromList(json.codeUnits);
        final result = JsonParser.parseFromBytes(bytes);
        
        expect(result.isSuccess, isTrue);
        final data = result.getOrNull();
        expect(data?['key'], equals('value'));
      });

      test('should handle empty bytes', () {
        final bytes = Uint8List(0);
        final result = JsonParser.parseFromBytes(bytes);
        
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), isNotEmpty);
      });
    });

    group('Cache Management', () {
      test('should clear cache without errors', () {
        expect(() => JsonParser.clearCache(), returnsNormally);
      });

      test('should provide cache stats', () {
        final stats = JsonParser.getCacheStats();
        expect(stats, isA<Map<String, dynamic>>());
      });
    });

    group('Error Handling', () {
      test('should provide error details for invalid JSON', () {
        const invalidJson = '{"unclosed": true';
        final result = JsonParser.parseObject(invalidJson);
        
        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), isNotEmpty);
      });

      test('should handle very large JSON strings', () {
        final largeJson = '{"data": "${'x' * 1000}"}';
        final result = JsonParser.parseObject(largeJson);
        
        expect(result.isSuccess, isTrue);
      });
    });
  });
}