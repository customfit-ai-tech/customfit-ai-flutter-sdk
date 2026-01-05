// test/unit/analytics/summary/cf_config_request_summary_test.dart
//
// Tests for CFConfigRequestSummary class
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/summary/cf_config_request_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CFConfigRequestSummary', () {
    group('Constructor', () {
      test('should create summary with required fields', () {
        final summary = CFConfigRequestSummary(
          requestedTime: '2023-01-01 12:00:00.000Z',
          userCustomerId: 'user123',
          sessionId: 'session456',
        );
        expect(summary.requestedTime, equals('2023-01-01 12:00:00.000Z'));
        expect(summary.userCustomerId, equals('user123'));
        expect(summary.sessionId, equals('session456'));
        expect(summary.configId, isNull);
        expect(summary.version, isNull);
        expect(summary.variationId, isNull);
        expect(summary.behaviourId, isNull);
        expect(summary.experienceId, isNull);
        expect(summary.ruleId, isNull);
      });
      test('should create summary with all fields', () {
        final summary = CFConfigRequestSummary(
          configId: 'config123',
          version: '1.0.0',
          requestedTime: '2023-01-01 12:00:00.000Z',
          variationId: 'variation456',
          userCustomerId: 'user123',
          sessionId: 'session456',
          behaviourId: 'behaviour789',
          experienceId: 'experience101',
          ruleId: 'rule202',
        );
        expect(summary.configId, equals('config123'));
        expect(summary.version, equals('1.0.0'));
        expect(summary.requestedTime, equals('2023-01-01 12:00:00.000Z'));
        expect(summary.variationId, equals('variation456'));
        expect(summary.userCustomerId, equals('user123'));
        expect(summary.sessionId, equals('session456'));
        expect(summary.behaviourId, equals('behaviour789'));
        expect(summary.experienceId, equals('experience101'));
        expect(summary.ruleId, equals('rule202'));
      });
      test('should provide timestamp getter', () {
        const requestedTime = '2023-01-01 12:00:00.000Z';
        final summary = CFConfigRequestSummary(
          requestedTime: requestedTime,
          userCustomerId: 'user123',
          sessionId: 'session456',
        );
        expect(summary.timestamp, equals(requestedTime));
        expect(summary.timestamp, equals(summary.requestedTime));
      });
    });
    group('Factory fromConfig', () {
      test('should create summary from config map with all fields', () {
        final config = {
          'config_id': 'config123',
          'version': '1.0.0',
          'user_id': 'internal-user-id',
          'variation_id': 'variation456',
          'behaviour_id': 'behaviour789',
          'experience_id': 'experience101',
          'rule_id': 'rule202',
        };
        final summary = CFConfigRequestSummary.fromConfig(
          config,
          'user123',
          'session456',
        );
        expect(summary.configId, equals('config123'));
        expect(summary.version, equals('1.0.0'));
        expect(summary.variationId, equals('variation456'));
        expect(summary.userCustomerId, equals('user123'));
        expect(summary.sessionId, equals('session456'));
        expect(summary.behaviourId, equals('behaviour789'));
        expect(summary.experienceId, equals('experience101'));
        expect(summary.ruleId, equals('rule202'));
        expect(summary.requestedTime, isNotEmpty);
        expect(summary.requestedTime, contains('Z')); // UTC format
      });
      test('should create summary from minimal config map', () {
        final config = <String, dynamic>{};
        final summary = CFConfigRequestSummary.fromConfig(
          config,
          'user123',
          'session456',
        );
        expect(summary.configId, isNull);
        expect(summary.version, isNull);
        expect(summary.variationId, isNull);
        expect(summary.userCustomerId, equals('user123'));
        expect(summary.sessionId, equals('session456'));
        expect(summary.behaviourId, isNull);
        expect(summary.experienceId, isNull);
        expect(summary.ruleId, isNull);
        expect(summary.requestedTime, isNotEmpty);
      });
      test('should create summary from partial config map', () {
        final config = {
          'config_id': 'config123',
          'variation_id': 'variation456',
          'experience_id': 'experience101',
        };
        final summary = CFConfigRequestSummary.fromConfig(
          config,
          'user123',
          'session456',
        );
        expect(summary.configId, equals('config123'));
        expect(summary.version, isNull);
        expect(summary.variationId, equals('variation456'));
        expect(summary.userCustomerId, equals('user123'));
        expect(summary.sessionId, equals('session456'));
        expect(summary.behaviourId, isNull);
        expect(summary.experienceId, equals('experience101'));
        expect(summary.ruleId, isNull);
      });
      test('should generate valid timestamp format', () {
        final config = {'config_id': 'test'};
        final summary = CFConfigRequestSummary.fromConfig(
          config,
          'user123',
          'session456',
        );
        // Check timestamp format: "yyyy-MM-dd HH:mm:ss.SSSZ"
        final timestamp = summary.requestedTime;
        expect(timestamp,
            matches(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}Z$'));
        // Should be a recent timestamp (within last few seconds)
        final parsed = DateTime.parse(timestamp.replaceAll(' ', 'T'));
        final now = DateTime.now().toUtc();
        final diff = now.difference(parsed).inSeconds.abs();
        expect(diff, lessThan(5)); // Should be very recent
      });
    });
    group('JSON Serialization', () {
      late CFConfigRequestSummary testSummary;
      setUp(() {
        testSummary = CFConfigRequestSummary(
          configId: 'config123',
          version: '1.0.0',
          requestedTime: '2023-01-01 12:00:00.000Z',
          variationId: 'variation456',
          userCustomerId: 'user123',
          sessionId: 'session456',
          behaviourId: 'behaviour789',
          experienceId: 'experience101',
          ruleId: 'rule202',
        );
      });
      test('should convert to map correctly', () {
        final map = testSummary.toMap();
        expect(map['config_id'], equals('config123'));
        expect(map['version'], equals('1.0.0'));
        expect(map['requested_time'], equals('2023-01-01 12:00:00.000Z'));
        expect(map['timestamp'], equals('2023-01-01 12:00:00.000Z')); // Alias
        expect(map['variation_id'], equals('variation456'));
        expect(map['user_customer_id'], equals('user123'));
        expect(map['session_id'], equals('session456'));
        expect(map['behaviour_id'], equals('behaviour789'));
        expect(map['experience_id'], equals('experience101'));
        expect(map['rule_id'], equals('rule202'));
      });
      test('should convert to JSON string', () {
        final jsonString = testSummary.toJson();
        expect(jsonString, isA<String>());
        expect(jsonString, isNotEmpty);
        // Verify it's valid JSON
        final decoded = jsonDecode(jsonString);
        expect(decoded, isA<Map<String, dynamic>>());
        expect(decoded['config_id'], equals('config123'));
        expect(decoded['user_customer_id'], equals('user123'));
      });
      test('should create from map correctly', () {
        final map = {
          'config_id': 'config123',
          'version': '1.0.0',
          'user_id': 'internal-user-id',
          'requested_time': '2023-01-01 12:00:00.000Z',
          'variation_id': 'variation456',
          'user_customer_id': 'user123',
          'session_id': 'session456',
          'behaviour_id': 'behaviour789',
          'experience_id': 'experience101',
          'rule_id': 'rule202',
        };
        final summary = CFConfigRequestSummary.fromMap(map);
        expect(summary.configId, equals('config123'));
        expect(summary.version, equals('1.0.0'));
        expect(summary.requestedTime, equals('2023-01-01 12:00:00.000Z'));
        expect(summary.variationId, equals('variation456'));
        expect(summary.userCustomerId, equals('user123'));
        expect(summary.sessionId, equals('session456'));
        expect(summary.behaviourId, equals('behaviour789'));
        expect(summary.experienceId, equals('experience101'));
        expect(summary.ruleId, equals('rule202'));
      });
      test('should handle round-trip serialization', () {
        final map = testSummary.toMap();
        final restored = CFConfigRequestSummary.fromMap(map);
        final restoredMap = restored.toMap();
        // Compare all non-null fields
        expect(restoredMap['config_id'], equals(map['config_id']));
        expect(restoredMap['version'], equals(map['version']));
        expect(restoredMap['requested_time'], equals(map['requested_time']));
        expect(restoredMap['variation_id'], equals(map['variation_id']));
        expect(
            restoredMap['user_customer_id'], equals(map['user_customer_id']));
        expect(restoredMap['session_id'], equals(map['session_id']));
        expect(restoredMap['behaviour_id'], equals(map['behaviour_id']));
        expect(restoredMap['experience_id'], equals(map['experience_id']));
        expect(restoredMap['rule_id'], equals(map['rule_id']));
      });
      test('should handle null values correctly', () {
        final summaryWithNulls = CFConfigRequestSummary(
          requestedTime: '2023-01-01 12:00:00.000Z',
          userCustomerId: 'user123',
          sessionId: 'session456',
          // All other fields are null
        );
        final map = summaryWithNulls.toMap();
        // Null values should be removed from map
        expect(map.containsKey('config_id'), isFalse);
        expect(map.containsKey('version'), isFalse);
        expect(map.containsKey('user_id'), isFalse);
        expect(map.containsKey('variation_id'), isFalse);
        expect(map.containsKey('behaviour_id'), isFalse);
        expect(map.containsKey('experience_id'), isFalse);
        expect(map.containsKey('rule_id'), isFalse);
        // Required fields should be present
        expect(map['requested_time'], equals('2023-01-01 12:00:00.000Z'));
        expect(map['user_customer_id'], equals('user123'));
        expect(map['session_id'], equals('session456'));
      });
    });
    group('Unique Key Generation', () {
      test('should generate unique key with all fields', () {
        final summary = CFConfigRequestSummary(
          configId: 'config123',
          requestedTime: '2023-01-01 12:00:00.000Z',
          userCustomerId: 'user123',
          sessionId: 'session456',
          experienceId: 'experience101',
          variationId: 'variation456',
        );
        final key = summary.uniqueKey();
        expect(key, equals('config123_experience101_variation456'));
      });
      test('should generate unique key with null fields', () {
        final summary = CFConfigRequestSummary(
          requestedTime: '2023-01-01 12:00:00.000Z',
          userCustomerId: 'user123',
          sessionId: 'session456',
          // configId, experienceId, variationId are null
        );
        final key = summary.uniqueKey();
        expect(key, equals('unknown_unknown_unknown'));
      });
      test('should generate unique key with partial fields', () {
        final summary = CFConfigRequestSummary(
          configId: 'config123',
          requestedTime: '2023-01-01 12:00:00.000Z',
          userCustomerId: 'user123',
          sessionId: 'session456',
          experienceId: 'experience101',
          // variationId is null
        );
        final key = summary.uniqueKey();
        expect(key, equals('config123_experience101_unknown'));
      });
      test('should generate different keys for different summaries', () {
        final summary1 = CFConfigRequestSummary(
          configId: 'config1',
          requestedTime: '2023-01-01 12:00:00.000Z',
          userCustomerId: 'user123',
          sessionId: 'session456',
          experienceId: 'exp1',
          variationId: 'var1',
        );
        final summary2 = CFConfigRequestSummary(
          configId: 'config2',
          requestedTime: '2023-01-01 12:00:00.000Z',
          userCustomerId: 'user123',
          sessionId: 'session456',
          experienceId: 'exp2',
          variationId: 'var2',
        );
        expect(summary1.uniqueKey(), isNot(equals(summary2.uniqueKey())));
        expect(summary1.uniqueKey(), equals('config1_exp1_var1'));
        expect(summary2.uniqueKey(), equals('config2_exp2_var2'));
      });
    });
    group('String Representation', () {
      test('should provide meaningful toString', () {
        final summary = CFConfigRequestSummary(
          configId: 'config123',
          requestedTime: '2023-01-01 12:00:00.000Z',
          userCustomerId: 'user123',
          sessionId: 'session456',
          experienceId: 'experience101',
          variationId: 'variation456',
        );
        final string = summary.toString();
        expect(string, contains('CFConfigRequestSummary'));
        expect(string, contains('configId: config123'));
        expect(string, contains('experienceId: experience101'));
        expect(string, contains('variationId: variation456'));
      });
      test('should handle null values in toString', () {
        final summary = CFConfigRequestSummary(
          requestedTime: '2023-01-01 12:00:00.000Z',
          userCustomerId: 'user123',
          sessionId: 'session456',
        );
        final string = summary.toString();
        expect(string, contains('CFConfigRequestSummary'));
        expect(string, contains('configId: null'));
        expect(string, contains('experienceId: null'));
        expect(string, contains('variationId: null'));
      });
    });
    group('Edge Cases and Validation', () {
      test('should handle empty strings', () {
        final summary = CFConfigRequestSummary(
          configId: '',
          version: '',
          requestedTime: '2023-01-01 12:00:00.000Z',
          variationId: '',
          userCustomerId: 'user123',
          sessionId: 'session456',
          behaviourId: '',
          experienceId: '',
          ruleId: '',
        );
        final map = summary.toMap();
        // Empty strings should be preserved (not removed like nulls)
        expect(map['config_id'], equals(''));
        expect(map['version'], equals(''));
        expect(map['requested_time'], equals('2023-01-01 12:00:00.000Z'));
        expect(map['variation_id'], equals(''));
        expect(map['behaviour_id'], equals(''));
        expect(map['experience_id'], equals(''));
        expect(map['rule_id'], equals(''));
      });
      test('should handle special characters in fields', () {
        final summary = CFConfigRequestSummary(
          configId: 'config-123_special!@#',
          version: '1.0.0-beta+build.1',
          requestedTime: '2023-01-01 12:00:00.000Z',
          variationId: 'variation_456-test',
          userCustomerId: 'user+123@example.com',
          sessionId: 'session-456_789',
          behaviourId: 'behaviour#789',
          experienceId: 'experience\$101',
          ruleId: 'rule%202',
        );
        final jsonString = summary.toJson();
        final restored = CFConfigRequestSummary.fromMap(jsonDecode(jsonString));
        expect(restored.configId, equals('config-123_special!@#'));
        expect(restored.version, equals('1.0.0-beta+build.1'));
        expect(restored.requestedTime, equals('2023-01-01 12:00:00.000Z'));
        expect(restored.variationId, equals('variation_456-test'));
        expect(restored.userCustomerId, equals('user+123@example.com'));
        expect(restored.sessionId, equals('session-456_789'));
        expect(restored.behaviourId, equals('behaviour#789'));
        expect(restored.experienceId, equals('experience\$101'));
        expect(restored.ruleId, equals('rule%202'));
      });
      test('should handle unicode characters', () {
        final summary = CFConfigRequestSummary(
          configId: 'config-🎯',
          version: '1.0.0-α',
          requestedTime: '2023-01-01 12:00:00.000Z',
          variationId: 'variation-🚀',
          userCustomerId: 'user-日本語',
          sessionId: 'session-العربية',
          behaviourId: 'behaviour-русский',
          experienceId: 'experience-한국어',
          ruleId: 'rule-français',
        );
        final jsonString = summary.toJson();
        final restored = CFConfigRequestSummary.fromMap(jsonDecode(jsonString));
        expect(restored.configId, equals('config-🎯'));
        expect(restored.version, equals('1.0.0-α'));
        expect(restored.requestedTime, equals('2023-01-01 12:00:00.000Z'));
        expect(restored.variationId, equals('variation-🚀'));
        expect(restored.userCustomerId, equals('user-日本語'));
        expect(restored.sessionId, equals('session-العربية'));
        expect(restored.behaviourId, equals('behaviour-русский'));
        expect(restored.experienceId, equals('experience-한국어'));
        expect(restored.ruleId, equals('rule-français'));
      });
      test('should handle very long strings', () {
        final longString = 'a' * 1000;
        final summary = CFConfigRequestSummary(
          configId: longString,
          requestedTime: '2023-01-01 12:00:00.000Z',
          userCustomerId: 'user123',
          sessionId: 'session456',
          variationId: 'variation456',
          experienceId: 'experience101',
          behaviourId: 'behaviour789',
          ruleId: 'rule202',
        );
        final jsonString = summary.toJson();
        final restored = CFConfigRequestSummary.fromMap(jsonDecode(jsonString));
        expect(restored.configId, equals(longString));
        expect(restored.configId, hasLength(1000));
      });
    });
    group('Timestamp Formatting', () {
      test('should format timestamps correctly', () {
        final testCases = [
          DateTime.utc(2023, 1, 1, 12, 0, 0, 0),
          DateTime.utc(2023, 12, 31, 23, 59, 59, 999),
          DateTime.utc(2000, 1, 1, 0, 0, 0, 1),
          DateTime.utc(2099, 6, 15, 14, 30, 45, 123),
        ];
        // Test that timestamp is always in the correct format regardless of the current time
        for (int i = 0; i < testCases.length; i++) {
          final config = {'test': 'value', 'index': i};
          // Create a summary that uses the internal timestamp formatting
          final summary = CFConfigRequestSummary.fromConfig(
            config,
            'user123',
            'session456',
          );
          // The timestamp should match the expected format
          expect(summary.requestedTime,
              matches(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}Z$'));
          // Verify different configs produce different summaries
          // Note: The summary doesn't retain the original config, it extracts specific fields
          // We can verify uniqueness by checking the summary object itself or its fields
        }
      });
      test('should handle edge case timestamps', () {
        final config = {'test': 'value'};
        final summary = CFConfigRequestSummary.fromConfig(
          config,
          'user123',
          'session456',
        );
        // Should produce a valid timestamp
        final timestamp = summary.requestedTime;
        expect(timestamp, isNotEmpty);
        expect(timestamp, endsWith('Z'));
        expect(timestamp, contains(' '));
        expect(timestamp, contains('.'));
        // Should be parseable as a DateTime
        final parsed = DateTime.parse(timestamp.replaceAll(' ', 'T'));
        expect(parsed, isA<DateTime>());
        expect(parsed.isUtc, isTrue);
      });
    });
    group('Integration and Compatibility', () {
      test('should be compatible with backend format', () {
        final summary = CFConfigRequestSummary(
          configId: 'config123',
          version: '1.0.0',
          requestedTime: '2023-01-01 12:00:00.000Z',
          variationId: 'variation456',
          userCustomerId: 'user123',
          sessionId: 'session456',
          behaviourId: 'behaviour789',
          experienceId: 'experience101',
          ruleId: 'rule202',
        );
        final map = summary.toMap();
        // Should use snake_case keys (backend format)
        expect(map.keys, contains('config_id'));
        expect(map.keys, contains('requested_time'));
        expect(map.keys, contains('variation_id'));
        expect(map.keys, contains('user_customer_id'));
        expect(map.keys, contains('session_id'));
        expect(map.keys, contains('behaviour_id'));
        expect(map.keys, contains('experience_id'));
        expect(map.keys, contains('rule_id'));
        // Should not contain camelCase keys
        expect(map.keys, isNot(contains('configId')));
        expect(map.keys, isNot(contains('requestedTime')));
      });
      test('should maintain data integrity across serialization', () {
        final originalData = {
          'config_id': 'config123',
          'version': '1.0.0',
          'requested_time': '2023-01-01 12:00:00.000Z',
          'variation_id': 'variation456',
          'user_customer_id': 'user123',
          'session_id': 'session456',
          'behaviour_id': 'behaviour789',
          'experience_id': 'experience101',
          'rule_id': 'rule202',
        };
        // Create from map, serialize to JSON, deserialize back
        final summary1 = CFConfigRequestSummary.fromMap(originalData);
        final jsonString = summary1.toJson();
        final summary2 = CFConfigRequestSummary.fromMap(jsonDecode(jsonString));
        final finalMap = summary2.toMap();
        // All data should be preserved
        expect(finalMap['config_id'], equals(originalData['config_id']));
        expect(finalMap['version'], equals(originalData['version']));
        expect(
            finalMap['requested_time'], equals(originalData['requested_time']));
        expect(finalMap['variation_id'], equals(originalData['variation_id']));
        expect(finalMap['user_customer_id'],
            equals(originalData['user_customer_id']));
        expect(finalMap['session_id'], equals(originalData['session_id']));
        expect(finalMap['behaviour_id'], equals(originalData['behaviour_id']));
        expect(
            finalMap['experience_id'], equals(originalData['experience_id']));
        expect(finalMap['rule_id'], equals(originalData['rule_id']));
      });
    });
  });
}
