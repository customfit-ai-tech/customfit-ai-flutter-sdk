import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/logging/logger.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Logger', () {
    setUp(() {
      // Reset logger state before each test
      Logger.enabled = true;
      Logger.debugEnabled = false;
    });
    tearDown(() {
      // Reset logger state after each test
      Logger.enabled = true;
      Logger.debugEnabled = false;
    });
    group('Configuration', () {
      test('should configure logging settings', () {
        Logger.configure(enabled: false, debugEnabled: true);
        expect(Logger.enabled, isFalse);
        expect(Logger.debugEnabled, isTrue);
      });
      test('should enable both logging and debug', () {
        Logger.configure(enabled: true, debugEnabled: true);
        expect(Logger.enabled, isTrue);
        expect(Logger.debugEnabled, isTrue);
      });
      test('should disable both logging and debug', () {
        Logger.configure(enabled: false, debugEnabled: false);
        expect(Logger.enabled, isFalse);
        expect(Logger.debugEnabled, isFalse);
      });
      test('should handle mixed configuration', () {
        Logger.configure(enabled: true, debugEnabled: false);
        expect(Logger.enabled, isTrue);
        expect(Logger.debugEnabled, isFalse);
      });
    });
    group('Static Properties', () {
      test('should have default enabled state', () {
        expect(Logger.enabled, isTrue);
      });
      test('should have default debug disabled state', () {
        expect(Logger.debugEnabled, isFalse);
      });
      test('should allow enabling debug logging', () {
        Logger.debugEnabled = true;
        expect(Logger.debugEnabled, isTrue);
      });
      test('should allow disabling logging entirely', () {
        Logger.enabled = false;
        expect(Logger.enabled, isFalse);
      });
    });
    group('Logging Methods Existence', () {
      test('should have trace method', () {
        expect(() => Logger.trace('test'), returnsNormally);
      });
      test('should have debug method', () {
        expect(() => Logger.d('test'), returnsNormally);
      });
      test('should have info method', () {
        expect(() => Logger.i('test'), returnsNormally);
      });
      test('should have warning method', () {
        expect(() => Logger.w('test'), returnsNormally);
      });
      test('should have error method', () {
        expect(() => Logger.e('test'), returnsNormally);
      });
      test('should have exception method', () {
        final error = Exception('test error');
        expect(() => Logger.exception(error, 'test message'), returnsNormally);
      });
    });
    group('Exception Logging', () {
      test('should handle exception with message only', () {
        final error = Exception('test error');
        expect(() => Logger.exception(error, 'exception message'),
            returnsNormally);
      });
      test('should handle exception with stacktrace', () {
        final error = Exception('test error');
        final stackTrace = StackTrace.current;
        expect(
            () => Logger.exception(error, 'exception message',
                stackTrace: stackTrace),
            returnsNormally);
      });
      test('should handle different error types', () {
        expect(() => Logger.exception('string error', 'string exception'),
            returnsNormally);
        expect(() => Logger.exception(42, 'number exception'), returnsNormally);
        expect(() => Logger.exception({'key': 'value'}, 'map exception'),
            returnsNormally);
      });
    });
    group('Message Handling', () {
      test('should handle empty messages', () {
        expect(() => Logger.i(''), returnsNormally);
        expect(() => Logger.w(''), returnsNormally);
        expect(() => Logger.e(''), returnsNormally);
      });
      test('should handle whitespace messages', () {
        expect(() => Logger.i('   '), returnsNormally);
        expect(() => Logger.w('\t\n'), returnsNormally);
      });
      test('should handle very long messages', () {
        final longMessage = 'a' * 10000;
        expect(() => Logger.i(longMessage), returnsNormally);
      });
      test('should handle special characters', () {
        const specialMessage = 'Message with 🎉 emojis and \n newlines \t tabs';
        expect(() => Logger.i(specialMessage), returnsNormally);
      });
      test('should handle API POLL messages', () {
        expect(() => Logger.i('API POLL: fetching configuration'),
            returnsNormally);
      });
      test('should handle SUMMARY messages', () {
        expect(() => Logger.i('SUMMARY: processed 10 events'), returnsNormally);
      });
      test('should handle CONFIG messages', () {
        expect(() => Logger.i('CONFIG VALUE: feature_flag = true'),
            returnsNormally);
        expect(() => Logger.i('CONFIG UPDATE: refreshed configuration'),
            returnsNormally);
      });
      test('should handle TRACK messages', () {
        expect(() => Logger.i('TRACK: user clicked button'), returnsNormally);
        expect(
            () => Logger.i('🔔 Event tracked successfully'), returnsNormally);
      });
    });
    group('Shutdown', () {
      test('should handle shutdown gracefully', () async {
        expect(() => Logger.shutdown(), returnsNormally);
      });
      test('should complete shutdown without errors', () async {
        await expectLater(Logger.shutdown(), completes);
      });
    });
    group('Behavioral Tests', () {
      test('should not throw when logging while disabled', () {
        Logger.enabled = false;
        expect(() => Logger.trace('trace'), returnsNormally);
        expect(() => Logger.d('debug'), returnsNormally);
        expect(() => Logger.i('info'), returnsNormally);
        expect(() => Logger.w('warn'), returnsNormally);
        expect(() => Logger.e('error'), returnsNormally);
      });
      test('should not throw when debug logging while debug disabled', () {
        Logger.enabled = true;
        Logger.debugEnabled = false;
        expect(() => Logger.trace('trace'), returnsNormally);
        expect(() => Logger.d('debug'), returnsNormally);
      });
      test('should not throw when debug logging while debug enabled', () {
        Logger.enabled = true;
        Logger.debugEnabled = true;
        expect(() => Logger.trace('trace'), returnsNormally);
        expect(() => Logger.d('debug'), returnsNormally);
      });
    });
    group('Rapid Logging', () {
      test('should handle rapid successive calls', () {
        Logger.enabled = true;
        expect(() {
          for (int i = 0; i < 100; i++) {
            Logger.i('rapid message $i');
          }
        }, returnsNormally);
      });
      test('should handle concurrent logging', () async {
        Logger.enabled = true;
        Logger.debugEnabled = true;
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(Future(() {
            Logger.i('concurrent message $i');
          }));
        }
        await expectLater(Future.wait(futures), completes);
      });
    });
    group('Configuration Changes During Runtime', () {
      test('should handle configuration changes', () {
        Logger.enabled = true;
        Logger.debugEnabled = false;
        // Should not throw
        Logger.d('debug before enable');
        Logger.debugEnabled = true;
        Logger.d('debug after enable');
        Logger.enabled = false;
        Logger.i('info after disable');
        expect(Logger.enabled, isFalse);
        expect(Logger.debugEnabled, isTrue);
      });
      test('should maintain state across multiple configuration calls', () {
        Logger.configure(enabled: true, debugEnabled: true);
        expect(Logger.enabled, isTrue);
        expect(Logger.debugEnabled, isTrue);
        Logger.configure(enabled: false, debugEnabled: false);
        expect(Logger.enabled, isFalse);
        expect(Logger.debugEnabled, isFalse);
        Logger.configure(enabled: true, debugEnabled: false);
        expect(Logger.enabled, isTrue);
        expect(Logger.debugEnabled, isFalse);
      });
    });
    group('Edge Cases', () {
      test('should handle null-like messages gracefully', () {
        expect(() => Logger.i('null'), returnsNormally);
        expect(() => Logger.i('undefined'), returnsNormally);
      });
      test('should handle numeric messages', () {
        expect(() => Logger.i('123'), returnsNormally);
        expect(() => Logger.i('3.14159'), returnsNormally);
      });
      test('should handle boolean-like messages', () {
        expect(() => Logger.i('true'), returnsNormally);
        expect(() => Logger.i('false'), returnsNormally);
      });
      test('should handle JSON-like messages', () {
        expect(() => Logger.i('{"key": "value"}'), returnsNormally);
        expect(() => Logger.i('[1, 2, 3]'), returnsNormally);
      });
    });
  });
}
