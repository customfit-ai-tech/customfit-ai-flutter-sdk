import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_information.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_status.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ConnectionInformation', () {
    group('Constructor Tests', () {
      test('should create instance with required parameters only', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.connected,
          isOfflineMode: false,
        );
        expect(info.status, equals(ConnectionStatus.connected));
        expect(info.isOfflineMode, equals(false));
        expect(info.lastError, isNull);
        expect(info.lastSuccessfulConnectionTimeMs, equals(0));
        expect(info.failureCount, equals(0));
        expect(info.nextReconnectTimeMs, equals(0));
      });
      test('should create instance with all parameters', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.disconnected,
          isOfflineMode: true,
          lastError: 'Network timeout',
          lastSuccessfulConnectionTimeMs: 1234567890,
          failureCount: 3,
          nextReconnectTimeMs: 1234567900,
        );
        expect(info.status, equals(ConnectionStatus.disconnected));
        expect(info.isOfflineMode, equals(true));
        expect(info.lastError, equals('Network timeout'));
        expect(info.lastSuccessfulConnectionTimeMs, equals(1234567890));
        expect(info.failureCount, equals(3));
        expect(info.nextReconnectTimeMs, equals(1234567900));
      });
      test('should handle different ConnectionStatus values', () {
        final statuses = [
          ConnectionStatus.connected,
          ConnectionStatus.connecting,
          ConnectionStatus.disconnected,
        ];
        for (final status in statuses) {
          final info = ConnectionInformation(
            status: status,
            isOfflineMode: false,
          );
          expect(info.status, equals(status));
        }
      });
      test('should handle boolean values for isOfflineMode', () {
        final offlineInfo = ConnectionInformation(
          status: ConnectionStatus.disconnected,
          isOfflineMode: true,
        );
        expect(offlineInfo.isOfflineMode, isTrue);
        final onlineInfo = ConnectionInformation(
          status: ConnectionStatus.connected,
          isOfflineMode: false,
        );
        expect(onlineInfo.isOfflineMode, isFalse);
      });
      test('should handle null lastError', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.connected,
          isOfflineMode: false,
          lastError: null,
        );
        expect(info.lastError, isNull);
      });
      test('should handle various numeric values', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.connecting,
          isOfflineMode: false,
          lastSuccessfulConnectionTimeMs: 9999999999999,
          failureCount: 999,
          nextReconnectTimeMs: 1111111111111,
        );
        expect(info.lastSuccessfulConnectionTimeMs, equals(9999999999999));
        expect(info.failureCount, equals(999));
        expect(info.nextReconnectTimeMs, equals(1111111111111));
      });
      test('should handle zero values for numeric fields', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.connected,
          isOfflineMode: false,
          lastSuccessfulConnectionTimeMs: 0,
          failureCount: 0,
          nextReconnectTimeMs: 0,
        );
        expect(info.lastSuccessfulConnectionTimeMs, equals(0));
        expect(info.failureCount, equals(0));
        expect(info.nextReconnectTimeMs, equals(0));
      });
      test('should handle negative values for numeric fields', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.connected,
          isOfflineMode: false,
          lastSuccessfulConnectionTimeMs: -1,
          failureCount: -5,
          nextReconnectTimeMs: -100,
        );
        expect(info.lastSuccessfulConnectionTimeMs, equals(-1));
        expect(info.failureCount, equals(-5));
        expect(info.nextReconnectTimeMs, equals(-100));
      });
    });
    group('toString() Tests', () {
      test('should return formatted string with all fields', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.connected,
          isOfflineMode: false,
          lastError: 'Test error',
          lastSuccessfulConnectionTimeMs: 1234567890,
          failureCount: 5,
          nextReconnectTimeMs: 1234567900,
        );
        final result = info.toString();
        expect(result, contains('ConnectionInformation'));
        expect(result, contains('status: ConnectionStatus.connected'));
        expect(result, contains('offline: false'));
        expect(result, contains('lastError: Test error'));
        expect(result, contains('lastSuccess: 1234567890'));
        expect(result, contains('failures: 5'));
        expect(result, contains('nextReconnect: 1234567900'));
      });
      test('should handle null lastError in toString', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.disconnected,
          isOfflineMode: true,
          lastError: null,
        );
        final result = info.toString();
        expect(result, contains('lastError: null'));
      });
      test('should handle all ConnectionStatus values in toString', () {
        final statuses = [
          ConnectionStatus.connected,
          ConnectionStatus.connecting,
          ConnectionStatus.disconnected,
        ];
        for (final status in statuses) {
          final info = ConnectionInformation(
            status: status,
            isOfflineMode: false,
          );
          final result = info.toString();
          expect(result, contains('status: $status'));
        }
      });
      test('should handle offline mode in toString', () {
        final offlineInfo = ConnectionInformation(
          status: ConnectionStatus.disconnected,
          isOfflineMode: true,
        );
        expect(offlineInfo.toString(), contains('offline: true'));
        final onlineInfo = ConnectionInformation(
          status: ConnectionStatus.connected,
          isOfflineMode: false,
        );
        expect(onlineInfo.toString(), contains('offline: false'));
      });
      test('should handle empty error message', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.disconnected,
          isOfflineMode: false,
          lastError: '',
        );
        final result = info.toString();
        expect(result, contains('lastError: '));
      });
      test('should handle special characters in error message', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.disconnected,
          isOfflineMode: false,
          lastError: 'Error: "Connection" failed\nWith special chars: \t\r',
        );
        final result = info.toString();
        expect(result, contains('lastError: Error: "Connection" failed\nWith special chars: \t\r'));
      });
      test('should handle very long error messages', () {
        final longError = 'A' * 1000;
        final info = ConnectionInformation(
          status: ConnectionStatus.disconnected,
          isOfflineMode: false,
          lastError: longError,
        );
        final result = info.toString();
        expect(result, contains('lastError: $longError'));
      });
    });
    group('Field Access Tests', () {
      test('should provide read access to all fields', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.connecting,
          isOfflineMode: true,
          lastError: 'Test error',
          lastSuccessfulConnectionTimeMs: 123,
          failureCount: 456,
          nextReconnectTimeMs: 789,
        );
        // Verify all fields are accessible
        expect(info.status, equals(ConnectionStatus.connecting));
        expect(info.isOfflineMode, equals(true));
        expect(info.lastError, equals('Test error'));
        expect(info.lastSuccessfulConnectionTimeMs, equals(123));
        expect(info.failureCount, equals(456));
        expect(info.nextReconnectTimeMs, equals(789));
      });
      test('should maintain immutability of fields', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.connected,
          isOfflineMode: false,
        );
        // Fields should be final and not modifiable
        expect(info.status, equals(ConnectionStatus.connected));
        expect(info.isOfflineMode, equals(false));
      });
    });
    group('Use Case Scenarios', () {
      test('should represent successful connection state', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.connected,
          isOfflineMode: false,
          lastError: null,
          lastSuccessfulConnectionTimeMs: DateTime.now().millisecondsSinceEpoch,
          failureCount: 0,
          nextReconnectTimeMs: 0,
        );
        expect(info.status, equals(ConnectionStatus.connected));
        expect(info.isOfflineMode, isFalse);
        expect(info.lastError, isNull);
        expect(info.failureCount, equals(0));
      });
      test('should represent connection failure with retry info', () {
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        final info = ConnectionInformation(
          status: ConnectionStatus.disconnected,
          isOfflineMode: false,
          lastError: 'Connection timeout',
          lastSuccessfulConnectionTimeMs: currentTime - 60000, // 1 minute ago
          failureCount: 3,
          nextReconnectTimeMs: currentTime + 5000, // 5 seconds from now
        );
        expect(info.status, equals(ConnectionStatus.disconnected));
        expect(info.isOfflineMode, isFalse);
        expect(info.lastError, equals('Connection timeout'));
        expect(info.failureCount, equals(3));
        expect(info.nextReconnectTimeMs, greaterThan(currentTime));
      });
      test('should represent offline mode state', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.disconnected,
          isOfflineMode: true,
          lastError: 'User initiated offline mode',
          lastSuccessfulConnectionTimeMs: 0,
          failureCount: 0,
          nextReconnectTimeMs: 0,
        );
        expect(info.status, equals(ConnectionStatus.disconnected));
        expect(info.isOfflineMode, isTrue);
        expect(info.lastError, equals('User initiated offline mode'));
      });
      test('should represent connecting state', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.connecting,
          isOfflineMode: false,
          lastError: null,
          lastSuccessfulConnectionTimeMs: DateTime.now().millisecondsSinceEpoch - 10000,
          failureCount: 1,
          nextReconnectTimeMs: 0,
        );
        expect(info.status, equals(ConnectionStatus.connecting));
        expect(info.isOfflineMode, isFalse);
      });
    });
    group('Edge Cases', () {
      test('should handle maximum integer values', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.connected,
          isOfflineMode: false,
          lastSuccessfulConnectionTimeMs: 9223372036854775807, // max int64
          failureCount: 2147483647, // max int32
          nextReconnectTimeMs: 9223372036854775807,
        );
        expect(info.lastSuccessfulConnectionTimeMs, equals(9223372036854775807));
        expect(info.failureCount, equals(2147483647));
        expect(info.nextReconnectTimeMs, equals(9223372036854775807));
      });
      test('should handle unicode characters in error message', () {
        final info = ConnectionInformation(
          status: ConnectionStatus.disconnected,
          isOfflineMode: false,
          lastError: '연결 실패 🔌 Connection failed ñ ç €',
        );
        expect(info.lastError, equals('연결 실패 🔌 Connection failed ñ ç €'));
        expect(info.toString(), contains('연결 실패 🔌 Connection failed ñ ç €'));
      });
      test('should create multiple instances independently', () {
        final info1 = ConnectionInformation(
          status: ConnectionStatus.connected,
          isOfflineMode: false,
          failureCount: 1,
        );
        final info2 = ConnectionInformation(
          status: ConnectionStatus.disconnected,
          isOfflineMode: true,
          failureCount: 5,
        );
        expect(info1.status, equals(ConnectionStatus.connected));
        expect(info1.failureCount, equals(1));
        expect(info2.status, equals(ConnectionStatus.disconnected));
        expect(info2.failureCount, equals(5));
      });
    });
  });
}