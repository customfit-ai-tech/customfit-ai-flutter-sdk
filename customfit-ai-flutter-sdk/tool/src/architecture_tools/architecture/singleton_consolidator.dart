import 'dart:io';
import 'architecture_analyzer.dart';

/// Provides consolidation strategies for singleton patterns
class SingletonConsolidator {
  final ArchitectureReport report;

  SingletonConsolidator(this.report);

  /// Generate a SharedPreferences wrapper service
  String generateSharedPreferencesWrapper() {
    return '''
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized wrapper for SharedPreferences access
/// This replaces the 20+ direct calls to SharedPreferences.getInstance()
class PreferencesService {
  static PreferencesService? _instance;
  static SharedPreferences? _prefs;
  
  /// Private constructor
  PreferencesService._();
  
  /// Get singleton instance
  static Future<PreferencesService> getInstance() async {
    if (_instance == null) {
      _instance = PreferencesService._();
      _prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }
  
  /// Get SharedPreferences instance directly if needed
  SharedPreferences get prefs => _prefs!;
  
  // Common preference operations
  
  Future<bool> setString(String key, String value) async {
    return _prefs!.setString(key, value);
  }
  
  String? getString(String key) {
    return _prefs!.getString(key);
  }
  
  Future<bool> setInt(String key, int value) async {
    return _prefs!.setInt(key, value);
  }
  
  int? getInt(String key) {
    return _prefs!.getInt(key);
  }
  
  Future<bool> setBool(String key, bool value) async {
    return _prefs!.setBool(key, value);
  }
  
  bool? getBool(String key) {
    return _prefs!.getBool(key);
  }
  
  Future<bool> setStringList(String key, List<String> value) async {
    return _prefs!.setStringList(key, value);
  }
  
  List<String>? getStringList(String key) {
    return _prefs!.getStringList(key);
  }
  
  Future<bool> remove(String key) async {
    return _prefs!.remove(key);
  }
  
  Future<bool> clear() async {
    return _prefs!.clear();
  }
  
  bool containsKey(String key) {
    return _prefs!.containsKey(key);
  }
  
  Set<String> getKeys() {
    return _prefs!.getKeys();
  }
}

// Usage example:
// final prefsService = await PreferencesService.getInstance();
// await prefsService.setString('key', 'value');
// final value = prefsService.getString('key');
''';
  }

  /// Generate improved ServiceLocator with better patterns
  String generateImprovedServiceLocator() {
    return '''
import 'dart:async';

/// Improved dependency injection container
/// Addresses the 35+ ServiceLocator.get<T>() calls with better patterns
class DependencyContainer {
  static final _instance = DependencyContainer._();
  static DependencyContainer get instance => _instance;
  
  final _services = <Type, dynamic>{};
  final _factories = <Type, dynamic Function()>{};
  final _singletonFactories = <Type, Future<dynamic> Function()>{};
  final _initializingFutures = <Type, Completer<dynamic>>{};
  
  DependencyContainer._();
  
  /// Register a singleton instance
  void registerSingleton<T>(T instance) {
    _services[T] = instance;
  }
  
  /// Register a lazy singleton (created on first access)
  void registerLazySingleton<T>(T Function() factory) {
    _factories[T] = factory;
  }
  
  /// Register an async singleton
  void registerAsyncSingleton<T>(Future<T> Function() factory) {
    _singletonFactories[T] = factory;
  }
  
  /// Get a registered service
  T get<T>() {
    // Check if already instantiated
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }
    
    // Check for lazy factory
    if (_factories.containsKey(T)) {
      final instance = _factories[T]!() as T;
      _services[T] = instance;
      _factories.remove(T);
      return instance;
    }
    
    throw StateError('Service \$T not registered');
  }
  
  /// Get an async service
  Future<T> getAsync<T>() async {
    // Check if already instantiated
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }
    
    // Check if already initializing
    if (_initializingFutures.containsKey(T)) {
      return await _initializingFutures[T]!.future as T;
    }
    
    // Check for async factory
    if (_singletonFactories.containsKey(T)) {
      final completer = Completer<T>();
      _initializingFutures[T] = completer;
      
      try {
        final instance = await _singletonFactories[T]!() as T;
        _services[T] = instance;
        _singletonFactories.remove(T);
        _initializingFutures.remove(T);
        completer.complete(instance);
        return instance;
      } catch (e) {
        _initializingFutures.remove(T);
        completer.completeError(e);
        rethrow;
      }
    }
    
    throw StateError('Async service \$T not registered');
  }
  
  /// Check if a service is registered
  bool isRegistered<T>() {
    return _services.containsKey(T) || 
           _factories.containsKey(T) || 
           _singletonFactories.containsKey(T);
  }
  
  /// Clear all registrations (for testing)
  void reset() {
    _services.clear();
    _factories.clear();
    _singletonFactories.clear();
    _initializingFutures.clear();
  }
}

// Extension for easier access
extension GetIt on DependencyContainer {
  static T get<T>() => DependencyContainer.instance.get<T>();
  static Future<T> getAsync<T>() => DependencyContainer.instance.getAsync<T>();
}
''';
  }

  /// Generate a singleton registry to track all singletons
  String generateSingletonRegistry() {
    return '''
/// Registry to track and manage all singleton instances
/// Helps consolidate the ${report.totalSingletons} singleton instances found
class SingletonRegistry {
  static final _instance = SingletonRegistry._();
  static SingletonRegistry get instance => _instance;
  
  final _singletons = <String, dynamic>{};
  final _metadata = <String, SingletonMetadata>{};
  
  SingletonRegistry._();
  
  /// Register a singleton with metadata
  void register<T>({
    required String name,
    required T instance,
    String? description,
    bool isLazy = false,
  }) {
    _singletons[name] = instance;
    _metadata[name] = SingletonMetadata(
      type: T,
      name: name,
      description: description,
      isLazy: isLazy,
      registeredAt: DateTime.now(),
    );
  }
  
  /// Get a registered singleton
  T? get<T>(String name) {
    return _singletons[name] as T?;
  }
  
  /// Get all registered singletons of a type
  List<T> getAllOfType<T>() {
    return _singletons.values.whereType<T>().toList();
  }
  
  /// Get registry statistics
  Map<String, dynamic> getStats() {
    final typeCount = <Type, int>{};
    for (final meta in _metadata.values) {
      typeCount[meta.type] = (typeCount[meta.type] ?? 0) + 1;
    }
    
    return {
      'totalSingletons': _singletons.length,
      'byType': typeCount,
      'registrationTimes': _metadata.map((k, v) => MapEntry(k, v.registeredAt)),
    };
  }
  
  /// Clear all singletons (for testing)
  void clear() {
    _singletons.clear();
    _metadata.clear();
  }
}

class SingletonMetadata {
  final Type type;
  final String name;
  final String? description;
  final bool isLazy;
  final DateTime registeredAt;
  
  SingletonMetadata({
    required this.type,
    required this.name,
    this.description,
    required this.isLazy,
    required this.registeredAt,
  });
}
''';
  }

  /// Generate refactoring script for common patterns
  String generateRefactoringScript() {
    final buffer = StringBuffer();

    buffer.writeln('#!/bin/bash');
    buffer.writeln('# Singleton Consolidation Refactoring Script');
    buffer.writeln('# Generated from architecture analysis\n');

    buffer.writeln('echo "🔧 Starting singleton consolidation refactoring..."');
    buffer.writeln();

    // SharedPreferences refactoring
    buffer.writeln('# Step 1: Replace SharedPreferences.getInstance() calls');
    buffer.writeln('echo "📦 Refactoring SharedPreferences usage..."');
    buffer.writeln();

    final sharedPrefsFiles = <String>{};
    for (final singleton in report.singletons) {
      if (singleton.pattern == SingletonPattern.sharedPreferences) {
        sharedPrefsFiles.add(singleton.filePath);
      }
    }

    for (final file in sharedPrefsFiles) {
      buffer.writeln('# Update $file');
      buffer.writeln(
          'sed -i.bak \'s/SharedPreferences\\.getInstance()/PreferencesService.getInstance()/g\' "$file"');
    }

    buffer.writeln();
    buffer.writeln('# Step 2: Update imports');
    buffer.writeln('echo "📝 Updating imports..."');

    for (final file in sharedPrefsFiles) {
      buffer.writeln('# Add PreferencesService import to $file');
      buffer.writeln(
          'sed -i.bak \'1s/^/import \'package:customfit_ai_flutter_sdk\\/src\\/services\\/preferences_service.dart\';\\n/\' "$file"');
    }

    buffer.writeln();
    buffer.writeln('echo "✅ Refactoring complete!"');
    buffer.writeln('echo "📊 Updated ${sharedPrefsFiles.length} files"');
    buffer.writeln();
    buffer.writeln('# Note: Review changes and run tests before committing');

    return buffer.toString();
  }

  /// Generate migration guide
  String generateMigrationGuide() {
    final buffer = StringBuffer();

    buffer.writeln('# Singleton Consolidation Migration Guide\n');

    buffer.writeln('## Overview');
    buffer.writeln(
        'This guide helps migrate from ${report.totalSingletons} scattered singleton instances to a consolidated architecture.\n');

    buffer.writeln('## Current State');
    buffer.writeln('- Total singleton instances: ${report.totalSingletons}');
    buffer.writeln('- Unique classes: ${report.singletonsByClass.length}');
    buffer.writeln('- Most common patterns:');

    final sortedPatterns = report.patternCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedPatterns.take(3)) {
      buffer.writeln('  - ${entry.key.description}: ${entry.value} instances');
    }

    buffer.writeln('\n## Migration Steps\n');

    buffer.writeln('### 1. SharedPreferences Consolidation');
    buffer.writeln(
        'Replace all ${report.patternCounts[SingletonPattern.sharedPreferences] ?? 0} direct calls with PreferencesService:\n');
    buffer.writeln('```dart');
    buffer.writeln('// Before:');
    buffer.writeln('final prefs = await SharedPreferences.getInstance();');
    buffer.writeln('await prefs.setString(\'key\', \'value\');');
    buffer.writeln();
    buffer.writeln('// After:');
    buffer.writeln(
        'final prefsService = await PreferencesService.getInstance();');
    buffer.writeln('await prefsService.setString(\'key\', \'value\');');
    buffer.writeln('```\n');

    buffer.writeln('### 2. ServiceLocator Migration');
    buffer.writeln(
        'Replace ${report.patternCounts[SingletonPattern.serviceLocator] ?? 0} ServiceLocator calls with dependency injection:\n');
    buffer.writeln('```dart');
    buffer.writeln('// Before:');
    buffer.writeln('final tracker = ServiceLocator.get<EventTracker>();');
    buffer.writeln();
    buffer.writeln('// After (constructor injection):');
    buffer.writeln('class MyClass {');
    buffer.writeln('  final EventTracker _eventTracker;');
    buffer.writeln('  ');
    buffer.writeln('  MyClass(this._eventTracker);');
    buffer.writeln('}');
    buffer.writeln('```\n');

    buffer.writeln('### 3. Static Instance Consolidation');
    buffer.writeln(
        'Consolidate ${report.patternCounts[SingletonPattern.staticInstance] ?? 0} static _instance fields:\n');
    buffer.writeln('```dart');
    buffer.writeln('// Register all singletons in one place:');
    buffer.writeln('void setupDependencies() {');
    buffer.writeln('  final container = DependencyContainer.instance;');
    buffer.writeln('  ');
    buffer.writeln('  // Register services');
    buffer.writeln('  container.registerLazySingleton(() => HttpClient());');
    buffer.writeln('  container.registerLazySingleton(() => EventTracker());');
    buffer.writeln(
        '  container.registerAsyncSingleton(() => SessionManager.create());');
    buffer.writeln('}');
    buffer.writeln('```\n');

    buffer.writeln('## Benefits');
    buffer.writeln('- **Testability**: Easy to mock dependencies');
    buffer.writeln('- **Maintainability**: Central place for all dependencies');
    buffer.writeln('- **Performance**: Lazy loading and proper initialization');
    buffer
        .writeln('- **Type Safety**: Compile-time checking of dependencies\n');

    buffer.writeln('## Testing');
    buffer.writeln('```dart');
    buffer.writeln('// Easy testing with mocked dependencies');
    buffer.writeln('void main() {');
    buffer.writeln('  setUp(() {');
    buffer.writeln('    DependencyContainer.instance.reset();');
    buffer.writeln(
        '    DependencyContainer.instance.registerSingleton(MockEventTracker());');
    buffer.writeln('  });');
    buffer.writeln('}');
    buffer.writeln('```');

    return buffer.toString();
  }

  /// Save all consolidation artifacts
  Future<void> saveArtifacts(String outputDir) async {
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Save SharedPreferences wrapper
    final prefsFile = File('$outputDir/preferences_service.dart');
    await prefsFile.writeAsString(generateSharedPreferencesWrapper());
    print('✅ Created: ${prefsFile.path}');

    // Save improved service locator
    final containerFile = File('$outputDir/dependency_container.dart');
    await containerFile.writeAsString(generateImprovedServiceLocator());
    print('✅ Created: ${containerFile.path}');

    // Save singleton registry
    final registryFile = File('$outputDir/singleton_registry.dart');
    await registryFile.writeAsString(generateSingletonRegistry());
    print('✅ Created: ${registryFile.path}');

    // Save refactoring script
    final scriptFile = File('$outputDir/refactor_singletons.sh');
    await scriptFile.writeAsString(generateRefactoringScript());
    // Make script executable
    if (Platform.isLinux || Platform.isMacOS) {
      await Process.run('chmod', ['+x', scriptFile.path]);
    }
    print('✅ Created: ${scriptFile.path}');

    // Save migration guide
    final guideFile = File('$outputDir/MIGRATION_GUIDE.md');
    await guideFile.writeAsString(generateMigrationGuide());
    print('✅ Created: ${guideFile.path}');
  }
}
