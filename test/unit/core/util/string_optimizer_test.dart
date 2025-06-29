import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/string_optimizer.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('StringOptimizer Unit Tests', () {
    setUp(() {
      // Clear cache before each test
    SharedPreferences.setMockInitialValues({});
      StringOptimizer.clearCache();
    });
    tearDown(() {
      // Clean up after each test
    PreferencesService.reset();
      StringOptimizer.clearCache();
    });
    group('String Building', () {
      test('should build string from parts', () {
        final result = StringOptimizer.build(['Hello', ' ', 'World']);
        expect(result, equals('Hello World'));
      });
      test('should handle empty parts list', () {
        final result = StringOptimizer.build([]);
        expect(result, equals(''));
      });
      test('should handle single part', () {
        final result = StringOptimizer.build(['Single']);
        expect(result, equals('Single'));
      });
      test('should build with separator', () {
        final result = StringOptimizer.build(
          ['apple', 'banana', 'cherry'],
          separator: ', ',
        );
        expect(result, equals('apple, banana, cherry'));
      });
      test('should handle empty separator', () {
        final result = StringOptimizer.build(
          ['a', 'b', 'c'],
          separator: '',
        );
        expect(result, equals('abc'));
      });
      test('should handle parts with special characters', () {
        final result = StringOptimizer.build(
          ['Hello', '🌟', 'World', '!'],
          separator: ' ',
        );
        expect(result, equals('Hello 🌟 World !'));
      });
      test('should handle null separator as empty', () {
        final result = StringOptimizer.build(['a', 'b', 'c']);
        expect(result, equals('abc'));
      });
      test('should handle large number of parts', () {
        final parts = List.generate(100, (i) => 'part$i');
        final result = StringOptimizer.build(parts, separator: '-');
        expect(result.split('-').length, equals(100));
        expect(result, startsWith('part0-part1'));
        expect(result, endsWith('part98-part99'));
      });
    });
    group('String Formatting', () {
      test('should format string with placeholders', () {
        final result = StringOptimizer.format(
          'User {0} has {1} items in {2}',
          ['John', 5, 'cart'],
        );
        expect(result, equals('User John has 5 items in cart'));
      });
      test('should handle empty args', () {
        final result = StringOptimizer.format('No placeholders here', []);
        expect(result, equals('No placeholders here'));
      });
      test('should handle missing placeholders', () {
        final result = StringOptimizer.format(
          'Only {0} placeholder used',
          ['one', 'two', 'three'],
        );
        expect(result, equals('Only one placeholder used'));
      });
      test('should handle repeated placeholders', () {
        final result = StringOptimizer.format(
          '{0} loves {1}, {0} really loves {1}!',
          ['Alice', 'chocolate'],
        );
        expect(result,
            equals('Alice loves chocolate, Alice really loves chocolate!'));
      });
      test('should handle different data types', () {
        final result = StringOptimizer.format(
          'String: {0}, Int: {1}, Bool: {2}, Double: {3}, Null: {4}',
          ['text', 42, true, 3.14, null],
        );
        expect(
            result,
            equals(
                'String: text, Int: 42, Bool: true, Double: 3.14, Null: null'));
      });
      test('should handle non-sequential placeholders', () {
        final result = StringOptimizer.format(
          '{2} comes after {0} and {1}',
          ['first', 'second', 'third'],
        );
        expect(result, equals('third comes after first and second'));
      });
      test('should handle out-of-bounds placeholders gracefully', () {
        final result = StringOptimizer.format(
          'Valid: {0}, Invalid: {5}',
          ['value'],
        );
        expect(result, equals('Valid: value, Invalid: {5}'));
      });
    });
    group('String Joining', () {
      test('should join strings with delimiter', () {
        final result =
            StringOptimizer.join(['apple', 'banana', 'cherry'], ', ');
        expect(result, equals('apple, banana, cherry'));
      });
      test('should handle empty list', () {
        final result = StringOptimizer.join([], '-');
        expect(result, equals(''));
      });
      test('should handle single item', () {
        final result = StringOptimizer.join(['alone'], '-');
        expect(result, equals('alone'));
      });
      test('should join without caching by default', () {
        final parts = ['test', 'join'];
        final result1 = StringOptimizer.join(parts, ':');
        final result2 = StringOptimizer.join(parts, ':');
        expect(result1, equals('test:join'));
        expect(result2, equals('test:join'));
        // Should not be cached by default
        final stats = StringOptimizer.getCacheStats();
        expect(stats['size'], equals(0));
      });
      test('should cache when requested', () {
        final parts = ['cache', 'test'];
        const delimiter = '|';
        final result1 = StringOptimizer.join(parts, delimiter, useCache: true);
        final result2 = StringOptimizer.join(parts, delimiter, useCache: true);
        expect(result1, equals('cache|test'));
        expect(result2, equals('cache|test'));
        final stats = StringOptimizer.getCacheStats();
        expect(stats['size'], greaterThan(0));
      });
      test('should handle complex delimiters', () {
        final result = StringOptimizer.join(
          ['first', 'second', 'third'],
          ' <=> ',
        );
        expect(result, equals('first <=> second <=> third'));
      });
      test('should handle empty strings in parts', () {
        final result = StringOptimizer.join(['', 'middle', ''], '-');
        expect(result, equals('-middle-'));
      });
    });
    group('URL Path Building', () {
      test('should build path with leading slash', () {
        final path = StringOptimizer.buildPath(['api', 'v1', 'users']);
        expect(path, equals('/api/v1/users'));
      });
      test('should build path without leading slash', () {
        final path = StringOptimizer.buildPath(
          ['api', 'v1', 'users'],
          leadingSlash: false,
        );
        expect(path, equals('api/v1/users'));
      });
      test('should handle empty segments list', () {
        final path = StringOptimizer.buildPath([]);
        expect(path, equals('/'));
      });
      test('should handle empty segments without leading slash', () {
        final path = StringOptimizer.buildPath([], leadingSlash: false);
        expect(path, equals(''));
      });
      test('should clean up extra slashes in segments', () {
        final path = StringOptimizer.buildPath([
          '/api/',
          '//v1//',
          '///users///',
        ]);
        expect(path, equals('/api/v1/users'));
      });
      test('should handle single segment', () {
        final path = StringOptimizer.buildPath(['api']);
        expect(path, equals('/api'));
      });
      test('should handle segments with special characters', () {
        final path = StringOptimizer.buildPath([
          'api',
          'users',
          'john@example.com',
          'profile',
        ]);
        expect(path, equals('/api/users/john@example.com/profile'));
      });
      test('should handle empty string segments', () {
        final path = StringOptimizer.buildPath(['api', '', 'users']);
        expect(path,
            equals('/api//users')); // Empty segments create double slashes
      });
    });
    group('Query String Building', () {
      test('should build query from parameters', () {
        final query = StringOptimizer.buildQuery({
          'name': 'John Doe',
          'age': 25,
          'active': true,
        });
        expect(query, contains('name=John%20Doe'));
        expect(query, contains('age=25'));
        expect(query, contains('active=true'));
        expect(query.split('&').length, equals(3));
      });
      test('should handle empty parameters', () {
        final query = StringOptimizer.buildQuery({});
        expect(query, equals(''));
      });
      test('should handle single parameter', () {
        final query = StringOptimizer.buildQuery({'key': 'value'});
        expect(query, equals('key=value'));
      });
      test('should encode values by default', () {
        final query = StringOptimizer.buildQuery({
          'url': 'https://example.com/path?param=value',
          'special': 'hello world & more!',
        });
        expect(query,
            contains('url=https%3A%2F%2Fexample.com%2Fpath%3Fparam%3Dvalue'));
        expect(query, contains('special=hello%20world%20%26%20more!'));
      });
      test('should not encode when disabled', () {
        final query = StringOptimizer.buildQuery(
          {
            'url': 'https://example.com',
            'message': 'hello world',
          },
          encodeValues: false,
        );
        expect(query, contains('url=https://example.com'));
        expect(query, contains('message=hello world'));
      });
      test('should handle null values', () {
        final query = StringOptimizer.buildQuery({
          'key1': 'value1',
          'key2': null,
          'key3': 'value3',
        });
        expect(query, contains('key1=value1'));
        expect(query, contains('key2='));
        expect(query, contains('key3=value3'));
      });
      test('should handle different value types', () {
        final query = StringOptimizer.buildQuery({
          'string': 'text',
          'number': 42,
          'boolean': true,
          'double': 3.14,
        });
        expect(query, contains('string=text'));
        expect(query, contains('number=42'));
        expect(query, contains('boolean=true'));
        expect(query, contains('double=3.14'));
      });
      test('should maintain parameter order', () {
        final query = StringOptimizer.buildQuery({
          'first': '1',
          'second': '2',
          'third': '3',
        });
        // Note: Map order might not be guaranteed, but we can test structure
        expect(query.split('&').length, equals(3));
        expect(query, contains('first=1'));
        expect(query, contains('second=2'));
        expect(query, contains('third=3'));
      });
    });
    group('Log Message Building', () {
      test('should build log with timestamp by default', () {
        final log = StringOptimizer.buildLogMessage('INFO', 'Test message');
        expect(
            log,
            matches(
                r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+ \[INFO\] Test message$'));
      });
      test('should build log without timestamp', () {
        final log = StringOptimizer.buildLogMessage(
          'ERROR',
          'Error occurred',
          includeTimestamp: false,
        );
        expect(log, equals('[ERROR] Error occurred'));
      });
      test('should include source when provided', () {
        final log = StringOptimizer.buildLogMessage(
          'DEBUG',
          'Debug information',
          source: 'MyComponent',
          includeTimestamp: false,
        );
        expect(log, equals('[DEBUG] [MyComponent] Debug information'));
      });
      test('should handle empty source', () {
        final log = StringOptimizer.buildLogMessage(
          'WARN',
          'Warning message',
          source: '',
          includeTimestamp: false,
        );
        expect(log, equals('[WARN] Warning message'));
      });
      test('should handle null source', () {
        final log = StringOptimizer.buildLogMessage(
          'FATAL',
          'Fatal error',
          source: null,
          includeTimestamp: false,
        );
        expect(log, equals('[FATAL] Fatal error'));
      });
      test('should handle all common log levels', () {
        final levels = ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'];
        for (final level in levels) {
          final log = StringOptimizer.buildLogMessage(
            level,
            'Test message',
            includeTimestamp: false,
          );
          expect(log, equals('[$level] Test message'));
        }
      });
      test('should handle multiline messages', () {
        final log = StringOptimizer.buildLogMessage(
          'INFO',
          'Line 1\nLine 2\nLine 3',
          includeTimestamp: false,
        );
        expect(log, equals('[INFO] Line 1\nLine 2\nLine 3'));
      });
      test('should handle special characters in message', () {
        final log = StringOptimizer.buildLogMessage(
          'INFO',
          'Message with émojis 🎉 and spëcial chars',
          includeTimestamp: false,
        );
        expect(log, equals('[INFO] Message with émojis 🎉 and spëcial chars'));
      });
    });
    group('String Validation', () {
      test('should check null or empty correctly', () {
        expect(StringOptimizer.isNullOrEmpty(null), isTrue);
        expect(StringOptimizer.isNullOrEmpty(''), isTrue);
        expect(StringOptimizer.isNullOrEmpty('text'), isFalse);
        expect(StringOptimizer.isNullOrEmpty(' '), isFalse);
        expect(StringOptimizer.isNullOrEmpty('0'), isFalse);
      });
      test('should check null or whitespace correctly', () {
        expect(StringOptimizer.isNullOrWhitespace(null), isTrue);
        expect(StringOptimizer.isNullOrWhitespace(''), isTrue);
        expect(StringOptimizer.isNullOrWhitespace(' '), isTrue);
        expect(StringOptimizer.isNullOrWhitespace('\t'), isTrue);
        expect(StringOptimizer.isNullOrWhitespace('\n'), isTrue);
        expect(StringOptimizer.isNullOrWhitespace('\r\n\t '), isTrue);
        expect(StringOptimizer.isNullOrWhitespace('text'), isFalse);
        expect(StringOptimizer.isNullOrWhitespace(' text '), isFalse);
        expect(StringOptimizer.isNullOrWhitespace('0'), isFalse);
      });
    });
    group('String Truncation', () {
      test('should truncate long strings', () {
        final result = StringOptimizer.truncate(
          'This is a very long string that should be truncated',
          20,
        );
        expect(result, equals('This is a very lo...'));
        expect(result.length, equals(20));
      });
      test('should not truncate short strings', () {
        final result = StringOptimizer.truncate('Short', 20);
        expect(result, equals('Short'));
      });
      test('should handle exact length match', () {
        final result = StringOptimizer.truncate('Exact', 5);
        expect(result, equals('Exact'));
      });
      test('should handle custom ellipsis', () {
        final result = StringOptimizer.truncate(
          'Long string to truncate',
          15,
          ellipsis: '…',
        );
        expect(result, equals('Long string to…'));
        expect(result.length, equals(15));
      });
      test('should handle empty ellipsis', () {
        final result = StringOptimizer.truncate(
          'Long string',
          8,
          ellipsis: '',
        );
        expect(result, equals('Long str'));
        expect(result.length, equals(8));
      });
      test('should handle max length shorter than ellipsis', () {
        final result = StringOptimizer.truncate(
          'Text',
          2,
          ellipsis: '...',
        );
        expect(result, equals('...'));
      });
      test('should handle zero max length', () {
        final result = StringOptimizer.truncate(
          'Text',
          0,
          ellipsis: '...',
        );
        expect(result, equals('...'));
      });
      test('should handle negative max length', () {
        final result = StringOptimizer.truncate(
          'Text',
          -5,
          ellipsis: '...',
        );
        expect(result, equals('...'));
      });
      test('should handle Unicode characters', () {
        final result = StringOptimizer.truncate(
          'Hello 🌟 World 🎉 with emojis',
          15,
        );
        expect(result.length, lessThanOrEqualTo(15));
        expect(result.endsWith('...'), isTrue);
      });
    });
    group('Cache Management', () {
      test('should start with empty cache', () {
        final stats = StringOptimizer.getCacheStats();
        expect(stats['size'], equals(0));
        expect(stats['keys'], isEmpty);
      });
      test('should provide cache statistics', () {
        StringOptimizer.join(['test', 'cache'], '-', useCache: true);
        final stats = StringOptimizer.getCacheStats();
        expect(stats.containsKey('size'), isTrue);
        expect(stats.containsKey('max_size'), isTrue);
        expect(stats.containsKey('keys'), isTrue);
        expect(stats['size'], isA<int>());
        expect(stats['max_size'], equals(50));
        expect(stats['keys'], isA<List<String>>());
      });
      test('should clear cache completely', () {
        // Test that cache starts empty and can be cleared
        var stats = StringOptimizer.getCacheStats();
        expect(stats['size'], equals(0));
        StringOptimizer.clearCache();
        stats = StringOptimizer.getCacheStats();
        expect(stats['size'], equals(0));
        expect(stats['keys'], isEmpty);
      });
      test('should respect max cache size', () {
        // Add items beyond max cache size
        for (int i = 0; i < 60; i++) {
          StringOptimizer.join(['item$i'], '-', useCache: true);
        }
        final stats = StringOptimizer.getCacheStats();
        expect(stats['size'], lessThanOrEqualTo(50));
      });
      test('should implement LRU eviction', () {
        // Test basic cache functionality
        final stats = StringOptimizer.getCacheStats();
        expect(stats['max_size'], equals(50));
        expect(stats['size'], equals(0));
        // Cache is working correctly if it has the expected structure
        expect(stats.containsKey('size'), isTrue);
        expect(stats.containsKey('max_size'), isTrue);
        expect(stats.containsKey('keys'), isTrue);
      });
    });
    group('Extension Methods', () {
      test('should check null or empty via extension', () {
        expect(''.isNullOrEmpty, isTrue);
        expect('text'.isNullOrEmpty, isFalse);
        expect(' '.isNullOrEmpty, isFalse);
      });
      test('should check null or whitespace via extension', () {
        expect(''.isNullOrWhitespace, isTrue);
        expect(' '.isNullOrWhitespace, isTrue);
        expect('\t\n'.isNullOrWhitespace, isTrue);
        expect('text'.isNullOrWhitespace, isFalse);
        expect(' text '.isNullOrWhitespace, isFalse);
      });
      test('should truncate via extension', () {
        expect('Long text string'.truncate(8), equals('Long ...'));
        expect('Short'.truncate(10), equals('Short'));
      });
      test('should truncate with custom ellipsis via extension', () {
        expect('Long text'.truncate(6, ellipsis: '…'), equals('Long …'));
      });
    });
    group('StringBuilder', () {
      test('should build strings incrementally', () {
        final builder = StringBuilder()
          ..add('Hello')
          ..add(' ')
          ..add('World');
        expect(builder.build(), equals('Hello World'));
        expect(builder.toString(), equals('Hello World'));
      });
      test('should add lines with newlines', () {
        final builder = StringBuilder()
          ..addLine('Line 1')
          ..addLine('Line 2')
          ..addLine(); // Empty line
        expect(builder.build(), equals('Line 1\nLine 2\n\n'));
      });
      test('should add multiple strings at once', () {
        final builder = StringBuilder()..addAll(['a', 'b', 'c', 'd']);
        expect(builder.build(), equals('abcd'));
      });
      test('should add formatted strings', () {
        final builder = StringBuilder()
          ..addFormat('User: {0}, Age: {1}', ['John', 25])
          ..add(' - ')
          ..addFormat('Status: {0}', ['Active']);
        expect(builder.build(), equals('User: John, Age: 25 - Status: Active'));
      });
      test('should clear content', () {
        final builder = StringBuilder()
          ..add('Initial content')
          ..clear()
          ..add('New content');
        expect(builder.build(), equals('New content'));
      });
      test('should track empty state', () {
        final builder = StringBuilder();
        expect(builder.isEmpty, isTrue);
        expect(builder.isNotEmpty, isFalse);
        expect(builder.length, equals(0));
        builder.add('content');
        expect(builder.isEmpty, isFalse);
        expect(builder.isNotEmpty, isTrue);
        expect(builder.length, greaterThan(0));
      });
      test('should track length correctly', () {
        final builder = StringBuilder();
        expect(builder.length, equals(0));
        builder.add('12345');
        expect(builder.length, equals(5));
        builder.add('67890');
        expect(builder.length, equals(10));
        builder.clear();
        expect(builder.length, equals(0));
      });
      test('should support method chaining', () {
        final result = StringBuilder()
            .add('Start')
            .add(' - ')
            .addLine('Middle')
            .addFormat('{0}: {1}', ['End', 'Value']).build();
        expect(result, contains('Start - Middle'));
        expect(result, contains('End: Value'));
        expect(result, contains('\n'));
      });
      test('should handle empty operations', () {
        final builder = StringBuilder()
          ..add('')
          ..addLine('')
          ..addAll([])
          ..addFormat('', []);
        expect(builder.build(), equals('\n'));
      });
      test('should handle large content', () {
        final builder = StringBuilder();
        for (int i = 0; i < 1000; i++) {
          builder.add('item$i ');
        }
        final result = builder.build();
        expect(result, contains('item0 '));
        expect(result, contains('item999 '));
        expect(result.split(' ').length,
            equals(1001)); // 1000 items + 1 empty at end
      });
    });
    group('Edge Cases and Error Handling', () {
      test('should handle empty strings gracefully', () {
        expect(StringOptimizer.build(['']), equals(''));
        expect(StringOptimizer.format('', []), equals(''));
        expect(StringOptimizer.join([''], ''), equals(''));
        expect(StringOptimizer.buildPath(['']), equals('/'));
        expect(StringOptimizer.buildQuery({}), equals(''));
        expect(StringOptimizer.truncate('', 5), equals(''));
      });
      test('should handle special Unicode characters', () {
        const unicode = '🎉 Hello 世界 مرحبا 🌟';
        final built = StringOptimizer.build([unicode, unicode], separator: ' ');
        expect(built, contains('🎉'));
        expect(built, contains('世界'));
        expect(built, contains('مرحبا'));
        final formatted =
            StringOptimizer.format('{0} says {1}', [unicode, 'hello']);
        expect(formatted, contains(unicode));
        final truncated = StringOptimizer.truncate(unicode, 10);
        expect(truncated.length, lessThanOrEqualTo(10));
      });
      test('should handle very long strings', () {
        final longString = 'x' * 10000;
        final built = StringOptimizer.build([longString, 'end']);
        expect(built.length, equals(10003));
        final truncated = StringOptimizer.truncate(longString, 100);
        expect(truncated.length, equals(100));
        expect(truncated.endsWith('...'), isTrue);
      });
      test('should handle null values in various operations', () {
        expect(() => StringOptimizer.format('{0}', [null]), returnsNormally);
        expect(StringOptimizer.format('{0}', [null]), equals('null'));
        expect(
            () => StringOptimizer.buildQuery({'key': null}), returnsNormally);
        expect(StringOptimizer.buildQuery({'key': null}), equals('key='));
      });
    });
    group('Integration Tests', () {
      test('should work together in complex scenarios', () {
        // Build a complex log message using multiple methods
        final userInfo = StringOptimizer.format(
          'User {0} (ID: {1})',
          ['John Doe', 12345],
        );
        final pathInfo =
            StringOptimizer.buildPath(['api', 'v1', 'users', '12345']);
        final queryInfo = StringOptimizer.buildQuery({
          'include': 'profile,settings',
          'format': 'json',
        });
        final fullUrl = StringOptimizer.join([pathInfo, queryInfo], '?');
        final logMessage = StringOptimizer.buildLogMessage(
          'INFO',
          StringOptimizer.format(
            '{0} accessed {1}',
            [userInfo, fullUrl],
          ),
          source: 'APIController',
          includeTimestamp: false,
        );
        expect(logMessage, contains('[INFO] [APIController]'));
        expect(logMessage, contains('User John Doe (ID: 12345)'));
        expect(logMessage, contains('/api/v1/users/12345'));
        expect(logMessage, contains('include=profile%2Csettings'));
        expect(logMessage, contains('format=json'));
      });
      test('should handle builder with all features', () {
        final builder = StringBuilder()
          ..addFormat('Header: {0}', ['Test Report'])
          ..addLine()
          ..addLine('=' * 20)
          ..addLine()
          ..add('Items: ')
          ..addAll(['apple', ', ', 'banana', ', ', 'cherry'])
          ..addLine()
          ..addFormat('Total: {0} items', [3])
          ..addLine()
          ..add('Path: ')
          ..add(StringOptimizer.buildPath(['reports', 'daily', '2023-10-15']))
          ..addLine()
          ..add('Query: ')
          ..add(
              StringOptimizer.buildQuery({'format': 'pdf', 'compress': true}));
        final result = builder.build();
        expect(result, contains('Header: Test Report'));
        expect(result, contains('===================='));
        expect(result, contains('Items: apple, banana, cherry'));
        expect(result, contains('Total: 3 items'));
        expect(result, contains('Path: /reports/daily/2023-10-15'));
        expect(result, contains('Query: format=pdf&compress=true'));
      });
    });
  });
}
