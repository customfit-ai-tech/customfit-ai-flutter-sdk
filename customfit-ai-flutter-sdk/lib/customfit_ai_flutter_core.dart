/// Core module for CustomFit.ai Flutter SDK providing essential components.
///
/// This module exports the core functionality needed for basic SDK usage,
/// including feature flag evaluation, user management, and session handling.
///
/// Usage:
/// ```dart
/// import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_core.dart';
/// ```
///
/// For full SDK features including analytics and advanced configuration:
/// ```dart
/// import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
/// ```
library;

// Core client and configuration
export 'src/client/cf_client.dart';
export 'src/client/cf_client_feature_flags.dart';
export 'src/client/cf_client_events.dart';
export 'src/client/cf_client_listeners.dart';
export 'src/client/cf_client_recovery.dart';

// Recovery types - Added as per plan
export 'src/client/cf_client_recovery.dart'
    show SystemHealthStatus, SystemOverallStatus, EventRecoveryResult;

// Core exports
export 'src/core/error/cf_result.dart';
export 'src/core/error/cf_error_code.dart';
export 'src/core/model/cf_user.dart';
export 'src/core/model/feature_flag_value.dart';

// Config exports
export 'src/config/core/cf_config.dart';

// Event exports
export 'src/analytics/event/event_data.dart';
export 'src/analytics/event/event_type.dart';
export 'src/analytics/event/event_tracker.dart';
export 'src/analytics/event/typed_event_properties.dart';

// Error handling exports
export 'src/core/error/error_category.dart';
export 'src/core/error/error_severity.dart';

// Platform exports
export 'src/core/model/device_context.dart';
export 'src/core/model/application_info.dart';

// Session management exports
export 'src/core/session/session_manager.dart';

// Manager exports
export 'src/client/managers/config_manager.dart';
export 'src/client/managers/user_manager.dart';
export 'src/client/managers/environment_manager.dart';
export 'src/client/managers/listener_manager.dart';

// Listener exports
export 'src/client/listener/feature_flag_change_listener.dart';
export 'src/client/listener/all_flags_listener.dart';
// Infrastructure modules (network, storage, logging, DI, utils)
export 'src/infrastructure/network/index.dart';
export 'src/infrastructure/storage/index.dart';
export 'src/infrastructure/platform/index.dart';
export 'src/infrastructure/di/index.dart';
export 'src/infrastructure/utils/index.dart' hide synchronized;
export 'src/infrastructure/logging/index.dart' hide LogLevel;

// Monitoring and constants
export 'src/monitoring/network_health_monitor.dart';
export 'src/constants/cf_constants.dart';

// Type-safe feature flags
export 'src/features/flag_definition.dart';
export 'src/features/typed_flags.dart';
export 'src/features/feature_flags.dart';
export 'src/features/flag_provider.dart';
export 'src/features/cf_flag_provider.dart';
