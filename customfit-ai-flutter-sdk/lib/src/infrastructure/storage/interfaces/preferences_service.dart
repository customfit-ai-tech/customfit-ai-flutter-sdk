// infrastructure/storage/interfaces/preferences_service.dart
//
// Abstract interface for preferences storage operations.
// Defines the contract for persistent key-value storage.

import 'dart:async';

/// Abstract interface for preferences storage
abstract class IPreferencesService {
  /// Get string value by key
  Future<String?> getString(String key);

  /// Set string value
  Future<void> setString(String key, String value);

  /// Get integer value by key
  Future<int?> getInt(String key);

  /// Set integer value
  Future<void> setInt(String key, int value);

  /// Get boolean value by key
  Future<bool?> getBool(String key);

  /// Set boolean value
  Future<void> setBool(String key, bool value);

  /// Remove value by key
  Future<void> remove(String key);

  /// Clear all stored values
  Future<void> clear();

  /// Check if key exists
  Future<bool> containsKey(String key);

  /// Get all keys
  Future<Set<String>> getKeys();
}
