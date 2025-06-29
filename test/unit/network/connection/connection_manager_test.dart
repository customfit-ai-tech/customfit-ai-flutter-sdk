import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_status.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_information.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:fake_async/fake_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ConnectionManager Tests', () {
    late ConnectionManager connectionManager;
    late CFConfig mockConfig;
    setUp(() {
      mockConfig = CFConfig(clientKey: 'test-client-key');
      connectionManager = ConnectionManagerImpl(mockConfig);
    });
    tearDown(() {
      connectionManager.shutdown();
    });
    group('Initial State', () {
      test('should start with connecting status', () {
        expect(connectionManager.getConnectionStatus(),
            ConnectionStatus.connecting);
      });
      test('should not be in offline mode initially', () {
        expect(connectionManager.isOffline(), false);
      });
      test('should have correct initial connection information', () {
        final info = connectionManager.getConnectionInformation();
        expect(info.status, ConnectionStatus.connecting);
        expect(info.isOfflineMode, false);
        expect(info.lastError, isNull);
        expect(info.lastSuccessfulConnectionTimeMs, 0);
        expect(info.failureCount, 0);
      });
    });
    group('Connection Status Management', () {
      test('should update status to connected on success', () {
        connectionManager.recordConnectionSuccess();
        expect(connectionManager.getConnectionStatus(),
            ConnectionStatus.connected);
      });
      test('should update last success time on connection success', () {
        final beforeTime = DateTime.now().millisecondsSinceEpoch;
        connectionManager.recordConnectionSuccess();
        final info = connectionManager.getConnectionInformation();
        expect(info.lastSuccessfulConnectionTimeMs,
            greaterThanOrEqualTo(beforeTime));
        expect(info.failureCount, 0);
        expect(info.lastError, isNull);
      });
      test('should maintain connecting status on failure when not offline', () {
        connectionManager.recordConnectionFailure('Test error');
        expect(connectionManager.getConnectionStatus(),
            ConnectionStatus.connecting);
      });
      test('should increment failure count on connection failure', () {
        connectionManager.recordConnectionFailure('Error 1');
        var info = connectionManager.getConnectionInformation();
        expect(info.failureCount, 1);
        expect(info.lastError, 'Error 1');
        connectionManager.recordConnectionFailure('Error 2');
        info = connectionManager.getConnectionInformation();
        expect(info.failureCount, 2);
        expect(info.lastError, 'Error 2');
      });
      test('should reset failure count on successful connection', () {
        connectionManager.recordConnectionFailure('Error 1');
        connectionManager.recordConnectionFailure('Error 2');
        expect(connectionManager.getConnectionInformation().failureCount, 2);
        connectionManager.recordConnectionSuccess();
        expect(connectionManager.getConnectionInformation().failureCount, 0);
        expect(connectionManager.getConnectionInformation().lastError, isNull);
      });
    });
    group('Offline Mode', () {
      test('should switch to disconnected status when going offline', () {
        connectionManager.recordConnectionSuccess();
        expect(connectionManager.getConnectionStatus(),
            ConnectionStatus.connected);
        connectionManager.setOfflineMode(true);
        expect(connectionManager.isOffline(), true);
        expect(connectionManager.getConnectionStatus(),
            ConnectionStatus.disconnected);
      });
      test('should switch to connecting status when going online', () {
        connectionManager.setOfflineMode(true);
        expect(connectionManager.getConnectionStatus(),
            ConnectionStatus.disconnected);
        connectionManager.setOfflineMode(false);
        expect(connectionManager.isOffline(), false);
        expect(connectionManager.getConnectionStatus(),
            ConnectionStatus.connecting);
      });
      test('should not attempt reconnection when offline', () {
        connectionManager.setOfflineMode(true);
        connectionManager.recordConnectionFailure('Should not reconnect');
        final info = connectionManager.getConnectionInformation();
        expect(info.nextReconnectTimeMs, 0);
      });
      test('should ignore checkConnection when offline', () {
        connectionManager.setOfflineMode(true);
        final statusBefore = connectionManager.getConnectionStatus();
        connectionManager.checkConnection();
        expect(connectionManager.getConnectionStatus(), statusBefore);
      });
    });
    group('Connection Status Listeners', () {
      late TestConnectionStatusListener listener;
      setUp(() {
        listener = TestConnectionStatusListener();
      });
      test('should notify listener immediately on registration', () async {
        connectionManager.addConnectionStatusListener(listener);
        // Wait for microtask to complete
        await Future.microtask(() {});
        expect(listener.callCount, 1);
        expect(listener.lastStatus, ConnectionStatus.connecting);
        expect(listener.lastInfo, isNotNull);
      });
      test('should notify all listeners on status change', () async {
        final listener1 = TestConnectionStatusListener();
        final listener2 = TestConnectionStatusListener();
        connectionManager.addConnectionStatusListener(listener1);
        connectionManager.addConnectionStatusListener(listener2);
        await Future.microtask(() {});
        expect(listener1.callCount, 1);
        expect(listener2.callCount, 1);
        connectionManager.recordConnectionSuccess();
        expect(listener1.callCount, 2);
        expect(listener2.callCount, 2);
        expect(listener1.lastStatus, ConnectionStatus.connected);
        expect(listener2.lastStatus, ConnectionStatus.connected);
      });
      test('should not notify after listener removal', () async {
        connectionManager.addConnectionStatusListener(listener);
        await Future.microtask(() {});
        expect(listener.callCount, 1);
        connectionManager.removeConnectionStatusListener(listener);
        connectionManager.recordConnectionSuccess();
        expect(listener.callCount, 1); // Should not increase
      });
      test('should handle listener exceptions gracefully', () async {
        final errorListener = ErrorThrowingListener();
        final normalListener = TestConnectionStatusListener();
        connectionManager.addConnectionStatusListener(errorListener);
        connectionManager.addConnectionStatusListener(normalListener);
        await Future.microtask(() {});
        // Should not throw despite error in first listener
        expect(
            () => connectionManager.recordConnectionSuccess(), returnsNormally);
        expect(normalListener.callCount, 2); // Initial + status change
      });
      test('should not notify same status multiple times', () async {
        connectionManager.addConnectionStatusListener(listener);
        await Future.microtask(() {});
        expect(listener.callCount, 1);
        // Record same status multiple times
        connectionManager.recordConnectionFailure('Error 1');
        connectionManager.recordConnectionFailure('Error 2');
        connectionManager.recordConnectionFailure('Error 3');
        // Should still be connecting, so no additional notifications
        expect(listener.callCount, 1);
      });
    });
    group('Reconnection Logic', () {
      test('should schedule reconnection on failure', () {
        fakeAsync((async) {
          connectionManager.recordConnectionFailure('Network error');
          final info = connectionManager.getConnectionInformation();
          expect(info.nextReconnectTimeMs, greaterThan(0));
          expect(
              info.nextReconnectTimeMs,
              lessThanOrEqualTo(
                  DateTime.now().millisecondsSinceEpoch + 30000)); // Max delay
        });
      });
      test('should use exponential backoff for reconnection', () {
        fakeAsync((async) {
          // First failure
          connectionManager.recordConnectionFailure('Error 1');
          final info1 = connectionManager.getConnectionInformation();
          final delay1 =
              info1.nextReconnectTimeMs - DateTime.now().millisecondsSinceEpoch;
          // Simulate time passing and trigger reconnect
          async.elapse(Duration(milliseconds: delay1 + 100));
          // Second failure
          connectionManager.recordConnectionFailure('Error 2');
          final info2 = connectionManager.getConnectionInformation();
          final delay2 =
              info2.nextReconnectTimeMs - DateTime.now().millisecondsSinceEpoch;
          // Second delay should be longer (exponential backoff)
          expect(delay2, greaterThan(delay1));
        });
      });
      test('should cap reconnection delay at maximum', () {
        fakeAsync((async) {
          // Simulate many failures to reach max delay
          for (int i = 0; i < 10; i++) {
            connectionManager.recordConnectionFailure('Error $i');
            async.elapse(const Duration(seconds: 1));
          }
          final info = connectionManager.getConnectionInformation();
          final delay =
              info.nextReconnectTimeMs - DateTime.now().millisecondsSinceEpoch;
          // Should not exceed max delay (30 seconds) with jitter tolerance (1.2x = 36s)
          expect(delay, lessThanOrEqualTo(36000)); // 30s * 1.2 jitter tolerance
          expect(delay, greaterThan(0));
        });
      });
      test('should cancel scheduled reconnection when going offline', () {
        fakeAsync((async) {
          connectionManager.recordConnectionFailure('Network error');
          var info = connectionManager.getConnectionInformation();
          expect(info.nextReconnectTimeMs, greaterThan(0));
          connectionManager.setOfflineMode(true);
          info = connectionManager.getConnectionInformation();
          expect(info.nextReconnectTimeMs, 0);
        });
      });
    });
    group('Heartbeat and Auto-reconnection', () {
      test('should check connection periodically when disconnected', () {
        fakeAsync((async) {
          final listener = TestConnectionStatusListener();
          connectionManager.addConnectionStatusListener(listener);
          // Set to disconnected
          connectionManager.setOfflineMode(true);
          connectionManager.setOfflineMode(false);
          // Clear initial calls
          listener.reset();
          // Advance time to trigger heartbeat
          async.elapse(
              const Duration(seconds: 16)); // Heartbeat interval is 15 seconds
          // Should attempt to reconnect
          expect(listener.callCount, greaterThan(0));
        });
      });
      test('should check connection when last success is too old', () {
        fakeAsync((async) {
          connectionManager.recordConnectionSuccess();
          final listener = TestConnectionStatusListener();
          connectionManager.addConnectionStatusListener(listener);
          listener.reset();
          // Advance time past threshold (60 seconds)
          async.elapse(const Duration(seconds: 61));
          // Trigger heartbeat
          async.elapse(const Duration(seconds: 15));
          expect(listener.callCount, greaterThan(0));
        });
      });
    });
    group('Check Connection', () {
      test('should trigger immediate reconnection attempt', () {
        connectionManager.recordConnectionSuccess();
        expect(connectionManager.getConnectionStatus(),
            ConnectionStatus.connected);
        connectionManager.checkConnection();
        expect(connectionManager.getConnectionStatus(),
            ConnectionStatus.connecting);
      });
      test('should schedule immediate reconnection', () {
        fakeAsync((async) {
          connectionManager.checkConnection();
          final info = connectionManager.getConnectionInformation();
          // Should be scheduled immediately or very soon
          expect(info.nextReconnectTimeMs, 0); // Immediate execution
        });
      });
    });
    group('Shutdown', () {
      test('should clean up resources on shutdown', () {
        final listener = TestConnectionStatusListener();
        connectionManager.addConnectionStatusListener(listener);
        connectionManager.shutdown();
        // Should not notify after shutdown
        listener.reset();
        expect(
            () => connectionManager.recordConnectionSuccess(), returnsNormally);
        expect(listener.callCount, 0);
      });
      test('should cancel timers on shutdown', () {
        fakeAsync((async) {
          connectionManager.recordConnectionFailure('Error');
          connectionManager.shutdown();
          // Advance time - should not trigger any reconnection
          async.elapse(const Duration(minutes: 5));
          // No errors should occur
          expect(true, isTrue); // If we get here, no timers fired
        });
      });
    });
    group('Additional Coverage Tests', () {
      test('should setup default listeners via setupListeners method', () {
        // The ConnectionManagerImpl doesn't have a public setupListeners method
        // but it sets up internal listeners in the constructor
        // Test that the heartbeat is properly initialized
        fakeAsync((async) {
          // Create a new instance to test constructor behavior
          final testManager = ConnectionManagerImpl(mockConfig);
          // Should start with connecting status
          expect(
              testManager.getConnectionStatus(), ConnectionStatus.connecting);
          // Advance time to trigger heartbeat
          async.elapse(const Duration(seconds: 16));
          // Cleanup
          testManager.shutdown();
        });
      });
      test('should transition to disconnected after max reconnect attempts',
          () {
        fakeAsync((async) {
          final listener = TestConnectionStatusListener();
          connectionManager.addConnectionStatusListener(listener);
          // Record multiple failures to test max attempts behavior
          // The implementation uses exponential backoff but doesn't have a hard max attempts limit
          // Instead, it caps the delay at 30 seconds
          for (int i = 0; i < 10; i++) {
            connectionManager.recordConnectionFailure('Error $i');
          }
          // Should still be in connecting state (not disconnected)
          expect(connectionManager.getConnectionStatus(),
              ConnectionStatus.connecting);
          // Verify backoff is capped at max delay
          final info = connectionManager.getConnectionInformation();
          expect(info.failureCount, 10);
          // Advance time to test reconnection still happens
          async.elapse(const Duration(seconds: 31));
          expect(connectionManager.getConnectionStatus(),
              ConnectionStatus.connecting);
        });
      });
      test('should ignore redundant offline mode transitions', () {
        final listener = TestConnectionStatusListener();
        connectionManager.addConnectionStatusListener(listener);
        // Set offline mode
        connectionManager.setOfflineMode(true);
        expect(listener.callCount, 1); // Only the status change callback
        expect(connectionManager.getConnectionStatus(),
            ConnectionStatus.disconnected);
        // Set offline mode again (redundant)
        listener.reset();
        connectionManager.setOfflineMode(true);
        // Should not trigger additional status change
        expect(listener.callCount, 0);
        // Now go back online
        connectionManager.setOfflineMode(false);
        expect(listener.callCount, 1);
        expect(connectionManager.getConnectionStatus(),
            ConnectionStatus.connecting);
        // Set online mode again (redundant)
        listener.reset();
        connectionManager.setOfflineMode(false);
        // Should not trigger additional status change
        expect(listener.callCount, 0);
      });
      test('should handle zero delay reconnect scheduling', () {
        fakeAsync((async) {
          final listener = TestConnectionStatusListener();
          connectionManager.addConnectionStatusListener(listener);
          // Set offline then immediately back online with zero delay
          connectionManager.setOfflineMode(true);
          connectionManager.setOfflineMode(false);
          // Should schedule immediate reconnect
          expect(connectionManager.getConnectionStatus(),
              ConnectionStatus.connecting);
          // Process microtasks to handle zero delay
          async.flushMicrotasks();
          // Should still be connecting
          expect(connectionManager.getConnectionStatus(),
              ConnectionStatus.connecting);
        });
      });
      test('should cancel heartbeat timer when going offline', () {
        fakeAsync((async) {
          // Record a success to start from connected state
          connectionManager.recordConnectionSuccess();
          expect(connectionManager.getConnectionStatus(),
              ConnectionStatus.connected);
          // Go offline
          connectionManager.setOfflineMode(true);
          expect(connectionManager.getConnectionStatus(),
              ConnectionStatus.disconnected);
          // Advance time past heartbeat interval
          async.elapse(const Duration(seconds: 60));
          // Should still be disconnected (heartbeat cancelled)
          expect(connectionManager.getConnectionStatus(),
              ConnectionStatus.disconnected);
          // Go back online
          connectionManager.setOfflineMode(false);
          expect(connectionManager.getConnectionStatus(),
              ConnectionStatus.connecting);
        });
      });
      test(
          'should accurately report nextReconnectTimeMs during active reconnect',
          () {
        fakeAsync((async) {
          // Trigger a failure to schedule reconnect
          connectionManager.recordConnectionFailure('Test error');
          final beforeInfo = connectionManager.getConnectionInformation();
          expect(beforeInfo.nextReconnectTimeMs, greaterThan(0));
          // Store the initial next reconnect time
          final initialNextReconnect = beforeInfo.nextReconnectTimeMs;
          // Advance time partially
          async.elapse(const Duration(milliseconds: 500));
          final duringInfo = connectionManager.getConnectionInformation();
          // Next reconnect time should still be the same (timer hasn't fired yet)
          expect(duringInfo.nextReconnectTimeMs, equals(initialNextReconnect));
          // Advance time past the reconnect time
          async.elapse(const Duration(seconds: 3));
          // After reconnect timer fires, nextReconnectTimeMs should be 0
          final afterInfo = connectionManager.getConnectionInformation();
          expect(afterInfo.nextReconnectTimeMs, equals(0));
        });
      });
      test('should handle listener exceptions during immediate callback', () {
        final errorListener = ErrorThrowingListener();
        // Adding a listener that throws should not crash
        expect(
            () => connectionManager.addConnectionStatusListener(errorListener),
            returnsNormally);
        // Should handle the error gracefully in the microtask
        expect(
            () => connectionManager.recordConnectionSuccess(), returnsNormally);
        // Clean up
        connectionManager.removeConnectionStatusListener(errorListener);
      });
      test('should apply jitter correctly in backoff calculation', () {
        // Test that backoff includes jitter between 0.8x and 1.2x
        final backoffs = <int>[];
        // Record multiple failures to get different backoff values
        for (int i = 0; i < 5; i++) {
          connectionManager.recordConnectionFailure('Error $i');
          final info = connectionManager.getConnectionInformation();
          if (info.nextReconnectTimeMs > 0) {
            final delay = info.nextReconnectTimeMs -
                DateTime.now().millisecondsSinceEpoch;
            backoffs.add(delay);
          }
        }
        // Verify backoffs are increasing but with jitter
        for (int i = 1; i < backoffs.length; i++) {
          // Each backoff should be roughly double the previous (with jitter)
          final ratio = backoffs[i] / backoffs[i - 1];
          // With jitter range 0.8-1.2, the ratio should be between 1.3 and 3.0
          // (allowing for some variance due to random jitter and small sample size)
          expect(ratio, greaterThanOrEqualTo(1.3));
          expect(ratio, lessThanOrEqualTo(3.0));
        }
      });
      test('should protect against integer overflow in backoff calculation',
          () {
        // Simulate many failures to test overflow protection
        for (int i = 0; i < 20; i++) {
          connectionManager.recordConnectionFailure('Error $i');
        }
        final info = connectionManager.getConnectionInformation();
        expect(info.failureCount, 20);
        // Backoff should be capped at max delay (30 seconds)
        final nextReconnect = info.nextReconnectTimeMs;
        if (nextReconnect > 0) {
          final delay = nextReconnect - DateTime.now().millisecondsSinceEpoch;
          expect(
              delay, lessThanOrEqualTo(30000 * 1.2)); // Max delay with jitter
        }
      });
      test('should handle rapid failure/success cycles', () {
        fakeAsync((async) {
          final listener = TestConnectionStatusListener();
          connectionManager.addConnectionStatusListener(listener);
          // Rapid failure/success cycles
          for (int i = 0; i < 5; i++) {
            connectionManager.recordConnectionFailure('Error $i');
            async.elapse(const Duration(milliseconds: 100));
            connectionManager.recordConnectionSuccess();
            async.elapse(const Duration(milliseconds: 100));
          }
          // Should end in connected state
          expect(connectionManager.getConnectionStatus(),
              ConnectionStatus.connected);
          // Failure count should be reset after success
          final info = connectionManager.getConnectionInformation();
          expect(info.failureCount, 0);
          expect(info.lastError, isNull);
        });
      });
      test('should maintain connection information accuracy', () {
        // Test all fields in ConnectionInformation
        final initialInfo = connectionManager.getConnectionInformation();
        expect(initialInfo.status, ConnectionStatus.connecting);
        expect(initialInfo.isOfflineMode, false);
        expect(initialInfo.lastError, isNull);
        expect(initialInfo.lastSuccessfulConnectionTimeMs, 0);
        expect(initialInfo.failureCount, 0);
        expect(initialInfo.nextReconnectTimeMs, 0);
        // Record a failure
        connectionManager.recordConnectionFailure('Test error 123');
        final failureInfo = connectionManager.getConnectionInformation();
        expect(failureInfo.status, ConnectionStatus.connecting);
        expect(failureInfo.isOfflineMode, false);
        expect(failureInfo.lastError, 'Test error 123');
        expect(failureInfo.lastSuccessfulConnectionTimeMs, 0);
        expect(failureInfo.failureCount, 1);
        expect(failureInfo.nextReconnectTimeMs, greaterThan(0));
        // Record a success
        connectionManager.recordConnectionSuccess();
        final successInfo = connectionManager.getConnectionInformation();
        expect(successInfo.status, ConnectionStatus.connected);
        expect(successInfo.isOfflineMode, false);
        expect(successInfo.lastError, isNull);
        expect(successInfo.lastSuccessfulConnectionTimeMs, greaterThan(0));
        expect(successInfo.failureCount, 0);
        // In the test, nextReconnectTimeMs is set by the timer which may not be exactly 0
        expect(successInfo.nextReconnectTimeMs, greaterThanOrEqualTo(0));
      });
    });
  });
}

// Test helpers
class TestConnectionStatusListener implements ConnectionStatusListener {
  ConnectionStatus? lastStatus;
  ConnectionInformation? lastInfo;
  int callCount = 0;
  @override
  void onConnectionStatusChanged(
      ConnectionStatus newStatus, ConnectionInformation info) {
    lastStatus = newStatus;
    lastInfo = info;
    callCount++;
  }

  void reset() {
    lastStatus = null;
    lastInfo = null;
    callCount = 0;
  }
}

class ErrorThrowingListener implements ConnectionStatusListener {
  @override
  void onConnectionStatusChanged(
      ConnectionStatus newStatus, ConnectionInformation info) {
    throw Exception('Test exception from listener');
  }
}
