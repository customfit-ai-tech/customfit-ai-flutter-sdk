import '../../../config/core/cf_config.dart';
import '../../../core/model/cf_user.dart';
import '../../../client/managers/config_manager.dart';
import '../../../client/managers/user_manager.dart';
import '../../../client/managers/environment_manager.dart';
import '../../../client/managers/listener_manager.dart';
import './dependency_container.dart';
import '../../types.dart';

// Concrete implementations
import '../../network/internal/http_client_impl.dart';
import '../../network/internal/config_fetcher_impl.dart';
import '../../network/internal/connection_manager_impl.dart';
import '../../../analytics/event/event_tracker.dart';
import '../../../analytics/summary/summary_manager.dart';
import '../../platform/internal/default_background_state_monitor.dart'
    as platform;
import '../../../core/session/session_manager.dart';

/// Default implementation of DependencyFactory for production use
class DefaultDependencyFactory implements DependencyFactory {
  @override
  HttpClient createHttpClient(CFConfig config) {
    return HttpClientImpl(config);
  }

  @override
  ConnectionManagerImpl createConnectionManager(CFConfig config) {
    return ConnectionManagerImpl(config);
  }

  @override
  BackgroundStateMonitor createBackgroundMonitor() {
    return platform.DefaultBackgroundStateMonitor();
  }

  @override
  ConfigFetcher createConfigFetcher(
    HttpClient httpClient,
    CFConfig config,
    UserManager userManager,
  ) {
    return ConfigFetcherImpl(httpClient, config, userManager);
  }

  @override
  SummaryManager createSummaryManager(
    String sessionId,
    HttpClient httpClient,
    CFUser user,
    CFConfig config,
  ) {
    return SummaryManager(sessionId, httpClient, user, config);
  }

  @override
  EventTracker createEventTracker(
    HttpClient httpClient,
    ConnectionManagerImpl connectionManager,
    CFUser user,
    String sessionId,
    CFConfig config,
    SummaryManager summaryManager,
  ) {
    return EventTracker(
      httpClient,
      connectionManager,
      user,
      sessionId,
      config,
      summaryManager: summaryManager,
    );
  }

  @override
  SessionManager? createSessionManager(CFConfig config) {
    // Return null for now as SessionManager is not used in current implementation
    return null;
  }

  @override
  ConfigManager createConfigManager(
    CFConfig config,
    ConfigFetcher configFetcher,
    ConnectionManagerImpl connectionManager,
    SummaryManager summaryManager,
  ) {
    return ConfigManagerImpl(
      config: config,
      configFetcher: configFetcher,
      connectionManager: connectionManager,
      summaryManager: summaryManager,
    );
  }

  @override
  UserManager createUserManager(CFUser user) {
    return UserManagerImpl(user);
  }

  @override
  EnvironmentManager createEnvironmentManager(
    BackgroundStateMonitor backgroundMonitor,
    UserManager userManager,
  ) {
    return EnvironmentManagerImpl(
      backgroundStateMonitor: backgroundMonitor,
      userManager: userManager,
    );
  }

  @override
  ListenerManager createListenerManager() {
    return ListenerManager();
  }
}
