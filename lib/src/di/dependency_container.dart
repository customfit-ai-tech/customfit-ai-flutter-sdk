import 'dart:async';
import '../config/core/cf_config.dart';
import '../core/model/cf_user.dart';
import '../network/http_client.dart';
import '../network/connection/connection_manager.dart';
import '../platform/default_background_state_monitor.dart';
import '../client/managers/config_manager.dart';
import '../client/managers/user_manager.dart';
import '../client/managers/environment_manager.dart';
import '../client/managers/listener_manager.dart';
import './default_dependency_factory.dart';
import '../logging/logger.dart';

import '../analytics/event/event_tracker.dart';
import '../analytics/summary/summary_manager.dart';
import '../network/config/config_fetcher.dart';
import '../core/session/session_manager.dart';

/// Abstract factory interface for creating SDK dependencies
/// Used for dependency injection in tests
abstract class DependencyFactory {
  HttpClient createHttpClient(CFConfig config);
  ConnectionManagerImpl createConnectionManager(CFConfig config);
  BackgroundStateMonitor createBackgroundMonitor();
  ConfigFetcher createConfigFetcher(
    HttpClient httpClient,
    CFConfig config,
    CFUser user,
  );
  SummaryManager createSummaryManager(
    String sessionId,
    HttpClient httpClient,
    CFUser user,
    CFConfig config,
  );
  EventTracker createEventTracker(
    HttpClient httpClient,
    ConnectionManagerImpl connectionManager,
    CFUser user,
    String sessionId,
    CFConfig config,
    SummaryManager summaryManager,
  );
  SessionManager? createSessionManager(CFConfig config);
  ConfigManager createConfigManager(
    CFConfig config,
    ConfigFetcher configFetcher,
    ConnectionManagerImpl connectionManager,
    SummaryManager summaryManager,
  );
  UserManager createUserManager(CFUser user);
  EnvironmentManager createEnvironmentManager(
    BackgroundStateMonitor backgroundMonitor,
    UserManager userManager,
  );
  ListenerManager createListenerManager();
}

/// Improved dependency injection container
/// Provides improved dependency injection with better patterns
class DependencyContainer {
  static final _instance = DependencyContainer._();
  static DependencyContainer get instance => _instance;

  final _services = <Type, dynamic>{};
  final _factories = <Type, dynamic Function()>{};
  final _singletonFactories = <Type, Future<dynamic> Function()>{};
  final _initializingFutures = <Type, Completer<dynamic>>{};

  DependencyFactory? _factory;
  CFConfig? _config;
  CFUser? _user;
  String? _sessionId;
  bool _initialized = false;

  DependencyContainer._();

  /// Initialize the container with SDK configuration
  void initialize({
    required CFConfig config,
    required CFUser user,
    required String sessionId,
    DependencyFactory? factory,
  }) {
    if (_initialized) {
      Logger.w('DependencyContainer: Already initialized, reinitializing');
      reset();
    }

    _config = config;
    _user = user;
    _sessionId = sessionId;
    _factory = factory ?? DefaultDependencyFactory();
    _initialized = true;

    _registerServices();
    Logger.i(
      'DependencyContainer: Initialized with ${_factories.length} services',
    );
  }

  /// Update session ID and recreate session-dependent services
  void updateSessionId(String newSessionId) {
    if (!_initialized) {
      Logger.w(
        'DependencyContainer: Not initialized, cannot update session ID',
      );
      return;
    }

    _sessionId = newSessionId;
    Logger.d('DependencyContainer: Updated session ID');

    // Clear services that depend on session ID
    final sessionDependentTypes = <Type>[
      EventTracker,
      SummaryManager,
    ];

    for (final type in sessionDependentTypes) {
      if (_services.containsKey(type)) {
        _services.remove(type);
        Logger.d(
          'DependencyContainer: Cleared cached instance of $type for session update',
        );
      }
    }
  }

  /// Register all services using the factory
  void _registerServices() {
    if (_factory == null ||
        _config == null ||
        _user == null ||
        _sessionId == null) {
      throw StateError('DependencyContainer not properly initialized');
    }

    final factory = _factory!;
    final config = _config!;
    final user = _user!;
    final sessionId = _sessionId!;

    // Register core services
    registerLazySingleton<HttpClient>(
      () => factory.createHttpClient(config),
    );

    registerLazySingleton<ConnectionManagerImpl>(
      () => factory.createConnectionManager(config),
    );

    registerLazySingleton<BackgroundStateMonitor>(
      () => factory.createBackgroundMonitor(),
    );

    registerLazySingleton<ConfigFetcher>(
      () => factory.createConfigFetcher(get<HttpClient>(), config, user),
    );

    registerLazySingleton<SummaryManager>(
      () => factory.createSummaryManager(
        sessionId,
        get<HttpClient>(),
        user,
        config,
      ),
    );

    registerLazySingleton<EventTracker>(
      () => factory.createEventTracker(
        get<HttpClient>(),
        get<ConnectionManagerImpl>(),
        user,
        sessionId,
        config,
        get<SummaryManager>(),
      ),
    );

    // Register managers
    registerLazySingleton<ConfigManager>(
      () => factory.createConfigManager(
        config,
        get<ConfigFetcher>(),
        get<ConnectionManagerImpl>(),
        get<SummaryManager>(),
      ),
    );

    registerLazySingleton<UserManager>(() => factory.createUserManager(user));

    registerLazySingleton<EnvironmentManager>(
      () => factory.createEnvironmentManager(
        get<BackgroundStateMonitor>(),
        get<UserManager>(),
      ),
    );

    registerLazySingleton<ListenerManager>(
      () => factory.createListenerManager(),
    );
  }

  /// Shutdown all services
  Future<void> shutdown() async {
    if (!_initialized) {
      Logger.d('DependencyContainer: Not initialized, nothing to shutdown');
      return;
    }

    Logger.i('DependencyContainer: Shutting down');

    // Shutdown services that have shutdown methods
    final futures = <Future<void>>[];

    for (final service in _services.values) {
      try {
        if (service is EventTracker) {
          service.shutdown();
        } else if (service is SummaryManager) {
          service.shutdown();
        } else if (service is ConnectionManagerImpl) {
          service.shutdown();
        } else if (service is BackgroundStateMonitor) {
          service.shutdown();
        } else if (service is ConfigManager) {
          service.shutdown();
        } else if (service is EnvironmentManager) {
          service.shutdown();
        }
      } catch (e) {
        Logger.e(
          'DependencyContainer: Error shutting down service ${service.runtimeType}: $e',
        );
      }
    }

    // Wait for any async shutdowns
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    reset();
    _initialized = false;
    Logger.i('DependencyContainer: Shutdown complete');
  }

  /// Register a singleton instance
  void registerSingleton<T>(T instance) {
    _services[T] = instance;
  }

  /// Register a lazy singleton (created on first access)
  void registerLazySingleton<T>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Register an async singleton
  void registerAsyncSingleton<T>(Future<T> Function() factory) {
    _singletonFactories[T] = factory;
  }

  /// Get a registered service
  T get<T>() {
    // Check if already instantiated
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }

    // Check for lazy factory
    if (_factories.containsKey(T)) {
      final instance = _factories[T]!() as T;
      _services[T] = instance;
      _factories.remove(T);
      return instance;
    }

    throw StateError('Service $T not registered');
  }

  /// Get an async service
  Future<T> getAsync<T>() async {
    // Check if already instantiated
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }

    // Check if already initializing
    if (_initializingFutures.containsKey(T)) {
      try {
        return await _initializingFutures[T]!.future as T;
      } catch (e) {
        // If the initialization failed, clean up and allow retry
        _initializingFutures.remove(T);
        rethrow;
      }
    }

    // Check for async factory
    if (_singletonFactories.containsKey(T)) {
      final completer = Completer<T>();
      _initializingFutures[T] = completer;

      try {
        final instance = await _singletonFactories[T]!() as T;
        _services[T] = instance;
        _singletonFactories.remove(T);
        _initializingFutures.remove(T);
        completer.complete(instance);
        return instance;
      } catch (e) {
        // Remove failed service from both futures and factories to allow re-registration
        _initializingFutures.remove(T);
        _singletonFactories.remove(T);
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
        rethrow;
      }
    }

    throw StateError('Async service $T not registered');
  }

  /// Check if a service is registered
  bool isRegistered<T>() {
    return _services.containsKey(T) ||
        _factories.containsKey(T) ||
        _singletonFactories.containsKey(T);
  }

  /// Clear all registrations (for testing)
  void reset() {
    _services.clear();
    _factories.clear();
    _singletonFactories.clear();
    _initializingFutures.clear();
  }
}

// Extension for easier access
extension GetIt on DependencyContainer {
  static T get<T>() => DependencyContainer.instance.get<T>();
  static Future<T> getAsync<T>() => DependencyContainer.instance.getAsync<T>();
}
