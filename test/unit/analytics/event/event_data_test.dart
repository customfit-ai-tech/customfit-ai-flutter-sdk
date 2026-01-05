// test/unit/analytics/event/event_data_test.dart
//
// Tests for EventData class
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_data.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_type.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('EventData', () {
    const testEventId = 'test-event-id-123';
    const testCustomerId = 'customer-456';
    const testSessionId = 'session-789';
    const testTimestamp = 1640995200000; // 2022-01-01T00:00:00.000Z
    final testProperties = {'key1': 'value1', 'key2': 42, 'key3': true};
    group('Constructor', () {
      test('should create EventData with all required fields', () {
        final eventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          properties: testProperties,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
        expect(eventData.eventId, equals(testEventId));
        expect(eventData.eventCustomerId, equals(testCustomerId));
        expect(eventData.eventType, equals(EventType.track));
        expect(eventData.properties, equals(testProperties));
        expect(eventData.sessionId, equals(testSessionId));
        expect(eventData.eventTimestamp, equals(testTimestamp));
      });
      test('should create EventData with empty properties by default', () {
        final eventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
        expect(eventData.properties, isEmpty);
        expect(eventData.properties, equals(const <String, dynamic>{}));
      });
      test('should handle null and edge case properties', () {
        final edgeProperties = {
          'null_value': null,
          'empty_string': '',
          'zero': 0,
          'false_bool': false,
          'empty_list': <String>[],
          'empty_map': <String, dynamic>{},
        };
        final eventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          properties: edgeProperties,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
        expect(eventData.properties, equals(edgeProperties));
      });
    });
    group('Factory Constructor - create', () {
      test('should create EventData with auto-generated values', () {
        final eventData = EventData.create(
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          properties: testProperties,
          sessionId: testSessionId,
        );
        expect(eventData.eventId, isNotEmpty);
        expect(eventData.eventId,
            matches(RegExp(r'^[0-9a-f-]{36}$'))); // UUID v4 format
        expect(eventData.eventCustomerId, equals(testCustomerId));
        expect(eventData.eventType, equals(EventType.track));
        expect(eventData.properties, equals(testProperties));
        expect(eventData.sessionId, equals(testSessionId));
        expect(eventData.eventTimestamp, isA<int>());
        expect(eventData.eventTimestamp, greaterThan(0));
      });
      test('should use provided timestamp when given', () {
        final eventData = EventData.create(
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
        expect(eventData.eventTimestamp, equals(testTimestamp));
      });
      test('should generate current timestamp when not provided', () {
        final beforeCreation = DateTime.now().millisecondsSinceEpoch;
        final eventData = EventData.create(
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          sessionId: testSessionId,
        );
        final afterCreation = DateTime.now().millisecondsSinceEpoch;
        expect(eventData.eventTimestamp, greaterThanOrEqualTo(beforeCreation));
        expect(eventData.eventTimestamp, lessThanOrEqualTo(afterCreation));
      });
      test('should generate unique event IDs', () {
        final eventData1 = EventData.create(
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          sessionId: testSessionId,
        );
        final eventData2 = EventData.create(
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          sessionId: testSessionId,
        );
        expect(eventData1.eventId, isNot(equals(eventData2.eventId)));
      });
      test('should use empty properties by default', () {
        final eventData = EventData.create(
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          sessionId: testSessionId,
        );
        expect(eventData.properties, isEmpty);
      });
    });
    group('JSON Serialization', () {
      late EventData testEventData;
      setUp(() {
        testEventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          properties: testProperties,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
      });
      test('should convert to map correctly', () {
        final map = testEventData.toMap();
        expect(map['eventId'], equals(testEventId));
        expect(map['eventCustomerId'], equals(testCustomerId));
        expect(map['eventType'], equals('track'));
        expect(map['properties'], equals(testProperties));
        expect(map['sessionId'], equals(testSessionId));
        expect(map['eventTimestamp'], equals(testTimestamp));
      });
      test('should create from map correctly', () {
        final map = {
          'eventId': testEventId,
          'eventCustomerId': testCustomerId,
          'eventType': 'track',
          'properties': testProperties,
          'sessionId': testSessionId,
          'eventTimestamp': testTimestamp,
        };
        final eventData = EventData.fromMap(map);
        expect(eventData.eventId, equals(testEventId));
        expect(eventData.eventCustomerId, equals(testCustomerId));
        expect(eventData.eventType, equals(EventType.track));
        expect(eventData.properties, equals(testProperties));
        expect(eventData.sessionId, equals(testSessionId));
        expect(eventData.eventTimestamp, equals(testTimestamp));
      });
      test('should handle round-trip serialization', () {
        final map = testEventData.toMap();
        final restored = EventData.fromMap(map);
        expect(restored.eventId, equals(testEventData.eventId));
        expect(restored.eventCustomerId, equals(testEventData.eventCustomerId));
        expect(restored.eventType, equals(testEventData.eventType));
        expect(restored.properties, equals(testEventData.properties));
        expect(restored.sessionId, equals(testEventData.sessionId));
        expect(restored.eventTimestamp, equals(testEventData.eventTimestamp));
      });
      test('should support toJson alias', () {
        final toMapResult = testEventData.toMap();
        final toJsonResult = testEventData.toJson();
        expect(toJsonResult, equals(toMapResult));
      });
      test('should support fromJson alias', () {
        final map = testEventData.toMap();
        final fromMap = EventData.fromMap(map);
        final fromJson = EventData.fromJson(map);
        expect(fromJson.eventId, equals(fromMap.eventId));
        expect(fromJson.eventCustomerId, equals(fromMap.eventCustomerId));
        expect(fromJson.eventType, equals(fromMap.eventType));
        expect(fromJson.properties, equals(fromMap.properties));
        expect(fromJson.sessionId, equals(fromMap.sessionId));
        expect(fromJson.eventTimestamp, equals(fromMap.eventTimestamp));
      });
    });
    group('JSON String Conversion', () {
      late EventData testEventData;
      setUp(() {
        testEventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          properties: testProperties,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
      });
      test('should convert to JSON string', () {
        final jsonString = testEventData.toJsonString();
        expect(jsonString, isA<String>());
        expect(jsonString, isNotEmpty);
        // Verify it's valid JSON
        final decoded = jsonDecode(jsonString);
        expect(decoded, isA<Map<String, dynamic>>());
      });
      test('should create from JSON string', () {
        final jsonString = testEventData.toJsonString();
        final restored = EventData.fromJsonString(jsonString);
        expect(restored.eventId, equals(testEventData.eventId));
        expect(restored.eventCustomerId, equals(testEventData.eventCustomerId));
        expect(restored.eventType, equals(testEventData.eventType));
        expect(restored.properties, equals(testEventData.properties));
        expect(restored.sessionId, equals(testEventData.sessionId));
        expect(restored.eventTimestamp, equals(testEventData.eventTimestamp));
      });
      test('should handle round-trip JSON string conversion', () {
        final jsonString = testEventData.toJsonString();
        final restored = EventData.fromJsonString(jsonString);
        final restoredJsonString = restored.toJsonString();
        final originalDecoded = jsonDecode(jsonString);
        final restoredDecoded = jsonDecode(restoredJsonString);
        expect(restoredDecoded, equals(originalDecoded));
      });
      test('should handle complex properties in JSON string', () {
        final complexProperties = {
          'nested': {
            'level1': {'level2': 'value'}
          },
          'list': [1, 2, 3, 'string', true],
          'mixed': {'number': 42, 'boolean': false, 'null': null},
        };
        final eventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          properties: complexProperties,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
        final jsonString = eventData.toJsonString();
        final restored = EventData.fromJsonString(jsonString);
        expect(restored.properties, equals(complexProperties));
      });
    });
    group('API Serialization', () {
      late EventData testEventData;
      setUp(() {
        testEventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          properties: testProperties,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
      });
      test('should serialize for API with correct field mapping', () {
        final apiData = testEventData.serializeForAPI();
        expect(apiData['insert_id'], equals(testEventId));
        expect(apiData['event_customer_id'], equals(testCustomerId));
        expect(apiData['event_type'], equals('TRACK'));
        expect(apiData['properties'], equals(testProperties));
        expect(apiData['session_id'], equals(testSessionId));
        expect(apiData['event_timestamp'], isA<String>());
      });
      test('should format timestamp correctly for API', () {
        final apiData = testEventData.serializeForAPI();
        final timestamp = apiData['event_timestamp'] as String;
        expect(timestamp, equals('2022-01-01 00:00:00.000Z'));
        expect(timestamp,
            matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}Z$')));
      });
      test('should handle different timestamps correctly', () {
        final testCases = [
          1640995200000, // 2022-01-01T00:00:00.000Z
          1640995200123, // 2022-01-01T00:00:00.123Z
          1609459200000, // 2021-01-01T00:00:00.000Z
          1672531200000, // 2023-01-01T00:00:00.000Z
        ];
        final expectedFormats = [
          '2022-01-01 00:00:00.000Z',
          '2022-01-01 00:00:00.123Z',
          '2021-01-01 00:00:00.000Z',
          '2023-01-01 00:00:00.000Z',
        ];
        for (int i = 0; i < testCases.length; i++) {
          final eventData = EventData(
            eventId: testEventId,
            eventCustomerId: testCustomerId,
            eventType: EventType.track,
            sessionId: testSessionId,
            eventTimestamp: testCases[i],
          );
          final apiData = eventData.serializeForAPI();
          expect(apiData['event_timestamp'], equals(expectedFormats[i]));
        }
      });
      test('should convert event type to uppercase', () {
        final apiData = testEventData.serializeForAPI();
        expect(apiData['event_type'], equals('TRACK'));
      });
      test('should preserve properties exactly', () {
        final complexProperties = {
          'string': 'value',
          'number': 42,
          'boolean': true,
          'null': null,
          'nested': {'key': 'value'},
          'list': [1, 2, 3],
        };
        final eventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          properties: complexProperties,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
        final apiData = eventData.serializeForAPI();
        expect(apiData['properties'], equals(complexProperties));
      });
    });
    group('Timestamp Formatting', () {
      test('should format various timestamps correctly', () {
        final testCases = [
          {'timestamp': 0, 'expected': '1970-01-01 00:00:00.000Z'},
          {'timestamp': 1640995200000, 'expected': '2022-01-01 00:00:00.000Z'},
          {'timestamp': 1640995200123, 'expected': '2022-01-01 00:00:00.123Z'},
          {'timestamp': 1640995261456, 'expected': '2022-01-01 00:01:01.456Z'},
        ];
        for (final testCase in testCases) {
          final eventData = EventData(
            eventId: testEventId,
            eventCustomerId: testCustomerId,
            eventType: EventType.track,
            sessionId: testSessionId,
            eventTimestamp: testCase['timestamp'] as int,
          );
          final apiData = eventData.serializeForAPI();
          expect(apiData['event_timestamp'], equals(testCase['expected']),
              reason: 'Failed for timestamp: ${testCase['timestamp']}');
        }
      });
      test('should handle edge case timestamps', () {
        final edgeCases = [
          1, // Very small timestamp
          DateTime.now().millisecondsSinceEpoch, // Current time
          2147483647000, // Near max 32-bit timestamp
        ];
        for (final timestamp in edgeCases) {
          final eventData = EventData(
            eventId: testEventId,
            eventCustomerId: testCustomerId,
            eventType: EventType.track,
            sessionId: testSessionId,
            eventTimestamp: timestamp,
          );
          final apiData = eventData.serializeForAPI();
          final formattedTimestamp = apiData['event_timestamp'] as String;
          expect(
              formattedTimestamp,
              matches(
                  RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}Z$')));
          expect(formattedTimestamp, endsWith('Z'));
        }
      });
    });
    group('Edge Cases and Error Handling', () {
      test('should handle empty strings', () {
        final eventData = EventData(
          eventId: '',
          eventCustomerId: '',
          eventType: EventType.track,
          sessionId: '',
          eventTimestamp: testTimestamp,
        );
        expect(eventData.eventId, isEmpty);
        expect(eventData.eventCustomerId, isEmpty);
        expect(eventData.sessionId, isEmpty);
        final map = eventData.toMap();
        expect(map['eventId'], isEmpty);
        expect(map['eventCustomerId'], isEmpty);
        expect(map['sessionId'], isEmpty);
      });
      test('should handle very large properties', () {
        final largeProperties = <String, dynamic>{};
        for (int i = 0; i < 1000; i++) {
          largeProperties['key$i'] = 'value$i';
        }
        final eventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          properties: largeProperties,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
        expect(eventData.properties, hasLength(1000));
        // Should be able to serialize
        final jsonString = eventData.toJsonString();
        expect(jsonString, isNotEmpty);
        // Should be able to deserialize
        final restored = EventData.fromJsonString(jsonString);
        expect(restored.properties, hasLength(1000));
      });
      test('should handle special characters in properties', () {
        final specialProperties = {
          'unicode': 'Hello 🌍',
          'newlines': 'Line 1\nLine 2\nLine 3',
          'quotes': 'He said "Hello" to her',
          'backslashes': 'Path\\to\\file',
          'tabs': 'Column1\tColumn2\tColumn3',
        };
        final eventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          properties: specialProperties,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
        final jsonString = eventData.toJsonString();
        final restored = EventData.fromJsonString(jsonString);
        expect(restored.properties, equals(specialProperties));
      });
      test('should handle deeply nested properties', () {
        final deepProperties = {
          'level1': {
            'level2': {
              'level3': {
                'level4': {'level5': 'deep value'}
              }
            }
          }
        };
        final eventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          properties: deepProperties,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
        final jsonString = eventData.toJsonString();
        final restored = EventData.fromJsonString(jsonString);
        expect(restored.properties, equals(deepProperties));
      });
    });
    group('Type Safety and Validation', () {
      test('should maintain type safety for all fields', () {
        final eventData = EventData.create(
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          sessionId: testSessionId,
        );
        expect(eventData.eventId, isA<String>());
        expect(eventData.eventCustomerId, isA<String>());
        expect(eventData.eventType, isA<EventType>());
        expect(eventData.properties, isA<Map<String, dynamic>>());
        expect(eventData.sessionId, isA<String>());
        expect(eventData.eventTimestamp, isA<int>());
      });
      test('should handle type conversion in fromMap', () {
        final map = {
          'eventId': testEventId,
          'eventCustomerId': testCustomerId,
          'eventType': 'TRACK', // Different case
          'properties': testProperties,
          'sessionId': testSessionId,
          'eventTimestamp': testTimestamp,
        };
        final eventData = EventData.fromMap(map);
        expect(eventData.eventType, equals(EventType.track));
      });
      test('should work with different EventType values', () {
        final eventData = EventData(
          eventId: testEventId,
          eventCustomerId: testCustomerId,
          eventType: EventType.track,
          sessionId: testSessionId,
          eventTimestamp: testTimestamp,
        );
        final map = eventData.toMap();
        expect(map['eventType'], equals('track'));
        final apiData = eventData.serializeForAPI();
        expect(apiData['event_type'], equals('TRACK'));
      });
    });
  });
}
