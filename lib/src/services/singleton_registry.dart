/// Registry to track and manage all singleton instances
/// Helps consolidate the 85 singleton instances found
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
    final instance = _singletons[name];
    if (instance is T) {
      return instance;
    }
    return null;
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
