// lib/src/core/util/simple_storage_helper.dart
//
// Simple storage helper that replaces the over-engineered storage abstraction.
// Uses SharedPreferences directly for key-value storage and dart:io File operations
// for file storage, eliminating unnecessary abstraction layers.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../logging/logger.dart';

/// Simple storage helper that provides direct access to storage operations
/// without unnecessary abstraction layers
class SimpleStorageHelper {
  static const String _source = 'SimpleStorageHelper';
  static SharedPreferences? _prefs;
  static bool _initialized = false;

  /// Initialize the storage helper
  static Future<void> init() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      Logger.d('$_source: Storage helper initialized');
    } catch (e) {
      Logger.e('$_source: Failed to initialize storage: $e');
      // Don't rethrow - let methods handle the null case gracefully
    }
  }

  /// Ensure storage is initialized
  static Future<void> _ensureInitialized() async {
    if (!_initialized || _prefs == null) {
      await init();
    }
  }

  // ========== KEY-VALUE STORAGE OPERATIONS ==========

  /// Get a string value from storage
  static Future<String?> getString(String key) async {
    await _ensureInitialized();

    try {
      return _prefs?.getString(key);
    } catch (e) {
      Logger.e('$_source: Failed to get string for key $key: $e');
      return null;
    }
  }

  /// Set a string value in storage
  static Future<bool> setString(String key, String value) async {
    await _ensureInitialized();

    try {
      return await _prefs?.setString(key, value) ?? false;
    } catch (e) {
      Logger.e('$_source: Failed to set string for key $key: $e');
      return false;
    }
  }

  /// Remove a value from storage
  static Future<bool> remove(String key) async {
    await _ensureInitialized();

    try {
      return await _prefs?.remove(key) ?? false;
    } catch (e) {
      Logger.e('$_source: Failed to remove key $key: $e');
      return false;
    }
  }

  /// Get all keys from storage
  static Future<Set<String>> getKeys() async {
    await _ensureInitialized();

    try {
      return _prefs?.getKeys() ?? <String>{};
    } catch (e) {
      Logger.e('$_source: Failed to get keys: $e');
      return <String>{};
    }
  }

  /// Clear all storage
  static Future<bool> clear() async {
    await _ensureInitialized();

    try {
      return await _prefs?.clear() ?? false;
    } catch (e) {
      Logger.e('$_source: Failed to clear storage: $e');
      return false;
    }
  }

  // ========== FILE STORAGE OPERATIONS ==========

  /// Read file contents as string
  static Future<String?> readFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      Logger.e('$_source: Failed to read file $path: $e');
      return null;
    }
  }

  /// Write content to file
  static Future<bool> writeFile(String path, String content) async {
    try {
      final file = File(path);

      // Create parent directories if they don't exist
      await file.parent.create(recursive: true);

      await file.writeAsString(content);
      return true;
    } catch (e) {
      Logger.e('$_source: Failed to write file $path: $e');
      return false;
    }
  }

  /// Check if storage is available
  static bool get isAvailable => _initialized && _prefs != null;

  /// Reset storage helper (for testing)
  static void reset() {
    _prefs = null;
    _initialized = false;
  }
}
