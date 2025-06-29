// lib/src/services/secure_storage_service.dart
//
// Secure storage service using flutter_secure_storage for sensitive data.
// Provides encrypted storage for API keys, tokens, and other sensitive information.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../logging/logger.dart';

/// Service for secure storage of sensitive data
class SecureStorageService {
  static const String _tag = 'SecureStorageService';
  static SecureStorageService? _instance;

  late final FlutterSecureStorage _storage;
  final Map<String, String> _memoryCache = {};
  bool _isAvailable = false;
  bool _initialized = false;

  /// Android-specific options for secure storage
  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    sharedPreferencesName: 'cf_secure_prefs',
    preferencesKeyPrefix: 'cf_secure_',
  );

  /// iOS-specific options for secure storage
  static const IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    accountName: 'customfit_sdk',
  );

  /// Private constructor
  SecureStorageService._() {
    _storage = const FlutterSecureStorage(
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  /// Get singleton instance
  static Future<SecureStorageService> getInstance() async {
    if (_instance == null) {
      _instance = SecureStorageService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  /// Initialize the secure storage service
  Future<void> _initialize() async {
    if (_initialized) return;

    try {
      // Test if secure storage is available by attempting a read
      await _storage.read(key: 'cf_test_key');
      _isAvailable = true;
      Logger.d('$_tag: Secure storage initialized successfully');
    } catch (e) {
      _isAvailable = false;
      Logger.w('$_tag: Secure storage not available: $e');

      // On web platform, secure storage is not available
      if (_isWeb()) {
        Logger.d('$_tag: Running on web platform, using memory storage');
      }
    } finally {
      _initialized = true;
    }
  }

  /// Check if running on web platform
  bool _isWeb() {
    try {
      return identical(0, 0.0); // This is true only on web
    } catch (_) {
      return false;
    }
  }

  /// Check if secure storage is available
  bool get isAvailable => _isAvailable;

  /// Store a string value securely
  Future<bool> setString(String key, String value) async {
    try {
      if (_isAvailable) {
        await _storage.write(key: key, value: value);
        // Also cache in memory for faster access
        _memoryCache[key] = value;
        return true;
      } else {
        // Fallback to memory storage for platforms without secure storage
        _memoryCache[key] = value;
        Logger.d('$_tag: Stored in memory cache: $key');
        return true;
      }
    } catch (e) {
      Logger.e('$_tag: Failed to store secure value: $e');
      return false;
    }
  }

  /// Retrieve a string value from secure storage
  Future<String?> getString(String key) async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(key)) {
        return _memoryCache[key];
      }

      if (_isAvailable) {
        final value = await _storage.read(key: key);
        if (value != null) {
          // Cache the value for faster subsequent access
          _memoryCache[key] = value;
        }
        return value;
      } else {
        // Fallback to memory storage
        return _memoryCache[key];
      }
    } catch (e) {
      Logger.e('$_tag: Failed to retrieve secure value: $e');
      return null;
    }
  }

  /// Remove a value from secure storage
  Future<bool> remove(String key) async {
    try {
      if (_isAvailable) {
        await _storage.delete(key: key);
      }
      _memoryCache.remove(key);
      return true;
    } catch (e) {
      Logger.e('$_tag: Failed to remove secure value: $e');
      return false;
    }
  }

  /// Clear all secure storage
  Future<bool> clearAll() async {
    try {
      if (_isAvailable) {
        await _storage.deleteAll();
      }
      _memoryCache.clear();
      return true;
    } catch (e) {
      Logger.e('$_tag: Failed to clear secure storage: $e');
      return false;
    }
  }

  /// Check if a key exists in secure storage
  Future<bool> containsKey(String key) async {
    if (_memoryCache.containsKey(key)) {
      return true;
    }

    if (_isAvailable) {
      try {
        final value = await _storage.read(key: key);
        return value != null;
      } catch (e) {
        Logger.e('$_tag: Failed to check key existence: $e');
        return false;
      }
    }

    return false;
  }

  /// Get all keys (only from memory cache for security)
  Set<String> getCachedKeys() {
    return _memoryCache.keys.toSet();
  }

  /// Constructor for testing (allows injection of mock storage)
  SecureStorageService._withMockStorage(FlutterSecureStorage mockStorage) {
    _storage = mockStorage;
    _isAvailable = true;
    _initialized = true;
  }

  /// Get instance for testing (allows injection of mock storage)
  static SecureStorageService getTestInstance(
      FlutterSecureStorage mockStorage) {
    return SecureStorageService._withMockStorage(mockStorage);
  }

  /// Clear instance (for testing)
  static void clearInstance() {
    _instance = null;
  }
}
