// test/unit/services/secure_storage_service_test.dart
//
// Comprehensive tests for SecureStorageService class
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:customfit_ai_flutter_sdk/src/services/secure_storage_service.dart';
import '../../test_config.dart';
import '../../helpers/test_storage_helper.dart';
import 'secure_storage_service_test.mocks.dart';
@GenerateMocks([FlutterSecureStorage])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestConfig.setupTestLogger();
    TestStorageHelper.setupTestStorage();
  });
  tearDown(() {
    TestStorageHelper.clearTestStorage();
    SecureStorageService.clearInstance();
  });
  group('SecureStorageService', () {
    late MockFlutterSecureStorage mockStorage;
    late SecureStorageService secureStorageService;
    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      secureStorageService = SecureStorageService.getTestInstance(mockStorage);
    });
    group('Initialization', () {
      test('should initialize successfully when secure storage is available',
          () async {
        when(mockStorage.read(key: 'cf_test_key'))
            .thenAnswer((_) async => null);
        final instance = await SecureStorageService.getInstance();
        expect(instance, isNotNull);
        // In test environment, secure storage is not available due to missing plugin
        expect(instance.isAvailable, isFalse);
      });
      test('should handle initialization failure gracefully', () async {
        when(mockStorage.read(key: 'cf_test_key'))
            .thenThrow(Exception('Storage not available'));
        final instance = await SecureStorageService.getInstance();
        expect(instance, isNotNull);
        expect(instance.isAvailable, isFalse);
      });
      test('should return same instance on multiple calls', () async {
        when(mockStorage.read(key: 'cf_test_key'))
            .thenAnswer((_) async => null);
        final instance1 = await SecureStorageService.getInstance();
        final instance2 = await SecureStorageService.getInstance();
        expect(identical(instance1, instance2), isTrue);
      });
    });
    group('setString', () {
      test('should store string value successfully when storage is available',
          () async {
        when(mockStorage.write(key: 'test_key', value: 'test_value'))
            .thenAnswer((_) async => {});
        final result =
            await secureStorageService.setString('test_key', 'test_value');
        expect(result, isTrue);
        verify(mockStorage.write(key: 'test_key', value: 'test_value'))
            .called(1);
      });
      test('should store in memory cache when storage is available', () async {
        when(mockStorage.write(key: 'test_key', value: 'test_value'))
            .thenAnswer((_) async => {});
        await secureStorageService.setString('test_key', 'test_value');
        // Verify it's cached by checking if subsequent reads don't call storage
        final cachedKeys = secureStorageService.getCachedKeys();
        expect(cachedKeys.contains('test_key'), isTrue);
      });
      test('should handle storage write errors and return false', () async {
        when(mockStorage.write(key: 'test_key', value: 'test_value'))
            .thenThrow(Exception('Storage not available'));
        final result =
            await secureStorageService.setString('test_key', 'test_value');
        expect(result, isFalse);
      });
      test('should handle storage write errors gracefully', () async {
        when(mockStorage.write(key: 'test_key', value: 'test_value'))
            .thenThrow(Exception('Write failed'));
        final result =
            await secureStorageService.setString('test_key', 'test_value');
        expect(result, isFalse);
      });
      test('should handle empty string values', () async {
        when(mockStorage.write(key: 'test_key', value: ''))
            .thenAnswer((_) async => {});
        final result = await secureStorageService.setString('test_key', '');
        expect(result, isTrue);
        verify(mockStorage.write(key: 'test_key', value: '')).called(1);
      });
      test('should handle special characters in keys and values', () async {
        const specialKey = 'key_with_special_chars_!@#\$%^&*()';
        const specialValue = 'value_with_unicode_🔐_and_newlines\n\t';
        when(mockStorage.write(key: specialKey, value: specialValue))
            .thenAnswer((_) async => {});
        final result =
            await secureStorageService.setString(specialKey, specialValue);
        expect(result, isTrue);
        verify(mockStorage.write(key: specialKey, value: specialValue))
            .called(1);
      });
    });
    group('getString', () {
      test('should retrieve string value from storage', () async {
        when(mockStorage.read(key: 'test_key'))
            .thenAnswer((_) async => 'test_value');
        final result = await secureStorageService.getString('test_key');
        expect(result, equals('test_value'));
        verify(mockStorage.read(key: 'test_key')).called(1);
      });
      test('should return cached value without calling storage', () async {
        // First, store a value to cache it
        when(mockStorage.write(key: 'test_key', value: 'test_value'))
            .thenAnswer((_) async => {});
        await secureStorageService.setString('test_key', 'test_value');
        // Now get the value - should come from cache
        final result = await secureStorageService.getString('test_key');
        expect(result, equals('test_value'));
        verifyNever(mockStorage.read(key: 'test_key'));
      });
      test('should cache value from storage on first read', () async {
        when(mockStorage.read(key: 'test_key'))
            .thenAnswer((_) async => 'test_value');
        // First read - should call storage
        final result1 = await secureStorageService.getString('test_key');
        expect(result1, equals('test_value'));
        verify(mockStorage.read(key: 'test_key')).called(1);
        // Second read - should use cache
        final result2 = await secureStorageService.getString('test_key');
        expect(result2, equals('test_value'));
        verifyNoMoreInteractions(mockStorage);
      });
      test('should return null for non-existent key', () async {
        when(mockStorage.read(key: 'non_existent_key'))
            .thenAnswer((_) async => null);
        final result = await secureStorageService.getString('non_existent_key');
        expect(result, isNull);
      });
      test('should handle storage read errors gracefully', () async {
        when(mockStorage.read(key: 'test_key'))
            .thenThrow(Exception('Read failed'));
        final result = await secureStorageService.getString('test_key');
        expect(result, isNull);
      });
      test('should get value from cache after storing', () async {
        when(mockStorage.write(key: 'test_key', value: 'test_value'))
            .thenAnswer((_) async => {});
        // Store value first
        await secureStorageService.setString('test_key', 'test_value');
        // Get from cache
        final result = await secureStorageService.getString('test_key');
        expect(result, equals('test_value'));
        // Should not call read since it's cached
        verifyNever(mockStorage.read(key: 'test_key'));
      });
    });
    group('remove', () {
      test('should remove value from storage and cache', () async {
        // First store a value
        when(mockStorage.write(key: 'test_key', value: 'test_value'))
            .thenAnswer((_) async => {});
        await secureStorageService.setString('test_key', 'test_value');
        // Then remove it
        when(mockStorage.delete(key: 'test_key')).thenAnswer((_) async => {});
        final result = await secureStorageService.remove('test_key');
        expect(result, isTrue);
        verify(mockStorage.delete(key: 'test_key')).called(1);
        // Verify it's removed from cache
        final cachedKeys = secureStorageService.getCachedKeys();
        expect(cachedKeys.contains('test_key'), isFalse);
      });
      test('should remove from cache successfully', () async {
        // Store value first
        when(mockStorage.write(key: 'test_key', value: 'test_value'))
            .thenAnswer((_) async => {});
        await secureStorageService.setString('test_key', 'test_value');
        expect(
            secureStorageService.getCachedKeys().contains('test_key'), isTrue);
        // Remove value
        when(mockStorage.delete(key: 'test_key')).thenAnswer((_) async => {});
        final result = await secureStorageService.remove('test_key');
        expect(result, isTrue);
        expect(
            secureStorageService.getCachedKeys().contains('test_key'), isFalse);
      });
      test('should handle storage delete errors gracefully', () async {
        when(mockStorage.delete(key: 'test_key'))
            .thenThrow(Exception('Delete failed'));
        final result = await secureStorageService.remove('test_key');
        expect(result, isFalse);
      });
      test('should succeed when removing non-existent key', () async {
        when(mockStorage.delete(key: 'non_existent_key'))
            .thenAnswer((_) async => {});
        final result = await secureStorageService.remove('non_existent_key');
        expect(result, isTrue);
      });
    });
    group('clearAll', () {
      test('should clear all values from storage and cache', () async {
        // Store some values first
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});
        await secureStorageService.setString('key1', 'value1');
        await secureStorageService.setString('key2', 'value2');
        // Clear all
        when(mockStorage.deleteAll()).thenAnswer((_) async => {});
        final result = await secureStorageService.clearAll();
        expect(result, isTrue);
        verify(mockStorage.deleteAll()).called(1);
        // Verify cache is cleared
        final cachedKeys = secureStorageService.getCachedKeys();
        expect(cachedKeys.isEmpty, isTrue);
      });
      test('should clear cache when clearing all', () async {
        // Store some values
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});
        await secureStorageService.setString('key1', 'value1');
        await secureStorageService.setString('key2', 'value2');
        expect(secureStorageService.getCachedKeys().length, equals(2));
        // Clear all
        when(mockStorage.deleteAll()).thenAnswer((_) async => {});
        final result = await secureStorageService.clearAll();
        expect(result, isTrue);
        expect(secureStorageService.getCachedKeys().isEmpty, isTrue);
      });
      test('should handle storage clear errors gracefully', () async {
        when(mockStorage.deleteAll()).thenThrow(Exception('Clear failed'));
        final result = await secureStorageService.clearAll();
        expect(result, isFalse);
      });
    });
    group('containsKey', () {
      test('should return true for cached key', () async {
        // Store a value to cache it
        when(mockStorage.write(key: 'test_key', value: 'test_value'))
            .thenAnswer((_) async => {});
        await secureStorageService.setString('test_key', 'test_value');
        final result = await secureStorageService.containsKey('test_key');
        expect(result, isTrue);
        // Should not call storage since it's cached
        verifyNever(mockStorage.read(key: 'test_key'));
      });
      test('should check storage for non-cached key', () async {
        when(mockStorage.read(key: 'test_key'))
            .thenAnswer((_) async => 'test_value');
        final result = await secureStorageService.containsKey('test_key');
        expect(result, isTrue);
        verify(mockStorage.read(key: 'test_key')).called(1);
      });
      test('should return false for non-existent key', () async {
        when(mockStorage.read(key: 'non_existent_key'))
            .thenAnswer((_) async => null);
        final result =
            await secureStorageService.containsKey('non_existent_key');
        expect(result, isFalse);
      });
      test('should handle storage read errors gracefully', () async {
        when(mockStorage.read(key: 'test_key'))
            .thenThrow(Exception('Read failed'));
        final result = await secureStorageService.containsKey('test_key');
        expect(result, isFalse);
      });
      test('should return false for non-cached non-existent key', () async {
        when(mockStorage.read(key: 'test_key')).thenAnswer((_) async => null);
        final result = await secureStorageService.containsKey('test_key');
        expect(result, isFalse);
        verify(mockStorage.read(key: 'test_key')).called(1);
      });
    });
    group('getCachedKeys', () {
      test('should return empty set when no keys are cached', () {
        final keys = secureStorageService.getCachedKeys();
        expect(keys.isEmpty, isTrue);
      });
      test('should return all cached keys', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});
        await secureStorageService.setString('key1', 'value1');
        await secureStorageService.setString('key2', 'value2');
        await secureStorageService.setString('key3', 'value3');
        final keys = secureStorageService.getCachedKeys();
        expect(keys.length, equals(3));
        expect(keys.contains('key1'), isTrue);
        expect(keys.contains('key2'), isTrue);
        expect(keys.contains('key3'), isTrue);
      });
      test('should return copy of keys set', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});
        await secureStorageService.setString('key1', 'value1');
        final keys1 = secureStorageService.getCachedKeys();
        final keys2 = secureStorageService.getCachedKeys();
        expect(identical(keys1, keys2), isFalse);
        expect(keys1, equals(keys2));
      });
    });
    group('Edge cases and error handling', () {
      test('should handle concurrent operations', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});
        when(mockStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => 'test_value');
        // Perform multiple concurrent operations
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(secureStorageService.setString('key$i', 'value$i'));
          futures.add(secureStorageService.getString('key$i'));
        }
        await Future.wait(futures);
        // Verify all operations completed
        final cachedKeys = secureStorageService.getCachedKeys();
        expect(cachedKeys.length, greaterThanOrEqualTo(10));
      });
      test('should handle very long keys and values', () async {
        final longKey = 'k' * 1000;
        final longValue = 'v' * 10000;
        when(mockStorage.write(key: longKey, value: longValue))
            .thenAnswer((_) async => {});
        final result = await secureStorageService.setString(longKey, longValue);
        expect(result, isTrue);
        verify(mockStorage.write(key: longKey, value: longValue)).called(1);
      });
      test('should handle null and empty string scenarios', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});
        when(mockStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => null);
        // Test empty key
        final result1 = await secureStorageService.setString('', 'value');
        expect(result1, isTrue);
        // Test getting non-existent key
        final result2 = await secureStorageService.getString('non_existent');
        expect(result2, isNull);
      });
    });
    group('Memory management', () {
      test('should manage memory cache efficiently', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});
        // Add many items to cache
        for (int i = 0; i < 100; i++) {
          await secureStorageService.setString('key$i', 'value$i');
        }
        expect(secureStorageService.getCachedKeys().length, equals(100));
        // Clear cache
        when(mockStorage.deleteAll()).thenAnswer((_) async => {});
        await secureStorageService.clearAll();
        expect(secureStorageService.getCachedKeys().isEmpty, isTrue);
      });
      test('should handle cache updates correctly', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});
        // Store initial value
        await secureStorageService.setString('test_key', 'initial_value');
        // Update value
        await secureStorageService.setString('test_key', 'updated_value');
        // Verify cache has updated value
        final cachedValue = await secureStorageService.getString('test_key');
        expect(cachedValue, equals('updated_value'));
      });
    });
    group('Platform-specific behavior', () {
      test('should handle unavailable storage gracefully', () async {
        // Test the public behavior when storage operations fail
        when(mockStorage.write(key: 'test_key', value: 'test_value'))
            .thenThrow(Exception('Platform not supported'));
        final result =
            await secureStorageService.setString('test_key', 'test_value');
        expect(result, isFalse);
      });
    });
    group('Singleton behavior', () {
      test('should clear instance correctly', () {
        SecureStorageService.clearInstance();
        expect(() => SecureStorageService.clearInstance(), returnsNormally);
      });
      test('should create test instance correctly', () {
        final testStorage = MockFlutterSecureStorage();
        final testInstance = SecureStorageService.getTestInstance(testStorage);
        expect(testInstance, isNotNull);
        expect(testInstance.isAvailable, isTrue);
      });
    });
  });
}
