import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/sdk_settings.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('SdkSettings', () {
    group('Constructor', () {
      test('should create instance with provided values', () {
        final ruleEvents = ['event1', 'event2', 'event3'];
        final settings = SdkSettings(
          cfAccountEnabled: true,
          cfSkipSdk: false,
          ruleEvents: ruleEvents,
        );
        expect(settings.cfAccountEnabled, isTrue);
        expect(settings.cfSkipSdk, isFalse);
        expect(settings.ruleEvents, equals(ruleEvents));
      });
      test('should create instance with all false/empty values', () {
        const settings = SdkSettings(
          cfAccountEnabled: false,
          cfSkipSdk: true,
          ruleEvents: [],
        );
        expect(settings.cfAccountEnabled, isFalse);
        expect(settings.cfSkipSdk, isTrue);
        expect(settings.ruleEvents, isEmpty);
      });
    });
    group('fromJson', () {
      test('should create instance from complete JSON', () {
        final json = {
          'cf_account_enabled': true,
          'cf_skip_sdk': false,
          'rule_events': ['event1', 'event2'],
        };
        final settings = SdkSettings.fromJson(json);
        expect(settings.cfAccountEnabled, isTrue);
        expect(settings.cfSkipSdk, isFalse);
        expect(settings.ruleEvents, equals(['event1', 'event2']));
      });
      test('should use default values for missing fields', () {
        final json = <String, dynamic>{};
        final settings = SdkSettings.fromJson(json);
        expect(settings.cfAccountEnabled, isTrue); // Default
        expect(settings.cfSkipSdk, isFalse); // Default
        expect(settings.ruleEvents, isEmpty); // Default
      });
      test('should handle null values with defaults', () {
        final json = {
          'cf_account_enabled': null,
          'cf_skip_sdk': null,
          'rule_events': null,
        };
        final settings = SdkSettings.fromJson(json);
        expect(settings.cfAccountEnabled, isTrue);
        expect(settings.cfSkipSdk, isFalse);
        expect(settings.ruleEvents, isEmpty);
      });
      test('should handle partial JSON', () {
        final json = {
          'cf_account_enabled': false,
          'rule_events': ['single_event'],
        };
        final settings = SdkSettings.fromJson(json);
        expect(settings.cfAccountEnabled, isFalse);
        expect(settings.cfSkipSdk, isFalse); // Default
        expect(settings.ruleEvents, equals(['single_event']));
      });
      test('should handle non-list rule_events', () {
        final json = {
          'cf_account_enabled': true,
          'cf_skip_sdk': false,
          'rule_events': 'not_a_list',
        };
        // This should throw an exception as the implementation doesn't handle non-lists
        expect(() => SdkSettings.fromJson(json), throwsA(isA<TypeError>()));
      });
      test('should convert rule_events from mixed types', () {
        final json = {
          'rule_events': [1, 'string_event', true, null],
        };
        // This should throw an exception as the implementation expects strings
        expect(() => SdkSettings.fromJson(json), throwsA(isA<TypeError>()));
      });
    });
    group('toJson', () {
      test('should convert to JSON with all fields', () {
        const settings = SdkSettings(
          cfAccountEnabled: true,
          cfSkipSdk: false,
          ruleEvents: ['event1', 'event2'],
        );
        final json = settings.toJson();
        expect(json['cf_account_enabled'], isTrue);
        expect(json['cf_skip_sdk'], isFalse);
        expect(json['rule_events'], equals(['event1', 'event2']));
      });
      test('should handle empty rule events', () {
        const settings = SdkSettings(
          cfAccountEnabled: false,
          cfSkipSdk: true,
          ruleEvents: [],
        );
        final json = settings.toJson();
        expect(json['cf_account_enabled'], isFalse);
        expect(json['cf_skip_sdk'], isTrue);
        expect(json['rule_events'], isEmpty);
      });
    });
    group('copyWith', () {
      test('should create copy with updated cfAccountEnabled', () {
        const original = SdkSettings(
          cfAccountEnabled: true,
          cfSkipSdk: false,
          ruleEvents: ['event1'],
        );
        final updated = original.copyWith(cfAccountEnabled: false);
        expect(updated.cfAccountEnabled, isFalse);
        expect(updated.cfSkipSdk, equals(original.cfSkipSdk));
        expect(updated.ruleEvents, equals(original.ruleEvents));
      });
      test('should create copy with updated cfSkipSdk', () {
        const original = SdkSettings(
          cfAccountEnabled: true,
          cfSkipSdk: false,
          ruleEvents: ['event1'],
        );
        final updated = original.copyWith(cfSkipSdk: true);
        expect(updated.cfAccountEnabled, equals(original.cfAccountEnabled));
        expect(updated.cfSkipSdk, isTrue);
        expect(updated.ruleEvents, equals(original.ruleEvents));
      });
      test('should create copy with updated ruleEvents', () {
        const original = SdkSettings(
          cfAccountEnabled: true,
          cfSkipSdk: false,
          ruleEvents: ['event1'],
        );
        final newEvents = ['event2', 'event3'];
        final updated = original.copyWith(ruleEvents: newEvents);
        expect(updated.cfAccountEnabled, equals(original.cfAccountEnabled));
        expect(updated.cfSkipSdk, equals(original.cfSkipSdk));
        expect(updated.ruleEvents, equals(newEvents));
      });
      test('should create copy with multiple updates', () {
        const original = SdkSettings(
          cfAccountEnabled: true,
          cfSkipSdk: false,
          ruleEvents: ['event1'],
        );
        final updated = original.copyWith(
          cfAccountEnabled: false,
          cfSkipSdk: true,
          ruleEvents: ['new_event'],
        );
        expect(updated.cfAccountEnabled, isFalse);
        expect(updated.cfSkipSdk, isTrue);
        expect(updated.ruleEvents, equals(['new_event']));
      });
      test('should create identical copy when no parameters provided', () {
        const original = SdkSettings(
          cfAccountEnabled: true,
          cfSkipSdk: false,
          ruleEvents: ['event1'],
        );
        final copy = original.copyWith();
        expect(copy.cfAccountEnabled, equals(original.cfAccountEnabled));
        expect(copy.cfSkipSdk, equals(original.cfSkipSdk));
        expect(copy.ruleEvents, equals(original.ruleEvents));
      });
    });
    group('Round-trip serialization', () {
      test('should maintain data integrity through JSON cycle', () {
        const original = SdkSettings(
          cfAccountEnabled: false,
          cfSkipSdk: true,
          ruleEvents: ['event1', 'event2', 'event3'],
        );
        final json = original.toJson();
        final restored = SdkSettings.fromJson(json);
        expect(restored.cfAccountEnabled, equals(original.cfAccountEnabled));
        expect(restored.cfSkipSdk, equals(original.cfSkipSdk));
        expect(restored.ruleEvents, equals(original.ruleEvents));
      });
    });
  });
  group('SdkSettingsBuilder', () {
    group('Builder Pattern', () {
      test('should create builder with default values', () {
        final settings = SdkSettings.builder().build().getOrThrow();
        expect(settings.cfAccountEnabled, isTrue); // Default
        expect(settings.cfSkipSdk, isFalse); // Default
        expect(settings.ruleEvents, isEmpty); // Default
      });
      test('should build with cfAccountEnabled', () {
        final settings = SdkSettings.builder().cfAccountEnabled(false).build().getOrThrow();
        expect(settings.cfAccountEnabled, isFalse);
        expect(settings.cfSkipSdk, isFalse);
        expect(settings.ruleEvents, isEmpty);
      });
      test('should build with cfSkipSdk', () {
        final settings = SdkSettings.builder().cfSkipSdk(true).build().getOrThrow();
        expect(settings.cfAccountEnabled, isTrue);
        expect(settings.cfSkipSdk, isTrue);
        expect(settings.ruleEvents, isEmpty);
      });
      test('should build with ruleEvents', () {
        final events = ['event1', 'event2'];
        final settings = SdkSettings.builder().ruleEvents(events).build().getOrThrow();
        expect(settings.cfAccountEnabled, isTrue);
        expect(settings.cfSkipSdk, isFalse);
        expect(settings.ruleEvents, equals(events));
      });
      test('should build with all properties', () {
        final events = ['event1', 'event2', 'event3'];
        final settings = SdkSettings.builder()
            .cfAccountEnabled(false)
            .cfSkipSdk(true)
            .ruleEvents(events)
            .build().getOrThrow();
        expect(settings.cfAccountEnabled, isFalse);
        expect(settings.cfSkipSdk, isTrue);
        expect(settings.ruleEvents, equals(events));
      });
      test('should support method chaining', () {
        final events = ['chained_event'];
        final settings = SdkSettings.builder()
            .cfAccountEnabled(false)
            .cfSkipSdk(true)
            .ruleEvents(events)
            .build().getOrThrow();
        expect(settings.cfAccountEnabled, isFalse);
        expect(settings.cfSkipSdk, isTrue);
        expect(settings.ruleEvents, equals(events));
      });
      test('should allow property overriding', () {
        final builder = SdkSettings.builder()
            .cfAccountEnabled(true)
            .cfAccountEnabled(false); // Override
        final settings = builder.build().getOrThrow();
        expect(settings.cfAccountEnabled, isFalse);
      });
      test('should handle empty rule events', () {
        final settings = SdkSettings.builder().ruleEvents([]).build().getOrThrow();
        expect(settings.ruleEvents, isEmpty);
      });
      test('should handle multiple rule events updates', () {
        final builder = SdkSettings.builder().ruleEvents(['event1']).ruleEvents(
            ['event2', 'event3']); // Override
        final settings = builder.build().getOrThrow();
        expect(settings.ruleEvents, equals(['event2', 'event3']));
      });
    });
    group('Builder Factory', () {
      test('should create new builder instance each time', () {
        final builder1 = SdkSettings.builder();
        final builder2 = SdkSettings.builder();
        expect(identical(builder1, builder2), isFalse);
        // Modify one builder
        builder1.cfAccountEnabled(false);
        final settings1 = builder1.build().getOrThrow();
        final settings2 = builder2.build().getOrThrow();
        expect(settings1.cfAccountEnabled, isFalse);
        expect(settings2.cfAccountEnabled, isTrue); // Should not be affected
      });
    });
    group('Edge Cases', () {
      test('should handle very large rule events list', () {
        final largeEventsList = List.generate(1000, (index) => 'event_$index');
        final settings =
            SdkSettings.builder().ruleEvents(largeEventsList).build().getOrThrow();
        expect(settings.ruleEvents, equals(largeEventsList));
        expect(settings.ruleEvents.length, equals(1000));
      });
      test('should handle special characters in rule events', () {
        final specialEvents = [
          'event with spaces',
          'event-with-dashes',
          'event_with_underscores',
          'event.with.dots',
          'event@with@symbols',
          'event🚀with🌟emojis',
        ];
        final settings =
            SdkSettings.builder().ruleEvents(specialEvents).build().getOrThrow();
        expect(settings.ruleEvents, equals(specialEvents));
      });
      test('should handle duplicate events in rule events', () {
        final eventsWithDuplicates = [
          'event1',
          'event2',
          'event1',
          'event3',
          'event2'
        ];
        final settings =
            SdkSettings.builder().ruleEvents(eventsWithDuplicates).build().getOrThrow();
        expect(settings.ruleEvents,
            equals(eventsWithDuplicates)); // Should preserve duplicates
      });
    });
  });
}
