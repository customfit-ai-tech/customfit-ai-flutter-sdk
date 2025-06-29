import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/recovery_managers.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/recovery_utils.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
import 'package:customfit_ai_flutter_sdk/src/core/session/session_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../../helpers/test_storage_helper.dart';
@GenerateMocks([SessionManager])
import 'session_recovery_manager_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockSessionManager mockSessionManager;
  setUp(() {
    mockSessionManager = MockSessionManager();
    SharedPreferences.setMockInitialValues({});
    // Setup test storage with secure storage
    TestStorageHelper.setupTestStorage();
  });
  tearDown(() {
    PreferencesService.reset();
    TestStorageHelper.clearTestStorage();
  });
  group('SessionRecoveryManager Tests', () {
    group('recoverFromSessionTimeout', () {
      test('should successfully recover from session timeout', () async {
        // Arrange
        const newSessionId = 'new-session-123';
        when(mockSessionManager.forceRotation())
            .thenAnswer((_) async => newSessionId);
        // Act
        final result = await SessionRecoveryManager.recoverFromSessionTimeout(
          mockSessionManager,
          reason: 'Session expired',
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, newSessionId);
        verify(mockSessionManager.forceRotation()).called(1);
      });
      test('should handle session rotation failure', () async {
        // Arrange
        when(mockSessionManager.forceRotation())
            .thenThrow(Exception('Rotation failed'));
        // Act
        final result = await SessionRecoveryManager.recoverFromSessionTimeout(
          mockSessionManager,
          reason: 'Session timeout',
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.error?.category, ErrorCategory.session);
        expect(result.getErrorMessage(),
            contains('Failed to execute session_timeout_recovery'));
      });
      test('should retry on temporary failures', () async {
        // Arrange
        var callCount = 0;
        when(mockSessionManager.forceRotation()).thenAnswer((_) async {
          callCount++;
          if (callCount < 3) {
            throw Exception('Temporary failure');
          }
          return 'recovered-session-id';
        });
        // Act
        final result = await SessionRecoveryManager.recoverFromSessionTimeout(
          mockSessionManager,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 'recovered-session-id');
        verify(mockSessionManager.forceRotation()).called(3);
      });
      test('should fail after max retries', () async {
        // Arrange
        when(mockSessionManager.forceRotation())
            .thenThrow(Exception('Network error during rotation'));
        // Act
        final result = await SessionRecoveryManager.recoverFromSessionTimeout(
          mockSessionManager,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.error?.category, ErrorCategory.session);
        // Should attempt 3 times (maxRetries)
        verify(mockSessionManager.forceRotation()).called(3);
      });
    });
    group('recoverFromSessionInvalidation', () {
      test('should successfully recover from session invalidation', () async {
        // Arrange
        const invalidSessionId = 'invalid-session-123';
        const newSessionId = 'new-valid-session-456';
        when(mockSessionManager.forceRotation())
            .thenAnswer((_) async => newSessionId);
        // Act
        final result =
            await SessionRecoveryManager.recoverFromSessionInvalidation(
          mockSessionManager,
          invalidSessionId: invalidSessionId,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, newSessionId);
        verify(mockSessionManager.forceRotation()).called(1);
      });
      test('should handle recovery without invalid session ID', () async {
        // Arrange
        const newSessionId = 'new-session-789';
        when(mockSessionManager.forceRotation())
            .thenAnswer((_) async => newSessionId);
        // Act
        final result =
            await SessionRecoveryManager.recoverFromSessionInvalidation(
          mockSessionManager,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, newSessionId);
      });
      test('should handle rotation failure during invalidation recovery',
          () async {
        // Arrange
        when(mockSessionManager.forceRotation())
            .thenThrow(Exception('Unable to create new session'));
        // Act
        final result =
            await SessionRecoveryManager.recoverFromSessionInvalidation(
          mockSessionManager,
          invalidSessionId: 'bad-session',
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.error?.category, ErrorCategory.session);
        expect(result.getErrorMessage(),
            contains('Failed to execute session_invalidation_recovery'));
      });
      test('should retry with fewer attempts for invalidation', () async {
        // Arrange
        var callCount = 0;
        when(mockSessionManager.forceRotation()).thenAnswer((_) async {
          callCount++;
          if (callCount < 2) {
            throw Exception('Temporary failure');
          }
          return 'recovered-session';
        });
        // Act
        final result =
            await SessionRecoveryManager.recoverFromSessionInvalidation(
          mockSessionManager,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 'recovered-session');
        verify(mockSessionManager.forceRotation()).called(2);
      });
    });
    group('recoverFromAuthFailure', () {
      test('should successfully recover with token refresh', () async {
        // Arrange
        const oldToken = 'expired-token';
        const newToken = 'fresh-token';
        Future<String?> tokenRefreshCallback() async => newToken;
        // Act
        final result = await SessionRecoveryManager.recoverFromAuthFailure(
          authToken: oldToken,
          tokenRefreshCallback: tokenRefreshCallback,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, true);
      });
      test('should fail when no refresh callback provided', () async {
        // Act
        final result = await SessionRecoveryManager.recoverFromAuthFailure(
          authToken: 'expired-token',
          tokenRefreshCallback: null,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.error?.category, ErrorCategory.authentication);
        expect(result.getErrorMessage(),
            contains('no refresh mechanism available'));
      });
      test('should handle null token from refresh callback', () async {
        // Arrange
        Future<String?> tokenRefreshCallback() async => null;
        // Act
        final result = await SessionRecoveryManager.recoverFromAuthFailure(
          tokenRefreshCallback: tokenRefreshCallback,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.error?.category, ErrorCategory.authentication);
      });
      test('should handle empty token from refresh callback', () async {
        // Arrange
        Future<String?> tokenRefreshCallback() async => '';
        // Act
        final result = await SessionRecoveryManager.recoverFromAuthFailure(
          tokenRefreshCallback: tokenRefreshCallback,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.error?.category, ErrorCategory.authentication);
      });
      test('should retry token refresh on failure', () async {
        // Arrange
        var callCount = 0;
        Future<String?> tokenRefreshCallback() async {
          callCount++;
          if (callCount < 2) {
            throw Exception('Network error');
          }
          return 'new-token';
        }

        // Act
        final result = await SessionRecoveryManager.recoverFromAuthFailure(
          tokenRefreshCallback: tokenRefreshCallback,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, true);
        expect(callCount, 2);
      });
      test('should fail after max refresh attempts', () async {
        // Arrange
        Future<String?> tokenRefreshCallback() async {
          throw Exception('Token refresh service unavailable');
        }

        // Act
        final result = await SessionRecoveryManager.recoverFromAuthFailure(
          tokenRefreshCallback: tokenRefreshCallback,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.error?.category, ErrorCategory.authentication);
      });
    });
    group('recoverFromSessionCorruption', () {
      test('should successfully recover from session corruption', () async {
        // Arrange
        const newSessionId = 'clean-session-123';
        when(mockSessionManager.forceRotation())
            .thenAnswer((_) async => newSessionId);
        // Act
        final result =
            await SessionRecoveryManager.recoverFromSessionCorruption(
          mockSessionManager,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, newSessionId);
        verify(mockSessionManager.forceRotation()).called(1);
      });
      test('should handle failure to create clean session', () async {
        // Arrange
        when(mockSessionManager.forceRotation())
            .thenThrow(Exception('Critical session error'));
        // Act
        final result =
            await SessionRecoveryManager.recoverFromSessionCorruption(
          mockSessionManager,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.error?.category, ErrorCategory.session);
        expect(result.getErrorMessage(),
            contains('Failed to execute session_corruption_recovery'));
      });
      test('should retry only once for corruption scenarios', () async {
        // Arrange
        var callCount = 0;
        when(mockSessionManager.forceRotation()).thenAnswer((_) async {
          callCount++;
          throw Exception('Persistent corruption');
        });
        // Act
        final result =
            await SessionRecoveryManager.recoverFromSessionCorruption(
          mockSessionManager,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(callCount, 1); // Only 1 retry for corruption
      });
    });
    group('performSessionHealthCheck', () {
      test('should return healthy for valid active session', () async {
        // Arrange
        final currentSession = SessionData(
          sessionId: 'active-session',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          lastActiveAt: DateTime.now().millisecondsSinceEpoch,
          appStartTime: DateTime.now().millisecondsSinceEpoch,
        );
        when(mockSessionManager.getCurrentSession()).thenReturn(currentSession);
        // Act
        final result = await SessionRecoveryManager.performSessionHealthCheck(
          mockSessionManager,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, SessionHealthStatus.healthy);
      });
      test('should return noSession when no active session', () async {
        // Arrange
        when(mockSessionManager.getCurrentSession()).thenReturn(null);
        // Act
        final result = await SessionRecoveryManager.performSessionHealthCheck(
          mockSessionManager,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, SessionHealthStatus.noSession);
      });
      test('should detect and recover from expired session', () async {
        // Arrange
        final expiredSession = SessionData(
          sessionId: 'expired-session',
          createdAt: DateTime.now()
              .subtract(const Duration(hours: 25))
              .millisecondsSinceEpoch,
          lastActiveAt: DateTime.now()
              .subtract(const Duration(hours: 25))
              .millisecondsSinceEpoch,
          appStartTime: DateTime.now()
              .subtract(const Duration(hours: 25))
              .millisecondsSinceEpoch,
        );
        when(mockSessionManager.getCurrentSession()).thenReturn(expiredSession);
        when(mockSessionManager.forceRotation())
            .thenAnswer((_) async => 'new-session');
        // Act
        final result = await SessionRecoveryManager.performSessionHealthCheck(
          mockSessionManager,
          maxSessionAge: const Duration(hours: 24),
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, SessionHealthStatus.recovered);
        verify(mockSessionManager.forceRotation()).called(1);
      });
      test('should detect and recover from inactive session', () async {
        // Arrange
        final inactiveSession = SessionData(
          sessionId: 'inactive-session',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          lastActiveAt: DateTime.now()
              .subtract(const Duration(hours: 2))
              .millisecondsSinceEpoch,
          appStartTime: DateTime.now().millisecondsSinceEpoch,
        );
        when(mockSessionManager.getCurrentSession())
            .thenReturn(inactiveSession);
        when(mockSessionManager.forceRotation())
            .thenAnswer((_) async => 'new-session');
        // Act
        final result = await SessionRecoveryManager.performSessionHealthCheck(
          mockSessionManager,
          maxInactivity: const Duration(hours: 1),
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, SessionHealthStatus.recovered);
        verify(mockSessionManager.forceRotation()).called(1);
      });
      test('should handle recovery failure during health check', () async {
        // Arrange
        final expiredSession = SessionData(
          sessionId: 'expired-session',
          createdAt: DateTime.now()
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch,
          lastActiveAt: DateTime.now()
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch,
          appStartTime: DateTime.now()
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch,
        );
        when(mockSessionManager.getCurrentSession()).thenReturn(expiredSession);
        when(mockSessionManager.forceRotation())
            .thenThrow(Exception('Recovery failed'));
        // Act
        final result = await SessionRecoveryManager.performSessionHealthCheck(
          mockSessionManager,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.error?.category, ErrorCategory.session);
      });
      test('should handle exception during health check', () async {
        // Arrange
        when(mockSessionManager.getCurrentSession())
            .thenThrow(Exception('Session access error'));
        // Act
        final result = await SessionRecoveryManager.performSessionHealthCheck(
          mockSessionManager,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.error?.category, ErrorCategory.session);
        expect(
            result.getErrorMessage(), contains('Session health check failed'));
      });
      test('should respect custom session age and inactivity limits', () async {
        // Arrange
        final recentSession = SessionData(
          sessionId: 'recent-session',
          createdAt: DateTime.now()
              .subtract(const Duration(minutes: 30))
              .millisecondsSinceEpoch,
          lastActiveAt: DateTime.now()
              .subtract(const Duration(minutes: 20))
              .millisecondsSinceEpoch,
          appStartTime: DateTime.now()
              .subtract(const Duration(minutes: 30))
              .millisecondsSinceEpoch,
        );
        when(mockSessionManager.getCurrentSession()).thenReturn(recentSession);
        // Act
        final result = await SessionRecoveryManager.performSessionHealthCheck(
          mockSessionManager,
          maxSessionAge: const Duration(hours: 1),
          maxInactivity: const Duration(minutes: 30),
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, SessionHealthStatus.healthy);
        verifyNever(mockSessionManager.forceRotation());
      });
    });
    group('Error Handling', () {
      test('should handle null session manager gracefully', () async {
        // This test is more theoretical as Dart will catch null issues at compile time
        // But we can test error handling in the recovery methods
        when(mockSessionManager.forceRotation())
            .thenThrow(StateError('SessionManager not initialized'));
        final result = await SessionRecoveryManager.recoverFromSessionTimeout(
          mockSessionManager,
        );
        expect(result.isSuccess, false);
        expect(result.error?.category, ErrorCategory.session);
      });
    });
  });
  group('SessionHealthStatus Tests', () {
    test('should have all expected enum values', () {
      expect(SessionHealthStatus.values.length, 4);
      expect(SessionHealthStatus.values, contains(SessionHealthStatus.healthy));
      expect(
          SessionHealthStatus.values, contains(SessionHealthStatus.recovered));
      expect(
          SessionHealthStatus.values, contains(SessionHealthStatus.noSession));
      expect(
          SessionHealthStatus.values, contains(SessionHealthStatus.unhealthy));
    });
  });
  group('Exception Tests', () {
    test('SessionRecoveryException should format message correctly', () {
      final exception = SessionRecoveryException('Session recovery failed');
      expect(exception.toString(),
          'SessionRecoveryException: Session recovery failed');
      expect(exception.message, 'Session recovery failed');
    });
    test('AuthRecoveryException should format message correctly', () {
      final exception = AuthRecoveryException('Auth token refresh failed');
      expect(exception.toString(),
          'AuthRecoveryException: Auth token refresh failed');
      expect(exception.message, 'Auth token refresh failed');
    });
  });
}
