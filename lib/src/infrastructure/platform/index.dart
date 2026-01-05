// infrastructure/platform/index.dart
//
// Public API for platform infrastructure module.
// Exposes only interfaces, hides internal implementations.

// Public interfaces
export 'interfaces/device_info_detector.dart';
export 'interfaces/background_state_monitor.dart';

// Public models
export 'models/device_context.dart';
export 'models/application_info.dart';

// Internal implementations are not exported - they remain encapsulated
// Hidden: internal/device_info_detector_impl.dart
// Hidden: internal/default_background_state_monitor.dart
// Hidden: internal/app_state.dart
// Hidden: internal/battery_state.dart
