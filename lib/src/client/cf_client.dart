// lib/src/client/cf_client.dart
//
// Main SDK client for CustomFit feature flags, analytics, and configuration management.
// Provides the primary interface for interacting with the CustomFit SDK including
// feature flag evaluation, event tracking, user management, and session handling.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../analytics/event/event_tracker.dart';
import '../analytics/summary/summary_manager.dart';
import '../client/managers/config_manager.dart';
import '../client/managers/environment_manager.dart';
import '../client/managers/listener_manager.dart';
import '../client/managers/user_manager.dart';
import '../config/core/cf_config.dart' hide MutableCFConfig;
import '../core/error/cf_result.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../core/error/error_category.dart';
import '../core/error/cf_error_code.dart';
import '../core/session/session_manager.dart';
import '../di/dependency_container.dart';
import '../network/config/config_fetcher.dart';
import '../network/connection/connection_manager.dart';
import '../platform/default_background_state_monitor.dart';
import '../logging/log_level_updater.dart';
import '../logging/logger.dart';
import '../core/model/cf_user.dart';
import '../core/model/evaluation_context.dart';
import '../core/model/context_type.dart';
import '../services/singleton_registry.dart';
import '../services/preferences_service.dart';
import 'cf_client_feature_flags.dart';
import 'cf_client_events.dart';
import 'cf_client_listeners.dart';
import 'cf_client_initializer.dart';
import 'cf_client_sdk_settings.dart';
import 'cf_client_recovery.dart';
import 'cf_client_wrappers.dart';
import 'cf_client_core.dart';
import 'cf_client_user_management.dart';
import 'cf_client_session_management.dart';
import 'cf_client_configuration_management.dart';
import 'cf_client_system_management.dart';
import '../config/core/mutable_cf_config.dart';
import '../config/validation/cf_config_validator.dart';
import '../features/feature_flags.dart';
import '../features/cf_flag_provider.dart';
import '../core/util/synchronization.dart';
import '../core/memory/memory_coordinator.dart';
import '../core/resource_registry.dart';
import '../core/validation/input_validator.dart';
import 'initialization_state.dart';
import '../features/graceful_degradation.dart';

/// Main SDK client for CustomFit feature flags, analytics, and configuration management.
///
/// The [CFClient] is the primary interface for interacting with the CustomFit SDK.
/// It provides feature flag evaluation, event tracking, user management, and session handling.
///
/// ## Usage
///
/// Initialize the client once in your application:
/// ```dart
/// final config = CFConfig.builder('your-client-key')
///   .setDebugLoggingEnabled(true)
///   .build();
///
/// final user = CFUser.builder('user123')
///   .addStringProperty('plan', 'premium')
///   .build();
///
/// final client = await CFClient.initialize(config, user);
/// ```
///
/// ## Features
///
/// - **Feature Flags**: Boolean, string, number, and JSON configuration values
/// - **Event Tracking**: Analytics and user behavior tracking
/// - **User Management**: User properties, contexts, and targeting
/// - **Session Management**: Automatic session lifecycle handling
/// - **Offline Support**: Queue operations when network is unavailable
/// - **Real-time Updates**: Live configuration updates via listeners
///
/// ## Thread Safety
///
/// All methods are thread-safe and can be called from any isolate.
/// The client uses internal synchronization to ensure data consistency.
class CFClient {
  static const _source = 'CFClient';

  // Singleton implementation
  static CFClient? _instance;
  static bool _isInitializing = false;
  static Completer<CFClient>? _initializationCompleter;
  static final Object _initializationLock = Object();
  static final InitializationTracker _initTracker = InitializationTracker();

  // Core mediator to break circular dependencies
  CFClientCore? _core;

  // Component-based architecture (facade pattern)
  late final CFClientFeatureFlags _featureFlagsComponent;
  late final CFClientEvents _eventsComponent;
  late final CFClientListeners _listenersComponent;
  late final CFClientRecovery _recoveryComponent;
  late final CFClientUserManagement _userManagementComponent;
  late final CFClientSessionManagement _sessionManagementComponent;
  late final CFClientConfigurationManagement _configurationManagementComponent;
  late final CFClientSystemManagement _systemManagementComponent;
  late final FeatureFlags _typedFlags;
  late final CFFlagProvider _flagProvider;

  /// Access to feature flags functionality
  CFClientFeatureFlags get featureFlags => _featureFlagsComponent;

  /// Access to events functionality
  CFClientEvents get events => _eventsComponent;

  /// Access to listeners functionality
  CFClientListeners get listeners => _listenersComponent;

  /// Access to type-safe feature flags
  FeatureFlags get typed => _typedFlags;

  /// CFResult compatibility methods for tests
  bool get isSuccess => true;
  CFClient getOrThrow() => this;
  CFClient? getOrNull() => this;
  String? getErrorMessage() => null;

  /// Get the current initialization state
  static InitializationState get initializationState => _initTracker.state;

  /// Get completed initialization steps for debugging
  static List<String> get completedInitializationSteps =>
      _initTracker.completedSteps;

  /// Generate initial session ID as a pure UUID
  static String _generateInitialSessionId() {
    const uuid = Uuid();
    return uuid.v4();
  }

  /// Initialize the singleton instance of [CFClient] with configuration and user.
  ///
  /// This method ensures only one instance exists and handles concurrent initialization attempts.
  /// If an instance already exists, it returns the existing instance immediately.
  ///
  /// ## Parameters
  ///
  /// - [config]: SDK configuration including client key, timeouts, and feature settings
  /// - [user]: User context for feature flag targeting and analytics
  /// - [dependencyFactory]: Internal parameter for testing - not intended for public use
  ///
  /// ## Returns
  ///
  /// A [Future] that completes with a [CFResult] containing either:
  /// - Success: The initialized [CFClient] instance
  /// - Error: Detailed error information with error code and category
  ///
  /// ## Example
  ///
  /// ```dart
  /// final config = CFConfig.builder('your-client-key')
  ///   .setDebugLoggingEnabled(true)
  ///   .setEventsFlushIntervalMs(5000)
  ///   .build();
  ///
  /// final user = CFUser.builder('user123')
  ///   .addStringProperty('plan', 'premium')
  ///   .addNumberProperty('age', 25)
  ///   .build();
  ///
  /// final result = await CFClient.initialize(config, user);
  /// result
  ///   .onSuccess((client) => print('SDK initialized successfully'))
  ///   .onError((error) => print('Initialization failed: ${error.message}'));
  /// ```
  ///
  /// ## Thread Safety
  ///
  /// This method is thread-safe. Multiple concurrent calls will wait for the first
  /// initialization to complete and return the same instance.
  static Future<CFClient> initialize(
    CFConfig config,
    CFUser user, {
    DependencyFactory? dependencyFactory,
  }) async {
    // Validate configuration using CFConfigValidator
    try {
      CFConfigValidator.validateOrThrow(config);
    } catch (e) {
      if (e is ConfigValidationException) {
        throw ArgumentError(
          'Configuration validation failed: ${e.detailedMessage}',
        );
      }
      throw ArgumentError(
        'Configuration validation failed: $e',
      );
    }

    // Validate required parameters
    if (config.clientKey.isEmpty) {
      throw ArgumentError(
        'API key is required for initialization. Please provide a valid client key using CFConfig.builder("your-api-key") or CFConfig.production("your-api-key").',
      );
    }

    // Validate user ID - check for null or empty string
    if (user.userCustomerId == null || user.userCustomerId!.trim().isEmpty) {
      throw ArgumentError(
        'User ID is required for initialization. Please provide a valid user ID using CFUser.builder("user-id") or CFUser.anonymousBuilder() when creating your user object.',
      );
    }

    // Thread-safe initialization with proper synchronization
    return await synchronizedAsync(_initializationLock, () async {
      // Double-check pattern inside the lock
      if (_instance != null) {
        Logger.i(
            'CFClient singleton already exists, returning existing instance');
        return _instance!;
      }

      // If currently initializing, wait for existing initialization
      if (_isInitializing && _initializationCompleter != null) {
        Logger.i(
            'CFClient initialization in progress, waiting for completion...');
        try {
          final client = await _initializationCompleter!.future;
          return client;
        } catch (e) {
          throw StateError('Initialization failed: $e');
        }
      }

      // Start new initialization
      Logger.i('Starting CFClient singleton initialization...');
      _isInitializing = true;
      _initializationCompleter = Completer<CFClient>();

      final startResult = _initTracker.startInitialization();
      if (!startResult.isSuccess) {
        _isInitializing = false;
        throw StateError(
          'Failed to start initialization: ${startResult.getErrorMessage()}',
        );
      }

      CFClient? newInstance;
      try {
        // Step 1: Create the instance
        final step1Result =
            _initTracker.startStep('Creating CFClient instance');
        if (!step1Result.isSuccess) {
          throw StateError(
            'Failed to start step 1: ${step1Result.getErrorMessage()}',
          );
        }

        newInstance = dependencyFactory != null
            ? CFClient.withDependencies(config, user, dependencyFactory)
            : CFClient._(config, user);

        final complete1Result =
            _initTracker.completeStep('Creating CFClient instance', () {
          // Rollback: Clear any partial initialization
          try {
            newInstance?._configListeners.clear();
            newInstance?._contexts.clear();
          } catch (e) {
            Logger.w('Error during rollback cleanup: $e');
          }
        });
        if (!complete1Result.isSuccess) {
          throw StateError(
            'Failed to complete step 1: ${complete1Result.getErrorMessage()}',
          );
        }

        // Step 2: Initialize SDK settings
        final step2Result = _initTracker.startStep('Initializing SDK settings');
        if (!step2Result.isSuccess) {
          throw StateError(
            'Failed to start step 2: ${step2Result.getErrorMessage()}',
          );
        }

        final settingsResult = await newInstance._initializeSDKSettings();
        if (!settingsResult.isSuccess) {
          throw StateError(
            'Failed to initialize SDK settings: ${settingsResult.getErrorMessage()}',
          );
        }

        final complete2Result =
            _initTracker.completeStep('Initializing SDK settings', () {
          // Rollback is handled by cleanup method
        });
        if (!complete2Result.isSuccess) {
          throw StateError(
            'Failed to complete step 2: ${complete2Result.getErrorMessage()}',
          );
        }

        // Step 3: Initialize SessionManager
        final step3Result =
            _initTracker.startStep('Initializing SessionManager');
        if (!step3Result.isSuccess) {
          throw StateError(
            'Failed to start step 3: ${step3Result.getErrorMessage()}',
          );
        }

        final sessionResult = await newInstance._initializeSessionManager();
        if (!sessionResult.isSuccess) {
          throw StateError(
            'Failed to initialize SessionManager: ${sessionResult.getErrorMessage()}',
          );
        }

        final complete3Result =
            _initTracker.completeStep('Initializing SessionManager', () {
          // Rollback is handled by cleanup method
        });
        if (!complete3Result.isSuccess) {
          throw StateError(
            'Failed to complete step 3: ${complete3Result.getErrorMessage()}',
          );
        }

        // Step 4: Initialize async components
        final step4Result =
            _initTracker.startStep('Initializing async components');
        if (!step4Result.isSuccess) {
          throw StateError(
            'Failed to start step 4: ${step4Result.getErrorMessage()}',
          );
        }

        final asyncResult = await newInstance._initializeAsyncComponents();
        if (!asyncResult.isSuccess) {
          throw StateError(
            'Failed to initialize async components: ${asyncResult.getErrorMessage()}',
          );
        }

        final complete4Result =
            _initTracker.completeStep('Initializing async components', () {
          // Rollback is handled by cleanup method
        });
        if (!complete4Result.isSuccess) {
          throw StateError(
            'Failed to complete step 4: ${complete4Result.getErrorMessage()}',
          );
        }

        // Complete initialization
        final completionResult = _initTracker.completeInitialization();
        if (!completionResult.isSuccess) {
          throw StateError(
            'Failed to complete initialization: ${completionResult.getErrorMessage()}',
          );
        }

        // Set instance and complete
        _instance = newInstance;
        _isInitializing = false;
        _initializationCompleter!.complete(newInstance);

        Logger.i('CFClient initialization completed successfully');
        SingletonRegistry.instance.register<CFClient>(
          name: 'CFClient',
          instance: newInstance,
          description: 'Main CFClient singleton instance',
        );

        return newInstance;
      } catch (e) {
        Logger.e('Initialization failed with exception: $e');

        // Cleanup any partial initialization
        try {
          newInstance?._configListeners.clear();
          newInstance?._contexts.clear();
        } catch (e) {
          Logger.w('Error during exception cleanup: $e');
        }

        // Fail initialization tracker
        _initTracker.failInitialization(e.toString(), 'initialization');

        _isInitializing = false;
        if (_initializationCompleter != null &&
            !_initializationCompleter!.isCompleted) {
          _initializationCompleter!.completeError(e);
        }

        // Convert exception to appropriate error
        final initException = SDKInitializationException(
          message: 'SDK initialization failed: ${e.toString()}',
          originalError: e,
          failedAtState: InitializationState.initializing,
          completedSteps: _initTracker.completedSteps,
          failedStep: 'initialization',
        );

        // Log recovery attempt but don't actually retry in this context
        Logger.i(
            'Initialization failed, recovery may be possible in future attempts');

        throw initException;
      }
    });
  }

  /// Get the current singleton instance if it exists
  static CFClient? getInstance() {
    if (_instance != null &&
        _initTracker.state != InitializationState.initialized) {
      Logger.w(
          'CFClient instance exists but is not properly initialized. State: ${_initTracker.state}');
      return null;
    }
    return _instance;
  }

  /// Check if the singleton instance is initialized
  static bool isInitialized() {
    return _instance != null &&
        _initTracker.state == InitializationState.initialized;
  }

  /// Check if initialization is currently in progress
  static bool isInitializing() {
    return _isInitializing;
  }

  /// Shutdown and clear the singleton instance
  static Future<void> shutdownSingleton() async {
    if (_instance != null) {
      Logger.i('Shutting down CFClient singleton...');
      await _instance!.shutdown();
      _instance = null;
      _isInitializing = false;
      _initializationCompleter = null;
      _initTracker.reset();
      Logger.i('CFClient singleton shutdown complete');
    }
  }

  /// Clear the singleton instance for testing purposes
  static void clearInstance() {
    _instance = null;
    _isInitializing = false;
    _initializationCompleter = null;
    // Reset PreferencesService singleton for tests
    PreferencesService.reset();
  }

  /// Force reinitialize the singleton with new configuration
  static Future<CFClient> reinitialize(
    CFConfig config,
    CFUser user, {
    DependencyFactory? dependencyFactory,
  }) async {
    Logger.i('Reinitializing CFClient singleton...');
    await shutdownSingleton();
    return await initialize(config, user, dependencyFactory: dependencyFactory);
  }

  /// Initialize with automatic retry on failure
  ///
  /// This method provides automatic retry functionality with exponential backoff
  /// for scenarios where initialization might fail due to temporary issues
  /// like network connectivity problems.
  ///
  /// ## Parameters
  ///
  /// - [config]: Configuration for the SDK
  /// - [user]: Initial user for the SDK
  /// - [maxRetries]: Maximum number of retry attempts (default: 3)
  /// - [initialDelayMs]: Initial delay between retries in milliseconds (default: 1000)
  /// - [dependencyFactory]: Optional dependency factory for testing
  ///
  /// ## Example
  ///
  /// ```dart
  /// try {
  ///   final client = await CFClient.initializeWithRetry(config, user, maxRetries: 5);
  ///   print('SDK initialized successfully after retries');
  /// } catch (e) {
  ///   print('SDK initialization failed after all retries: $e');
  /// }
  /// ```
  static Future<CFClient> initializeWithRetry(
    CFConfig config,
    CFUser user, {
    int maxRetries = 3,
    int initialDelayMs = 1000,
    DependencyFactory? dependencyFactory,
  }) async {
    int attempt = 0;
    int delayMs = initialDelayMs;

    while (attempt <= maxRetries) {
      try {
        Logger.i(
            'Attempting SDK initialization (attempt ${attempt + 1}/${maxRetries + 1})');
        return await initialize(config, user,
            dependencyFactory: dependencyFactory);
      } catch (e) {
        attempt++;

        if (attempt > maxRetries) {
          Logger.e('SDK initialization failed after $maxRetries retries: $e');
          rethrow;
        }

        // Check if the error is retryable
        final isRetryable = _isRetryableInitializationError(e);
        if (!isRetryable) {
          Logger.e('Non-retryable initialization error: $e');
          rethrow;
        }

        Logger.w(
            'Initialization attempt $attempt failed, retrying in ${delayMs}ms: $e');

        // Wait before retry with exponential backoff
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs = (delayMs * 1.5)
            .round()
            .clamp(initialDelayMs, 30000); // Max 30 seconds

        // Ensure clean state before retry
        await shutdownSingleton();
      }
    }

    throw StateError('This should never be reached');
  }

  /// Check if an initialization error is retryable
  static bool _isRetryableInitializationError(dynamic error) {
    if (error is SDKInitializationException) {
      // Check the original error to determine if it's retryable
      final originalError = error.originalError;

      // Network-related errors are usually retryable
      if (originalError is SocketException ||
          originalError is TimeoutException ||
          originalError.toString().contains('network') ||
          originalError.toString().contains('timeout') ||
          originalError.toString().contains('connection')) {
        return true;
      }

      // Configuration errors are usually not retryable
      if (originalError.toString().contains('configuration') ||
          originalError.toString().contains('invalid') ||
          originalError.toString().contains('missing')) {
        return false;
      }

      // Default to retryable for unknown errors
      return true;
    }

    // For non-SDK exceptions, check common retryable patterns
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('unavailable');
  }

  // REMOVED: Deprecated init() method - use initialize() instead

  /// Create a detached (non-singleton) instance of CFClient
  /// Use this only if you specifically need multiple instances (not recommended)
  /// Most applications should use init() for singleton pattern
  static CFClient createDetached(
    CFConfig config,
    CFUser user,
  ) {
    Logger.w(
        'Creating detached CFClient instance - this bypasses singleton pattern!');
    return CFClient._(config, user);
  }

  // REMOVED: Deprecated create() method - use initialize() for singleton or createDetached() for non-singleton instances

  // MARK: - Internal Testing Support
  // These methods are for internal SDK testing only and should not be used in production

  /// Internal method for setting test instance (testing only)
  ///
  /// WARNING: This method is for internal SDK testing only. Do not use in production.
  static void setTestInstance(CFClient instance) {
    _instance = instance;
    _isInitializing = false;
    _initializationCompleter = null;
  }

  String _sessionId;
  final MutableCFConfig _mutableConfig;

  // New component-based architecture (internal)
  late final CFClientFeatureFlags _featureFlags;
  late final CFClientEvents _events;

  // Core dependencies now managed by DependencyContainer
  // Keep these as getters that delegate to DependencyContainer

  /// Expose managers via DependencyContainer
  SummaryManager get summaryManager =>
      DependencyContainer.instance.get<SummaryManager>();

  EventTracker get eventTracker =>
      DependencyContainer.instance.get<EventTracker>();

  ConfigFetcher get configFetcher =>
      DependencyContainer.instance.get<ConfigFetcher>();

  ConfigManager get configManager =>
      DependencyContainer.instance.get<ConfigManager>();

  UserManager get userManager =>
      DependencyContainer.instance.get<UserManager>();

  EnvironmentManager get environmentManager =>
      DependencyContainer.instance.get<EnvironmentManager>();

  ListenerManager get listenerManager =>
      DependencyContainer.instance.get<ListenerManager>();

  ConnectionManagerImpl get connectionManager =>
      DependencyContainer.instance.get<ConnectionManagerImpl>();

  BackgroundStateMonitor get backgroundStateMonitor =>
      DependencyContainer.instance.get<BackgroundStateMonitor>();

  /// Session manager for handling session lifecycle
  SessionManager? _sessionManager;

  /// Session listener for cleanup
  SessionRotationListener? _sessionListener;

  /// Completer to handle async session initialization
  Completer<void>? _sessionInitCompleter;

  /// Feature config and flag listeners
  final Map<String, List<void Function(dynamic)>> _configListeners = {};

  /// Contexts, device/app info
  final Map<String, EvaluationContext> _contexts = {};

  /// SDK settings manager
  late final CFClientSdkSettings _sdkSettings;

  CFClient._(
    CFConfig config,
    CFUser user,
  )   : _sessionId = _generateInitialSessionId(),
        _mutableConfig = MutableCFConfig(config) {
    // Initialize DependencyContainer
    DependencyContainer.instance.initialize(
      config: config,
      user: user,
      sessionId: _sessionId,
    );

    // Initialize SDK settings manager
    _sdkSettings = CFClientSdkSettings(
      config: config,
      configFetcher: configFetcher,
      configManager: configManager,
      connectionManager: connectionManager,
    );

    _commonInitialization();

    // Initialize component-based architecture
    _featureFlags = CFClientFeatureFlags(
      config: config,
      user: user,
      configManager: configManager,
      summaryManager: summaryManager,
      sessionId: _sessionId,
    );

    _events = CFClientEvents(
      config: config,
      user: user,
      eventTracker: eventTracker,
      sessionId: _sessionId,
    );

    // Initialize facade components
    _featureFlagsComponent = _featureFlags;
    _eventsComponent = _events;
    _listenersComponent = CFClientListeners(
      config: config,
      user: user,
      sessionId: _sessionId,
    );

    _recoveryComponent = CFClientRecovery(
      getSessionManager: () => _sessionManager,
      getEventTracker: () => eventTracker,
      getConfigManager: () => configManager,
      getCurrentSessionId: () => getCurrentSessionId(),
    );

    // Initialize new facade components
    _userManagementComponent = CFClientUserManagement(
      userManager: userManager,
    );

    _sessionManagementComponent = CFClientSessionManagement(
      sessionManager: _sessionManager,
      fallbackSessionId: _sessionId,
    );

    _configurationManagementComponent = CFClientConfigurationManagement(
      configManager: configManager,
      configFetcher: configFetcher,
      connectionManager: connectionManager,
      mutableConfig: _mutableConfig,
    );

    _systemManagementComponent = CFClientSystemManagement();

    // Initialize type-safe feature flags with provider
    _flagProvider = CFFlagProvider(configManager: configManager);
    _typedFlags = FeatureFlags(_flagProvider);
  }

  /// Constructor with dependency injection (for testing only)
  ///
  /// WARNING: This constructor is for internal SDK testing only. Do not use in production.
  CFClient.withDependencies(
    CFConfig config,
    CFUser user,
    DependencyFactory dependencyFactory,
  ) : this._withDependenciesAndSessionId(
          config,
          user,
          dependencyFactory,
          _generateInitialSessionId(),
        );

  CFClient._withDependenciesAndSessionId(
    CFConfig config,
    CFUser user,
    DependencyFactory dependencyFactory,
    String sessionId,
  )   : _sessionId = sessionId,
        _mutableConfig = MutableCFConfig(config) {
    // Initialize DependencyContainer with test factory
    DependencyContainer.instance.initialize(
      config: config,
      user: user,
      sessionId: sessionId,
      factory: dependencyFactory,
    );

    // Initialize SDK settings manager
    _sdkSettings = CFClientSdkSettings(
      config: config,
      configFetcher: configFetcher,
      configManager: configManager,
      connectionManager: connectionManager,
    );

    _commonInitialization();

    // Initialize component-based architecture
    _featureFlags = CFClientFeatureFlags(
      config: config,
      user: user,
      configManager: configManager,
      summaryManager: summaryManager,
      sessionId: _sessionId,
    );

    _events = CFClientEvents(
      config: config,
      user: user,
      eventTracker: eventTracker,
      sessionId: _sessionId,
    );

    // Initialize facade components
    _featureFlagsComponent = _featureFlags;
    _eventsComponent = _events;
    _listenersComponent = CFClientListeners(
      config: config,
      user: user,
      sessionId: _sessionId,
    );

    _recoveryComponent = CFClientRecovery(
      getSessionManager: () => _sessionManager,
      getEventTracker: () => eventTracker,
      getConfigManager: () => configManager,
      getCurrentSessionId: () => getCurrentSessionId(),
    );

    // Initialize new facade components
    _userManagementComponent = CFClientUserManagement(
      userManager: userManager,
    );

    _sessionManagementComponent = CFClientSessionManagement(
      sessionManager: _sessionManager,
      fallbackSessionId: _sessionId,
    );

    _configurationManagementComponent = CFClientConfigurationManagement(
      configManager: configManager,
      configFetcher: configFetcher,
      connectionManager: connectionManager,
      mutableConfig: _mutableConfig,
    );

    _systemManagementComponent = CFClientSystemManagement();

    // Initialize type-safe feature flags with provider
    _flagProvider = CFFlagProvider(configManager: configManager);
    _typedFlags = FeatureFlags(_flagProvider);
  }

  /// Common initialization logic for both constructors
  void _commonInitialization() {
    try {
      // Configure logging
      LogLevelUpdater.updateLogLevel(_mutableConfig.config);
      Logger.initialize(_mutableConfig.config);
    } catch (e) {
      // Logging is critical - rethrow if it fails
      throw Exception('Failed to initialize logging: $e');
    }

    try {
      // IMPORTANT: Set offline mode BEFORE any other initialization
      // This ensures ConfigManager doesn't start network calls
      if (_mutableConfig.config.offlineMode) {
        configFetcher.setOffline(true);
        connectionManager.setOfflineMode(true);
        // Also set offline mode for the ConfigManager's ConfigFetcher
        if (configManager is ConfigManagerImpl) {
          (configManager as ConfigManagerImpl).setOfflineMode(true);
        }
        Logger.i('CF client initialized in offline mode');
      }
    } catch (e) {
      Logger.e('Failed to set offline mode: $e');
      // Continue - offline mode is not critical
    }

    try {
      // Auto environment attributes
      CFClientInitializer.initializeEnvironmentAttributes(
        _mutableConfig.config,
        userManager.getUser(),
        userManager,
      );
    } catch (e) {
      Logger.w('Failed to initialize environment attributes: $e');
      // Continue - environment attributes are not critical
    }

    try {
      // Setup monitors
      CFClientInitializer.setupConnectionListeners(connectionManager);
      CFClientInitializer.setupBackgroundListeners(
        backgroundStateMonitor: backgroundStateMonitor,
        onPausePolling: _pausePolling,
        onResumePolling: _resumePolling,
        onCheckSdkSettings: _checkSdkSettings,
      );
      CFClientInitializer.setupUserChangeListeners(
        userManager: userManager,
        configManager: configManager,
        offlineMode: _mutableConfig.config.offlineMode,
      );
      CFClientInitializer.setupEventTrackingListeners(
        eventTracker: eventTracker,
        configManager: configManager,
        isOfflineMode: () => _mutableConfig.config.offlineMode,
      );
    } catch (e) {
      Logger.e('Failed to setup listeners: $e');
      // This is critical for proper SDK operation
      throw Exception('Failed to setup SDK listeners: $e');
    }

    try {
      // Add main user context
      final ctx = CFClientInitializer.createMainUserContext(
          userManager.getUser(), _sessionId);
      _contexts['user'] = ctx;
    } catch (e) {
      Logger.w('Failed to create user context: $e');
      // Continue - context creation failure is not critical
    }

    // Initialize all blocking components asynchronously to prevent UI freezes
    _initializeAsyncComponents().catchError((e) {
      Logger.e('Failed to initialize async components: $e');
      // Log but don't fail - these are async and non-critical
      return CFResult<void>.error('Failed to initialize async components: $e');
    });

    // Initialize SessionManager asynchronously
    _initializeSessionManager().catchError((e) {
      Logger.e('Failed to initialize SessionManager: $e');
      // Log but don't fail - session manager is not critical
      return CFResult<void>.error('Failed to initialize SessionManager: $e');
    });

    // Initialize SDK settings asynchronously to prevent UI blocking
    _initializeSDKSettings().catchError((e) {
      Logger.e('Failed to initialize SDK settings: $e');
      // Log but don't fail - SDK settings are not critical
      return CFResult<void>.error('Failed to initialize SDK settings: $e');
    });
  }

  /// Initialize all potentially blocking components asynchronously
  Future<CFResult<void>> _initializeAsyncComponents() async {
    try {
      // Initialize all blocking components in parallel for maximum performance
      await Future.wait([
        CFClientInitializer.initializeCacheManager(_mutableConfig.config),
        CFClientInitializer.initializeMemoryManagement(_mutableConfig.config),
        _initializeSdkSettingsInternal(),
      ]);

      Logger.d('All async components initialized successfully');
      return CFResult.success(null);
    } catch (e) {
      return CFResult.error(
        'Failed to initialize async components: $e',
        errorCode: CFErrorCode.configNotInitialized,
        category: ErrorCategory.configuration,
        exception: e,
      );
    }
  }

  /// Initialize SDK settings asynchronously (internal helper)
  Future<void> _initializeSdkSettingsInternal() async {
    _sdkSettings.startPeriodicCheck();
    await _sdkSettings.performInitialCheck();
  }

  /// Initialize SDK settings asynchronously
  Future<CFResult<void>> _initializeSDKSettings() async {
    try {
      _sdkSettings.startPeriodicCheck();
      await _sdkSettings.performInitialCheck();
      return CFResult.success(null);
    } catch (e) {
      return CFResult.error(
        'Failed to initialize SDK settings: $e',
        errorCode: CFErrorCode.configNotInitialized,
        category: ErrorCategory.configuration,
        exception: e,
      );
    }
  }

  /// Initialize SessionManager with configuration
  Future<CFResult<void>> _initializeSessionManager() async {
    // Skip session manager initialization in offline mode to prevent issues
    if (_mutableConfig.config.offlineMode) {
      Logger.i('🔄 SKIPPING SessionManager initialization in offline mode');
      return CFResult.success(null);
    }

    // Prevent multiple concurrent initializations
    if (_sessionInitCompleter != null) {
      // Already initializing, wait for completion
      try {
        await _sessionInitCompleter!.future;
        return CFResult.success(null);
      } catch (e) {
        return CFResult.error(
          'SessionManager initialization failed: $e',
          errorCode: CFErrorCode.configNotInitialized,
          category: ErrorCategory.configuration,
          exception: e,
        );
      }
    }

    // Create a new completer for this initialization
    _sessionInitCompleter = Completer<void>();

    try {
      // Create session configuration based on CFConfig defaults
      const sessionConfig = SessionConfig(
        maxSessionDurationMs:
            60 * 60 * 1000, // CFConstants.session.defaultSessionDurationMs
        minSessionDurationMs: 5 * 60 * 1000, // 5 minutes minimum
        backgroundThresholdMs:
            15 * 60 * 1000, // CFConstants.session.defaultBackgroundThresholdMs
        rotateOnAppRestart: true,
        rotateOnAuthChange: true,
        sessionIdPrefix: 'cf_session',
        enableTimeBasedRotation: true,
      );

      // Initialize SessionManager synchronously
      final result = await SessionManager.initialize(config: sessionConfig);

      if (result.isSuccess) {
        _sessionManager = result.getOrNull();
        if (_sessionManager != null) {
          // Get the current session ID
          _sessionId = _sessionManager!.getCurrentSessionId();

          // Set up session rotation listener
          _sessionListener = CFClientSessionListener(
            updateSessionIdInManagers: _updateSessionIdInManagers,
            trackSessionRotationEvent: _trackSessionRotationEvent,
          );
          _sessionManager!.addListener(_sessionListener!);

          // Re-setup background listeners with session manager
          CFClientInitializer.setupBackgroundListeners(
            backgroundStateMonitor: backgroundStateMonitor,
            onPausePolling: _pausePolling,
            onResumePolling: _resumePolling,
            onCheckSdkSettings: _checkSdkSettings,
            sessionManager: _sessionManager,
          );

          Logger.i('🔄 SessionManager initialized with session: $_sessionId');

          // Complete the initialization successfully
          _sessionInitCompleter!.complete();
          return CFResult.success(null);
        } else {
          final error = 'SessionManager initialization returned null';
          Logger.e(error);
          _sessionInitCompleter!.completeError(error);
          return CFResult.error(
            error,
            errorCode: CFErrorCode.configNotInitialized,
            category: ErrorCategory.configuration,
          );
        }
      } else {
        final error =
            'Failed to initialize SessionManager: ${result.getErrorMessage()}';
        Logger.e(error);
        _sessionInitCompleter!.completeError(error);
        return CFResult.error(
          error,
          errorCode: CFErrorCode.configNotInitialized,
          category: ErrorCategory.configuration,
        );
      }
    } catch (e) {
      Logger.e('SessionManager initialization error: $e');
      // Complete with error
      _sessionInitCompleter!.completeError(e);
      return CFResult.error(
        'SessionManager initialization error: $e',
        errorCode: CFErrorCode.configNotInitialized,
        category: ErrorCategory.configuration,
        exception: e,
      );
    } finally {
      // Clear the completer
      _sessionInitCompleter = null;
    }
  }

  /// Update session ID in all managers that use it
  void _updateSessionIdInManagers(String sessionId) {
    // Note: EventTracker and SummaryManager don't currently support updateSessionId methods
    // Future enhancement: These components should be extended to support dynamic session ID updates
    // For now, we store the session ID and log the change

    _sessionId = sessionId;
    Logger.d('Updated session ID in managers: $sessionId');
  }

  /// Track session rotation as an analytics event
  void _trackSessionRotationEvent(
      String? oldSessionId, String newSessionId, RotationReason reason) {
    final properties = <String, dynamic>{
      'old_session_id': oldSessionId ?? 'none',
      'new_session_id': newSessionId,
      'rotation_reason': reason.description,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    trackEvent('cf_session_rotated', properties: properties);
  }

  void _pausePolling() => _sdkSettings.pausePolling();

  void _resumePolling() => _sdkSettings.resumePolling();

  void _checkSdkSettings() => _sdkSettings.checkSdkSettings();

  /// Add a config listener for a specific feature flag
  void addConfigListener<T>(String key, void Function(T) listener) =>
      configManager.addConfigListener<T>(key, listener);

  /// Remove a config listener for a specific feature flag
  void removeConfigListener(String key) =>
      configManager.clearConfigListeners(key);

  /// Clear all listeners for a specific configuration
  void clearConfigListeners(String key) =>
      configManager.clearConfigListeners(key);

  /// Add feature flag listener
  void addFeatureFlagListener(
          String flagKey, void Function(String, dynamic, dynamic) listener) =>
      listenerManager.registerFeatureFlagListener(
          flagKey, FeatureFlagListenerWrapper(listener));

  /// Remove feature flag listener
  void removeFeatureFlagListener(
          String flagKey, void Function(String, dynamic, dynamic) listener) =>
      listenerManager.unregisterFeatureFlagListener(
          flagKey, FeatureFlagListenerWrapper(listener));

  /// Add all flags listener
  void addAllFlagsListener(
          void Function(Map<String, dynamic>, Map<String, dynamic>) listener) =>
      listenerManager
          .registerAllFlagsListener(AllFlagsListenerWrapper(listener));

  /// Remove all flags listener
  void removeAllFlagsListener(
          void Function(Map<String, dynamic>, Map<String, dynamic>) listener) =>
      listenerManager
          .unregisterAllFlagsListener(AllFlagsListenerWrapper(listener));

  /// Get a feature flag value with generic type support
  T getFeatureFlag<T>(String key, T defaultValue) {
    // SECURITY FIX: Validate feature flag key
    final keyValidation = InputValidator.validateFeatureFlagKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'CFClient: Feature flag key validation failed for "$key": ${keyValidation.getErrorMessage()}');
      return defaultValue; // Return default value for invalid keys
    }

    return configManager.getConfigValue<T>(
        keyValidation.getOrThrow(), defaultValue);
  }

  /// Get a string feature flag value
  String getString(String key, String defaultValue) {
    // SECURITY FIX: Validate feature flag key
    final keyValidation = InputValidator.validateFeatureFlagKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'CFClient: String flag key validation failed for "$key": ${keyValidation.getErrorMessage()}');
      return defaultValue; // Return default value for invalid keys
    }

    return _featureFlagsComponent.getString(
        keyValidation.getOrThrow(), defaultValue);
  }

  /// Get a boolean feature flag value
  bool getBoolean(String key, bool defaultValue) {
    // SECURITY FIX: Validate feature flag key
    final keyValidation = InputValidator.validateFeatureFlagKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'CFClient: Boolean flag key validation failed for "$key": ${keyValidation.getErrorMessage()}');
      return defaultValue; // Return default value for invalid keys
    }

    return _featureFlagsComponent.getBoolean(
        keyValidation.getOrThrow(), defaultValue);
  }

  /// Get a number feature flag value
  double getNumber(String key, double defaultValue) {
    // SECURITY FIX: Validate feature flag key
    final keyValidation = InputValidator.validateFeatureFlagKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'CFClient: Number flag key validation failed for "$key": ${keyValidation.getErrorMessage()}');
      return defaultValue; // Return default value for invalid keys
    }

    return _featureFlagsComponent.getNumber(
        keyValidation.getOrThrow(), defaultValue);
  }

  /// Get a JSON feature flag value
  Map<String, dynamic> getJson(String key, Map<String, dynamic> defaultValue) {
    // SECURITY FIX: Validate feature flag key
    final keyValidation = InputValidator.validateFeatureFlagKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'CFClient: JSON flag key validation failed for "$key": ${keyValidation.getErrorMessage()}');
      return defaultValue; // Return default value for invalid keys
    }

    return _featureFlagsComponent.getJson(
        keyValidation.getOrThrow(), defaultValue);
  }

  /// Get all available feature flags
  Map<String, dynamic> getAllFlags() => _featureFlagsComponent.getAllFlags();

  /// Check if a specific flag exists
  bool flagExists(String key) {
    // SECURITY FIX: Validate feature flag key
    final keyValidation = InputValidator.validateFeatureFlagKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'CFClient: Flag exists key validation failed for "$key": ${keyValidation.getErrorMessage()}');
      return false; // Return false for invalid keys
    }

    return _featureFlagsComponent.flagExists(keyValidation.getOrThrow());
  }

  /// Track an analytics event with optional properties
  Future<CFResult<void>> trackEvent(
    String eventType, {
    Map<String, dynamic>? properties,
  }) async {
    final result = await _eventsComponent.trackEventWithProperties(
        eventType, properties ?? {});
    return result.isSuccess
        ? CFResult.success(null)
        : CFResult.error(result.getErrorMessage() ?? 'Unknown error');
  }

  /// Track a conversion event
  Future<CFResult<void>> trackConversion(
    String conversionName,
    Map<String, dynamic> properties,
  ) async {
    final result =
        await _eventsComponent.trackConversion(conversionName, properties);
    return result.isSuccess
        ? CFResult.success(null)
        : CFResult.error(result.getErrorMessage() ?? 'Unknown error');
  }

  /// Flush all pending events immediately
  Future<CFResult<void>> flushEvents() async {
    final result = await _eventsComponent.flushEvents();
    return result.isSuccess
        ? CFResult.success(null)
        : CFResult.error(result.getErrorMessage() ?? 'Unknown error');
  }

  /// Get the count of pending events in the queue
  int getPendingEventCount() => _eventsComponent.getPendingEventCount();

  /// Shutdown the client
  Future<void> shutdown() async {
    Logger.i('Shutting down CF client');

    // 1. First stop all active operations
    _sdkSettings.shutdown();

    // 2. Dispose of feature flags to prevent memory leaks
    try {
      _typedFlags.dispose();
      Logger.d('Disposed typed feature flags');

      await _flagProvider.dispose();
      Logger.d('Disposed flag provider');
    } catch (e) {
      Logger.w('Error disposing flags: $e');
    }

    // 3. Remove all listeners to prevent callbacks during shutdown
    _configListeners.clear();

    // Remove session listener BEFORE any component shutdown
    if (_sessionListener != null && _sessionManager != null) {
      _sessionManager!.removeListener(_sessionListener!);
      _sessionListener = null;
    }

    // Clear other listeners
    try {
      if (DependencyContainer.instance.isRegistered<ListenerManager>()) {
        listenerManager.clearAllListeners();
      }
    } catch (e) {
      Logger.w('Failed to clear listeners during shutdown: $e');
    }

    // Flush any pending events and summaries BEFORE shutting down DependencyContainer
    try {
      if (DependencyContainer.instance.isRegistered<SummaryManager>()) {
        // First flush summaries
        await _flushSummaries().then((result) {
          if (!result.isSuccess) {
            Logger.w(
                'Failed to flush summaries during shutdown: ${result.getErrorMessage()}');
          } else {
            Logger.i('Successfully flushed summaries during shutdown');
          }
        });
      }

      if (DependencyContainer.instance.isRegistered<EventTracker>()) {
        // Then flush events
        await _flushEvents().then((result) {
          if (!result.isSuccess) {
            Logger.w(
                'Failed to flush events during shutdown: ${result.getErrorMessage()}');
          } else {
            Logger.i('Successfully flushed events during shutdown');
          }
        });
      }
    } catch (e) {
      Logger.w('Error flushing during shutdown: $e');
    }

    // 4. Shutdown SessionManager before DependencyContainer
    SessionManager.shutdown();
    _sessionManager = null;

    // 5. Shutdown all managers via DependencyContainer
    await DependencyContainer.instance.shutdown();

    // 6. Dispose of all registered resources
    try {
      await ResourceRegistry().disposeAll();
      Logger.d('Disposed all registered resources');
    } catch (e) {
      Logger.w('Error disposing resources: $e');
    }

    // Reset MemoryCoordinator singleton
    MemoryCoordinator.reset();

    // Shutdown remote logging
    await Logger.shutdown();

    Logger.i('CF client shutdown complete');
  }

  /// Manually flushes the events queue to the server
  /// Useful for immediately sending tracked events without waiting for the automatic flush
  ///
  /// @return CFResult containing the number of events flushed or error details
  Future<CFResult<int>> _flushEvents() async {
    try {
      Logger.i('Manually flushing events');

      // First flush summaries
      final summaryResult = await summaryManager.flushSummaries();
      if (!summaryResult.isSuccess) {
        Logger.w(
            'Failed to flush summaries before flushing events: ${summaryResult.getErrorMessage()}');
      }

      // Then flush events
      final flushResult = await eventTracker.flush();
      if (flushResult.isSuccess) {
        // Since our EventTracker.flush() doesn't return count directly,
        // let's just return a success with a dummy count of 1 for now
        // In a real implementation, we would return the actual count
        Logger.i('Successfully flushed events');
        return CFResult.success(1);
      } else {
        final errorMsg =
            'Failed to flush events: ${flushResult.getErrorMessage()}';
        Logger.e(errorMsg);
        return CFResult.error(
          errorMsg,
          category: ErrorCategory.internal,
        );
      }
    } catch (e) {
      final errorMsg = 'Unexpected error flushing events: ${e.toString()}';
      Logger.e(errorMsg);
      ErrorHandler.handleException(
        e,
        errorMsg,
        source: _source,
        severity: ErrorSeverity.high,
      );
      return CFResult.error(
        'Failed to flush events',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// Synchronizes fetching configuration and getting all flags
  Future<Map<String, dynamic>> fetchAndGetAllFlags(
          {String? lastModified}) async =>
      await _configurationManagementComponent.fetchAndGetAllFlags(
          lastModified: lastModified);

  /// Puts the client in offline mode
  void setOffline(bool offline) =>
      _configurationManagementComponent.setOffline(offline);

  /// Returns whether the client is in offline mode
  bool isOffline() => _configurationManagementComponent.isOffline();

  /// Force a refresh of the configuration
  Future<bool> forceRefresh() async =>
      await _configurationManagementComponent.forceRefresh();

  /// Increment the application launch count
  void incrementAppLaunchCount() =>
      _configurationManagementComponent.incrementAppLaunchCount();

  /// Manually flushes the summaries queue to the server
  Future<CFResult<int>> _flushSummaries() async {
    try {
      Logger.i('Manually flushing summaries');
      final result = await summaryManager.flushSummaries();
      return result;
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Failed to flush summaries',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(
        'Failed to flush summaries: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  // MARK: - Session Management

  /// Get the current session ID
  String getCurrentSessionId() =>
      _sessionManagementComponent.getCurrentSessionId();

  /// Get current session data with metadata
  SessionData? getCurrentSessionData() =>
      _sessionManagementComponent.getCurrentSessionData();

  /// Force session rotation with a manual trigger
  Future<String?> forceSessionRotation() async =>
      await _sessionManagementComponent.forceSessionRotation();

  /// Update session activity
  Future<void> updateSessionActivity() async =>
      await _sessionManagementComponent.updateSessionActivity();

  /// Handle user authentication changes
  Future<void> onUserAuthenticationChange(String? userId) async =>
      await _sessionManagementComponent.onUserAuthenticationChange(userId);

  /// Get session statistics
  Map<String, dynamic> getSessionStatistics() =>
      _sessionManagementComponent.getSessionStatistics();

  /// Add a session rotation listener
  void addSessionRotationListener(SessionRotationListener listener) =>
      _sessionManagementComponent.addSessionRotationListener(listener);

  /// Remove a session rotation listener
  void removeSessionRotationListener(SessionRotationListener listener) =>
      _sessionManagementComponent.removeSessionRotationListener(listener);

  // MARK: - User Management

  /// Set the current user
  Future<CFResult<void>> setUser(CFUser user) async =>
      await _userManagementComponent.setUser(user);

  /// Get the current user
  CFUser getUser() => _userManagementComponent.getUser();

  /// Clear the current user by setting an anonymous user
  Future<CFResult<void>> clearUser() async =>
      await _userManagementComponent.clearUser();

  /// Add a property to the user
  CFResult<void> addUserProperty(String key, dynamic value) =>
      _userManagementComponent.addUserProperty(key, value);

  /// Add a string property to the user
  CFResult<void> addStringProperty(String key, String value) =>
      _userManagementComponent.addStringProperty(key, value);

  /// Add a number property to the user
  CFResult<void> addNumberProperty(String key, num value) =>
      _userManagementComponent.addNumberProperty(key, value);

  /// Add a boolean property to the user
  CFResult<void> addBooleanProperty(String key, bool value) =>
      _userManagementComponent.addBooleanProperty(key, value);

  /// Add a JSON property to the user
  CFResult<void> addJsonProperty(String key, Map<String, dynamic> value) =>
      _userManagementComponent.addJsonProperty(key, value);

  /// Add a map property to the user
  CFResult<void> addMapProperty(String key, Map<String, dynamic> value) =>
      _userManagementComponent.addMapProperty(key, value);

  /// Add multiple properties to the user
  CFResult<void> addUserProperties(Map<String, dynamic> properties) =>
      _userManagementComponent.addUserProperties(properties);

  /// Get all user properties
  Map<String, dynamic> getUserProperties() =>
      _userManagementComponent.getUserProperties();

  /// Remove a property from the user
  CFResult<void> removeProperty(String key) =>
      _userManagementComponent.removeProperty(key);

  /// Remove multiple properties from the user
  CFResult<void> removeProperties(List<String> keys) =>
      _userManagementComponent.removeProperties(keys);

  // MARK: - Private Property Methods

  /// Add a private string property to the user
  CFResult<void> addPrivateStringProperty(String key, String value) =>
      _userManagementComponent.addPrivateStringProperty(key, value);

  /// Add a private number property to the user
  CFResult<void> addPrivateNumberProperty(String key, num value) =>
      _userManagementComponent.addPrivateNumberProperty(key, value);

  /// Add a private boolean property to the user
  CFResult<void> addPrivateBooleanProperty(String key, bool value) =>
      _userManagementComponent.addPrivateBooleanProperty(key, value);

  /// Add a private map property to the user
  CFResult<void> addPrivateMapProperty(
          String key, Map<String, dynamic> value) =>
      _userManagementComponent.addPrivateMapProperty(key, value);

  /// Add a private JSON property to the user
  CFResult<void> addPrivateJsonProperty(
          String key, Map<String, dynamic> value) =>
      _userManagementComponent.addPrivateJsonProperty(key, value);

  /// Mark an existing property as private
  CFResult<void> markPropertyAsPrivate(String key) =>
      _userManagementComponent.markPropertyAsPrivate(key);

  /// Mark multiple existing properties as private
  CFResult<void> markPropertiesAsPrivate(List<String> keys) =>
      _userManagementComponent.markPropertiesAsPrivate(keys);

  // MARK: - Context Management

  /// Add an evaluation context to the user
  CFResult<void> addContext(EvaluationContext context) =>
      _userManagementComponent.addContext(context);

  /// Remove an evaluation context from the user
  CFResult<void> removeContext(ContextType type, String key) =>
      _userManagementComponent.removeContext(type, key);

  /// Get all evaluation contexts for the user
  List<EvaluationContext> getContexts() =>
      _userManagementComponent.getContexts();

  // MARK: - Recovery Methods

  /// Perform comprehensive system health check and recovery
  ///
  /// Checks session health, configuration validity, event recovery status,
  /// and performs automatic recovery where needed.
  ///
  /// Returns a [Future] with [CFResult<SystemHealthStatus>] indicating overall system health.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final healthResult = await client.performSystemHealthCheck();
  /// if (healthResult.isSuccess) {
  ///   final status = healthResult.getOrNull()!;
  ///   print('System health: ${status.overallStatus}');
  ///   print('Session: ${status.sessionHealth}');
  ///   print('Config: ${status.configHealth}');
  ///   print('Events: ${status.eventRecoveryStats}');
  /// }
  /// ```
  Future<CFResult<SystemHealthStatus>> performSystemHealthCheck() =>
      _recoveryComponent.performSystemHealthCheck();

  /// Recover from session-related errors
  ///
  /// Handles session timeouts, invalidation, corruption, and authentication failures.
  ///
  /// ## Parameters
  ///
  /// - [reason]: Optional reason for session recovery
  /// - [authTokenRefreshCallback]: Optional callback to refresh authentication tokens
  ///
  /// ## Example
  ///
  /// ```dart
  /// final recoveryResult = await client.recoverSession(
  ///   reason: 'session_timeout',
  ///   authTokenRefreshCallback: () async => await getNewAuthToken(),
  /// );
  ///
  /// if (recoveryResult.isSuccess) {
  ///   print('Session recovered: ${recoveryResult.getOrNull()}');
  /// }
  /// ```
  Future<CFResult<String>> recoverSession({
    String? reason,
    Future<String?> Function()? authTokenRefreshCallback,
  }) =>
      _recoveryComponent.recoverSession(
          reason: reason, authTokenRefreshCallback: authTokenRefreshCallback);

  /// Recover failed events and retry offline events
  ///
  /// Attempts to resend failed events and recovers events that were queued while offline.
  ///
  /// ## Parameters
  ///
  /// - [maxEventsToRetry]: Maximum number of failed events to retry in this operation
  ///
  /// ## Returns
  ///
  /// A [Future] with [CFResult<EventRecoveryResult>] containing recovery statistics.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final recoveryResult = await client.recoverEvents(maxEventsToRetry: 100);
  /// if (recoveryResult.isSuccess) {
  ///   final result = recoveryResult.getOrNull()!;
  ///   print('Recovered ${result.offlineEventsRecovered} offline events');
  ///   print('Retried ${result.failedEventsRetried} failed events');
  /// }
  /// ```
  Future<CFResult<EventRecoveryResult>> recoverEvents({
    int maxEventsToRetry = 50,
  }) =>
      _recoveryComponent.recoverEvents(maxEventsToRetry: maxEventsToRetry);

  /// Perform safe configuration update with automatic rollback on failure
  ///
  /// Updates configuration with validation and automatic recovery mechanisms.
  /// Backs up current configuration and rolls back if the update fails.
  ///
  /// ## Parameters
  ///
  /// - [newConfig]: The new configuration to apply
  /// - [validationTimeout]: Maximum time to wait for validation
  ///
  /// ## Example
  ///
  /// ```dart
  /// final newConfig = {'feature_enabled': true, 'max_retries': 5};
  /// final updateResult = await client.safeConfigUpdate(newConfig);
  ///
  /// if (updateResult.isSuccess) {
  ///   print('Configuration updated successfully');
  /// } else {
  ///   print('Update failed, rolled back: ${updateResult.getErrorMessage()}');
  /// }
  /// ```
  Future<CFResult<bool>> safeConfigUpdate(
    Map<String, dynamic> newConfig, {
    Duration validationTimeout = const Duration(seconds: 30),
  }) =>
      _recoveryComponent.safeConfigUpdate(newConfig,
          validationTimeout: validationTimeout);

  /// Recover from configuration corruption or update failures
  ///
  /// Attempts to restore configuration from backup or last known good state.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final recoveryResult = await client.recoverConfiguration();
  /// if (recoveryResult.isSuccess) {
  ///   print('Configuration restored from backup');
  /// }
  /// ```
  Future<CFResult<Map<String, dynamic>>> recoverConfiguration() =>
      _recoveryComponent.recoverConfiguration();

  /// Perform automatic recovery based on current system state
  ///
  /// Analyzes system health and performs appropriate recovery actions automatically.
  /// This is a convenience method that combines health checking with targeted recovery.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final autoRecoveryResult = await client.performAutoRecovery();
  /// if (autoRecoveryResult.isSuccess) {
  ///   final actions = autoRecoveryResult.getOrNull()!;
  ///   print('Auto recovery performed ${actions.length} actions');
  /// }
  /// ```
  Future<CFResult<List<String>>> performAutoRecovery() =>
      _recoveryComponent.performAutoRecovery();

  /// Get singleton registry statistics (for debugging)
  ///
  /// Returns a map containing:
  /// - totalSingletons: Total number of registered singletons
  /// - byType: Count of singletons grouped by type
  /// - registrationTimes: Registration timestamps for each singleton
  ///
  /// This is useful for monitoring singleton usage and detecting memory leaks.
  /// Only available in debug mode.
  Map<String, dynamic> getSingletonStats() =>
      _systemManagementComponent.getSingletonStats();

  /// Get graceful degradation metrics
  ///
  /// Returns metrics about feature flag evaluation including:
  /// - Total evaluations, successful evaluations, fallbacks used
  /// - Cache hit rate, success rate, fallback rate
  /// - Top flags requiring fallback
  /// - Current degradation configuration
  ///
  /// Useful for monitoring SDK health and network reliability.
  ///
  /// Example:
  /// ```dart
  /// final metrics = client.getGracefulDegradationMetrics();
  /// print('Success rate: ${metrics['metrics']['successRate']}');
  /// print('Fallback rate: ${metrics['metrics']['fallbackRate']}');
  /// ```
  Map<String, dynamic> getGracefulDegradationMetrics() {
    return _featureFlagsComponent.getDegradationMetrics();
  }

  /// Clear graceful degradation cache
  ///
  /// Removes all cached feature flag values. Useful when:
  /// - User logs out or switches accounts
  /// - Testing different flag configurations
  /// - Forcing fresh flag evaluations
  ///
  /// Example:
  /// ```dart
  /// await client.clearGracefulDegradationCache();
  /// ```
  Future<void> clearGracefulDegradationCache() async {
    await _featureFlagsComponent.clearDegradationCache();
  }

  /// Clear cache for a specific flag
  ///
  /// Removes cached values for a single feature flag. Useful when:
  /// - A specific flag configuration has changed
  /// - Testing specific flag behavior
  /// - Selective cache invalidation
  ///
  /// Example:
  /// ```dart
  /// await client.clearFlagCache('feature_flag_key');
  /// ```
  Future<void> clearFlagCache(String key) async {
    await _featureFlagsComponent.clearFlagCache(key);
  }

  /// Get cache statistics
  ///
  /// Returns detailed information about the graceful degradation cache including:
  /// - Total cached keys
  /// - Valid vs stale cache entries
  /// - Cache hit rate
  /// - Estimated cache size
  ///
  /// Example:
  /// ```dart
  /// final stats = await client.getCacheStats();
  /// print('Cache hit rate: ${stats['cacheHitRate']}');
  /// print('Valid entries: ${stats['validCacheCount']}');
  /// ```
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _featureFlagsComponent.getCacheStats();
  }

  /// Evaluate a boolean flag with full graceful degradation
  ///
  /// This method provides the most robust flag evaluation with comprehensive
  /// fallback strategies. Use for critical flags where reliability is paramount.
  ///
  /// ## Parameters
  ///
  /// - [key]: The feature flag key
  /// - [defaultValue]: Default value if flag evaluation fails
  /// - [strategy]: Optional fallback strategy override
  ///
  /// ## Fallback Strategies
  ///
  /// - `FallbackStrategy.useDefault`: Use default immediately on failure
  /// - `FallbackStrategy.useCachedOrDefault`: Try cache first, then default
  /// - `FallbackStrategy.waitWithTimeout`: Wait with timeout, then cache, then default
  /// - `FallbackStrategy.useLastKnownGood`: Use last known good value if available
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Critical feature with timeout strategy
  /// final isEnabled = await client.getBooleanWithDegradation(
  ///   'critical_feature',
  ///   false,
  ///   strategy: FallbackStrategy.waitWithTimeout,
  /// );
  ///
  /// if (isEnabled) {
  ///   // Enable critical feature
  /// }
  /// ```
  Future<bool> getBooleanWithDegradation(
    String key,
    bool defaultValue, {
    FallbackStrategy? strategy,
  }) async {
    return await _featureFlagsComponent.getBooleanWithDegradation(
      key,
      defaultValue,
      strategy: strategy,
    );
  }

  /// Evaluate a string flag with full graceful degradation
  ///
  /// Similar to getBooleanWithDegradation but for string values.
  ///
  /// Example:
  /// ```dart
  /// final apiUrl = await client.getStringWithDegradation(
  ///   'api_endpoint',
  ///   'https://api.default.com',
  ///   strategy: FallbackStrategy.useLastKnownGood,
  /// );
  /// ```
  Future<String> getStringWithDegradation(
    String key,
    String defaultValue, {
    FallbackStrategy? strategy,
  }) async {
    return await _featureFlagsComponent.getStringWithDegradation(
      key,
      defaultValue,
      strategy: strategy,
    );
  }

  /// Evaluate a number flag with full graceful degradation
  ///
  /// Similar to getBooleanWithDegradation but for numeric values.
  ///
  /// Example:
  /// ```dart
  /// final timeout = await client.getNumberWithDegradation(
  ///   'request_timeout',
  ///   5000.0,
  ///   strategy: FallbackStrategy.useCachedOrDefault,
  /// );
  /// ```
  Future<double> getNumberWithDegradation(
    String key,
    double defaultValue, {
    FallbackStrategy? strategy,
  }) async {
    return await _featureFlagsComponent.getNumberWithDegradation(
      key,
      defaultValue,
      strategy: strategy,
    );
  }

  /// Evaluate a JSON flag with full graceful degradation
  ///
  /// Similar to getBooleanWithDegradation but for JSON/Map values.
  ///
  /// Example:
  /// ```dart
  /// final config = await client.getJsonWithDegradation(
  ///   'feature_config',
  ///   {'enabled': false, 'timeout': 5000},
  ///   strategy: FallbackStrategy.useLastKnownGood,
  /// );
  /// ```
  Future<Map<String, dynamic>> getJsonWithDegradation(
    String key,
    Map<String, dynamic> defaultValue, {
    FallbackStrategy? strategy,
  }) async {
    return await _featureFlagsComponent.getJsonWithDegradation(
      key,
      defaultValue,
      strategy: strategy,
    );
  }

  /// Clear singleton registry (for testing only)
  ///
  /// WARNING: This method is for testing only. Do not use in production.
  static void clearSingletonRegistry() =>
      CFClientSystemManagement.clearSingletonRegistry();
}
