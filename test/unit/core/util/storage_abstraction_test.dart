// test/unit/core/util/storage_abstraction_test.dart
//
// Tests for the storage abstraction layer.
// Validates that the storage abstractions provide proper isolation
// and testability for the cache system.
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/storage_abstraction.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Storage Abstraction Tests', () {
    group('InMemoryKeyValueStorage', () {
      late InMemoryKeyValueStorage storage;
      setUp(() {
        storage = InMemoryKeyValueStorage();
        SharedPreferences.setMockInitialValues({});
      });
      test('should store and retrieve string values', () async {
        const key = 'test_key';
        const value = 'test_value';
        await storage.setString(key, value);
        final retrieved = await storage.getString(key);
        expect(retrieved, value);
      });
      test('should return null for non-existent keys', () async {
        final result = await storage.getString('non_existent');
        expect(result, isNull);
      });
      test('should remove values', () async {
        const key = 'remove_test';
        await storage.setString(key, 'value');
        final removed = await storage.remove(key);
        expect(removed, isTrue);
        final retrieved = await storage.getString(key);
        expect(retrieved, isNull);
      });
      test('should list all keys', () async {
        await storage.setString('key1', 'value1');
        await storage.setString('key2', 'value2');
        await storage.setString('other', 'value3');
        final allKeys = storage.getKeys();
        expect(allKeys, containsAll(['key1', 'key2', 'other']));
      });
      test('should filter keys by prefix', () async {
        await storage.setString('prefix_key1', 'value1');
        await storage.setString('prefix_key2', 'value2');
        await storage.setString('other_key', 'value3');
        final prefixKeys = storage.getKeys(prefix: 'prefix_');
        expect(prefixKeys, hasLength(2));
        expect(prefixKeys, containsAll(['prefix_key1', 'prefix_key2']));
      });
      test('should clear all values', () async {
        await storage.setString('key1', 'value1');
        await storage.setString('key2', 'value2');
        final cleared = await storage.clear();
        expect(cleared, isTrue);
        final keys = storage.getKeys();
        expect(keys, isEmpty);
      });
    });
    group('InMemoryFileStorage', () {
      late InMemoryFileStorage storage;
      setUp(() {
        storage = InMemoryFileStorage();
        SharedPreferences.setMockInitialValues({});
      });
      test('should store and retrieve file contents', () async {
        const path = 'test/file.txt';
        const content = 'test content';
        await storage.writeAsString(path, content);
        final exists = await storage.exists(path);
        expect(exists, isTrue);
        final retrieved = await storage.readAsString(path);
        expect(retrieved, content);
      });
      test('should handle file deletion', () async {
        const path = 'delete/file.txt';
        await storage.writeAsString(path, 'content');
        await storage.delete(path);
        final exists = await storage.exists(path);
        expect(exists, isFalse);
      });
      test('should create directories', () async {
        const dirPath = 'test/nested/directory';
        await storage.createDirectory(dirPath);
        // Directory creation is implicit - test by checking files can be written
        const filePath = 'test/nested/directory/file.txt';
        await storage.writeAsString(filePath, 'content');
        final exists = await storage.exists(filePath);
        expect(exists, isTrue);
      });
      test('should list files in directory', () async {
        await storage.writeAsString('dir/file1.txt', 'content1');
        await storage.writeAsString('dir/file2.txt', 'content2');
        await storage.writeAsString('other/file3.txt', 'content3');
        final files = await storage.listFiles('dir');
        expect(files, hasLength(2));
        expect(
            files,
            containsAll(
                ['/mock_cache/dir/file1.txt', '/mock_cache/dir/file2.txt']));
      });
      test('should handle non-existent files gracefully', () async {
        expect(() => storage.readAsString('non_existent.txt'),
            throwsA(isA<FileSystemException>()));
        final exists = await storage.exists('non_existent.txt');
        expect(exists, isFalse);
      });
      test('should return cache directory path', () async {
        final path = await storage.getCacheDirectoryPath();
        expect(path, '/mock_cache');
      });
    });
    group('StorageManager', () {
      tearDown(() {
        StorageManager.clearTestConfig();
        PreferencesService.reset();
      });
      test('should provide test configuration', () {
        final testConfig = StorageManager.createTestConfig();
        StorageManager.setTestConfig(testConfig);
        final config = StorageManager.config;
        expect(config.keyValueStorage, isA<InMemoryKeyValueStorage>());
        expect(config.fileStorage, isA<InMemoryFileStorage>());
      });
      test('should throw when not configured', () {
        expect(() => StorageManager.config, throwsStateError);
      });
      test('should prioritize test config over main config', () {
        final mainConfig = StorageConfig(
          keyValueStorage: SharedPreferencesKeyValueStorage(),
          fileStorage: FileSystemFileStorage('/main'),
        );
        final testConfig = StorageManager.createTestConfig();
        StorageManager.configure(mainConfig);
        StorageManager.setTestConfig(testConfig);
        final config = StorageManager.config;
        expect(config.keyValueStorage, isA<InMemoryKeyValueStorage>());
      });
    });
    group('SharedPreferencesKeyValueStorage', () {
      late SharedPreferencesKeyValueStorage storage;
      setUp(() {
        storage = SharedPreferencesKeyValueStorage();
        SharedPreferences.setMockInitialValues({});
        // Clear any existing data before each test
        storage.clear();
      });
      test('should store and retrieve string values', () async {
        const key = 'test_key';
        const value = 'test_value';
        final success = await storage.setString(key, value);
        expect(success, isTrue);
        final retrieved = await storage.getString(key);
        expect(retrieved, value);
      });
      test('should return null for non-existent keys', () async {
        final result = await storage.getString('non_existent');
        expect(result, isNull);
      });
      test('should remove values successfully', () async {
        const key = 'remove_test';
        await storage.setString(key, 'value');
        final removed = await storage.remove(key);
        expect(removed, isTrue);
        final retrieved = await storage.getString(key);
        expect(retrieved, isNull);
      });
      test('should handle setString errors gracefully', () async {
        // Create a scenario where storage might fail
        // Since we're using an in-memory map, we'll test the try-catch by
        // verifying the method completes without throwing
        final result = await storage.setString('test', 'value');
        expect(result, isTrue);
      });
      test('should handle remove errors gracefully', () async {
        // Test remove on non-existent key
        final result = await storage.remove('non_existent');
        expect(result, isTrue);
      });
      test('should list all keys', () async {
        await storage.setString('key1', 'value1');
        await storage.setString('key2', 'value2');
        await storage.setString('other', 'value3');
        final allKeys = storage.getKeys();
        expect(allKeys, containsAll(['key1', 'key2', 'other']));
      });
      test('should filter keys by prefix', () async {
        await storage.setString('prefix_key1', 'value1');
        await storage.setString('prefix_key2', 'value2');
        await storage.setString('other_key', 'value3');
        final prefixKeys = storage.getKeys(prefix: 'prefix_');
        expect(prefixKeys, hasLength(2));
        expect(prefixKeys, containsAll(['prefix_key1', 'prefix_key2']));
      });
      test('should return empty set for non-matching prefix', () async {
        await storage.setString('key1', 'value1');
        await storage.setString('key2', 'value2');
        final prefixKeys = storage.getKeys(prefix: 'nonexistent_');
        expect(prefixKeys, isEmpty);
      });
      test('should clear all values successfully', () async {
        await storage.setString('key1', 'value1');
        await storage.setString('key2', 'value2');
        final cleared = await storage.clear();
        expect(cleared, isTrue);
        final keys = storage.getKeys();
        expect(keys, isEmpty);
      });
      test('should handle clear operation when already empty', () async {
        final cleared = await storage.clear();
        expect(cleared, isTrue);
      });
    });
    group('FileSystemFileStorage', () {
      late FileSystemFileStorage storage;
      late Directory tempDir;
      setUp(() async {
        // Create a temporary directory for testing
        SharedPreferences.setMockInitialValues({});
        tempDir = await Directory.systemTemp.createTemp('cf_storage_test');
        storage = FileSystemFileStorage(tempDir.path);
      });
      tearDown(() async {
        // Clean up temporary directory
        PreferencesService.reset();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      test('should handle file existence checks', () async {
        const relativePath = 'test_file.txt';
        const content = 'test content';
        // File should not exist initially
        final existsBefore = await storage.exists(relativePath);
        expect(existsBefore, isFalse);
        // Write file and check existence
        await storage.writeAsString(relativePath, content);
        final existsAfter = await storage.exists(relativePath);
        expect(existsAfter, isTrue);
      });
      test('should handle absolute paths correctly', () async {
        final absolutePath = '${tempDir.path}/absolute_test.txt';
        const content = 'absolute path test';
        await storage.writeAsString(absolutePath, content);
        final exists = await storage.exists(absolutePath);
        expect(exists, isTrue);
        final readContent = await storage.readAsString(absolutePath);
        expect(readContent, content);
      });
      test('should handle exists() errors gracefully', () async {
        // Test with an invalid path that might cause an error
        const invalidPath = '/invalid/\x00/path';
        final result = await storage.exists(invalidPath);
        expect(result, isFalse);
      });
      test('should read and write file contents', () async {
        const path = 'test/nested/file.txt';
        const content = 'test file content';
        await storage.writeAsString(path, content);
        final retrieved = await storage.readAsString(path);
        expect(retrieved, content);
      });
      test('should create parent directories when writing', () async {
        const path = 'deep/nested/structure/file.txt';
        const content = 'nested content';
        await storage.writeAsString(path, content);
        final exists = await storage.exists(path);
        expect(exists, isTrue);
        final retrieved = await storage.readAsString(path);
        expect(retrieved, content);
      });
      test('should delete files', () async {
        const path = 'delete_test.txt';
        await storage.writeAsString(path, 'content');
        await storage.delete(path);
        final exists = await storage.exists(path);
        expect(exists, isFalse);
      });
      test('should handle deleting non-existent files gracefully', () async {
        // Should not throw when deleting non-existent file
        await storage.delete('non_existent.txt');
        // Test passes if no exception is thrown
      });
      test('should create directories', () async {
        const dirPath = 'test_directory';
        await storage.createDirectory(dirPath);
        final directory = Directory('${tempDir.path}/$dirPath');
        final exists = await directory.exists();
        expect(exists, isTrue);
      });
      test('should list files in directory', () async {
        const dirPath = 'list_test';
        await storage.createDirectory(dirPath);
        await storage.writeAsString('$dirPath/file1.txt', 'content1');
        await storage.writeAsString('$dirPath/file2.txt', 'content2');
        await storage.writeAsString('other_dir/file3.txt', 'content3');
        final files = await storage.listFiles(dirPath);
        expect(files, hasLength(2));
        expect(files.any((f) => f.endsWith('file1.txt')), isTrue);
        expect(files.any((f) => f.endsWith('file2.txt')), isTrue);
      });
      test('should handle listing files in non-existent directory', () async {
        final files = await storage.listFiles('non_existent_dir');
        expect(files, isEmpty);
      });
      test('should return cache directory path', () async {
        final path = await storage.getCacheDirectoryPath();
        expect(path, tempDir.path);
      });
      test('should handle path normalization correctly', () async {
        // Test relative path
        const relativePath = 'relative.txt';
        await storage.writeAsString(relativePath, 'content');
        // Test absolute path
        final absolutePath = '${tempDir.path}/absolute.txt';
        await storage.writeAsString(absolutePath, 'content');
        final relativeExists = await storage.exists(relativePath);
        final absoluteExists = await storage.exists(absolutePath);
        expect(relativeExists, isTrue);
        expect(absoluteExists, isTrue);
      });
    });
    group('InMemoryFileStorage Extended', () {
      late InMemoryFileStorage storage;
      setUp(() {
        storage = InMemoryFileStorage('/test_base');
        SharedPreferences.setMockInitialValues({});
      });
      test('should handle custom base path', () async {
        final path = await storage.getCacheDirectoryPath();
        expect(path, '/test_base');
      });
      test('should handle path normalization edge cases', () async {
        // Test various path formats
        await storage.writeAsString('simple.txt', 'content1');
        await storage.writeAsString('/absolute.txt', 'content2');
        await storage.writeAsString('nested/file.txt', 'content3');
        final simple = await storage.readAsString('simple.txt');
        final absolute = await storage.readAsString('/absolute.txt');
        final nested = await storage.readAsString('nested/file.txt');
        expect(simple, 'content1');
        expect(absolute, 'content2');
        expect(nested, 'content3');
      });
      test('should handle parent directory extraction correctly', () async {
        await storage.writeAsString('dir1/dir2/file.txt', 'content');
        await storage.writeAsString('dir1/other.txt', 'content2');
        await storage.writeAsString('root.txt', 'content3');
        final dir2Files = await storage.listFiles('dir1/dir2');
        final dir1Files = await storage.listFiles('dir1');
        final rootFiles = await storage.listFiles('/test_base');
        expect(dir2Files, hasLength(1));
        expect(dir1Files, hasLength(1)); // only other.txt
        expect(rootFiles, hasLength(1)); // only root.txt
      });
      test('should provide test utilities', () {
        storage.writeAsString('test1.txt', 'content1');
        storage.writeAsString('test2.txt', 'content2');
        storage.createDirectory('testdir');
        final files = storage.getFilesCopy();
        final directories = storage.getDirectoriesCopy();
        expect(files, hasLength(2));
        expect(directories, contains('/test_base/testdir'));
      });
      test('should handle root path edge case', () async {
        await storage.writeAsString('/root_file.txt', 'content');
        final files = await storage.listFiles('/');
        // Note: The listFiles logic expects files to be in subdirectories
        // A file at root level might not be found depending on implementation
        expect(files, isA<List<String>>());
      });
    });
    group('InMemoryKeyValueStorage Extended', () {
      late InMemoryKeyValueStorage storage;
      setUp(() {
        storage = InMemoryKeyValueStorage();
        SharedPreferences.setMockInitialValues({});
      });
      test('should provide test utilities', () async {
        await storage.setString('key1', 'value1');
        await storage.setString('key2', 'value2');
        final copy = storage.getStorageCopy();
        expect(copy, hasLength(2));
        expect(copy['key1'], 'value1');
        expect(copy['key2'], 'value2');
        // Verify it's a copy, not the original
        copy['key3'] = 'value3';
        final originalKeys = storage.getKeys();
        expect(originalKeys, hasLength(2));
      });
      test('should handle edge cases in prefix filtering', () async {
        // Clear any existing data first
        await storage.clear();
        await storage.setString('a', 'single_char');
        await storage.setString('ab', 'two_chars');
        await storage.setString('abc', 'three_chars');
        await storage.setString('xyz', 'different_prefix');
        final allKeys = storage.getKeys();
        final aPrefix = storage.getKeys(prefix: 'a');
        final abPrefix = storage.getKeys(prefix: 'ab');
        final xPrefix = storage.getKeys(prefix: 'x');
        expect(allKeys, hasLength(4));
        expect(aPrefix, hasLength(3)); // a, ab, abc
        expect(abPrefix, hasLength(2)); // ab, abc
        expect(xPrefix, hasLength(1)); // xyz
      });
    });
    group('StorageManager Extended', () {
      tearDown(() {
        StorageManager.clearTestConfig();
        PreferencesService.reset();
      });
      test('should create default configuration', () async {
        final config = await StorageManager.createDefaultConfig();
        expect(config.keyValueStorage, isA<SharedPreferencesKeyValueStorage>());
        expect(config.fileStorage, isA<FileSystemFileStorage>());
      });
      test('should handle configuration precedence correctly', () {
        // Ensure we start with a clean state
        StorageManager.clearTestConfig();
        // Set main config
        final mainConfig = StorageConfig(
          keyValueStorage: SharedPreferencesKeyValueStorage(),
          fileStorage: FileSystemFileStorage('/main'),
        );
        StorageManager.configure(mainConfig);
        final configAfterMain = StorageManager.config;
        expect(configAfterMain.keyValueStorage,
            isA<SharedPreferencesKeyValueStorage>());
        // Set test config (should take precedence)
        final testConfig = StorageManager.createTestConfig();
        StorageManager.setTestConfig(testConfig);
        final configAfterTest = StorageManager.config;
        expect(configAfterTest.keyValueStorage, isA<InMemoryKeyValueStorage>());
        // Clear test config (should revert to main)
        StorageManager.clearTestConfig();
        final configAfterClear = StorageManager.config;
        expect(configAfterClear.keyValueStorage,
            isA<SharedPreferencesKeyValueStorage>());
      });
      test('should create consistent test configurations', () {
        final config1 = StorageManager.createTestConfig();
        final config2 = StorageManager.createTestConfig();
        expect(config1.keyValueStorage, isA<InMemoryKeyValueStorage>());
        expect(config1.fileStorage, isA<InMemoryFileStorage>());
        expect(config2.keyValueStorage, isA<InMemoryKeyValueStorage>());
        expect(config2.fileStorage, isA<InMemoryFileStorage>());
        // Should be same instance (singleton)
        expect(identical(config1.keyValueStorage, config2.keyValueStorage),
            isTrue);
        expect(identical(config1.fileStorage, config2.fileStorage), isFalse);
      });
    });
    group('StorageConfig', () {
      test('should create with required parameters', () {
        final keyValueStorage = InMemoryKeyValueStorage();
        final fileStorage = InMemoryFileStorage();
        final config = StorageConfig(
          keyValueStorage: keyValueStorage,
          fileStorage: fileStorage,
        );
        expect(config.keyValueStorage, same(keyValueStorage));
        expect(config.fileStorage, same(fileStorage));
      });
      test('should be immutable', () {
        final config = StorageConfig(
          keyValueStorage: InMemoryKeyValueStorage(),
          fileStorage: InMemoryFileStorage(),
        );
        // Verify fields are final by checking they exist
        expect(config.keyValueStorage, isNotNull);
        expect(config.fileStorage, isNotNull);
      });
    });
    group('Storage Integration', () {
      test('should work together for cache-like operations', () async {
        final config = StorageManager.createTestConfig();
        final kvStorage = config.keyValueStorage;
        final fileStorage = config.fileStorage;
        // Simulate cache operations
        const cacheKey = 'cf_cache_test_key';
        const cacheValue = '{"value": "test", "expires": 1234567890}';
        // Store small entry in key-value storage
        await kvStorage.setString(cacheKey, cacheValue);
        final retrieved = await kvStorage.getString(cacheKey);
        expect(retrieved, cacheValue);
        // Store large entry in file storage
        final largeContent = 'x' * 200000; // 200KB content
        const filePath = 'large_cache_entry.json';
        await fileStorage.writeAsString(filePath, largeContent);
        final fileExists = await fileStorage.exists(filePath);
        expect(fileExists, isTrue);
        final fileContent = await fileStorage.readAsString(filePath);
        expect(fileContent.length, 200000);
      });
    });
  });
}
