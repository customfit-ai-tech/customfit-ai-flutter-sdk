// lib/src/client/cf_client_initialization_manager.dart
//
// Initialization manager for CFClient that handles race conditions and provides
// proper synchronization. This fixes the race condition issue identified in the
// code review by implementing a robust state machine for initialization.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import '../config/core/cf_config.dart';
import '../core/model/cf_user.dart';
import '../core/util/synchronization.dart';
import '../logging/logger.dart';
import '../di/dependency_container.dart';

/// Initialization states for CFClient
enum InitializationState {
  uninitialized,
  validating,
  initializing,
  initialized,
  failed,
  shuttingDown,
  shutdown
}

/// Initialization step tracking
class InitializationStep {
  final String name;
  final DateTime startTime;
  DateTime? endTime;
  bool completed = false;
  String? error;

  InitializationStep(this.name) : startTime = DateTime.now();

  void complete() {
    completed = true;
    endTime = DateTime.now();
  }

  void fail(String errorMessage) {
    error = errorMessage;
    endTime = DateTime.now();
  }

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
}

/// Exception thrown during initialization failures
class InitializationException implements Exception {
  final String message;
  final dynamic originalError;
  final InitializationState failedAtState;
  final List<InitializationStep> completedSteps;
  final InitializationStep? failedStep;

  InitializationException({
    required this.message,
    required this.originalError,
    required this.failedAtState,
    required this.completedSteps,
    this.failedStep,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('InitializationException: $message');
    buffer.writeln('Failed at state: $failedAtState');
    buffer.writeln('Original error: $originalError');

    if (failedStep != null) {
      buffer.writeln(
          'Failed step: ${failedStep!.name} (${failedStep!.duration.inMilliseconds}ms)');
    }

    if (completedSteps.isNotEmpty) {
      buffer.writeln('Completed steps:');
      for (final step in completedSteps) {
        buffer.writeln('  - ${step.name}: ${step.duration.inMilliseconds}ms');
      }
    }

    return buffer.toString();
  }
}

/// Initialization manager that handles race conditions and provides proper synchronization
class CFClientInitializationManager {
  static CFClientInitializationManager? _instance;
  static final Object _lock = Object();

  // Initialization state tracking
  InitializationState _state = InitializationState.uninitialized;
  final List<InitializationStep> _completedSteps = [];
  InitializationStep? _currentStep;

  // Synchronization primitives
  Completer<dynamic>? _initializationCompleter;
  final Map<String, Completer<dynamic>> _stepCompleters = {};

  // Initialization context
  CFConfig? _config;
  CFUser? _user;
  DependencyFactory? _dependencyFactory;

  // Retry configuration
  int _maxRetries = 3;
  int _currentRetry = 0;
  Duration _retryDelay = const Duration(milliseconds: 1000);

  CFClientInitializationManager._();

  /// Get the singleton instance
  static CFClientInitializationManager get instance {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= CFClientInitializationManager._();
      });
    }
    return _instance!;
  }

  /// Get current initialization state
  InitializationState get state => _state;

  /// Check if initialization is in progress
  bool get isInitializing => _state == InitializationState.initializing;

  /// Check if initialization is complete
  bool get isInitialized => _state == InitializationState.initialized;

  /// Check if initialization has failed
  bool get hasFailed => _state == InitializationState.failed;

  /// Get initialization progress information
  Map<String, dynamic> getProgress() {
    return {
      'state': _state.toString(),
      'currentStep': _currentStep?.name,
      'completedSteps': _completedSteps.map((s) => s.name).toList(),
      'totalSteps': _completedSteps.length + (_currentStep != null ? 1 : 0),
      'currentRetry': _currentRetry,
      'maxRetries': _maxRetries,
    };
  }

  /// Initialize with comprehensive race condition handling
  Future<T> initialize<T>({
    required CFConfig config,
    required CFUser user,
    required Future<T> Function() initializationFunction,
    DependencyFactory? dependencyFactory,
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 1000),
  }) async {
    return await synchronizedAsync(_lock, () async {
      // Store configuration for potential retries
      _config = config;
      _user = user;
      _dependencyFactory = dependencyFactory;
      _maxRetries = maxRetries;
      _retryDelay = retryDelay;

      // Handle different states
      switch (_state) {
        case InitializationState.initialized:
          Logger.i('CFClient already initialized, returning existing result');
          return _initializationCompleter!.future as Future<T>;

        case InitializationState.initializing:
          Logger.i(
              'CFClient initialization in progress, waiting for completion...');
          return _initializationCompleter!.future as Future<T>;

        case InitializationState.failed:
          Logger.i('CFClient in failed state, attempting retry...');
          await _reset();
          break;

        case InitializationState.shuttingDown:
          throw InitializationException(
            message: 'Cannot initialize while shutting down',
            originalError: StateError('Shutdown in progress'),
            failedAtState: _state,
            completedSteps: [],
          );

        case InitializationState.shutdown:
          Logger.i('CFClient was shutdown, resetting for initialization...');
          await _reset();
          break;

        case InitializationState.uninitialized:
        case InitializationState.validating:
          // Continue with initialization
          break;
      }

      return await _performInitialization(initializationFunction);
    });
  }

  /// Perform the actual initialization with retry logic
  Future<T> _performInitialization<T>(
      Future<T> Function() initializationFunction) async {
    _currentRetry = 0;

    while (_currentRetry <= _maxRetries) {
      try {
        Logger.i(
            'Starting CFClient initialization (attempt ${_currentRetry + 1}/${_maxRetries + 1})');

        _state = InitializationState.validating;
        _initializationCompleter = Completer<T>();
        _completedSteps.clear();
        _currentStep = null;

        // Step 1: Validate parameters
        await _executeStep('Parameter validation', () async {
          await _validateParameters();
        });

        // Step 2: Initialize dependencies
        await _executeStep('Dependency initialization', () async {
          DependencyContainer.instance.initialize(
            config: _config!,
            user: _user!,
            sessionId: _generateSessionId(),
            factory: _dependencyFactory,
          );
        });

        // Step 3: Execute main initialization
        _state = InitializationState.initializing;
        final result = await _executeStep('Main initialization', () async {
          return await initializationFunction();
        });

        // Step 4: Finalization
        await _executeStep('Finalization', () async {
          _state = InitializationState.initialized;
        });

        Logger.i('CFClient initialization completed successfully');
        _initializationCompleter!.complete(result);
        return result;
      } catch (e) {
        _currentRetry++;

        if (_currentRetry > _maxRetries) {
          // All retries exhausted
          _state = InitializationState.failed;

          final exception = InitializationException(
            message:
                'CFClient initialization failed after $_maxRetries retries',
            originalError: e,
            failedAtState: _state,
            completedSteps: List.from(_completedSteps),
            failedStep: _currentStep,
          );

          Logger.e('CFClient initialization failed: $exception');
          if (_initializationCompleter != null &&
              !_initializationCompleter!.isCompleted) {
            _initializationCompleter!.completeError(exception);
          }
          throw exception;
        }

        // Check if error is retryable
        if (!_isRetryableError(e)) {
          _state = InitializationState.failed;

          final exception = InitializationException(
            message: 'CFClient initialization failed with non-retryable error',
            originalError: e,
            failedAtState: _state,
            completedSteps: List.from(_completedSteps),
            failedStep: _currentStep,
          );

          Logger.e('CFClient initialization failed: $exception');
          if (_initializationCompleter != null &&
              !_initializationCompleter!.isCompleted) {
            _initializationCompleter!.completeError(exception);
          }
          throw exception;
        }

        Logger.w(
            'Initialization attempt $_currentRetry failed, retrying in ${_retryDelay.inMilliseconds}ms: $e');

        // Wait before retry
        await Future.delayed(_retryDelay);

        // Exponential backoff with jitter
        _retryDelay = Duration(
            milliseconds: (_retryDelay.inMilliseconds * 1.5).round() +
                (DateTime.now().millisecondsSinceEpoch % 100));

        // Reset for retry
        await _resetForRetry();
      }
    }

    throw StateError('This should never be reached');
  }

  /// Execute an initialization step with proper error handling
  Future<T> _executeStep<T>(
      String stepName, Future<T> Function() stepFunction) async {
    _currentStep = InitializationStep(stepName);

    try {
      Logger.d('CFClient initialization: Starting step "$stepName"');
      final result = await stepFunction();

      _currentStep!.complete();
      _completedSteps.add(_currentStep!);
      _currentStep = null;

      Logger.d(
          'CFClient initialization: Completed step "$stepName" in ${_completedSteps.last.duration.inMilliseconds}ms');
      return result;
    } catch (e) {
      _currentStep!.fail(e.toString());
      Logger.e('CFClient initialization: Step "$stepName" failed: $e');
      rethrow;
    }
  }

  /// Validate initialization parameters
  Future<void> _validateParameters() async {
    if (_config == null) {
      throw ArgumentError('CFConfig is required');
    }

    if (_config!.clientKey.isEmpty) {
      throw ArgumentError('Client key is required');
    }

    if (_user == null) {
      throw ArgumentError('CFUser is required');
    }

    if (_user!.userCustomerId == null || _user!.userCustomerId!.isEmpty) {
      throw ArgumentError('User ID is required');
    }
  }

  /// Check if an error is retryable
  bool _isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network-related errors are usually retryable
    if (errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('unavailable') ||
        errorString.contains('socket')) {
      return true;
    }

    // Configuration errors are usually not retryable
    if (errorString.contains('argument') ||
        errorString.contains('invalid') ||
        errorString.contains('missing') ||
        errorString.contains('configuration')) {
      return false;
    }

    // Default to retryable for unknown errors
    return true;
  }

  /// Generate a session ID
  String _generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch % 10000}';
  }

  /// Reset for retry
  Future<void> _resetForRetry() async {
    _state = InitializationState.uninitialized;
    _completedSteps.clear();
    _currentStep = null;

    // Shutdown DependencyContainer if it was initialized
    try {
      await DependencyContainer.instance.shutdown();
    } catch (e) {
      Logger.w('Error shutting down DependencyContainer for retry: $e');
    }
  }

  /// Full reset
  Future<void> _reset() async {
    _state = InitializationState.uninitialized;
    _completedSteps.clear();
    _currentStep = null;
    _initializationCompleter = null;
    _stepCompleters.clear();
    _currentRetry = 0;
    _retryDelay = const Duration(milliseconds: 1000);
  }

  /// Shutdown the initialization manager
  Future<void> shutdown() async {
    return await synchronizedAsync(_lock, () async {
      if (_state == InitializationState.shutdown) {
        return;
      }

      Logger.i('CFClientInitializationManager: Shutting down...');
      _state = InitializationState.shuttingDown;

      // Complete any pending initialization with error
      if (_initializationCompleter != null &&
          !_initializationCompleter!.isCompleted) {
        _initializationCompleter!.completeError(InitializationException(
          message: 'Initialization cancelled due to shutdown',
          originalError: StateError('Shutdown requested'),
          failedAtState: _state,
          completedSteps: List.from(_completedSteps),
          failedStep: _currentStep,
        ));
      }

      await _reset();
      _state = InitializationState.shutdown;

      Logger.i('CFClientInitializationManager: Shutdown complete');
    });
  }

  /// Reset the singleton (for testing)
  static Future<void> resetSingleton() async {
    if (_instance != null) {
      await _instance!.shutdown();
      _instance = null;
    }
  }
}
