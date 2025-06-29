// lib/src/client/cf_client_core.dart
//
// Core initialization and management logic for CustomFit SDK.
// Handles dependency injection, lifecycle management, and acts as a mediator
// to break circular dependencies between CFClient and its managers.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'package:uuid/uuid.dart';
import '../config/core/cf_config.dart';
import '../di/dependency_container.dart';
import '../logging/logger.dart';
import '../core/model/cf_user.dart';
import '../core/util/synchronization.dart';

/// Core initialization states for better race condition handling
enum CoreInitializationState {
  uninitialized,
  initializing,
  initialized,
  failed,
  shuttingDown,
  shutdown
}

/// Exception thrown during core initialization failures
class CoreInitializationException implements Exception {
  final String message;
  final dynamic originalError;
  final CoreInitializationState failedAtState;
  final List<String> completedSteps;
  final String? failedStep;

  CoreInitializationException({
    required this.message,
    required this.originalError,
    required this.failedAtState,
    required this.completedSteps,
    this.failedStep,
  });

  @override
  String toString() {
    return 'CoreInitializationException: $message\n'
        'Failed at state: $failedAtState\n'
        'Failed step: ${failedStep ?? "Unknown"}\n'
        'Completed steps: ${completedSteps.join(", ")}\n'
        'Original error: $originalError';
  }
}

/// Core mediator class that breaks circular dependencies
/// Acts as a central coordinator for all SDK components without direct coupling
class CFClientCore {
  // Singleton pattern with improved race condition handling
  static CFClientCore? _instance;
  static CoreInitializationState _state = CoreInitializationState.uninitialized;
  static final Object _initializationLock = Object();
  static Completer<CFClientCore>? _initializationCompleter;
  static final List<String> _completedSteps = [];
  static String? _currentStep;

  // Core dependencies - accessed via interfaces to break circular dependencies
  late final String _sessionId;
  late final MutableCFConfig _mutableConfig;
  late final CFUser _initialUser;

  // Component registry - managers register themselves here
  final Map<Type, dynamic> _componentRegistry = {};
  final Map<String, StreamController<dynamic>> _eventBus = {};

  // Private constructor
  CFClientCore._({
    required CFConfig config,
    required CFUser user,
    required String sessionId,
  })  : _sessionId = sessionId,
        _mutableConfig = MutableCFConfig(config),
        _initialUser = user;

  /// Initialize the core with thread-safe singleton pattern
  static Future<CFClientCore> initialize({
    required CFConfig config,
    required CFUser user,
    DependencyFactory? dependencyFactory,
  }) async {
    // Validate required parameters first
    if (config.clientKey.isEmpty) {
      throw CoreInitializationException(
        message: 'API key is required for initialization',
        originalError: ArgumentError('Empty client key'),
        failedAtState: CoreInitializationState.uninitialized,
        completedSteps: [],
        failedStep: 'Parameter validation',
      );
    }

    if (user.userCustomerId == null || user.userCustomerId!.isEmpty) {
      throw CoreInitializationException(
        message: 'User ID is required for initialization',
        originalError: ArgumentError('Empty user ID'),
        failedAtState: CoreInitializationState.uninitialized,
        completedSteps: [],
        failedStep: 'Parameter validation',
      );
    }

    // Thread-safe initialization with proper synchronization
    return await synchronizedAsync(_initializationLock, () async {
      // Double-check pattern inside the lock
      if (_instance != null && _state == CoreInitializationState.initialized) {
        Logger.i(
            'CFClientCore already initialized, returning existing instance');
        return _instance!;
      }

      // If currently initializing, wait for existing initialization
      if (_state == CoreInitializationState.initializing &&
          _initializationCompleter != null) {
        Logger.i(
            'CFClientCore initialization in progress, waiting for completion...');
        return _initializationCompleter!.future;
      }

      // If in a failed state, reset before retrying
      if (_state == CoreInitializationState.failed) {
        Logger.i('CFClientCore in failed state, resetting for retry...');
        await _reset();
      }

      // Start new initialization
      Logger.i('Starting CFClientCore initialization...');
      _state = CoreInitializationState.initializing;
      _initializationCompleter = Completer<CFClientCore>();
      _completedSteps.clear();
      _currentStep = null;

      CFClientCore? newInstance;
      try {
        // Step 1: Create the core instance
        _currentStep = 'Creating CFClientCore instance';
        _completedSteps.add(_currentStep!);

        final sessionId = const Uuid().v4();
        newInstance = CFClientCore._(
          config: config,
          user: user,
          sessionId: sessionId,
        );

        // Step 2: Initialize DependencyContainer
        _currentStep = 'Initializing DependencyContainer';
        _completedSteps.add(_currentStep!);

        DependencyContainer.instance.initialize(
          config: config,
          user: user,
          sessionId: sessionId,
          factory: dependencyFactory,
        );

        // Step 3: Register core as a component in its own registry
        _currentStep = 'Registering core components';
        _completedSteps.add(_currentStep!);

        newInstance._registerCoreComponents();

        // Step 4: Initialize event bus for decoupled communication
        _currentStep = 'Initializing event bus';
        _completedSteps.add(_currentStep!);

        newInstance._initializeEventBus();

        // All steps completed successfully
        _instance = newInstance;
        _state = CoreInitializationState.initialized;
        _currentStep = null;

        Logger.i('CFClientCore initialization completed successfully');
        _initializationCompleter!.complete(newInstance);
        _initializationCompleter = null;
        return newInstance;
      } catch (e) {
        _state = CoreInitializationState.failed;

        // Perform cleanup
        if (newInstance != null) {
          try {
            await newInstance._cleanup();
          } catch (cleanupError) {
            Logger.e('Error during initialization cleanup: $cleanupError');
          }
        }

        final coreException = CoreInitializationException(
          message: 'Failed to initialize CFClientCore: $e',
          originalError: e,
          failedAtState: _state,
          completedSteps: List.from(_completedSteps),
          failedStep: _currentStep,
        );

        Logger.e('CFClientCore initialization failed: $coreException');
        if (_initializationCompleter != null &&
            !_initializationCompleter!.isCompleted) {
          _initializationCompleter!.completeError(coreException);
        }
        _initializationCompleter = null;
        throw coreException;
      }
    });
  }

  /// Get the current instance (null if not initialized)
  static CFClientCore? getInstance() {
    if (_state != CoreInitializationState.initialized) {
      return null;
    }
    return _instance;
  }

  /// Check if core is initialized
  static bool isInitialized() {
    return _instance != null && _state == CoreInitializationState.initialized;
  }

  /// Check if initialization is in progress
  static bool isInitializing() {
    return _state == CoreInitializationState.initializing;
  }

  /// Get current state
  static CoreInitializationState getState() {
    return _state;
  }

  /// Shutdown the core and clean up resources
  static Future<void> shutdown() async {
    return await synchronizedAsync(_initializationLock, () async {
      if (_instance == null) {
        Logger.d('CFClientCore not initialized, nothing to shutdown');
        return;
      }

      Logger.i('Shutting down CFClientCore...');
      _state = CoreInitializationState.shuttingDown;

      try {
        await _instance!._cleanup();
        await DependencyContainer.instance.shutdown();
      } catch (e) {
        Logger.e('Error during CFClientCore shutdown: $e');
      } finally {
        await _reset();
        _state = CoreInitializationState.shutdown;
        Logger.i('CFClientCore shutdown complete');
      }
    });
  }

  /// Reset all static state (for testing)
  static Future<void> _reset() async {
    _instance = null;
    _state = CoreInitializationState.uninitialized;
    _initializationCompleter = null;
    _completedSteps.clear();
    _currentStep = null;
  }

  /// Register core components in the registry
  void _registerCoreComponents() {
    // Register self for other components to access core functionality
    _componentRegistry[CFClientCore] = this;

    // Register configuration access
    _componentRegistry[CFConfig] = _mutableConfig.config;
    _componentRegistry[CFUser] = _initialUser;

    Logger.d('CFClientCore: Registered core components');
  }

  /// Initialize event bus for decoupled communication
  void _initializeEventBus() {
    // Create event streams for common events
    final eventTypes = [
      'config_changed',
      'user_updated',
      'session_rotated',
      'flag_evaluated',
      'event_tracked',
      'connection_status_changed',
    ];

    for (final eventType in eventTypes) {
      _eventBus[eventType] = StreamController<dynamic>.broadcast();
    }

    Logger.d(
        'CFClientCore: Initialized event bus with ${eventTypes.length} event types');
  }

  /// Register a component in the registry
  void registerComponent<T>(T component) {
    _componentRegistry[T] = component;
    Logger.d('CFClientCore: Registered component ${T.toString()}');
  }

  /// Get a registered component
  T? getComponent<T>() {
    return _componentRegistry[T] as T?;
  }

  /// Check if a component is registered
  bool hasComponent<T>() {
    return _componentRegistry.containsKey(T);
  }

  /// Publish an event to the event bus
  void publishEvent(String eventType, dynamic data) {
    final controller = _eventBus[eventType];
    if (controller != null && !controller.isClosed) {
      controller.add(data);
      Logger.d('CFClientCore: Published event $eventType');
    }
  }

  /// Subscribe to events from the event bus
  Stream<dynamic>? subscribeToEvent(String eventType) {
    final controller = _eventBus[eventType];
    return controller?.stream;
  }

  /// Get session ID
  String get sessionId => _sessionId;

  /// Get current configuration
  CFConfig get config => _mutableConfig.config;

  /// Get current user
  CFUser get user => _initialUser;

  /// Get dependency container instance
  DependencyContainer get dependencies => DependencyContainer.instance;

  /// Cleanup resources
  Future<void> _cleanup() async {
    Logger.d('CFClientCore: Cleaning up resources...');

    // Close all event bus controllers
    final futures = <Future<void>>[];
    for (final controller in _eventBus.values) {
      if (!controller.isClosed) {
        futures.add(controller.close());
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    _eventBus.clear();
    _componentRegistry.clear();

    Logger.d('CFClientCore: Cleanup complete');
  }
}
