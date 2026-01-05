// test/unit/core/error/session_recovery_manager_test.dart
//
// Simplified tests for SessionRecoveryManager after SDK simplification
// Tests basic session recovery functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/recovery_managers.dart';
import 'package:customfit_ai_flutter_sdk/src/core/session/session_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([SessionManager])
import 'session_recovery_manager_test.mocks.dart';

void main() {
  group('SessionRecoveryManager (Simplified)', () {
    late MockSessionManager mockSessionManager;

    setUp(() {
      mockSessionManager = MockSessionManager();
    });

    group('performSessionHealthCheck', () {
      test('should return healthy for valid session manager', () async {
        when(mockSessionManager.getCurrentSessionId()).thenReturn('valid_session');
        when(mockSessionManager.getCurrentSession()).thenReturn(
          SessionData(
            sessionId: 'valid_session',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            lastActiveAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        final result = await SessionRecoveryManager.performSessionHealthCheck(mockSessionManager);

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(SessionHealthStatus.healthy));
      });

      test('should return unhealthy for null session manager', () async {
        final result = await SessionRecoveryManager.performSessionHealthCheck(null);

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(SessionHealthStatus.unhealthy));
      });

      test('should return unhealthy for failing session manager', () async {
        when(mockSessionManager.getCurrentSessionId()).thenThrow(Exception('Session error'));

        final result = await SessionRecoveryManager.performSessionHealthCheck(mockSessionManager);

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(SessionHealthStatus.unhealthy));
      });
    });

    group('recoverFromSessionTimeout', () {
      test('should recover from session timeout successfully', () async {
        const newSessionId = 'new_session_123';
        
        final result = await SessionRecoveryManager.recoverFromSessionTimeout(
          () async => newSessionId,
          reason: 'timeout_test',
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(newSessionId));
      });

      test('should handle timeout recovery failure', () async {
        final result = await SessionRecoveryManager.recoverFromSessionTimeout(
          () async => throw Exception('Recovery failed'),
          reason: 'timeout_test',
        );

        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Recovery failed'));
      });
    });

    group('recoverFromSessionInvalidation', () {
      test('should recover from session invalidation', () async {
        const newSessionId = 'invalidation_recovery_session';
        
        final result = await SessionRecoveryManager.recoverFromSessionInvalidation(
          () async => newSessionId,
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(newSessionId));
      });

      test('should handle invalidation recovery failure', () async {
        final result = await SessionRecoveryManager.recoverFromSessionInvalidation(
          () async => throw Exception('Invalidation recovery failed'),
        );

        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Invalidation recovery failed'));
      });
    });

    group('recoverFromSessionCorruption', () {
      test('should recover from session corruption', () async {
        const newSessionId = 'corruption_recovery_session';
        
        final result = await SessionRecoveryManager.recoverFromSessionCorruption(
          () async => newSessionId,
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(newSessionId));
      });

      test('should handle corruption recovery failure', () async {
        final result = await SessionRecoveryManager.recoverFromSessionCorruption(
          () async => throw Exception('Corruption recovery failed'),
        );

        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Corruption recovery failed'));
      });
    });

    group('recoverFromAuthFailure', () {
      test('should recover from auth failure with token refresh', () async {
        const newToken = 'new_auth_token';
        
        final result = await SessionRecoveryManager.recoverFromAuthFailure(
          tokenRefreshCallback: () async => newToken,
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(newToken));
      });

      test('should handle auth recovery failure', () async {
        final result = await SessionRecoveryManager.recoverFromAuthFailure(
          tokenRefreshCallback: () async => throw Exception('Token refresh failed'),
        );

        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Token refresh failed'));
      });
    });
  });
}