import 'dart:async';
import 'dart:isolate';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';
import '../logging/logger.dart';

/// Centralized wrapper for SharedPreferences access with async-first design
/// This prevents UI blocking by ensuring all operations are non-blocking
/// SECURITY: Automatically uses secure storage for sensitive data
class PreferencesService {
  static const String _tag = 'PreferencesService';
  static PreferencesService? _instance;
  static SharedPreferences? _prefs;
  static SecureStorageService? _secureStorage;
  static Completer<void> _initLock = Completer<void>();
  static bool _isInitializing = false;

  // In-memory cache for frequently accessed values
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiration = Duration(seconds: 30);

  // SECURITY: Define sensitive key patterns that should use secure storage
  static const List<String> _sensitiveKeyPatterns = [
    'session',
    'api_key',
    'client_key',
    'auth',
    'token',
    'credential',
    'password',
    'secret',
    'private',
    'secure',
    'cf_session',
    'cf_user_token',
    'cf_auth',
  ];

  /// Private constructor
  PreferencesService._();

  /// Get singleton instance with lazy async initialization
  static Future<PreferencesService> getInstance() async {
    if (_instance == null) {
      _instance = PreferencesService._();

      // Start initialization if not already in progress
      if (!_isInitializing && !_initLock.isCompleted) {
        _isInitializing = true;
        _initializeAsync();
      }
    }

    // Wait for initialization to complete
    await _initLock.future;
    return _instance!;
  }

  /// Initialize SharedPreferences and SecureStorage asynchronously without blocking
  static void _initializeAsync() {
    Future(() async {
      try {
        // Initialize both regular and secure storage
        final futures = await Future.wait([
          SharedPreferences.getInstance(),
          SecureStorageService.getInstance(),
        ]);

        _prefs = futures[0] as SharedPreferences;
        _secureStorage = futures[1] as SecureStorageService;

        Logger.d(
            '$_tag: Initialized with secure storage support: ${_secureStorage!.isAvailable}');
      } catch (e) {
        Logger.e('$_tag: Failed to initialize storage services: $e');
        // In test environments, storage might not be available
        // Continue with null storage and handle gracefully in methods
      } finally {
        _isInitializing = false;
        if (!_initLock.isCompleted) {
          _initLock.complete();
        }
      }
    });
  }

  /// SECURITY: Check if a key should be stored securely
  static bool _isSensitiveKey(String key) {
    final lowerKey = key.toLowerCase();
    return _sensitiveKeyPatterns.any((pattern) => lowerKey.contains(pattern));
  }

  /// Get SharedPreferences instance directly if needed
  /// Returns null if not yet initialized
  SharedPreferences? get prefs {
    return _prefs;
  }

  /// Check if preferences are available
  bool get isAvailable => _prefs != null;

  /// Check if secure storage is available
  bool get isSecureStorageAvailable => _secureStorage?.isAvailable ?? false;

  /// Check if initialization is complete
  bool get isInitialized => _initLock.isCompleted;

  // SECURITY-ENHANCED: Common preference operations with automatic secure storage

  Future<bool> setString(String key, String value) async {
    await _ensureInitialized();

    // SECURITY: Use secure storage for sensitive data
    if (_isSensitiveKey(key)) {
      Logger.d('$_tag: Storing sensitive key securely: $key');
      if (_secureStorage != null) {
        final success = await _secureStorage!.setString(key, value);
        if (success) {
          // Update cache for faster access
          _cache[key] = value;
          _cacheTimestamps[key] = DateTime.now();
        }
        return success;
      } else {
        Logger.w('$_tag: Secure storage not available for sensitive key: $key');
        // Fallback to regular storage with warning
      }
    }

    // Use regular storage for non-sensitive data
    if (_prefs == null) return false;

    // Update cache
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();

    return _prefs!.setString(key, value);
  }

  /// Get string value asynchronously to prevent blocking
  Future<String?> getString(String key) async {
    // Check cache first
    if (_isCacheValid(key)) {
      return _cache[key] as String?;
    }

    await _ensureInitialized();

    // SECURITY: Check secure storage for sensitive data
    if (_isSensitiveKey(key)) {
      if (_secureStorage != null) {
        final value = await _secureStorage!.getString(key);
        if (value != null) {
          _updateCache(key, value);
          return value;
        }
      }
      // If not found in secure storage, don't fallback to regular storage
      // for security reasons
      return null;
    }

    // Use regular storage for non-sensitive data
    if (_prefs == null) return null;

    final value = _prefs!.getString(key);
    _updateCache(key, value);
    return value;
  }

  Future<bool> setInt(String key, int value) async {
    await _ensureInitialized();

    // SECURITY: Use secure storage for sensitive data
    if (_isSensitiveKey(key)) {
      Logger.d('$_tag: Storing sensitive key securely: $key');
      if (_secureStorage != null) {
        final success = await _secureStorage!.setString(key, value.toString());
        if (success) {
          _cache[key] = value;
          _cacheTimestamps[key] = DateTime.now();
        }
        return success;
      }
    }

    if (_prefs == null) return false;

    // Update cache
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();

    return _prefs!.setInt(key, value);
  }

  /// Get int value asynchronously to prevent blocking
  Future<int?> getInt(String key) async {
    // Check cache first
    if (_isCacheValid(key)) {
      return _cache[key] as int?;
    }

    await _ensureInitialized();

    // SECURITY: Check secure storage for sensitive data
    if (_isSensitiveKey(key)) {
      if (_secureStorage != null) {
        final stringValue = await _secureStorage!.getString(key);
        if (stringValue != null) {
          final intValue = int.tryParse(stringValue);
          if (intValue != null) {
            _updateCache(key, intValue);
            return intValue;
          }
        }
      }
      return null;
    }

    if (_prefs == null) return null;

    final value = _prefs!.getInt(key);
    _updateCache(key, value);
    return value;
  }

  Future<bool> setBool(String key, bool value) async {
    await _ensureInitialized();

    // SECURITY: Use secure storage for sensitive data
    if (_isSensitiveKey(key)) {
      Logger.d('$_tag: Storing sensitive key securely: $key');
      if (_secureStorage != null) {
        final success = await _secureStorage!.setString(key, value.toString());
        if (success) {
          _cache[key] = value;
          _cacheTimestamps[key] = DateTime.now();
        }
        return success;
      }
    }

    if (_prefs == null) return false;

    // Update cache
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();

    return _prefs!.setBool(key, value);
  }

  /// Get bool value asynchronously to prevent blocking
  Future<bool?> getBool(String key) async {
    // Check cache first
    if (_isCacheValid(key)) {
      return _cache[key] as bool?;
    }

    await _ensureInitialized();

    // SECURITY: Check secure storage for sensitive data
    if (_isSensitiveKey(key)) {
      if (_secureStorage != null) {
        final stringValue = await _secureStorage!.getString(key);
        if (stringValue != null) {
          final boolValue = stringValue.toLowerCase() == 'true';
          _updateCache(key, boolValue);
          return boolValue;
        }
      }
      return null;
    }

    if (_prefs == null) return null;

    final value = _prefs!.getBool(key);
    _updateCache(key, value);
    return value;
  }

  Future<bool> setStringList(String key, List<String> value) async {
    await _ensureInitialized();
    if (_prefs == null) return false;

    // Update cache
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();

    return _prefs!.setStringList(key, value);
  }

  /// Get string list asynchronously to prevent blocking
  Future<List<String>?> getStringList(String key) async {
    // Check cache first
    if (_isCacheValid(key)) {
      final cachedValue = _cache[key] as List<String>?;
      // Return a copy to prevent modification of cached data
      return cachedValue != null ? List<String>.from(cachedValue) : null;
    }

    await _ensureInitialized();
    if (_prefs == null) return null;

    final value = _prefs!.getStringList(key);
    _updateCache(key, value);
    // Return a copy to prevent modification of the original list
    return value != null ? List<String>.from(value) : null;
  }

  Future<bool> remove(String key) async {
    await _ensureInitialized();

    // Remove from cache
    _cache.remove(key);
    _cacheTimestamps.remove(key);

    // SECURITY: Remove from both storages for sensitive data
    if (_isSensitiveKey(key)) {
      if (_secureStorage != null) {
        await _secureStorage!.remove(key);
      }
    }

    if (_prefs == null) return false;
    return _prefs!.remove(key);
  }

  Future<bool> clear() async {
    await _ensureInitialized();

    // Clear cache
    _cache.clear();
    _cacheTimestamps.clear();

    // SECURITY: Clear secure storage as well
    if (_secureStorage != null) {
      await _secureStorage!.clearAll();
    }

    if (_prefs == null) return false;
    return _prefs!.clear();
  }

  /// Check if key exists asynchronously
  Future<bool> containsKey(String key) async {
    await _ensureInitialized();

    // SECURITY: Check secure storage for sensitive data
    if (_isSensitiveKey(key)) {
      if (_secureStorage != null) {
        return await _secureStorage!.containsKey(key);
      }
      return false;
    }

    if (_prefs == null) return false;
    return _prefs!.containsKey(key);
  }

  /// Get all keys asynchronously
  Future<Set<String>> getKeys() async {
    await _ensureInitialized();

    final keys = <String>{};

    // Add regular storage keys
    if (_prefs != null) {
      keys.addAll(_prefs!.getKeys());
    }

    // SECURITY: Add secure storage keys (only cached ones for security)
    if (_secureStorage != null) {
      keys.addAll(_secureStorage!.getCachedKeys());
    }

    return keys;
  }

  /// Get all keys synchronously (for storage abstraction)
  Set<String> getAllKeys() {
    final keys = <String>{};

    // Add regular storage keys if available
    if (_prefs != null) {
      keys.addAll(_prefs!.getKeys());
    }

    // SECURITY: Add secure storage keys (only cached ones for security)
    if (_secureStorage != null) {
      keys.addAll(_secureStorage!.getCachedKeys());
    }

    return keys;
  }

  // Helper methods

  /// Ensure initialization is complete
  Future<void> _ensureInitialized() async {
    if (!_initLock.isCompleted) {
      await _initLock.future;
    }
  }

  /// Check if cached value is still valid
  bool _isCacheValid(String key) {
    if (!_cache.containsKey(key)) return false;

    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheExpiration;
  }

  /// Update cache with new value
  void _updateCache(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Reset the singleton instance (for testing)
  static void reset() {
    _instance = null;
    _prefs = null;
    _secureStorage = null;
    _cache.clear();
    _cacheTimestamps.clear();
    if (!_initLock.isCompleted) {
      _initLock.complete();
    }
    _initLock = Completer<void>();
    _isInitializing = false;
  }

  /// Pre-warm the cache with frequently used keys
  /// This can be called during app startup to prevent blocking later
  Future<void> prewarmCache(List<String> keys) async {
    await _ensureInitialized();

    for (final key in keys) {
      // Use the appropriate storage based on sensitivity
      if (_isSensitiveKey(key)) {
        if (_secureStorage != null) {
          final value = await _secureStorage!.getString(key);
          if (value != null) {
            _updateCache(key, value);
          }
        }
      } else {
        if (_prefs != null && _prefs!.containsKey(key)) {
          final value = _prefs!.get(key);
          _updateCache(key, value);
        }
      }
    }
  }

  /// Execute heavy operations in background isolate
  /// This is useful for bulk operations that might block the UI
  static Future<T> runInIsolate<T>(
    Future<T> Function(SendPort sendPort) computation,
  ) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _isolateEntryPoint<T>,
      _IsolateData(computation, receivePort.sendPort),
    );

    try {
      final result = await receivePort.first as T;
      return result;
    } finally {
      isolate.kill(priority: Isolate.immediate);
      receivePort.close();
    }
  }

  static void _isolateEntryPoint<T>(_IsolateData<T> data) async {
    final result = await data.computation(data.sendPort);
    data.sendPort.send(result);
  }

  /// SECURITY: Get security status information
  Map<String, dynamic> getSecurityStatus() {
    return {
      'secureStorageAvailable': isSecureStorageAvailable,
      'regularStorageAvailable': isAvailable,
      'sensitiveKeyPatterns': _sensitiveKeyPatterns,
      'cachedSensitiveKeys': _cache.keys.where(_isSensitiveKey).length,
      'totalCachedKeys': _cache.length,
    };
  }
}

/// Data class for isolate communication
class _IsolateData<T> {
  final Future<T> Function(SendPort sendPort) computation;
  final SendPort sendPort;

  _IsolateData(this.computation, this.sendPort);
}

// Usage example:
// final prefsService = await PreferencesService.getInstance();
// 
// // Regular data (stored in SharedPreferences)
// await prefsService.setString('user_preference', 'value');
// 
// // Sensitive data (automatically stored in secure storage)
// await prefsService.setString('cf_session_id', 'session_12345');
// await prefsService.setString('api_key', 'secret_key');
// 
// final value = await prefsService.getString('cf_session_id');  // Retrieved from secure storage
