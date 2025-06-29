// lib/src/core/util/storage_abstraction.dart
//
// Storage abstraction layer for better testability and separation of concerns.
// Provides pluggable storage backends that can be easily mocked and tested
// without depending on platform-specific implementations.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/preferences_service.dart';
import '../../services/secure_storage_service.dart';

/// Abstract interface for key-value storage operations
abstract class KeyValueStorage {
  /// Get a string value for the given key
  Future<String?> getString(String key);

  /// Set a string value for the given key
  Future<bool> setString(String key, String value);

  /// Remove a value for the given key
  Future<bool> remove(String key);

  /// Get all keys that match an optional prefix
  Set<String> getKeys({String? prefix});

  /// Clear all stored values
  Future<bool> clear();
}

/// Abstract interface for file storage operations
abstract class FileStorage {
  /// Check if a file exists at the given path
  Future<bool> exists(String path);

  /// Read the contents of a file as a string
  Future<String> readAsString(String path);

  /// Write content to a file
  Future<void> writeAsString(String path, String content);

  /// Delete a file
  Future<void> delete(String path);

  /// Create a directory (including parent directories)
  Future<void> createDirectory(String path);

  /// List files in a directory
  Future<List<String>> listFiles(String directoryPath);

  /// Get the cache directory path
  Future<String> getCacheDirectoryPath();
}

/// Storage configuration for the cache system
class StorageConfig {
  final KeyValueStorage keyValueStorage;
  final FileStorage fileStorage;
  final SecureStorageService? secureStorage;

  const StorageConfig({
    required this.keyValueStorage,
    required this.fileStorage,
    this.secureStorage,
  });

  /// Check if secure storage is available
  bool get hasSecureStorage =>
      secureStorage != null && secureStorage!.isAvailable;
}

/// Concrete implementation using SharedPreferences for key-value storage
class SharedPreferencesKeyValueStorage implements KeyValueStorage {
  static const String _instanceKey = 'SharedPreferencesKeyValueStorage';

  // Cache the PreferencesService instance
  PreferencesService? _prefsService;
  bool _initialized = false;

  /// Initialize the storage with PreferencesService
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      try {
        _prefsService = await PreferencesService.getInstance();
        _initialized = true;
      } catch (e) {
        // In test environments or when SharedPreferences is not available
        _initialized = true; // Mark as initialized even if failed
      }
    }
  }

  @override
  Future<String?> getString(String key) async {
    await _ensureInitialized();
    if (_prefsService != null && _prefsService!.isAvailable) {
      return await _prefsService!.getString(key);
    }
    // Fallback to SharedPreferences directly for testing
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPrefs = prefs; // Cache for getKeys
      return prefs.getString(key);
    } catch (e) {
      // Final fallback to in-memory storage
      return InMemoryKeyValueStorage()._storage[key];
    }
  }

  @override
  Future<bool> setString(String key, String value) async {
    await _ensureInitialized();
    if (_prefsService != null && _prefsService!.isAvailable) {
      return await _prefsService!.setString(key, value);
    }
    // Fallback to SharedPreferences directly for testing
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPrefs = prefs; // Cache for getKeys
      return await prefs.setString(key, value);
    } catch (e) {
      // Final fallback to in-memory storage
      InMemoryKeyValueStorage()._storage[key] = value;
      return true;
    }
  }

  @override
  Future<bool> remove(String key) async {
    await _ensureInitialized();
    if (_prefsService != null && _prefsService!.isAvailable) {
      return await _prefsService!.remove(key);
    }
    // Fallback to SharedPreferences directly for testing
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(key);
    } catch (e) {
      // Final fallback to in-memory storage
      InMemoryKeyValueStorage()._storage.remove(key);
      return true;
    }
  }

  // Cache the SharedPreferences instance
  SharedPreferences? _cachedPrefs;

  @override
  Set<String> getKeys({String? prefix}) {
    // For test environments, SharedPreferences.getInstance() has already been called
    // and we can access the test values through PreferencesService
    if (_prefsService != null && _prefsService!.isAvailable) {
      // Use PreferencesService's synchronous getKeys method
      final keys = _prefsService!.getAllKeys();
      if (prefix == null) {
        return keys;
      }
      return keys.where((key) => key.startsWith(prefix)).toSet();
    }
    
    // Fallback: try to use cached prefs or return empty set
    if (_cachedPrefs != null) {
      final keys = _cachedPrefs!.getKeys();
      if (prefix == null) {
        return keys;
      }
      return keys.where((key) => key.startsWith(prefix)).toSet();
    }
    
    return <String>{};
  }

  @override
  Future<bool> clear() async {
    await _ensureInitialized();
    if (_prefsService != null && _prefsService!.isAvailable) {
      return await _prefsService!.clear();
    }
    // Fallback to in-memory storage for testing
    InMemoryKeyValueStorage()._storage.clear();
    return true;
  }
}

/// Concrete implementation using the file system for file storage
class FileSystemFileStorage implements FileStorage {
  final String _basePath;

  FileSystemFileStorage(this._basePath);

  @override
  Future<bool> exists(String path) async {
    try {
      final file = File(_getFullPath(path));
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> readAsString(String path) async {
    final file = File(_getFullPath(path));
    return await file.readAsString();
  }

  @override
  Future<void> writeAsString(String path, String content) async {
    final file = File(_getFullPath(path));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  @override
  Future<void> delete(String path) async {
    final file = File(_getFullPath(path));
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> createDirectory(String path) async {
    final directory = Directory(_getFullPath(path));
    await directory.create(recursive: true);
  }

  @override
  Future<List<String>> listFiles(String directoryPath) async {
    final directory = Directory(_getFullPath(directoryPath));
    if (await directory.exists()) {
      final entities = await directory.list().toList();
      return entities.whereType<File>().map((f) => f.path).toList();
    }
    return [];
  }

  @override
  Future<String> getCacheDirectoryPath() async {
    return _basePath;
  }

  String _getFullPath(String path) {
    if (path.startsWith('/')) {
      return path; // Absolute path
    }
    return '$_basePath/$path';
  }
}

/// In-memory storage implementation for testing
class InMemoryKeyValueStorage implements KeyValueStorage {
  static final InMemoryKeyValueStorage _instance =
      InMemoryKeyValueStorage._internal();
  final Map<String, String> _storage = {};

  factory InMemoryKeyValueStorage() {
    return _instance;
  }

  InMemoryKeyValueStorage._internal();

  @override
  Future<String?> getString(String key) async {
    return _storage[key];
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (key.isEmpty) return false;
    _storage[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _storage.remove(key);
    return true;
  }

  @override
  Set<String> getKeys({String? prefix}) {
    if (prefix == null) {
      return _storage.keys.toSet();
    }
    return _storage.keys.where((key) => key.startsWith(prefix)).toSet();
  }

  @override
  Future<bool> clear() async {
    _storage.clear();
    return true;
  }

  /// Get a copy of the current storage state for testing
  Map<String, String> getStorageCopy() {
    return Map<String, String>.from(_storage);
  }
}

/// In-memory file storage implementation for testing
class InMemoryFileStorage implements FileStorage {
  final Map<String, String> _files = {};
  final Set<String> _directories = {};
  final String _basePath;

  InMemoryFileStorage([this._basePath = '/mock_cache']);

  @override
  Future<bool> exists(String path) async {
    return _files.containsKey(_normalizePath(path));
  }

  @override
  Future<String> readAsString(String path) async {
    final normalizedPath = _normalizePath(path);
    if (!_files.containsKey(normalizedPath)) {
      throw FileSystemException('File not found', normalizedPath);
    }
    return _files[normalizedPath]!;
  }

  @override
  Future<void> writeAsString(String path, String content) async {
    final normalizedPath = _normalizePath(path);
    _files[normalizedPath] = content;

    // Ensure parent directories exist
    final parentDir = _getParentDirectory(normalizedPath);
    if (parentDir.isNotEmpty) {
      _directories.add(parentDir);
    }
  }

  @override
  Future<void> delete(String path) async {
    _files.remove(_normalizePath(path));
  }

  @override
  Future<void> createDirectory(String path) async {
    _directories.add(_normalizePath(path));
  }

  @override
  Future<List<String>> listFiles(String directoryPath) async {
    final normalizedDir = _normalizePath(directoryPath);
    return _files.keys
        .where((filePath) => _getParentDirectory(filePath) == normalizedDir)
        .toList();
  }

  @override
  Future<String> getCacheDirectoryPath() async {
    return _basePath;
  }

  String _normalizePath(String path) {
    if (path.startsWith('/')) {
      return path;
    }
    return '$_basePath/$path';
  }

  String _getParentDirectory(String path) {
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash <= 0) return '';
    return path.substring(0, lastSlash);
  }

  /// Get a copy of the current file storage state for testing
  Map<String, String> getFilesCopy() {
    return Map<String, String>.from(_files);
  }

  /// Get a copy of the current directories for testing
  Set<String> getDirectoriesCopy() {
    return Set<String>.from(_directories);
  }
}

/// Storage abstraction manager that provides storage instances
class StorageManager {
  static StorageConfig? _config;
  static StorageConfig? _testConfig;

  /// Set the storage configuration
  static void configure(StorageConfig config) {
    _config = config;
  }

  /// Set test configuration for unit testing
  static void setTestConfig(StorageConfig config) {
    _testConfig = config;
  }

  /// Clear test configuration
  static void clearTestConfig() {
    _testConfig = null;
  }

  /// Get the current storage configuration
  static StorageConfig get config {
    if (_testConfig != null) return _testConfig!;
    if (_config != null) return _config!;

    // Default configuration - in a real app this would use actual implementations
    throw StateError(
        'StorageManager not configured. Call StorageManager.configure() first.');
  }

  /// Create a default configuration for production use
  static Future<StorageConfig> createDefaultConfig() async {
    // In a real implementation, this would:
    // 1. Get the actual app documents directory
    // 2. Create proper SharedPreferences wrapper
    // 3. Return real storage implementations

    SecureStorageService? secureStorage;
    try {
      secureStorage = await SecureStorageService.getInstance();
    } catch (e) {
      // Secure storage might not be available on all platforms
      secureStorage = null;
    }

    return StorageConfig(
      keyValueStorage: SharedPreferencesKeyValueStorage(),
      fileStorage: FileSystemFileStorage('/tmp/cf_cache'),
      secureStorage: secureStorage,
    );
  }

  /// Create a test configuration with in-memory storage
  static StorageConfig createTestConfig() {
    return StorageConfig(
      keyValueStorage: InMemoryKeyValueStorage(),
      fileStorage: InMemoryFileStorage(),
    );
  }
}

/// Extension methods for StorageConfig to provide secure storage operations
extension SecureStorageExtension on StorageConfig {
  /// Store sensitive data securely
  Future<bool> setSecureString(String key, String value) async {
    if (!hasSecureStorage) {
      throw StateError('Secure storage not available for sensitive data');
    }
    return await secureStorage!.setString(key, value);
  }

  /// Retrieve sensitive data
  Future<String?> getSecureString(String key) async {
    if (!hasSecureStorage) {
      throw StateError('Secure storage not available for sensitive data');
    }
    return await secureStorage!.getString(key);
  }

  /// Remove sensitive data
  Future<bool> removeSecure(String key) async {
    if (!hasSecureStorage) {
      throw StateError('Secure storage not available for sensitive data');
    }
    return await secureStorage!.remove(key);
  }
}
