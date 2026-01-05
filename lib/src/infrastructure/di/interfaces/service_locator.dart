// infrastructure/di/interfaces/service_locator.dart
//
// Abstract interface for dependency injection and service location.
// Defines the contract for registering and resolving dependencies.

/// Abstract interface for service location
abstract class IServiceLocator {
  /// Register a singleton instance
  void registerSingleton<T>(T instance);

  /// Register a factory function
  void registerFactory<T>(T Function() factory);

  /// Register a lazy singleton (created on first access)
  void registerLazySingleton<T>(T Function() factory);

  /// Get instance of type T
  T get<T>();

  /// Check if type T is registered
  bool isRegistered<T>();

  /// Unregister type T
  void unregister<T>();

  /// Clear all registrations
  void reset();

  /// Get all registered types
  List<Type> getRegisteredTypes();
}
