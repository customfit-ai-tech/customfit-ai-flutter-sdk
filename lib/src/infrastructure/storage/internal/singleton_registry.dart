// lib/src/infrastructure/storage/internal/singleton_registry.dart
//
// Global singleton registry for managing shared instances across the SDK.
// Provides centralized management of singleton objects with lifecycle control
// and debugging support for better maintainability.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:collection';
import '../../logging/logger.dart';

/// Metadata for tracking singleton registration details
class SingletonMetadata {
  final String name;
  final String? description;
  final DateTime registeredAt;
  final Type type;

  const SingletonMetadata({
    required this.name,
    this.description,
    required this.registeredAt,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'registeredAt': registeredAt.toIso8601String(),
      'type': type.toString(),
    };
  }
}

/// Global registry for managing singleton instances across the SDK
class SingletonRegistry {
  static final SingletonRegistry _instance = SingletonRegistry._internal();
  static SingletonRegistry get instance => _instance;

  final Map<String, dynamic> _singletons = {};
  final Map<String, SingletonMetadata> _metadata = {};

  SingletonRegistry._internal();

  /// Register a singleton instance with optional metadata
  void register<T>(
    String name,
    T instance, {
    String? description,
  }) {
    final now = DateTime.now();

    if (_singletons.containsKey(name)) {
      Logger.w('SingletonRegistry: Overwriting existing singleton: $name');
    }

    _singletons[name] = instance;
    _metadata[name] = SingletonMetadata(
      name: name,
      description: description,
      registeredAt: now,
      type: T,
    );

    Logger.d('SingletonRegistry: Registered $name of type $T');
  }

  /// Get a singleton instance by name and type
  T? get<T>(String name) {
    final instance = _singletons[name];
    if (instance == null) {
      Logger.w('SingletonRegistry: Singleton not found: $name');
      return null;
    }

    if (instance is T) {
      return instance;
    }

    Logger.w(
        'SingletonRegistry: Type mismatch for $name. Expected $T, got ${instance.runtimeType}');
    return null;
  }

  /// Check if a singleton is registered
  bool contains(String name) => _singletons.containsKey(name);

  /// Unregister a singleton
  bool unregister(String name) {
    final removed = _singletons.remove(name) != null;
    _metadata.remove(name);

    if (removed) {
      Logger.d('SingletonRegistry: Unregistered $name');
    } else {
      Logger.w(
          'SingletonRegistry: Attempted to unregister non-existent singleton: $name');
    }

    return removed;
  }

  /// Get all singletons of a specific type
  List<T> getAllOfType<T>() {
    return _singletons.values.whereType<T>().toList();
  }

  /// Get metadata for a singleton
  SingletonMetadata? getMetadata(String name) => _metadata[name];

  /// Get all registered singleton names
  List<String> getNames() => _singletons.keys.toList();

  /// Get registry statistics
  Map<String, dynamic> getStats() {
    final stats = <String, dynamic>{};
    final typeCount = <String, int>{};

    for (final entry in _singletons.entries) {
      final typeName = entry.value.runtimeType.toString();
      typeCount[typeName] = (typeCount[typeName] ?? 0) + 1;
    }

    stats['totalCount'] = _singletons.length;
    stats['typeDistribution'] = typeCount;
    stats['registrationOrder'] = _metadata.values
        .map((meta) => meta.toMap())
        .toList()
      ..sort((a, b) => DateTime.parse(a['registeredAt'] as String)
          .compareTo(DateTime.parse(b['registeredAt'] as String)));

    return stats;
  }

  /// Clear all registered singletons
  void clear() {
    final count = _singletons.length;
    _singletons.clear();
    _metadata.clear();
    Logger.d('SingletonRegistry: Cleared $count singletons');
  }

  /// Get a copy of all singleton names and their types for debugging
  Map<String, String> debug() {
    return UnmodifiableMapView(_singletons.map(
        (name, instance) => MapEntry(name, instance.runtimeType.toString())));
  }
}
