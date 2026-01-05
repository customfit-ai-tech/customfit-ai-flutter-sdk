// infrastructure/network/index.dart
//
// Public API for network infrastructure module.
// Exposes only interfaces and models, hides internal implementations.

// Public interfaces
export 'interfaces/http_client.dart';
export 'interfaces/connection_manager.dart';
export 'interfaces/config_fetcher.dart';

// Public models (DTOs)
export 'models/config_request.dart';
export 'models/config_response.dart';
export 'models/summary_request.dart';
export 'models/track_request.dart';

// Internal implementations are not exported - they remain encapsulated
// Hidden: internal/http_client_impl.dart
// Hidden: internal/connection_manager_impl.dart
// Hidden: internal/config_fetcher_impl.dart
// Hidden: internal/request_deduplicator.dart
// Hidden: internal/connection_information.dart
// Hidden: internal/connection_status.dart
