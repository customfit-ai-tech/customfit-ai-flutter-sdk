// infrastructure/storage/interfaces/secure_storage_service.dart
//
// Abstract interface for secure storage operations.
// Defines the contract for encrypted/secure key-value storage.

import 'dart:async';

/// Abstract interface for secure storage
abstract class ISecureStorageService {
  /// Get secure value by key
  Future<String?> read(String key);

  /// Set secure value
  Future<void> write(String key, String value);

  /// Remove secure value by key
  Future<void> delete(String key);

  /// Clear all secure storage
  Future<void> deleteAll();

  /// Check if key exists in secure storage
  Future<bool> containsKey(String key);

  /// Get all keys from secure storage
  Future<Set<String>> readAll();
}
