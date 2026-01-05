// test/unit/core/error/config_recovery_manager_simplified_test.dart
//
// Simplified tests for ConfigRecoveryManager after SDK simplification
// Tests basic recovery functionality without over-engineering

import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/recovery_managers.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/config_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../../helpers/test_storage_helper.dart';

@GenerateMocks([ConfigManager])
import 'config_recovery_manager_test.mocks.dart';

void main() {
  group('ConfigRecoveryManager (Simplified)', () {
    late MockConfigManager mockConfigManager;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestStorageHelper.setupTestStorage();
      mockConfigManager = MockConfigManager();
    });

    tearDown(() {
      TestStorageHelper.clearTestStorage();
    });

    group('recoverFromConfigUpdateFailure', () {
      test('should successfully recover from config update failure', () async {
        final fallbackConfig = {'feature1': true, 'feature2': 'value'};
        
        final result = await ConfigRecoveryManager.recoverFromConfigUpdateFailure(
          () async => fallbackConfig,
          failureReason: 'Network timeout',
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(fallbackConfig));
      });

      test('should handle recovery operation failure', () async {
        final result = await ConfigRecoveryManager.recoverFromConfigUpdateFailure(
          () async => throw Exception('Recovery failed'),
          failureReason: 'Network timeout',
        );

        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Recovery failed'));
      });
    });

    group('safeConfigUpdate', () {
      test('should perform safe config update', () async {
        when(mockConfigManager.getAllFlags()).thenReturn({'existing': 'config'});
        
        final newConfig = {'updated': 'config'};
        final result = await ConfigRecoveryManager.safeConfigUpdate(
          mockConfigManager,
          newConfig,
        );

        expect(result.isSuccess, isTrue);
      });

      test('should handle config manager errors during safe update', () async {
        when(mockConfigManager.getAllFlags()).thenThrow(Exception('Config error'));
        
        final newConfig = {'updated': 'config'};
        final result = await ConfigRecoveryManager.safeConfigUpdate(
          mockConfigManager,
          newConfig,
        );

        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Config error'));
      });
    });

    group('recoverFromConfigCorruption', () {
      test('should recover from config corruption', () async {
        final backupConfig = {'backup': 'config'};
        
        final result = await ConfigRecoveryManager.recoverFromConfigCorruption(
          () async => backupConfig,
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(backupConfig));
      });

      test('should handle corruption recovery failure', () async {
        final result = await ConfigRecoveryManager.recoverFromConfigCorruption(
          () async => throw Exception('Backup corrupted'),
        );

        expect(result.isSuccess, isFalse);
        expect(result.getErrorMessage(), contains('Backup corrupted'));
      });
    });

    group('performConfigHealthCheck', () {
      test('should return healthy status for valid config manager', () async {
        when(mockConfigManager.getAllFlags()).thenReturn({'valid': 'config'});
        
        final result = await ConfigRecoveryManager.performConfigHealthCheck(mockConfigManager);

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(ConfigHealthStatus.healthy));
      });

      test('should return invalid status for failing config manager', () async {
        when(mockConfigManager.getAllFlags()).thenThrow(Exception('Config error'));
        
        final result = await ConfigRecoveryManager.performConfigHealthCheck(mockConfigManager);

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(ConfigHealthStatus.invalid));
      });
    });
  });
}