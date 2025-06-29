// Core SDK Components
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
export 'src/network/connection/connection_manager.dart'
    show ConnectionStatusListener;
export 'src/network/connection/connection_status.dart';
export 'src/network/connection/connection_information.dart';

// Dependency injection exports
export 'src/di/dependency_container.dart';
// ServiceLocator is deprecated - use DependencyContainer instead
// export 'src/core/service_locator.dart';

// Network optimization exports
export 'src/network/efficiency/network_optimizer.dart';
export 'src/monitoring/network_health_monitor.dart';

// Utility exports
export 'src/core/util/cache_manager.dart';
export 'src/core/util/memory_manager.dart';
export 'src/core/util/json_parser.dart';
export 'src/core/util/string_optimizer.dart';
export 'src/core/util/retry_util.dart';

// Constants
export 'src/constants/cf_constants.dart';

// Logging
export 'src/logging/logger.dart' hide LogLevel;
export 'src/logging/remote_logger.dart';
export 'src/logging/log_level_updater.dart';

// Type-safe feature flags
export 'src/features/flag_definition.dart';
export 'src/features/typed_flags.dart';
export 'src/features/feature_flags.dart';
export 'src/features/flag_provider.dart';
export 'src/features/cf_flag_provider.dart';
