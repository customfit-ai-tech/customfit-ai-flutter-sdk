// lib/src/di/simple_service_factory.dart
//
// Simplified service factory that replaces complex dependency injection patterns
// with straightforward factory methods.
//
// This file is part of the CustomFit SDK for Flutter.

import 'package:uuid/uuid.dart';
import '../config/core/cf_config.dart';
import '../core/model/cf_user.dart';
import '../network/http_client.dart';
import '../network/config/config_fetcher.dart';
import '../network/connection/connection_manager.dart';
import '../analytics/event/event_tracker.dart';
import '../analytics/summary/summary_manager.dart';
import '../platform/default_background_state_monitor.dart';
import '../client/managers/config_manager.dart';
import '../client/managers/user_manager.dart';
import '../client/managers/environment_manager.dart';
import '../client/managers/listener_manager.dart';

/// Simplified service factory that creates SDK services without complex DI patterns
class SimpleServiceFactory {
  static const String _source = 'SimpleServiceFactory';
  static const _uuid = Uuid();

  // Cache for singleton instances
  static final Map<String, dynamic> _singletons = {};

  // UUID mappings to avoid hash collisions
  static final Map<String, String> _configUuids = {};
  static final Map<String, String> _userUuids = {};

  /// Generate or retrieve UUID for config
  static String _getConfigUuid(CFConfig config) {
    final key = '${config.clientKey}_${config.baseApiUrl}';
    return _configUuids[key] ??= _uuid.v4();
  }

  /// Generate or retrieve UUID for user
  static String _getUserUuid(CFUser user) {
    final key = '${user.userId}_${user.anonymous}';
    return _userUuids[key] ??= _uuid.v4();
  }

  /// Create HTTP client
  static HttpClient createHttpClient(CFConfig config) {
    final configId = _getConfigUuid(config);
    final key = 'HttpClient_$configId';
    return _singletons[key] ??= HttpClient(config);
  }

  /// Create connection manager
  static ConnectionManagerImpl createConnectionManager(CFConfig config) {
    final configId = _getConfigUuid(config);
    final key = 'ConnectionManager_$configId';
    return _singletons[key] ??= ConnectionManagerImpl(config);
  }

  /// Create background monitor
  static DefaultBackgroundStateMonitor createBackgroundMonitor() {
    const key = 'BackgroundMonitor';
    return _singletons[key] ??= DefaultBackgroundStateMonitor();
  }

  /// Create config fetcher
  static ConfigFetcher createConfigFetcher(
    CFConfig config,
    CFUser user, {
    HttpClient? httpClient,
  }) {
    final client = httpClient ?? createHttpClient(config);
    final configId = _getConfigUuid(config);
    final userId = _getUserUuid(user);
    final key = 'ConfigFetcher_${configId}_$userId';
    return _singletons[key] ??= ConfigFetcher(client, config, user);
  }

  /// Create summary manager
  static SummaryManager createSummaryManager(
    String sessionId,
    CFConfig config,
    CFUser user, {
    HttpClient? httpClient,
  }) {
    final client = httpClient ?? createHttpClient(config);
    final configId = _getConfigUuid(config);
    final userId = _getUserUuid(user);
    final key = 'SummaryManager_${sessionId}_${configId}_$userId';
    return _singletons[key] ??= SummaryManager(sessionId, client, user, config);
  }

  /// Create event tracker
  static EventTracker createEventTracker(
    String sessionId,
    CFConfig config,
    CFUser user, {
    HttpClient? httpClient,
    ConnectionManagerImpl? connectionManager,
    SummaryManager? summaryManager,
  }) {
    final client = httpClient ?? createHttpClient(config);
    final connMgr = connectionManager ?? createConnectionManager(config);
    final summMgr = summaryManager ??
        createSummaryManager(sessionId, config, user, httpClient: client);

    final configId = _getConfigUuid(config);
    final userId = _getUserUuid(user);
    final key = 'EventTracker_${sessionId}_${configId}_$userId';
    return _singletons[key] ??= EventTracker(
      client,
      connMgr,
      user,
      sessionId,
      config,
      summaryManager: summMgr,
    );
  }

  /// Create config manager
  static ConfigManagerImpl createConfigManager(
    CFConfig config,
    CFUser user, {
    ConfigFetcher? configFetcher,
    ConnectionManagerImpl? connectionManager,
    SummaryManager? summaryManager,
  }) {
    final fetcher = configFetcher ?? createConfigFetcher(config, user);
    final connMgr = connectionManager ?? createConnectionManager(config);
    final summMgr =
        summaryManager ?? createSummaryManager('default', config, user);

    final configId = _getConfigUuid(config);
    final userId = _getUserUuid(user);
    final key = 'ConfigManager_${configId}_$userId';
    return _singletons[key] ??= ConfigManagerImpl(
      config: config,
      configFetcher: fetcher,
      connectionManager: connMgr,
      summaryManager: summMgr,
    );
  }

  /// Create user manager
  static UserManagerImpl createUserManager(CFUser user) {
    final userId = _getUserUuid(user);
    final key = 'UserManager_$userId';
    return _singletons[key] ??= UserManagerImpl(user);
  }

  /// Create environment manager
  static EnvironmentManagerImpl createEnvironmentManager(
    CFUser user, {
    DefaultBackgroundStateMonitor? backgroundMonitor,
    UserManagerImpl? userManager,
  }) {
    final bgMonitor = backgroundMonitor ?? createBackgroundMonitor();
    final usrMgr = userManager ?? createUserManager(user);

    final userId = _getUserUuid(user);
    final key = 'EnvironmentManager_$userId';
    return _singletons[key] ??= EnvironmentManagerImpl(
      backgroundStateMonitor: bgMonitor,
      userManager: usrMgr,
    );
  }

  /// Create listener manager
  static ListenerManager createListenerManager() {
    const key = 'ListenerManager';
    return _singletons[key] ??= ListenerManager();
  }

  /// Create all services for a CFClient instance
  static CFClientServices createAllServices(
    String sessionId,
    CFConfig config,
    CFUser user,
  ) {
    // Create core services
    final httpClient = createHttpClient(config);
    final connectionManager = createConnectionManager(config);
    final backgroundMonitor = createBackgroundMonitor();

    // Create dependent services
    final configFetcher =
        createConfigFetcher(config, user, httpClient: httpClient);
    final summaryManager =
        createSummaryManager(sessionId, config, user, httpClient: httpClient);
    final eventTracker = createEventTracker(
      sessionId,
      config,
      user,
      httpClient: httpClient,
      connectionManager: connectionManager,
      summaryManager: summaryManager,
    );

    // Create managers
    final configManager = createConfigManager(
      config,
      user,
      configFetcher: configFetcher,
      connectionManager: connectionManager,
      summaryManager: summaryManager,
    );
    final userManager = createUserManager(user);
    final environmentManager = createEnvironmentManager(
      user,
      backgroundMonitor: backgroundMonitor,
      userManager: userManager,
    );
    final listenerManager = createListenerManager();

    return CFClientServices(
      httpClient: httpClient,
      connectionManager: connectionManager,
      backgroundMonitor: backgroundMonitor,
      configFetcher: configFetcher,
      summaryManager: summaryManager,
      eventTracker: eventTracker,
      configManager: configManager,
      userManager: userManager,
      environmentManager: environmentManager,
      listenerManager: listenerManager,
    );
  }

  /// Clear all cached singletons (for testing)
  static void clearCache() {
    _singletons.clear();
  }

  /// Clear specific service from cache
  static void clearService(String key) {
    _singletons.remove(key);
  }

  /// Get cached service count (for debugging)
  static int get cachedServiceCount => _singletons.length;
}

/// Container for all CFClient services
class CFClientServices {
  final HttpClient httpClient;
  final ConnectionManagerImpl connectionManager;
  final DefaultBackgroundStateMonitor backgroundMonitor;
  final ConfigFetcher configFetcher;
  final SummaryManager summaryManager;
  final EventTracker eventTracker;
  final ConfigManagerImpl configManager;
  final UserManagerImpl userManager;
  final EnvironmentManagerImpl environmentManager;
  final ListenerManager listenerManager;

  CFClientServices({
    required this.httpClient,
    required this.connectionManager,
    required this.backgroundMonitor,
    required this.configFetcher,
    required this.summaryManager,
    required this.eventTracker,
    required this.configManager,
    required this.userManager,
    required this.environmentManager,
    required this.listenerManager,
  });

  /// Shutdown all services
  Future<void> shutdown() async {
    eventTracker.shutdown();
    summaryManager.shutdown();
    connectionManager.shutdown();
    backgroundMonitor.shutdown();
    configManager.shutdown();
    environmentManager.shutdown();
  }
}
