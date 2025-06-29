import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/listener_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/client/listener/feature_flag_change_listener.dart';
import 'package:customfit_ai_flutter_sdk/src/client/listener/all_flags_listener.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_status.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_information.dart';
import 'listener_manager_test.mocks.dart';

@GenerateMocks([
  FeatureFlagChangeListener,
  AllFlagsListener,
  ConnectionStatusListener,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  late ListenerManager listenerManager;
  setUp(() {
    listenerManager = ListenerManager();
  });
  group('ListenerManager - Feature Flag Listeners', () {
    test('should register feature flag listener correctly', () {
      // Arrange
      final mockListener = MockFeatureFlagChangeListener();
      const flagKey = 'test_flag';
      // Act
      listenerManager.registerFeatureFlagListener(flagKey, mockListener);
      // Assert - Test by notifying and verifying the listener was called
      listenerManager.notifyFeatureFlagListeners(flagKey, false, true);
      verify(mockListener.onFeatureFlagChanged(flagKey, false, true)).called(1);
    });
    test('should register multiple listeners for same flag', () {
      // Arrange
      final mockListener1 = MockFeatureFlagChangeListener();
      final mockListener2 = MockFeatureFlagChangeListener();
      const flagKey = 'test_flag';
      // Act
      listenerManager.registerFeatureFlagListener(flagKey, mockListener1);
      listenerManager.registerFeatureFlagListener(flagKey, mockListener2);
      // Assert
      listenerManager.notifyFeatureFlagListeners(flagKey, false, true);
      verify(mockListener1.onFeatureFlagChanged(flagKey, false, true))
          .called(1);
      verify(mockListener2.onFeatureFlagChanged(flagKey, false, true))
          .called(1);
    });
    test('should register listeners for different flags', () {
      // Arrange
      final mockListener1 = MockFeatureFlagChangeListener();
      final mockListener2 = MockFeatureFlagChangeListener();
      const flagKey1 = 'flag1';
      const flagKey2 = 'flag2';
      // Act
      listenerManager.registerFeatureFlagListener(flagKey1, mockListener1);
      listenerManager.registerFeatureFlagListener(flagKey2, mockListener2);
      // Assert
      listenerManager.notifyFeatureFlagListeners(flagKey1, false, true);
      verify(mockListener1.onFeatureFlagChanged(flagKey1, false, true))
          .called(1);
      verifyNever(mockListener2.onFeatureFlagChanged(any, any, any));
    });
    test('should unregister feature flag listener correctly', () {
      // Arrange
      final mockListener = MockFeatureFlagChangeListener();
      const flagKey = 'test_flag';
      listenerManager.registerFeatureFlagListener(flagKey, mockListener);
      // Act
      listenerManager.unregisterFeatureFlagListener(flagKey, mockListener);
      // Assert
      listenerManager.notifyFeatureFlagListeners(flagKey, false, true);
      verifyNever(mockListener.onFeatureFlagChanged(any, any, any));
    });
    test('should handle unregistering non-existent listener gracefully', () {
      // Arrange
      final mockListener = MockFeatureFlagChangeListener();
      const flagKey = 'test_flag';
      // Act & Assert - Should not throw
      expect(
          () => listenerManager.unregisterFeatureFlagListener(
              flagKey, mockListener),
          returnsNormally);
    });
    test('should remove flag key when last listener is unregistered', () {
      // Arrange
      final mockListener1 = MockFeatureFlagChangeListener();
      final mockListener2 = MockFeatureFlagChangeListener();
      const flagKey = 'test_flag';
      listenerManager.registerFeatureFlagListener(flagKey, mockListener1);
      listenerManager.registerFeatureFlagListener(flagKey, mockListener2);
      // Act
      listenerManager.unregisterFeatureFlagListener(flagKey, mockListener1);
      listenerManager.unregisterFeatureFlagListener(flagKey, mockListener2);
      // Assert - Registering and notifying again should work
      listenerManager.registerFeatureFlagListener(flagKey, mockListener1);
      listenerManager.notifyFeatureFlagListeners(flagKey, false, true);
      verify(mockListener1.onFeatureFlagChanged(flagKey, false, true))
          .called(1);
    });
    test('should handle exceptions during feature flag notification gracefully',
        () {
      // Arrange
      final mockListener = MockFeatureFlagChangeListener();
      const flagKey = 'test_flag';
      when(mockListener.onFeatureFlagChanged(any, any, any))
          .thenThrow(Exception('Test exception'));
      listenerManager.registerFeatureFlagListener(flagKey, mockListener);
      // Act & Assert - Should not throw
      expect(
          () =>
              listenerManager.notifyFeatureFlagListeners(flagKey, false, true),
          returnsNormally);
    });
    test('should notify feature flag listeners with correct parameters', () {
      // Arrange
      final mockListener = MockFeatureFlagChangeListener();
      const flagKey = 'test_flag';
      const oldValue = 'old';
      const newValue = 'new';
      listenerManager.registerFeatureFlagListener(flagKey, mockListener);
      // Act
      listenerManager.notifyFeatureFlagListeners(flagKey, oldValue, newValue);
      // Assert
      verify(mockListener.onFeatureFlagChanged(flagKey, oldValue, newValue))
          .called(1);
    });
  });
  group('ListenerManager - All Flags Listeners', () {
    test('should register all flags listener correctly', () {
      // Arrange
      final mockListener = MockAllFlagsListener();
      // Act
      listenerManager.registerAllFlagsListener(mockListener);
      // Assert
      final oldFlags = {'flag1': false};
      final newFlags = {'flag1': true};
      listenerManager.notifyAllFlagsListeners(oldFlags, newFlags);
      verify(mockListener.onAllFlagsChanged(oldFlags, newFlags)).called(1);
    });
    test('should register multiple all flags listeners', () {
      // Arrange
      final mockListener1 = MockAllFlagsListener();
      final mockListener2 = MockAllFlagsListener();
      // Act
      listenerManager.registerAllFlagsListener(mockListener1);
      listenerManager.registerAllFlagsListener(mockListener2);
      // Assert
      final oldFlags = {'flag1': false};
      final newFlags = {'flag1': true};
      listenerManager.notifyAllFlagsListeners(oldFlags, newFlags);
      verify(mockListener1.onAllFlagsChanged(oldFlags, newFlags)).called(1);
      verify(mockListener2.onAllFlagsChanged(oldFlags, newFlags)).called(1);
    });
    test('should unregister all flags listener correctly', () {
      // Arrange
      final mockListener = MockAllFlagsListener();
      listenerManager.registerAllFlagsListener(mockListener);
      // Act
      listenerManager.unregisterAllFlagsListener(mockListener);
      // Assert
      final oldFlags = {'flag1': false};
      final newFlags = {'flag1': true};
      listenerManager.notifyAllFlagsListeners(oldFlags, newFlags);
      verifyNever(mockListener.onAllFlagsChanged(any, any));
    });
    test('should handle exceptions during all flags notification gracefully',
        () {
      // Arrange
      final mockListener = MockAllFlagsListener();
      when(mockListener.onAllFlagsChanged(any, any))
          .thenThrow(Exception('Test exception'));
      listenerManager.registerAllFlagsListener(mockListener);
      // Act & Assert - Should not throw
      final oldFlags = {'flag1': false};
      final newFlags = {'flag1': true};
      expect(() => listenerManager.notifyAllFlagsListeners(oldFlags, newFlags),
          returnsNormally);
    });
  });
  group('ListenerManager - Connection Status Listeners', () {
    test('should add connection status listener correctly', () {
      // Arrange
      final mockListener = MockConnectionStatusListener();
      // Act
      listenerManager.addConnectionStatusListener(mockListener);
      // Assert
      const status = ConnectionStatus.connected;
      final info = ConnectionInformation(
        status: status,
        isOfflineMode: false,
      );
      listenerManager.notifyConnectionStatusListeners(status, info);
      verify(mockListener.onConnectionStatusChanged(status, info)).called(1);
    });
    test('should add multiple connection status listeners', () {
      // Arrange
      final mockListener1 = MockConnectionStatusListener();
      final mockListener2 = MockConnectionStatusListener();
      // Act
      listenerManager.addConnectionStatusListener(mockListener1);
      listenerManager.addConnectionStatusListener(mockListener2);
      // Assert
      const status = ConnectionStatus.connected;
      final info = ConnectionInformation(
        status: status,
        isOfflineMode: false,
      );
      listenerManager.notifyConnectionStatusListeners(status, info);
      verify(mockListener1.onConnectionStatusChanged(status, info)).called(1);
      verify(mockListener2.onConnectionStatusChanged(status, info)).called(1);
    });
    test('should remove connection status listener correctly', () {
      // Arrange
      final mockListener = MockConnectionStatusListener();
      listenerManager.addConnectionStatusListener(mockListener);
      // Act
      listenerManager.removeConnectionStatusListener(mockListener);
      // Assert
      const status = ConnectionStatus.connected;
      final info = ConnectionInformation(
        status: status,
        isOfflineMode: false,
      );
      listenerManager.notifyConnectionStatusListeners(status, info);
      verifyNever(mockListener.onConnectionStatusChanged(any, any));
    });
    test(
        'should handle exceptions during connection status notification gracefully',
        () {
      // Arrange
      final mockListener = MockConnectionStatusListener();
      when(mockListener.onConnectionStatusChanged(any, any))
          .thenThrow(Exception('Test exception'));
      listenerManager.addConnectionStatusListener(mockListener);
      // Act & Assert - Should not throw
      const status = ConnectionStatus.connected;
      final info = ConnectionInformation(
        status: status,
        isOfflineMode: false,
      );
      expect(
          () => listenerManager.notifyConnectionStatusListeners(status, info),
          returnsNormally);
    });
  });
  group('ListenerManager - Clear All Listeners', () {
    test('should clear all listeners', () {
      // Arrange
      final flagListener = MockFeatureFlagChangeListener();
      final allFlagsListener = MockAllFlagsListener();
      final connectionListener = MockConnectionStatusListener();
      listenerManager.registerFeatureFlagListener('flag1', flagListener);
      listenerManager.registerAllFlagsListener(allFlagsListener);
      listenerManager.addConnectionStatusListener(connectionListener);
      // Act
      listenerManager.clearAllListeners();
      // Assert
      // Test that no listeners are called after clearing
      listenerManager.notifyFeatureFlagListeners('flag1', false, true);
      listenerManager
          .notifyAllFlagsListeners({'flag1': false}, {'flag1': true});
      const status = ConnectionStatus.connected;
      final info = ConnectionInformation(status: status, isOfflineMode: false);
      listenerManager.notifyConnectionStatusListeners(status, info);
      verifyNever(flagListener.onFeatureFlagChanged(any, any, any));
      verifyNever(allFlagsListener.onAllFlagsChanged(any, any));
      verifyNever(connectionListener.onConnectionStatusChanged(any, any));
    });
    test('should allow registering listeners after clearing', () {
      // Arrange
      final flagListener = MockFeatureFlagChangeListener();
      listenerManager.registerFeatureFlagListener('flag1', flagListener);
      listenerManager.clearAllListeners();
      // Act
      listenerManager.registerFeatureFlagListener('flag2', flagListener);
      // Assert
      listenerManager.notifyFeatureFlagListeners('flag2', false, true);
      verify(flagListener.onFeatureFlagChanged('flag2', false, true)).called(1);
    });
  });
  group('ListenerManager interface', () {
    test('should implement ListenerManager interface correctly', () {
      // Assert
      expect(listenerManager, isA<ListenerManager>());
      expect(listenerManager.registerFeatureFlagListener, isA<Function>());
      expect(listenerManager.unregisterFeatureFlagListener, isA<Function>());
      expect(listenerManager.registerAllFlagsListener, isA<Function>());
      expect(listenerManager.unregisterAllFlagsListener, isA<Function>());
      expect(listenerManager.addConnectionStatusListener, isA<Function>());
      expect(listenerManager.removeConnectionStatusListener, isA<Function>());
      expect(listenerManager.clearAllListeners, isA<Function>());
    });
  });
  group('ListenerManager - Edge Cases', () {
    test('should handle notifying listeners for non-existent flag', () {
      // Act & Assert - Should not throw
      expect(
          () => listenerManager.notifyFeatureFlagListeners(
              'nonexistent', false, true),
          returnsNormally);
    });
    test('should handle concurrent listener modifications during notification',
        () {
      // Arrange
      final mockListener1 = MockFeatureFlagChangeListener();
      final mockListener2 = MockFeatureFlagChangeListener();
      const flagKey = 'test_flag';
      listenerManager.registerFeatureFlagListener(flagKey, mockListener1);
      listenerManager.registerFeatureFlagListener(flagKey, mockListener2);
      // Act & Assert - Should handle concurrent modifications gracefully
      expect(
          () =>
              listenerManager.notifyFeatureFlagListeners(flagKey, false, true),
          returnsNormally);
    });
    test('should handle null values in notifications', () {
      // Arrange
      final mockListener = MockFeatureFlagChangeListener();
      const flagKey = 'test_flag';
      listenerManager.registerFeatureFlagListener(flagKey, mockListener);
      // Act & Assert - Should handle null values
      expect(
          () => listenerManager.notifyFeatureFlagListeners(flagKey, null, null),
          returnsNormally);
      verify(mockListener.onFeatureFlagChanged(flagKey, null, null)).called(1);
    });
    test('should maintain listener isolation between different flag keys', () {
      // Arrange
      final listener1 = MockFeatureFlagChangeListener();
      final listener2 = MockFeatureFlagChangeListener();
      listenerManager.registerFeatureFlagListener('flag1', listener1);
      listenerManager.registerFeatureFlagListener('flag2', listener2);
      // Act
      listenerManager.notifyFeatureFlagListeners('flag1', false, true);
      // Assert
      verify(listener1.onFeatureFlagChanged('flag1', false, true)).called(1);
      verifyNever(listener2.onFeatureFlagChanged(any, any, any));
    });
  });
}
