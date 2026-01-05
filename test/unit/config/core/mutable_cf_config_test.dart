import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/mutable_cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart'
    hide MutableCFConfig;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CFConfig testConfig;
  late MutableCFConfig mutableConfig;
  setUp(() {
    testConfig = CFConfig.builder(
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c')
        .setOfflineMode(false)
        .setDebugLoggingEnabled(true)
        .setEventsFlushIntervalMs(30000)
        .setNetworkConnectionTimeoutMs(10000)
        .setAutoEnvAttributesEnabled(true)
        .build()
        .getOrThrow();
    mutableConfig = MutableCFConfig(testConfig);
  });
  group('MutableCFConfig Constructor Tests', () {
    test('should initialize with provided config', () {
      expect(mutableConfig.config, equals(testConfig));
      expect(mutableConfig.offlineMode, equals(testConfig.offlineMode));
      expect(mutableConfig.autoEnvAttributesEnabled,
          equals(testConfig.autoEnvAttributesEnabled));
    });
    test('should initialize with empty changes', () {
      expect(mutableConfig.hasChanges, false);
      expect(mutableConfig.getChanges(), isEmpty);
    });
    test('should initialize offline mode from config', () {
      final offlineConfig = CFConfig.builder(
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c')
          .setOfflineMode(true)
          .build()
          .getOrThrow();
      final mutableOfflineConfig = MutableCFConfig(offlineConfig);
      expect(mutableOfflineConfig.offlineMode, true);
    });
  });
  group('Offline Mode Tests', () {
    test('should get current offline mode', () {
      expect(mutableConfig.offlineMode, false);
    });
    test('should set offline mode and track changes', () {
      // Initially false
      expect(mutableConfig.offlineMode, false);
      expect(mutableConfig.hasChanges, false);
      // Set to true
      mutableConfig.setOfflineMode(true);
      expect(mutableConfig.offlineMode, true);
      expect(mutableConfig.hasChanges, true);
      final changes = mutableConfig.getChanges();
      expect(changes.containsKey('offlineMode'), true);
      expect(changes['offlineMode']['oldValue'], false);
      expect(changes['offlineMode']['newValue'], true);
      expect(changes['offlineMode']['timestamp'], isA<String>());
    });
    test('should not track changes when setting same value', () {
      // Set to current value (false)
      mutableConfig.setOfflineMode(false);
      expect(mutableConfig.hasChanges, false);
      expect(mutableConfig.getChanges(), isEmpty);
      // Set to true, then back to true
      mutableConfig.setOfflineMode(true);
      expect(mutableConfig.hasChanges, true);
      final initialChangesCount = mutableConfig.getChanges().length;
      mutableConfig.setOfflineMode(true); // Same value
      expect(mutableConfig.getChanges().length, equals(initialChangesCount));
    });
    test('should handle multiple offline mode changes', () {
      mutableConfig.setOfflineMode(true);
      mutableConfig.setOfflineMode(false);
      mutableConfig.setOfflineMode(true);
      expect(mutableConfig.offlineMode, true);
      expect(mutableConfig.hasChanges, true);
      final changes = mutableConfig.getChanges();
      expect(changes.containsKey('offlineMode'), true);
    });
  });
  group('Auto Environment Attributes Tests', () {
    test('should get auto environment attributes from underlying config', () {
      expect(mutableConfig.autoEnvAttributesEnabled,
          testConfig.autoEnvAttributesEnabled);
    });
    test(
        'should reflect config value when config has auto env attributes disabled',
        () {
      final configWithoutAutoEnv = CFConfig.builder(
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c')
          .setAutoEnvAttributesEnabled(false)
          .build()
          .getOrThrow();
      final mutableConfigWithoutAutoEnv = MutableCFConfig(configWithoutAutoEnv);
      expect(mutableConfigWithoutAutoEnv.autoEnvAttributesEnabled, false);
    });
  });
  group('Change Listener Tests', () {
    test('should add and notify change listeners', () {
      String? lastProperty;
      dynamic lastOldValue;
      dynamic lastNewValue;
      int notificationCount = 0;
      void listener(String property, dynamic oldValue, dynamic newValue) {
        lastProperty = property;
        lastOldValue = oldValue;
        lastNewValue = newValue;
        notificationCount++;
      }

      mutableConfig.addChangeListener(listener);
      mutableConfig.setOfflineMode(true);
      expect(notificationCount, 1);
      expect(lastProperty, 'offlineMode');
      expect(lastOldValue, false);
      expect(lastNewValue, true);
    });
    test('should support multiple change listeners', () {
      int listener1Count = 0;
      int listener2Count = 0;
      void listener1(String property, dynamic oldValue, dynamic newValue) {
        listener1Count++;
      }

      void listener2(String property, dynamic oldValue, dynamic newValue) {
        listener2Count++;
      }

      mutableConfig.addChangeListener(listener1);
      mutableConfig.addChangeListener(listener2);
      mutableConfig.setOfflineMode(true);
      expect(listener1Count, 1);
      expect(listener2Count, 1);
    });
    test('should remove change listeners', () {
      int notificationCount = 0;
      void listener(String property, dynamic oldValue, dynamic newValue) {
        notificationCount++;
      }

      mutableConfig.addChangeListener(listener);
      mutableConfig.setOfflineMode(true);
      expect(notificationCount, 1);
      mutableConfig.removeChangeListener(listener);
      mutableConfig.setOfflineMode(false);
      expect(notificationCount, 1); // Should not increase
    });
    test('should handle listener exceptions gracefully', () {
      void faultyListener(String property, dynamic oldValue, dynamic newValue) {
        throw Exception('Listener error');
      }

      void normalListener(String property, dynamic oldValue, dynamic newValue) {
        // This should still be called despite the faulty listener
      }
      mutableConfig.addChangeListener(faultyListener);
      mutableConfig.addChangeListener(normalListener);
      // Should not throw exception
      expect(() => mutableConfig.setOfflineMode(true), returnsNormally);
      expect(mutableConfig.offlineMode, true);
    });
    test('should not notify listeners when value does not change', () {
      int notificationCount = 0;
      void listener(String property, dynamic oldValue, dynamic newValue) {
        notificationCount++;
      }

      mutableConfig.addChangeListener(listener);
      mutableConfig.setOfflineMode(false); // Same as current value
      expect(notificationCount, 0);
    });
  });
  group('Change Tracking Tests', () {
    test('should track changes with timestamps', () {
      final beforeChange = DateTime.now();
      mutableConfig.setOfflineMode(true);
      final afterChange = DateTime.now();
      final changes = mutableConfig.getChanges();
      expect(changes.containsKey('offlineMode'), true);
      final changeData = changes['offlineMode'];
      expect(changeData['oldValue'], false);
      expect(changeData['newValue'], true);
      final timestamp = DateTime.parse(changeData['timestamp']);
      expect(
          timestamp.isAfter(beforeChange) ||
              timestamp.isAtSameMomentAs(beforeChange),
          true);
      expect(
          timestamp.isBefore(afterChange) ||
              timestamp.isAtSameMomentAs(afterChange),
          true);
    });
    test('should return unmodifiable changes map', () {
      mutableConfig.setOfflineMode(true);
      final changes = mutableConfig.getChanges();
      expect(() => changes['newKey'] = 'newValue', throwsUnsupportedError);
    });
    test('should clear change history', () {
      mutableConfig.setOfflineMode(true);
      expect(mutableConfig.hasChanges, true);
      expect(mutableConfig.getChanges().isNotEmpty, true);
      mutableConfig.clearChangeHistory();
      expect(mutableConfig.hasChanges, false);
      expect(mutableConfig.getChanges().isEmpty, true);
      // Current state should remain unchanged
      expect(mutableConfig.offlineMode, true);
    });
    test('should track multiple property changes', () {
      mutableConfig.setOfflineMode(true);
      expect(mutableConfig.hasChanges, true);
      final changes = mutableConfig.getChanges();
      expect(changes.length, 1);
      expect(changes.containsKey('offlineMode'), true);
    });
    test('should update existing change when property changes multiple times',
        () {
      mutableConfig.setOfflineMode(true);
      final firstChangeTime =
          mutableConfig.getChanges()['offlineMode']['timestamp'];
      // Small delay to ensure different timestamp
      Future.delayed(const Duration(milliseconds: 1));
      mutableConfig.setOfflineMode(false);
      final changes = mutableConfig.getChanges();
      expect(changes.length, 1); // Still only one entry for offlineMode
      expect(changes['offlineMode']['oldValue'],
          true); // Previous value (from last change)
      expect(changes['offlineMode']['newValue'], false); // Current value
      // Timestamp should be updated
      final finalChangeTime = changes['offlineMode']['timestamp'];
      expect(finalChangeTime, isNot(equals(firstChangeTime)));
    });
  });
  group('Summary Tests', () {
    test('should provide configuration summary', () {
      final summary = mutableConfig.getSummary();
      expect(summary, isA<Map<String, dynamic>>());
      expect(summary['environment'], testConfig.environment.toString());
      expect(summary['offlineMode'], testConfig.offlineMode);
      expect(summary['debugLoggingEnabled'], testConfig.debugLoggingEnabled);
      expect(
          summary['eventsFlushIntervalMs'], testConfig.eventsFlushIntervalMs);
      expect(summary['networkConnectionTimeoutMs'],
          testConfig.networkConnectionTimeoutMs);
      expect(summary['changesCount'], 0);
      expect(summary['hasChanges'], false);
    });
    test('should update summary when changes are made', () {
      mutableConfig.setOfflineMode(true);
      final summary = mutableConfig.getSummary();
      expect(summary['offlineMode'], true);
      expect(summary['changesCount'], 1);
      expect(summary['hasChanges'], true);
    });
    test('should reflect cleared changes in summary', () {
      mutableConfig.setOfflineMode(true);
      mutableConfig.clearChangeHistory();
      final summary = mutableConfig.getSummary();
      expect(summary['offlineMode'], true); // Current state preserved
      expect(summary['changesCount'], 0); // Changes cleared
      expect(summary['hasChanges'], false);
    });
  });
  group('Integration Tests', () {
    test('should handle complete workflow', () {
      // Add listeners
      final changeEvents = <Map<String, dynamic>>[];
      void listener(String property, dynamic oldValue, dynamic newValue) {
        changeEvents.add({
          'property': property,
          'oldValue': oldValue,
          'newValue': newValue,
        });
      }

      mutableConfig.addChangeListener(listener);
      // Make changes
      mutableConfig.setOfflineMode(true);
      expect(changeEvents.length, 1);
      // Check state
      expect(mutableConfig.offlineMode, true);
      expect(mutableConfig.hasChanges, true);
      // Get summary
      final summary = mutableConfig.getSummary();
      expect(summary['hasChanges'], true);
      expect(summary['changesCount'], 1);
      // Clear changes
      mutableConfig.clearChangeHistory();
      expect(mutableConfig.hasChanges, false);
      // State should be preserved
      expect(mutableConfig.offlineMode, true);
      // Make another change
      mutableConfig.setOfflineMode(false);
      expect(changeEvents.length, 2);
      expect(mutableConfig.hasChanges, true);
      // Remove listener
      mutableConfig.removeChangeListener(listener);
      mutableConfig.setOfflineMode(true);
      expect(changeEvents.length, 2); // Should not increase
    });
    test('should work with different initial configurations', () {
      final customConfig = CFConfig.builder(
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c')
          .setOfflineMode(true)
          .setDebugLoggingEnabled(false)
          .setAutoEnvAttributesEnabled(false)
          .build()
          .getOrThrow();
      final customMutableConfig = MutableCFConfig(customConfig);
      expect(customMutableConfig.offlineMode, true);
      expect(customMutableConfig.autoEnvAttributesEnabled, false);
      expect(customMutableConfig.hasChanges, false);
      final summary = customMutableConfig.getSummary();
      expect(summary['environment'], 'CFEnvironment.production');
      expect(summary['offlineMode'], true);
      expect(summary['debugLoggingEnabled'], false);
    });
    test('should handle edge cases', () {
      // Test with minimal config
      final minimalConfig = CFConfig.builder(
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c')
          .build()
          .getOrThrow();
      final minimalMutableConfig = MutableCFConfig(minimalConfig);
      expect(minimalMutableConfig.offlineMode, minimalConfig.offlineMode);
      // Test rapid changes
      for (int i = 0; i < 10; i++) {
        minimalMutableConfig.setOfflineMode(i % 2 == 0);
      }
      expect(minimalMutableConfig.hasChanges, true);
      // Test listener with null values (edge case)
      void nullSafeListener(
          String property, dynamic oldValue, dynamic newValue) {
        expect(property, isNotNull);
        // oldValue and newValue can be any type, including null
      }

      minimalMutableConfig.addChangeListener(nullSafeListener);
      minimalMutableConfig.setOfflineMode(true);
    });
  });
  group('Error Handling Tests', () {
    test('should handle multiple listener errors gracefully', () {
      void errorListener1(String property, dynamic oldValue, dynamic newValue) {
        throw StateError('Error 1');
      }

      void errorListener2(String property, dynamic oldValue, dynamic newValue) {
        throw ArgumentError('Error 2');
      }

      void errorListener3(String property, dynamic oldValue, dynamic newValue) {
        throw Exception('Error 3');
      }

      mutableConfig.addChangeListener(errorListener1);
      mutableConfig.addChangeListener(errorListener2);
      mutableConfig.addChangeListener(errorListener3);
      // Should not throw any exceptions
      expect(() => mutableConfig.setOfflineMode(true), returnsNormally);
      expect(mutableConfig.offlineMode, true);
      expect(mutableConfig.hasChanges, true);
    });
    test('should handle removing non-existent listener', () {
      void listener(String property, dynamic oldValue, dynamic newValue) {}
      // Remove without adding - should not throw
      expect(
          () => mutableConfig.removeChangeListener(listener), returnsNormally);
      // Add and remove twice - should not throw
      mutableConfig.addChangeListener(listener);
      mutableConfig.removeChangeListener(listener);
      expect(
          () => mutableConfig.removeChangeListener(listener), returnsNormally);
    });
  });
}
