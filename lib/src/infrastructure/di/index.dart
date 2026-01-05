// infrastructure/di/index.dart
//
// Public API for dependency injection infrastructure module.
// Exposes only interfaces, hides internal implementations.

// Public interfaces
export 'interfaces/service_locator.dart';

// Internal implementations are not exported - they remain encapsulated
// Hidden: internal/dependency_container_impl.dart
// Hidden: internal/default_dependency_factory.dart
// Hidden: internal/simple_service_factory.dart
