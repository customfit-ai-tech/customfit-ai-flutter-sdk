import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_status.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ConnectionStatus Tests', () {
    group('Enum Values', () {
      test('should have all expected enum values', () {
        expect(ConnectionStatus.values.length, 4);
        expect(ConnectionStatus.values, contains(ConnectionStatus.connected));
        expect(ConnectionStatus.values, contains(ConnectionStatus.connecting));
        expect(
            ConnectionStatus.values, contains(ConnectionStatus.disconnected));
        expect(ConnectionStatus.values, contains(ConnectionStatus.unknown));
      });
    });
    group('String Value Extension', () {
      test('should return correct string value for connected', () {
        expect(ConnectionStatus.connected.stringValue, 'connected');
      });
      test('should return correct string value for connecting', () {
        expect(ConnectionStatus.connecting.stringValue, 'connecting');
      });
      test('should return correct string value for disconnected', () {
        expect(ConnectionStatus.disconnected.stringValue, 'disconnected');
      });
      test('should return correct string value for unknown', () {
        expect(ConnectionStatus.unknown.stringValue, 'unknown');
      });
    });
    group('From String Extension', () {
      test('should parse connected status from string', () {
        expect(ConnectionStatusExtension.fromString('connected'),
            ConnectionStatus.connected);
        expect(ConnectionStatusExtension.fromString('Connected'),
            ConnectionStatus.connected);
        expect(ConnectionStatusExtension.fromString('CONNECTED'),
            ConnectionStatus.connected);
      });
      test('should parse connecting status from string', () {
        expect(ConnectionStatusExtension.fromString('connecting'),
            ConnectionStatus.connecting);
        expect(ConnectionStatusExtension.fromString('Connecting'),
            ConnectionStatus.connecting);
        expect(ConnectionStatusExtension.fromString('CONNECTING'),
            ConnectionStatus.connecting);
      });
      test('should parse disconnected status from string', () {
        expect(ConnectionStatusExtension.fromString('disconnected'),
            ConnectionStatus.disconnected);
        expect(ConnectionStatusExtension.fromString('Disconnected'),
            ConnectionStatus.disconnected);
        expect(ConnectionStatusExtension.fromString('DISCONNECTED'),
            ConnectionStatus.disconnected);
      });
      test('should parse unknown status from string', () {
        expect(ConnectionStatusExtension.fromString('unknown'),
            ConnectionStatus.unknown);
        expect(ConnectionStatusExtension.fromString('Unknown'),
            ConnectionStatus.unknown);
        expect(ConnectionStatusExtension.fromString('UNKNOWN'),
            ConnectionStatus.unknown);
      });
      test('should return unknown for invalid string', () {
        expect(ConnectionStatusExtension.fromString('invalid'),
            ConnectionStatus.unknown);
        expect(
            ConnectionStatusExtension.fromString(''), ConnectionStatus.unknown);
        expect(ConnectionStatusExtension.fromString('123'),
            ConnectionStatus.unknown);
        expect(ConnectionStatusExtension.fromString('null'),
            ConnectionStatus.unknown);
      });
      test('should handle edge cases', () {
        // Note: The implementation doesn't trim whitespace, so these return unknown
        expect(ConnectionStatusExtension.fromString(' connected '),
            ConnectionStatus.unknown);
        expect(ConnectionStatusExtension.fromString('connected\n'),
            ConnectionStatus.unknown);
        expect(ConnectionStatusExtension.fromString('\tconnecting'),
            ConnectionStatus.unknown);
        // Only exact matches work (case-insensitive)
        expect(ConnectionStatusExtension.fromString('connected'),
            ConnectionStatus.connected);
      });
    });
    group('Round Trip Conversion', () {
      test('should convert to string and back for all enum values', () {
        for (final status in ConnectionStatus.values) {
          final stringValue = status.stringValue;
          final parsedStatus =
              ConnectionStatusExtension.fromString(stringValue);
          expect(parsedStatus, status, reason: 'Failed for status: $status');
        }
      });
    });
    group('Equality', () {
      test('should properly compare enum values', () {
        expect(ConnectionStatus.connected == ConnectionStatus.connected, true);
        expect(
            ConnectionStatus.connected == ConnectionStatus.connecting, false);
        expect(
            ConnectionStatus.disconnected == ConnectionStatus.unknown, false);
      });
      test('should work with switch statements', () {
        ConnectionStatus getStatus() => ConnectionStatus.connected;
        String result;
        switch (getStatus()) {
          case ConnectionStatus.connected:
            result = 'connected';
            break;
          case ConnectionStatus.connecting:
            result = 'connecting';
            break;
          case ConnectionStatus.disconnected:
            result = 'disconnected';
            break;
          case ConnectionStatus.unknown:
            result = 'unknown';
            break;
        }
        expect(result, 'connected');
      });
    });
  });
}
