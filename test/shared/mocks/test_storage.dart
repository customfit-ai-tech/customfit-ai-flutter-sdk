// test/shared/mocks/test_storage.dart
//
// In-memory storage implementation for testing.
// Provides a SharedPreferences-like interface with an in-memory Map backend,
// simulating persistent storage without actual file I/O.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'dart:async';
import 'dart:convert';
/// Test storage implementation that mimics SharedPreferences behavior
class TestStorage {
  // In-memory storage backend
  final Map<String, dynamic> _storage = {};
  // Track operation counts for verification
  int readCount = 0;
  int writeCount = 0;
  int deleteCount = 0;
  int clearCount = 0;
  // Configuration for simulating errors
  bool shouldFailNextRead = false;
  bool shouldFailNextWrite = false;
  bool shouldFailNextDelete = false;
  Duration? operationDelay;
  // Listeners for storage changes
  final List<Function(String key, dynamic value)> _changeListeners = [];
  /// Get a string value from storage
  Future<String?> getString(String key) async {
    return _performOperation(() {
      readCount++;
      final value = _storage[key];
      return value?.toString();
    }, 'read');
  }
  /// Set a string value in storage
  Future<bool> setString(String key, String value) async {
    return _performOperation(() {
      writeCount++;
      _storage[key] = value;
      _notifyListeners(key, value);
      return true;
    }, 'write');
  }
  /// Get an integer value from storage
  Future<int?> getInt(String key) async {
    return _performOperation(() {
      readCount++;
      final value = _storage[key];
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }, 'read');
  }
  /// Set an integer value in storage
  Future<bool> setInt(String key, int value) async {
    return _performOperation(() {
      writeCount++;
      _storage[key] = value;
      _notifyListeners(key, value);
      return true;
    }, 'write');
  }
  /// Get a boolean value from storage
  Future<bool?> getBool(String key) async {
    return _performOperation(() {
      readCount++;
      final value = _storage[key];
      if (value == null) return null;
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return null;
    }, 'read');
  }
  /// Set a boolean value in storage
  Future<bool> setBool(String key, bool value) async {
    return _performOperation(() {
      writeCount++;
      _storage[key] = value;
      _notifyListeners(key, value);
      return true;
    }, 'write');
  }
  /// Get a list of strings from storage
  Future<List<String>?> getStringList(String key) async {
    return _performOperation(() {
      readCount++;
      final value = _storage[key];
      if (value == null) return null;
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return null;
    }, 'read');
  }
  /// Set a list of strings in storage
  Future<bool> setStringList(String key, List<String> value) async {
    return _performOperation(() {
      writeCount++;
      _storage[key] = value;
      _notifyListeners(key, value);
      return true;
    }, 'write');
  }
  /// Get a JSON map from storage
  Future<Map<String, dynamic>?> getJsonMap(String key) async {
    return _performOperation(() {
      readCount++;
      final value = _storage[key];
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }
      return null;
    }, 'read');
  }
  /// Set a JSON map in storage
  Future<bool> setJsonMap(String key, Map<String, dynamic> value) async {
    return _performOperation(() {
      writeCount++;
      _storage[key] = Map<String, dynamic>.from(value);
      _notifyListeners(key, value);
      return true;
    }, 'write');
  }
  /// Remove a value from storage
  Future<bool> remove(String key) async {
    return _performOperation(() {
      deleteCount++;
      final existed = _storage.containsKey(key);
      _storage.remove(key);
      if (existed) {
        _notifyListeners(key, null);
      }
      return existed;
    }, 'delete');
  }
  /// Clear all values from storage
  Future<bool> clear() async {
    return _performOperation(() {
      clearCount++;
      final keys = _storage.keys.toList();
      _storage.clear();
      for (final key in keys) {
        _notifyListeners(key, null);
      }
      return true;
    }, 'clear');
  }
  /// Check if a key exists in storage
  Future<bool> containsKey(String key) async {
    return _performOperation(() {
      readCount++;
      return _storage.containsKey(key);
    }, 'read');
  }
  /// Get all keys in storage
  Future<Set<String>> getKeys() async {
    return _performOperation(() {
      readCount++;
      return _storage.keys.toSet();
    }, 'read');
  }
  /// Reload storage (no-op for in-memory storage)
  Future<void> reload() async {
    // No-op for in-memory storage
  }
  /// Add a listener for storage changes
  void addChangeListener(Function(String key, dynamic value) listener) {
    _changeListeners.add(listener);
  }
  /// Remove a change listener
  void removeChangeListener(Function(String key, dynamic value) listener) {
    _changeListeners.remove(listener);
  }
  /// Reset the storage and all counters
  void reset() {
    _storage.clear();
    readCount = 0;
    writeCount = 0;
    deleteCount = 0;
    clearCount = 0;
    shouldFailNextRead = false;
    shouldFailNextWrite = false;
    shouldFailNextDelete = false;
    operationDelay = null;
    _changeListeners.clear();
  }
  /// Get a snapshot of the current storage state
  Map<String, dynamic> getSnapshot() {
    return Map<String, dynamic>.from(_storage);
  }
  /// Restore storage from a snapshot
  void restoreSnapshot(Map<String, dynamic> snapshot) {
    _storage.clear();
    _storage.addAll(snapshot);
  }
  /// Get operation statistics
  Map<String, int> getStats() {
    return {
      'reads': readCount,
      'writes': writeCount,
      'deletes': deleteCount,
      'clears': clearCount,
      'totalOperations': readCount + writeCount + deleteCount + clearCount,
      'currentKeys': _storage.length,
    };
  }
  /// Simulate storage corruption for a key
  void corruptKey(String key) {
    if (_storage.containsKey(key)) {
      _storage[key] = '<corrupted_data>';
    }
  }
  /// Set storage size limit (for testing size constraints)
  int? _sizeLimitBytes;
  void setSizeLimit(int? bytes) {
    _sizeLimitBytes = bytes;
  }
  /// Calculate current storage size
  int getCurrentSize() {
    int size = 0;
    _storage.forEach((key, value) {
      size += key.length;
      size += _estimateValueSize(value);
    });
    return size;
  }
  int _estimateValueSize(dynamic value) {
    if (value == null) return 0;
    if (value is String) return value.length;
    if (value is num) return 8;
    if (value is bool) return 1;
    if (value is List || value is Map) {
      return jsonEncode(value).length;
    }
    return value.toString().length;
  }
  Future<T> _performOperation<T>(T Function() operation, String type) async {
    // Simulate operation delay if configured
    if (operationDelay != null) {
      await Future.delayed(operationDelay!);
    }
    // Check for simulated failures
    if (type == 'read' && shouldFailNextRead) {
      shouldFailNextRead = false;
      throw Exception('Simulated storage read failure');
    }
    if (type == 'write' && shouldFailNextWrite) {
      shouldFailNextWrite = false;
      throw Exception('Simulated storage write failure');
    }
    if (type == 'delete' && shouldFailNextDelete) {
      shouldFailNextDelete = false;
      throw Exception('Simulated storage delete failure');
    }
    // Check size limit for write operations
    if (type == 'write' && _sizeLimitBytes != null) {
      final currentSize = getCurrentSize();
      if (currentSize > _sizeLimitBytes!) {
        throw Exception('Storage size limit exceeded: $currentSize > $_sizeLimitBytes');
      }
    }
    return operation();
  }
  void _notifyListeners(String key, dynamic value) {
    for (final listener in _changeListeners) {
      listener(key, value);
    }
  }
}
/// Factory for creating TestStorage instances with different configurations
class TestStorageFactory {
  /// Create a storage instance with pre-populated data
  static TestStorage withData(Map<String, dynamic> initialData) {
    final storage = TestStorage();
    initialData.forEach((key, value) {
      storage._storage[key] = value;
    });
    return storage;
  }
  /// Create a storage instance that fails on specific operations
  static TestStorage withFailures({
    bool failReads = false,
    bool failWrites = false,
    bool failDeletes = false,
  }) {
    final storage = TestStorage();
    storage.shouldFailNextRead = failReads;
    storage.shouldFailNextWrite = failWrites;
    storage.shouldFailNextDelete = failDeletes;
    return storage;
  }
  /// Create a storage instance with operation delays
  static TestStorage withDelay(Duration delay) {
    final storage = TestStorage();
    storage.operationDelay = delay;
    return storage;
  }
  /// Create a storage instance with size limit
  static TestStorage withSizeLimit(int bytes) {
    final storage = TestStorage();
    storage.setSizeLimit(bytes);
    return storage;
  }
}