import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/config_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/user_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/environment_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/listener_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/di/dependency_container.dart';
import 'package:customfit_ai_flutter_sdk/src/network/http_client.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_tracker.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/summary/summary_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/network/config/config_fetcher.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/core/session/session_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/default_background_state_monitor.dart';
import '../../shared/mocks/mock_http_client.dart';
import 'mocks/mock_event_tracker.dart';
import 'mocks/mock_summary_manager.dart';
import 'mocks/mock_config_fetcher.dart';
import 'mocks/mock_connection_manager.dart';
import 'mocks/mock_background_monitor.dart';
import 'mocks/mock_session_manager.dart';

/// Mock dependency factory for testing
///
/// This factory creates mock implementations of all dependencies
/// for use in unit tests. It allows complete control over the
/// behavior of each dependency.
///
/// Example usage:
/// ```dart
/// final mockFactory = MockDependencyFactory();
///
/// // Configure mock behaviors
/// mockFactory.mockHttpClient.configureResponse('/api/config', {'feature': true});
/// mockFactory.mockEventTracker.shouldFailFlush = true;
///
/// // Initialize client with mocks
/// final client = await CFClientDI.initialize(
///   config,
///   user,
///   dependencyFactory: mockFactory,
/// );
///
/// // Verify interactions
/// expect(mockFactory.mockHttpClient.requestCount, equals(1));
/// expect(mockFactory.mockEventTracker.pendingEvents, isEmpty);
/// ```
class MockDependencyFactory implements DependencyFactory {
  // Expose mock instances for test configuration
  late final MockHttpClient mockHttpClient;
  late final MockEventTracker mockEventTracker;
  late final MockSummaryManager mockSummaryManager;
  late final MockConfigFetcher mockConfigFetcher;
  late final MockConnectionManager mockConnectionManager;
  late final MockBackgroundMonitor mockBackgroundMonitor;
  late final MockSessionManager mockSessionManager;
  MockDependencyFactory() {
    // Initialize all mock instances immediately
    mockHttpClient = MockHttpClient();
    mockEventTracker = MockEventTracker();
    mockSummaryManager = MockSummaryManager();
    mockConfigFetcher = MockConfigFetcher();
    mockConnectionManager = MockConnectionManager();
    mockBackgroundMonitor = MockBackgroundMonitor();
    mockSessionManager = MockSessionManager();
  }
  @override
  HttpClient createHttpClient(CFConfig config) {
    return mockHttpClient;
  }

  @override
  ConnectionManagerImpl createConnectionManager(CFConfig config) {
    return ConnectionManagerImpl(config);
  }

  @override
  BackgroundStateMonitor createBackgroundMonitor() {
    return mockBackgroundMonitor;
  }

  @override
  ConfigFetcher createConfigFetcher(
    HttpClient httpClient,
    CFConfig config,
    CFUser user,
  ) {
    return mockConfigFetcher;
  }

  @override
  SummaryManager createSummaryManager(
    String sessionId,
    HttpClient httpClient,
    CFUser user,
    CFConfig config,
  ) {
    return mockSummaryManager;
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
    return mockEventTracker;
  }

  @override
  SessionManager? createSessionManager(CFConfig config) {
    if (config.offlineMode) {
      return null;
    }
    return mockSessionManager;
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
