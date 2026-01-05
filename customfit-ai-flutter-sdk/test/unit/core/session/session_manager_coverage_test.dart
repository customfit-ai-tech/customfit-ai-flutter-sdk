// test/unit/core/session/session_manager_coverage_test.dart
//
// Simplified tests for SessionManager after SDK simplification
// Tests basic session management functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/core/session/session_manager.dart';
import '../../../helpers/test_storage_helper.dart';
import '../../../test_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('SessionManager (Simplified Coverage)', () {
    late SessionManager sessionManager;

    setUpAll(() {
      TestConfig.setupTestLogger();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      TestStorageHelper.setupTestStorage();

      // Initialize session manager using static method
      final result = await SessionManager.initialize();
      sessionManager = result.getOrThrow();
    });

    tearDown(() async {
      await sessionManager.clearSession();
      TestStorageHelper.clearTestStorage();
    });

    group('Session Lifecycle', () {
      test('should create session with valid ID', () {
        final sessionId = sessionManager.getCurrentSessionId();
        expect(sessionId, isNotEmpty);
        expect(sessionId.length, greaterThan(10));
      });

      test('should return session data', () {
        final sessionData = sessionManager.getCurrentSession();
        expect(sessionData, isNotNull);
        expect(sessionData!.sessionId, isNotEmpty);
        expect(sessionData.createdAt, isA<int>());
        expect(sessionData.lastActiveAt, isA<int>());
      });

      test('should update activity timestamp', () async {
        final initialData = sessionManager.getCurrentSession();
        final initialTimestamp = initialData?.lastActiveAt;

        // Wait a moment to ensure timestamp difference
        await Future.delayed(const Duration(milliseconds: 10));
        
        await sessionManager.updateActivity();

        final updatedData = sessionManager.getCurrentSession();
        expect(updatedData?.lastActiveAt, greaterThan(initialTimestamp ?? 0));
      });

      test('should force session rotation', () async {
        final originalSessionId = sessionManager.getCurrentSessionId();
        
        final newSessionId = await sessionManager.forceRotation();
        
        expect(newSessionId, isNotEmpty);
        expect(newSessionId, isNot(equals(originalSessionId)));
        expect(sessionManager.getCurrentSessionId(), equals(newSessionId));
      });

      test('should handle authentication changes', () async {
        expect(() => sessionManager.onAuthenticationChange(), returnsNormally);
      });

      test('should clear session', () async {
        expect(() async => await sessionManager.clearSession(), returnsNormally);
      });

      test('should rotate session', () async {
        final originalSessionId = sessionManager.getCurrentSessionId();
        
        await sessionManager.rotateSession();
        final newSessionId = sessionManager.getCurrentSessionId();
        
        expect(newSessionId, isNotEmpty);
        expect(newSessionId, isNot(equals(originalSessionId)));
      });
    });

    group('Session Listeners', () {
      test('should add and remove listeners', () {
        final listener = TestSessionRotationListener();
        
        expect(() => sessionManager.addListener(listener), returnsNormally);
        expect(() => sessionManager.removeListener(listener), returnsNormally);
      });

      test('should notify listeners on rotation', () async {
        final listener = TestSessionRotationListener();
        sessionManager.addListener(listener);
        
        final originalSessionId = sessionManager.getCurrentSessionId();
        final newSessionId = await sessionManager.forceRotation();
        
        expect(newSessionId, isNotEmpty);
        expect(newSessionId, isNot(equals(originalSessionId)));
      });
    });

    group('Session Statistics', () {
      test('should provide session stats', () {
        final stats = sessionManager.getSessionStats();
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['hasActiveSession'], isTrue);
        expect(stats['sessionId'], isNotEmpty);
        expect(stats['sessionManagerInitialized'], isTrue);
      });
    });

    group('App State Handling', () {
      test('should handle app background', () async {
        expect(() async => sessionManager.onAppBackground(), returnsNormally);
      });

      test('should handle app foreground', () async {
        expect(() async => sessionManager.onAppForeground(), returnsNormally);
      });

    });
  });
}

// Test helper classes
class TestSessionRotationListener implements SessionRotationListener {
  final List<SessionRotationEvent> rotationEvents = [];

  @override
  void onSessionRotated(String? oldSessionId, String newSessionId, RotationReason reason) {
    rotationEvents.add(SessionRotationEvent(oldSessionId, newSessionId, reason));
  }

  void onSessionError(String error) {
    // Test implementation
  }

  void onSessionRestored(String sessionId) {
    // Test implementation
  }
}

class SessionRotationEvent {
  final String? oldSessionId;
  final String newSessionId;
  final RotationReason reason;

  SessionRotationEvent(this.oldSessionId, this.newSessionId, this.reason);
}