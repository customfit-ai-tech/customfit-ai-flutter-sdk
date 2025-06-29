import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PreferencesService', () {
    setUp(() {
      // Reset singleton before each test
      PreferencesService.reset();
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      // Clean up after each test
      PreferencesService.reset();
    });
    group('Singleton Pattern Tests', () {
      test('should return the same instance on multiple calls', () async {
        final instance1 = await PreferencesService.getInstance();
        final instance2 = await PreferencesService.getInstance();
        expect(identical(instance1, instance2), isTrue);
      });
      test('should initialize SharedPreferences only once', () async {
        // First call initializes
        final instance1 = await PreferencesService.getInstance();
        expect(instance1, isNotNull);
        expect(instance1.prefs, isNotNull);
        // Second call should reuse the same SharedPreferences
        final instance2 = await PreferencesService.getInstance();
        expect(identical(instance1.prefs, instance2.prefs), isTrue);
      });
      test('should handle concurrent getInstance calls', () async {
        // Launch multiple concurrent calls
        final futures = List.generate(
          10, 
          (_) => PreferencesService.getInstance()
        );
        final instances = await Future.wait(futures);
        // All instances should be identical
        for (int i = 1; i < instances.length; i++) {
          expect(identical(instances[0], instances[i]), isTrue);
        }
      });
      test('should reset singleton properly', () async {
        final instance1 = await PreferencesService.getInstance();
        PreferencesService.reset();
        final instance2 = await PreferencesService.getInstance();
        // Should be different instances after reset
        expect(identical(instance1, instance2), isFalse);
      });
    });
    group('String Operations', () {
      test('should set and get string values', () async {
        final service = await PreferencesService.getInstance();
        final result = await service.setString('testKey', 'testValue');
        expect(result, isTrue);
        final value = await service.getString('testKey');
        expect(value, equals('testValue'));
      });
      test('should return null for non-existent string key', () async {
        final service = await PreferencesService.getInstance();
        final value = await service.getString('nonExistentKey');
        expect(value, isNull);
      });
      test('should handle empty string values', () async {
        final service = await PreferencesService.getInstance();
        await service.setString('emptyKey', '');
        final value = await service.getString('emptyKey');
        expect(value, equals(''));
      });
      test('should handle special characters in strings', () async {
        final service = await PreferencesService.getInstance();
        const specialString = 'Test\nWith\tSpecial™©®\u{1F600}Characters';
        await service.setString('specialKey', specialString);
        final value = await service.getString('specialKey');
        expect(value, equals(specialString));
      });
      test('should overwrite existing string values', () async {
        final service = await PreferencesService.getInstance();
        await service.setString('key', 'value1');
        await service.setString('key', 'value2');
        final value = await service.getString('key');
        expect(value, equals('value2'));
      });
    });
    group('Integer Operations', () {
      test('should set and get integer values', () async {
        final service = await PreferencesService.getInstance();
        final result = await service.setInt('intKey', 42);
        expect(result, isTrue);
        final value = await service.getInt('intKey');
        expect(value, equals(42));
      });
      test('should return null for non-existent int key', () async {
        final service = await PreferencesService.getInstance();
        final value = await service.getInt('nonExistentIntKey');
        expect(value, isNull);
      });
      test('should handle zero values', () async {
        final service = await PreferencesService.getInstance();
        await service.setInt('zeroKey', 0);
        final value = await service.getInt('zeroKey');
        expect(value, equals(0));
      });
      test('should handle negative values', () async {
        final service = await PreferencesService.getInstance();
        await service.setInt('negativeKey', -12345);
        final value = await service.getInt('negativeKey');
        expect(value, equals(-12345));
      });
      test('should handle maximum and minimum int values', () async {
        final service = await PreferencesService.getInstance();
        // Test max value
        await service.setInt('maxKey', 9223372036854775807);
        final maxValue = await service.getInt('maxKey');
        expect(maxValue, equals(9223372036854775807));
        // Test min value
        await service.setInt('minKey', -9223372036854775808);
        final minValue = await service.getInt('minKey');
        expect(minValue, equals(-9223372036854775808));
      });
    });
    group('Boolean Operations', () {
      test('should set and get boolean values', () async {
        final service = await PreferencesService.getInstance();
        final result1 = await service.setBool('boolKey1', true);
        expect(result1, isTrue);
        final result2 = await service.setBool('boolKey2', false);
        expect(result2, isTrue);
        expect(await service.getBool('boolKey1'), isTrue);
        expect(await service.getBool('boolKey2'), isFalse);
      });
      test('should return null for non-existent bool key', () async {
        final service = await PreferencesService.getInstance();
        final value = await service.getBool('nonExistentBoolKey');
        expect(value, isNull);
      });
      test('should overwrite boolean values', () async {
        final service = await PreferencesService.getInstance();
        await service.setBool('flipKey', true);
        expect(await service.getBool('flipKey'), isTrue);
        await service.setBool('flipKey', false);
        expect(await service.getBool('flipKey'), isFalse);
      });
    });
    group('String List Operations', () {
      test('should set and get string list values', () async {
        final service = await PreferencesService.getInstance();
        final list = ['item1', 'item2', 'item3'];
        final result = await service.setStringList('listKey', list);
        expect(result, isTrue);
        final value = await service.getStringList('listKey');
        expect(value, equals(list));
      });
      test('should return null for non-existent list key', () async {
        final service = await PreferencesService.getInstance();
        final value = await service.getStringList('nonExistentListKey');
        expect(value, isNull);
      });
      test('should handle empty lists', () async {
        final service = await PreferencesService.getInstance();
        await service.setStringList('emptyListKey', []);
        final value = await service.getStringList('emptyListKey');
        expect(value, equals([]));
      });
      test('should handle lists with empty strings', () async {
        final service = await PreferencesService.getInstance();
        final list = ['', 'item', '', 'another'];
        await service.setStringList('mixedListKey', list);
        final value = await service.getStringList('mixedListKey');
        expect(value, equals(list));
      });
      test('should handle lists with special characters', () async {
        final service = await PreferencesService.getInstance();
        final list = ['Special\nChars', 'Unicode™', '🎉'];
        await service.setStringList('specialListKey', list);
        final value = await service.getStringList('specialListKey');
        expect(value, equals(list));
      });
      test('should create new list instance on get', () async {
        final service = await PreferencesService.getInstance();
        final originalList = ['item1', 'item2'];
        await service.setStringList('listKey', originalList);
        final retrievedList = await service.getStringList('listKey');
        retrievedList!.add('item3');
        // Original stored list should not be modified
        final secondRetrievedList = await service.getStringList('listKey');
        expect(secondRetrievedList, equals(['item1', 'item2']));
      });
    });
    group('Key Management Operations', () {
      test('should check if key exists', () async {
        final service = await PreferencesService.getInstance();
        expect(await service.containsKey('testKey'), isFalse);
        await service.setString('testKey', 'value');
        expect(await service.containsKey('testKey'), isTrue);
      });
      test('should get all keys', () async {
        final service = await PreferencesService.getInstance();
        // Initially empty
        expect(await service.getKeys(), isEmpty);
        // Add various types of values
        await service.setString('stringKey', 'value');
        await service.setInt('intKey', 42);
        await service.setBool('boolKey', true);
        await service.setStringList('listKey', ['item']);
        final keys = await service.getKeys();
        expect(keys.length, equals(4));
        expect(keys, containsAll(['stringKey', 'intKey', 'boolKey', 'listKey']));
      });
      test('should remove specific key', () async {
        final service = await PreferencesService.getInstance();
        await service.setString('keyToRemove', 'value');
        expect(await service.containsKey('keyToRemove'), isTrue);
        final result = await service.remove('keyToRemove');
        expect(result, isTrue);
        expect(await service.containsKey('keyToRemove'), isFalse);
      });
      test('should handle removing non-existent key', () async {
        final service = await PreferencesService.getInstance();
        final result = await service.remove('nonExistentKey');
        expect(result, isTrue); // SharedPreferences returns true even for non-existent keys
      });
      test('should clear all preferences', () async {
        final service = await PreferencesService.getInstance();
        // Add multiple values
        await service.setString('key1', 'value1');
        await service.setInt('key2', 42);
        await service.setBool('key3', true);
        final keys = await service.getKeys();
        expect(keys.length, equals(3));
        final result = await service.clear();
        expect(result, isTrue);
        expect(await service.getKeys(), isEmpty);
      });
    });
    group('Direct Prefs Access', () {
      test('should provide direct access to SharedPreferences', () async {
        final service = await PreferencesService.getInstance();
        final prefs = service.prefs;
        expect(prefs, isA<SharedPreferences>());
        // Should be able to use SharedPreferences methods directly
        await prefs?.setDouble('doubleKey', 3.14);
        expect(prefs?.getDouble('doubleKey'), equals(3.14));
      });
      test('should maintain consistency between service and direct access', () async {
        final service = await PreferencesService.getInstance();
        // Set via service
        await service.setString('sharedKey', 'sharedValue');
        // Get via direct prefs access
        final value = service.prefs?.getString('sharedKey');
        expect(value, equals('sharedValue'));
        // Set via direct prefs access
        await service.prefs?.setInt('directKey', 100);
        // Get via service
        expect(await service.getInt('directKey'), equals(100));
      });
    });
    group('Error Handling and Edge Cases', () {
      test('should handle type mismatches gracefully', () async {
        final service = await PreferencesService.getInstance();
        // Set a string value
        await service.setString('mixedKey', 'stringValue');
        // Try to get it as different types - SharedPreferences throws exceptions
        expect(() async => await service.getInt('mixedKey'), throwsA(isA<TypeError>()));
        expect(() async => await service.getBool('mixedKey'), throwsA(isA<TypeError>()));
        expect(() async => await service.getStringList('mixedKey'), throwsA(isA<TypeError>()));
      });
      test('should handle concurrent operations', () async {
        final service = await PreferencesService.getInstance();
        // Perform multiple concurrent operations
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(service.setString('key$i', 'value$i'));
          futures.add(service.setInt('int$i', i));
          futures.add(service.setBool('bool$i', i % 2 == 0));
        }
        await Future.wait(futures);
        // Verify all values were set correctly
        for (int i = 0; i < 10; i++) {
          expect(await service.getString('key$i'), equals('value$i'));
          expect(await service.getInt('int$i'), equals(i));
          expect(await service.getBool('bool$i'), equals(i % 2 == 0));
        }
      });
      test('should handle very long strings', () async {
        final service = await PreferencesService.getInstance();
        final longString = 'A' * 10000;
        await service.setString('longKey', longString);
        expect(await service.getString('longKey'), equals(longString));
      });
      test('should handle large string lists', () async {
        final service = await PreferencesService.getInstance();
        final largeList = List.generate(100, (i) => 'Item $i');
        await service.setStringList('largeListKey', largeList);
        expect(await service.getStringList('largeListKey'), equals(largeList));
      });
    });
    group('Integration Scenarios', () {
      test('should support typical app settings workflow', () async {
        final service = await PreferencesService.getInstance();
        // User preferences
        await service.setBool('notifications_enabled', true);
        await service.setString('theme', 'dark');
        await service.setInt('font_size', 16);
        await service.setStringList('favorite_items', ['item1', 'item2']);
        // Later retrieval
        expect(await service.getBool('notifications_enabled'), isTrue);
        expect(await service.getString('theme'), equals('dark'));
        expect(await service.getInt('font_size'), equals(16));
        expect(await service.getStringList('favorite_items'), equals(['item1', 'item2']));
      });
      test('should support cache invalidation pattern', () async {
        final service = await PreferencesService.getInstance();
        // Store cache data
        await service.setString('cache_data', 'cached_value');
        await service.setInt('cache_timestamp', DateTime.now().millisecondsSinceEpoch);
        // Check and invalidate
        expect(await service.containsKey('cache_data'), isTrue);
        await service.remove('cache_data');
        await service.remove('cache_timestamp');
        expect(await service.containsKey('cache_data'), isFalse);
        expect(await service.containsKey('cache_timestamp'), isFalse);
      });
    });
  });
}