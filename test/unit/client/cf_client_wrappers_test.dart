// test/unit/client/cf_client_wrappers_test.dart
//
// Comprehensive tests for CFClient wrapper classes
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/client/cf_client_wrappers.dart';
import 'package:customfit_ai_flutter_sdk/src/core/session/session_manager.dart';
import '../../helpers/test_storage_helper.dart';
import '../../test_config.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestConfig.setupTestLogger(); // Enable logger for coverage
    SharedPreferences.setMockInitialValues({});
    // Setup test storage with secure storage
    TestStorageHelper.setupTestStorage();
  });
  group('CFClientSessionListener', () {
    late CFClientSessionListener sessionListener;
    late List<String> updateSessionIdCalls;
    late List<Map<String, dynamic>> trackEventCalls;
    setUp(() {
      updateSessionIdCalls = [];
      trackEventCalls = [];
      sessionListener = CFClientSessionListener(
        updateSessionIdInManagers: (sessionId) {
          updateSessionIdCalls.add(sessionId);
        },
        trackSessionRotationEvent: (oldSessionId, newSessionId, reason) {
          trackEventCalls.add({
            'oldSessionId': oldSessionId,
            'newSessionId': newSessionId,
            'reason': reason,
          });
        },
      );
    });
    group('Constructor', () {
      test('should create instance with required callbacks', () {
        expect(sessionListener, isNotNull);
      });
    });
    group('onSessionRotated', () {
      test('should handle session rotation with old session ID', () {
        const oldSessionId = 'old-session-123';
        const newSessionId = 'new-session-456';
        const reason = RotationReason.manualRotation;
        sessionListener.onSessionRotated(oldSessionId, newSessionId, reason);
        expect(updateSessionIdCalls, contains(newSessionId));
        expect(trackEventCalls.length, equals(1));
        expect(trackEventCalls[0]['oldSessionId'], equals(oldSessionId));
        expect(trackEventCalls[0]['newSessionId'], equals(newSessionId));
        expect(trackEventCalls[0]['reason'], equals(reason));
      });
      test('should handle session rotation with null old session ID', () {
        const newSessionId = 'new-session-456';
        const reason = RotationReason.appStart;
        sessionListener.onSessionRotated(null, newSessionId, reason);
        expect(updateSessionIdCalls, contains(newSessionId));
        expect(trackEventCalls.length, equals(1));
        expect(trackEventCalls[0]['oldSessionId'], isNull);
        expect(trackEventCalls[0]['newSessionId'], equals(newSessionId));
        expect(trackEventCalls[0]['reason'], equals(reason));
      });
      test('should handle empty session IDs', () {
        sessionListener.onSessionRotated('', '', RotationReason.manualRotation);
        expect(updateSessionIdCalls, contains(''));
        expect(trackEventCalls.length, equals(1));
        expect(trackEventCalls[0]['oldSessionId'], equals(''));
        expect(trackEventCalls[0]['newSessionId'], equals(''));
      });
    });
    group('onSessionRestored', () {
      test('should handle session restoration', () {
        const sessionId = 'restored-session-789';
        sessionListener.onSessionRestored(sessionId);
        expect(updateSessionIdCalls, contains(sessionId));
        expect(
            trackEventCalls.length, equals(0)); // No tracking for restoration
      });
      test('should handle empty session ID restoration', () {
        sessionListener.onSessionRestored('');
        expect(updateSessionIdCalls, contains(''));
      });
    });
    group('onSessionError', () {
      test('should handle session errors', () {
        const error = 'Session connection failed';
        // This method only logs, so we just verify it doesn't throw
        expect(() => sessionListener.onSessionError(error), returnsNormally);
      });
      test('should handle empty error message', () {
        expect(() => sessionListener.onSessionError(''), returnsNormally);
      });
    });
  });
  group('FeatureFlagListenerWrapper', () {
    late FeatureFlagListenerWrapper wrapper;
    late List<Map<String, dynamic>> callbackCalls;
    setUp(() {
      callbackCalls = [];
      wrapper = FeatureFlagListenerWrapper((flagKey, oldValue, newValue) {
        callbackCalls.add({
          'flagKey': flagKey,
          'oldValue': oldValue,
          'newValue': newValue,
        });
      });
    });
    group('Constructor', () {
      test('should create instance with callback', () {
        expect(wrapper, isNotNull);
      });
    });
    group('onFeatureFlagChanged', () {
      test('should call callback with correct parameters', () {
        const flagKey = 'test_flag';
        const oldValue = false;
        const newValue = true;
        wrapper.onFeatureFlagChanged(flagKey, oldValue, newValue);
        expect(callbackCalls.length, equals(1));
        expect(callbackCalls[0]['flagKey'], equals(flagKey));
        expect(callbackCalls[0]['oldValue'], equals(oldValue));
        expect(callbackCalls[0]['newValue'], equals(newValue));
      });
      test('should handle string values', () {
        wrapper.onFeatureFlagChanged('string_flag', 'old', 'new');
        expect(callbackCalls.length, equals(1));
        expect(callbackCalls[0]['oldValue'], equals('old'));
        expect(callbackCalls[0]['newValue'], equals('new'));
      });
      test('should handle null values', () {
        wrapper.onFeatureFlagChanged('null_flag', null, 'value');
        expect(callbackCalls.length, equals(1));
        expect(callbackCalls[0]['oldValue'], isNull);
        expect(callbackCalls[0]['newValue'], equals('value'));
      });
    });
    group('Equality and Hash Code', () {
      test('should be equal when callbacks are the same', () {
        void callback(String flagKey, dynamic oldValue, dynamic newValue) {}
        final wrapper1 = FeatureFlagListenerWrapper(callback);
        final wrapper2 = FeatureFlagListenerWrapper(callback);
        expect(wrapper1, equals(wrapper2));
        expect(wrapper1.hashCode, equals(wrapper2.hashCode));
      });
      test('should not be equal when callbacks are different', () {
        void callback1(String flagKey, dynamic oldValue, dynamic newValue) {}
        void callback2(String flagKey, dynamic oldValue, dynamic newValue) {}
        final wrapper1 = FeatureFlagListenerWrapper(callback1);
        final wrapper2 = FeatureFlagListenerWrapper(callback2);
        expect(wrapper1, isNot(equals(wrapper2)));
      });
    });
  });
  group('AllFlagsListenerWrapper', () {
    late AllFlagsListenerWrapper wrapper;
    late List<Map<String, dynamic>> callbackCalls;
    setUp(() {
      callbackCalls = [];
      wrapper = AllFlagsListenerWrapper((oldFlags, newFlags) {
        callbackCalls.add({
          'oldFlags': oldFlags,
          'newFlags': newFlags,
        });
      });
    });
    group('Constructor', () {
      test('should create instance with callback', () {
        expect(wrapper, isNotNull);
      });
    });
    group('onAllFlagsChanged', () {
      test('should call callback with correct parameters', () {
        final oldFlags = {'flag1': true, 'flag2': 'value1'};
        final newFlags = {'flag1': false, 'flag2': 'value2', 'flag3': 42};
        wrapper.onAllFlagsChanged(oldFlags, newFlags);
        expect(callbackCalls.length, equals(1));
        expect(callbackCalls[0]['oldFlags'], equals(oldFlags));
        expect(callbackCalls[0]['newFlags'], equals(newFlags));
      });
      test('should handle empty flag maps', () {
        final oldFlags = <String, dynamic>{};
        final newFlags = <String, dynamic>{};
        wrapper.onAllFlagsChanged(oldFlags, newFlags);
        expect(callbackCalls.length, equals(1));
        expect(callbackCalls[0]['oldFlags'], equals(oldFlags));
        expect(callbackCalls[0]['newFlags'], equals(newFlags));
      });
    });
    group('Equality and Hash Code', () {
      test('should be equal when callbacks are the same', () {
        void callback(
            Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags) {}
        final wrapper1 = AllFlagsListenerWrapper(callback);
        final wrapper2 = AllFlagsListenerWrapper(callback);
        expect(wrapper1, equals(wrapper2));
        expect(wrapper1.hashCode, equals(wrapper2.hashCode));
      });
    });
  });
}
