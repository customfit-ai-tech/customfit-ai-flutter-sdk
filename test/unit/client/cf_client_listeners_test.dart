// test/unit/client/cf_client_listeners_test.dart
//
// Comprehensive tests for CFClientListeners class to achieve 80%+ coverage
// Tests all listener management methods, notifications, and edge cases
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/client/cf_client_listeners.dart';
import 'package:customfit_ai_flutter_sdk/src/client/listener/feature_flag_change_listener.dart';
import 'package:customfit_ai_flutter_sdk/src/client/listener/all_flags_listener.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import '../../utils/test_constants.dart';
import '../../test_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestConfig.setupTestLogger(); // Enable logger for coverage
    SharedPreferences.setMockInitialValues({});
  });
  group('CFClientListeners', () {
    late CFClientListeners listenersComponent;
    late CFConfig testConfig;
    late CFUser testUser;
    late String testSessionId;
    setUp(() {
      testSessionId = 'test-session-123';
      testConfig = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(true)
          .setOfflineMode(false)
          .build().getOrThrow();
      testUser = CFUser.builder('test-user-123')
          .addStringProperty('test_key', 'test_value')
          .build().getOrThrow();
      listenersComponent = CFClientListeners(
        config: testConfig,
        user: testUser,
        sessionId: testSessionId,
      );
    });
    group('Constructor', () {
      test('should create instance with all required parameters', () {
        expect(listenersComponent, isNotNull);
      });
    });
    group('Configuration Listeners', () {
      test('should add config listener successfully', () {
        // Arrange
        bool listenerCalled = false;
        dynamic receivedValue;
        void configListener(dynamic value) {
          listenerCalled = true;
          receivedValue = value;
        }

        // Act
        listenersComponent.addConfigListener('test_flag', configListener);
        // Verify listener was added by triggering notification
        listenersComponent.notifyConfigListeners('test_flag', 'test_value');
        // Assert
        expect(listenerCalled, isTrue);
        expect(receivedValue, equals('test_value'));
      });
      test('should add multiple listeners for same config key', () {
        // Arrange
        int listener1Calls = 0;
        int listener2Calls = 0;
        void listener1(dynamic value) => listener1Calls++;
        void listener2(dynamic value) => listener2Calls++;
        // Act
        listenersComponent.addConfigListener('test_flag', listener1);
        listenersComponent.addConfigListener('test_flag', listener2);
        listenersComponent.notifyConfigListeners('test_flag', 'test_value');
        // Assert
        expect(listener1Calls, equals(1));
        expect(listener2Calls, equals(1));
      });
      test('should add listeners for different config keys', () {
        // Arrange
        bool listener1Called = false;
        bool listener2Called = false;
        void listener1(dynamic value) => listener1Called = true;
        void listener2(dynamic value) => listener2Called = true;
        // Act
        listenersComponent.addConfigListener('flag1', listener1);
        listenersComponent.addConfigListener('flag2', listener2);
        listenersComponent.notifyConfigListeners('flag1', 'value1');
        listenersComponent.notifyConfigListeners('flag2', 'value2');
        // Assert
        expect(listener1Called, isTrue);
        expect(listener2Called, isTrue);
      });
      test('should remove config listener successfully', () {
        // Arrange
        bool listenerCalled = false;
        void configListener(dynamic value) => listenerCalled = true;
        listenersComponent.addConfigListener('test_flag', configListener);
        // Act
        final removed = listenersComponent.removeConfigListener(
            'test_flag', configListener);
        listenersComponent.notifyConfigListeners('test_flag', 'test_value');
        // Assert
        expect(removed, isTrue);
        expect(listenerCalled, isFalse);
      });
      test('should return false when removing non-existent listener', () {
        // Arrange
        void configListener(dynamic value) {}
        // Act
        final removed = listenersComponent.removeConfigListener(
            'test_flag', configListener);
        // Assert
        expect(removed, isFalse);
      });
      test('should remove individual listeners correctly', () {
        // Arrange
        bool listener1Called = false;
        bool listener2Called = false;
        void listener1(dynamic value) => listener1Called = true;
        void listener2(dynamic value) => listener2Called = true;
        listenersComponent.addConfigListener('test_flag', listener1);
        listenersComponent.addConfigListener('test_flag', listener2);
        // Act - Remove only listener1
        final removed1 =
            listenersComponent.removeConfigListener('test_flag', listener1);
        listenersComponent.notifyConfigListeners('test_flag', 'test_value');
        // Assert
        expect(removed1, isTrue);
        expect(listener1Called, isFalse);
        expect(listener2Called, isTrue);
      });
      test('should clear all listeners using clearAllListeners', () {
        // Arrange
        bool configListenerCalled = false;
        void configListener(dynamic value) => configListenerCalled = true;
        listenersComponent.addConfigListener('test_flag', configListener);
        // Act
        listenersComponent.clearAllListeners();
        listenersComponent.notifyConfigListeners('test_flag', 'test_value');
        // Assert
        expect(configListenerCalled, isFalse);
        expect(listenersComponent.getTotalListenerCount(), equals(0));
      });
      test('should notify config listeners with different value types', () {
        // Arrange
        final receivedValues = <dynamic>[];
        void configListener(dynamic value) => receivedValues.add(value);
        listenersComponent.addConfigListener('test_flag', configListener);
        // Act
        listenersComponent.notifyConfigListeners('test_flag', 'string_value');
        listenersComponent.notifyConfigListeners('test_flag', 42);
        listenersComponent.notifyConfigListeners('test_flag', 3.14);
        listenersComponent.notifyConfigListeners('test_flag', true);
        listenersComponent.notifyConfigListeners('test_flag', {'key': 'value'});
        listenersComponent.notifyConfigListeners('test_flag', [1, 2, 3]);
        listenersComponent.notifyConfigListeners('test_flag', null);
        // Assert
        expect(receivedValues.length, equals(7));
        expect(receivedValues[0], equals('string_value'));
        expect(receivedValues[1], equals(42));
        expect(receivedValues[2], equals(3.14));
        expect(receivedValues[3], isTrue);
        expect(receivedValues[4], equals({'key': 'value'}));
        expect(receivedValues[5], equals([1, 2, 3]));
        expect(receivedValues[6], isNull);
      });
      test('should handle listener exceptions gracefully', () {
        // Arrange
        bool goodListenerCalled = false;
        void badListener(dynamic value) => throw Exception('Listener error');
        void goodListener(dynamic value) => goodListenerCalled = true;
        listenersComponent.addConfigListener('test_flag', badListener);
        listenersComponent.addConfigListener('test_flag', goodListener);
        // Act & Assert - Should not throw
        expect(
            () => listenersComponent.notifyConfigListeners(
                'test_flag', 'test_value'),
            returnsNormally);
        expect(goodListenerCalled, isTrue);
      });
      test('should not notify listeners for different keys', () {
        // Arrange
        bool listenerCalled = false;
        void configListener(dynamic value) => listenerCalled = true;
        listenersComponent.addConfigListener('flag1', configListener);
        // Act
        listenersComponent.notifyConfigListeners('flag2', 'test_value');
        // Assert
        expect(listenerCalled, isFalse);
      });
    });
    group('Feature Flag Listeners', () {
      test('should add feature flag listener successfully', () {
        // Arrange
        String? receivedFlagKey;
        dynamic receivedOldValue;
        dynamic receivedNewValue;
        final listener = TestFeatureFlagChangeListener(
          onChanged: (flagKey, oldValue, newValue) {
            receivedFlagKey = flagKey;
            receivedOldValue = oldValue;
            receivedNewValue = newValue;
          },
        );
        // Act
        listenersComponent.addFeatureFlagListener('test_flag', listener);
        listenersComponent.notifyFeatureFlagListeners(
            'test_flag', 'old', 'new');
        // Assert
        expect(receivedFlagKey, equals('test_flag'));
        expect(receivedOldValue, equals('old'));
        expect(receivedNewValue, equals('new'));
      });
      test('should add multiple listeners for same flag', () {
        // Arrange
        int listener1Calls = 0;
        int listener2Calls = 0;
        final listener1 = TestFeatureFlagChangeListener(
          onChanged: (flagKey, oldValue, newValue) => listener1Calls++,
        );
        final listener2 = TestFeatureFlagChangeListener(
          onChanged: (flagKey, oldValue, newValue) => listener2Calls++,
        );
        // Act
        listenersComponent.addFeatureFlagListener('test_flag', listener1);
        listenersComponent.addFeatureFlagListener('test_flag', listener2);
        listenersComponent.notifyFeatureFlagListeners('test_flag', false, true);
        // Assert
        expect(listener1Calls, equals(1));
        expect(listener2Calls, equals(1));
      });
      test('should remove feature flag listener successfully', () {
        // Arrange
        bool listenerCalled = false;
        final listener = TestFeatureFlagChangeListener(
          onChanged: (flagKey, oldValue, newValue) => listenerCalled = true,
        );
        listenersComponent.addFeatureFlagListener('test_flag', listener);
        // Act
        final removed =
            listenersComponent.removeFeatureFlagListener('test_flag', listener);
        listenersComponent.notifyFeatureFlagListeners('test_flag', false, true);
        // Assert
        expect(removed, isTrue);
        expect(listenerCalled, isFalse);
      });
      test(
          'should return false when removing non-existent feature flag listener',
          () {
        // Arrange
        final listener = TestFeatureFlagChangeListener(
          onChanged: (flagKey, oldValue, newValue) {},
        );
        // Act
        final removed =
            listenersComponent.removeFeatureFlagListener('test_flag', listener);
        // Assert
        expect(removed, isFalse);
      });
      test('should handle feature flag listener exceptions gracefully', () {
        // Arrange
        bool goodListenerCalled = false;
        final badListener = TestFeatureFlagChangeListener(
          onChanged: (flagKey, oldValue, newValue) =>
              throw Exception('Listener error'),
        );
        final goodListener = TestFeatureFlagChangeListener(
          onChanged: (flagKey, oldValue, newValue) => goodListenerCalled = true,
        );
        listenersComponent.addFeatureFlagListener('test_flag', badListener);
        listenersComponent.addFeatureFlagListener('test_flag', goodListener);
        // Act & Assert - Should not throw
        expect(
            () => listenersComponent.notifyFeatureFlagListeners(
                'test_flag', false, true),
            returnsNormally);
        expect(goodListenerCalled, isTrue);
      });
    });
    group('All Flags Listeners', () {
      test('should add all flags listener successfully', () {
        // Arrange
        Map<String, dynamic>? receivedOldFlags;
        Map<String, dynamic>? receivedNewFlags;
        final listener = TestAllFlagsListener(
          onChanged: (oldFlags, newFlags) {
            receivedOldFlags = oldFlags;
            receivedNewFlags = newFlags;
          },
        );
        // Act
        listenersComponent.addAllFlagsListener(listener);
        final oldFlags = {'flag1': true, 'flag2': 'old'};
        final newFlags = {'flag1': false, 'flag2': 'new', 'flag3': 42};
        listenersComponent.notifyAllFlagsListeners(oldFlags, newFlags);
        // Assert
        expect(receivedOldFlags, equals(oldFlags));
        expect(receivedNewFlags, equals(newFlags));
      });
      test('should remove all flags listener successfully', () {
        // Arrange
        bool listenerCalled = false;
        final listener = TestAllFlagsListener(
          onChanged: (oldFlags, newFlags) => listenerCalled = true,
        );
        listenersComponent.addAllFlagsListener(listener);
        // Act
        final removed = listenersComponent.removeAllFlagsListener(listener);
        listenersComponent.notifyAllFlagsListeners({}, {'flag': 'value'});
        // Assert
        expect(removed, isTrue);
        expect(listenerCalled, isFalse);
      });
      test('should return false when removing non-existent all flags listener',
          () {
        // Arrange
        final listener = TestAllFlagsListener(
          onChanged: (oldFlags, newFlags) {},
        );
        // Act
        final removed = listenersComponent.removeAllFlagsListener(listener);
        // Assert
        expect(removed, isFalse);
      });
      test('should handle all flags listener exceptions gracefully', () {
        // Arrange
        bool goodListenerCalled = false;
        final badListener = TestAllFlagsListener(
          onChanged: (oldFlags, newFlags) => throw Exception('Listener error'),
        );
        final goodListener = TestAllFlagsListener(
          onChanged: (oldFlags, newFlags) => goodListenerCalled = true,
        );
        listenersComponent.addAllFlagsListener(badListener);
        listenersComponent.addAllFlagsListener(goodListener);
        // Act & Assert - Should not throw
        expect(
            () => listenersComponent
                .notifyAllFlagsListeners({}, {'flag': 'value'}),
            returnsNormally);
        expect(goodListenerCalled, isTrue);
      });
      test('should notify all flags listeners with empty maps', () {
        // Arrange
        Map<String, dynamic>? receivedOldFlags;
        Map<String, dynamic>? receivedNewFlags;
        final listener = TestAllFlagsListener(
          onChanged: (oldFlags, newFlags) {
            receivedOldFlags = oldFlags;
            receivedNewFlags = newFlags;
          },
        );
        listenersComponent.addAllFlagsListener(listener);
        // Act
        listenersComponent.notifyAllFlagsListeners({}, {});
        // Assert
        expect(receivedOldFlags, equals({}));
        expect(receivedNewFlags, equals({}));
      });
    });
    group('Edge Cases and Error Handling', () {
      test('should handle null values in listener notifications', () {
        // Arrange
        dynamic receivedValue;
        void configListener(dynamic value) => receivedValue = value;
        listenersComponent.addConfigListener('test_flag', configListener);
        // Act
        listenersComponent.notifyConfigListeners('test_flag', null);
        // Assert
        expect(receivedValue, isNull);
      });
      test('should handle empty string keys', () {
        // Arrange
        bool listenerCalled = false;
        void configListener(dynamic value) => listenerCalled = true;
        // Act
        listenersComponent.addConfigListener('', configListener);
        listenersComponent.notifyConfigListeners('', 'test_value');
        // Assert
        expect(listenerCalled, isTrue);
      });
      test('should handle special characters in keys', () {
        // Arrange
        bool listenerCalled = false;
        void configListener(dynamic value) => listenerCalled = true;
        const specialKey = 'flag-with_special.chars@123!';
        // Act
        listenersComponent.addConfigListener(specialKey, configListener);
        listenersComponent.notifyConfigListeners(specialKey, 'test_value');
        // Assert
        expect(listenerCalled, isTrue);
      });
      test('should handle many listeners for same key', () {
        // Arrange
        const int numListeners = 100;
        int totalCalls = 0;
        for (int i = 0; i < numListeners; i++) {
          listenersComponent.addConfigListener(
              'test_flag', (value) => totalCalls++);
        }
        // Act
        listenersComponent.notifyConfigListeners('test_flag', 'test_value');
        // Assert
        expect(totalCalls, equals(numListeners));
      });
      test('should handle removing same listener multiple times', () {
        // Arrange
        void configListener(dynamic value) {}
        listenersComponent.addConfigListener('test_flag', configListener);
        // Act
        final firstRemoval = listenersComponent.removeConfigListener(
            'test_flag', configListener);
        final secondRemoval = listenersComponent.removeConfigListener(
            'test_flag', configListener);
        // Assert
        expect(firstRemoval, isTrue);
        expect(secondRemoval, isFalse);
      });
    });
  });
}

// Test helper classes
class TestFeatureFlagChangeListener implements FeatureFlagChangeListener {
  final void Function(String flagKey, dynamic oldValue, dynamic newValue)
      onChanged;
  TestFeatureFlagChangeListener({required this.onChanged});
  @override
  void onFeatureFlagChanged(
      String flagKey, dynamic oldValue, dynamic newValue) {
    onChanged(flagKey, oldValue, newValue);
  }
}

class TestAllFlagsListener implements AllFlagsListener {
  final void Function(
      Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags) onChanged;
  TestAllFlagsListener({required this.onChanged});
  @override
  void onAllFlagsChanged(
      Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags) {
    onChanged(oldFlags, newFlags);
  }
}
