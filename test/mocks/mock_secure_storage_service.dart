// test/mocks/mock_secure_storage_service.dart
//
// Mock implementation of SecureStorageService for testing
import 'package:customfit_ai_flutter_sdk/src/services/secure_storage_service.dart';
/// Mock implementation of SecureStorageService for testing
class MockSecureStorageService implements SecureStorageService {
  final Map<String, String> _storage = {};
  bool _isAvailable = true;
  /// Create a test instance without going through the singleton
  MockSecureStorageService();
  /// Set whether the mock storage should be available
  void setAvailable(bool available) {
    _isAvailable = available;
  }
  @override
  bool get isAvailable => _isAvailable;
  @override
  Future<bool> setString(String key, String value) async {
    if (!_isAvailable) {
      return false;
    }
    _storage[key] = value;
    return true;
  }
  @override
  Future<String?> getString(String key) async {
    if (!_isAvailable) {
      return null;
    }
    return _storage[key];
  }
  @override
  Future<bool> remove(String key) async {
    if (!_isAvailable) {
      return false;
    }
    _storage.remove(key);
    return true;
  }
  @override
  Future<bool> clearAll() async {
    if (!_isAvailable) {
      return false;
    }
    _storage.clear();
    return true;
  }
  @override
  Future<bool> containsKey(String key) async {
    if (!_isAvailable) {
      return false;
    }
    return _storage.containsKey(key);
  }
  @override
  Set<String> getCachedKeys() {
    return _storage.keys.toSet();
  }
  /// Get the storage map for testing
  Map<String, String> getStorage() => Map.from(_storage);
}