import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/logging/logger.dart';

void main() {
  group('Flutter-React Native Equivalence Test', () {
    test('should have all React Native Logger methods', () {
      // Test that all React Native methods exist in Flutter
      expect(() => Logger.trace('test'), returnsNormally);
      expect(() => Logger.debug('test'), returnsNormally);
      expect(() => Logger.d('test'), returnsNormally);
      expect(() => Logger.info('test'), returnsNormally);
      expect(() => Logger.i('test'), returnsNormally);
      expect(() => Logger.warning('test'), returnsNormally);
      expect(() => Logger.w('test'), returnsNormally);
      expect(() => Logger.warn('test'), returnsNormally);
      expect(() => Logger.error('test'), returnsNormally);
      expect(() => Logger.e('test'), returnsNormally);
      expect(() => Logger.exception(Exception('test'), 'test'), returnsNormally);
    });

    test('should have all React Native utility methods', () {
      expect(() => Logger.setLevel(LogLevel.debug), returnsNormally);
      expect(() => Logger.setTestMode(true), returnsNormally);
      expect(() => Logger.prettyPrint({'key': 'value'}), returnsNormally);
      expect(() => Logger.network('GET', 'https://api.example.com'), returnsNormally);
      expect(() => Logger.network('POST', 'https://api.example.com', 200), returnsNormally);
      expect(() => Logger.config('Configuration updated'), returnsNormally);
      expect(() => Logger.track('Event tracked'), returnsNormally);
      expect(() => Logger.summary('Summary generated'), returnsNormally);
      expect(() => Logger.emoji('🎉', 'Success'), returnsNormally);
      expect(() => Logger.emoji('❌', 'Error', LogLevel.error), returnsNormally);
    });

    test('should have correct LogLevel enum values', () {
      expect(LogLevel.trace.value, equals(0));
      expect(LogLevel.debug.value, equals(1));
      expect(LogLevel.info.value, equals(2));
      expect(LogLevel.warning.value, equals(3));
      expect(LogLevel.error.value, equals(4));
    });

    test('should handle pretty print correctly', () {
      final result = Logger.prettyPrint({'key': 'value', 'number': 42});
      expect(result, contains('key'));
      expect(result, contains('value'));
      expect(result, contains('42'));
    });

    test('should have public properties accessible', () {
      expect(Logger.enabled, isA<bool>());
      expect(Logger.debugEnabled, isA<bool>());
      expect(Logger.testMode, isA<bool>());
      expect(Logger.logPrefix, equals('Customfit.ai-SDK [Flutter]'));
      expect(Logger.currentLevel, isA<LogLevel>());
    });
  });
}