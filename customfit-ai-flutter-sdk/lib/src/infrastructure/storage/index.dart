// infrastructure/storage/index.dart
//
// Public API for storage infrastructure module.
// Exposes only interfaces, hides internal implementations.

// Public interfaces
export 'interfaces/cache_manager.dart';
export 'interfaces/preferences_service.dart';
export 'interfaces/secure_storage_service.dart';

// Internal implementations are not exported - they remain encapsulated
// Hidden: internal/cache_manager_impl.dart
// Hidden: internal/config_cache.dart
// Hidden: internal/preferences_service_impl.dart
// Hidden: internal/secure_storage_service_impl.dart
// Hidden: internal/simple_storage_helper.dart
// Hidden: internal/storage_abstraction.dart
