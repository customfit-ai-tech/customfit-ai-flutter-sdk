// test/helpers/test_storage_helper.dart
//
// Helper functions for setting up storage in tests
import 'package:customfit_ai_flutter_sdk/src/core/util/storage_abstraction.dart';
import '../mocks/mock_secure_storage_service.dart';
/// Helper class for setting up storage in tests
class TestStorageHelper {
  /// Create a test storage configuration with mock secure storage
  static StorageConfig createTestStorageConfig({
    bool withSecureStorage = true,
    bool secureStorageAvailable = true,
  }) {
    final mockSecureStorage = withSecureStorage ? MockSecureStorageService() : null;
    if (mockSecureStorage != null) {
      mockSecureStorage.setAvailable(secureStorageAvailable);
    }
    return StorageConfig(
      keyValueStorage: InMemoryKeyValueStorage(),
      fileStorage: InMemoryFileStorage(),
      secureStorage: mockSecureStorage,
    );
  }
  /// Set up test storage configuration in StorageManager
  static void setupTestStorage({
    bool withSecureStorage = true,
    bool secureStorageAvailable = true,
  }) {
    final config = createTestStorageConfig(
      withSecureStorage: withSecureStorage,
      secureStorageAvailable: secureStorageAvailable,
    );
    StorageManager.setTestConfig(config);
  }
  /// Clear test storage configuration
  static void clearTestStorage() {
    StorageManager.clearTestConfig();
  }
}