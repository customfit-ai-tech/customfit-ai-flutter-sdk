import '../core/error/cf_result.dart';
import '../core/error/cf_result_extensions.dart';
import '../core/error/error_category.dart';
import '../core/error/cf_error_code.dart';

/// Tracks the initialization state of the CFClient
enum InitializationState {
  /// SDK has not been initialized yet
  notInitialized,

  /// SDK initialization is in progress
  initializing,

  /// SDK initialized successfully
  initialized,

  /// SDK initialization failed
  failed,

  /// SDK is shutting down
  shuttingDown,

  /// SDK has been shut down
  shutdown,
}

/// Exception thrown when SDK initialization fails
class SDKInitializationException implements Exception {
  final String message;
  final dynamic originalError;
  final InitializationState failedAtState;
  final List<String> completedSteps;
  final String failedStep;

  SDKInitializationException({
    required this.message,
    this.originalError,
    required this.failedAtState,
    required this.completedSteps,
    required this.failedStep,
  });

  @override
  String toString() {
    return 'SDKInitializationException: $message\n'
        'Failed at: $failedStep\n'
        'Completed steps: ${completedSteps.join(", ")}\n'
        'Original error: $originalError';
  }
}

/// Tracks initialization progress and allows rollback
class InitializationTracker {
  InitializationState _state = InitializationState.notInitialized;
  final List<String> _completedSteps = [];
  final List<Function()> _rollbackActions = [];
  String? _currentStep;

  InitializationState get state => _state;
  List<String> get completedSteps => List.unmodifiable(_completedSteps);
  String? get currentStep => _currentStep;

  /// Start initialization
  CFResult<void> startInitialization() {
    if (_state != InitializationState.notInitialized &&
        _state != InitializationState.failed &&
        _state != InitializationState.shutdown) {
      return CFResult.error(
        'Cannot start initialization from state: $_state',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidFormat,
      );
    }

    return CFResultExtensions.catching(
      () {
        _state = InitializationState.initializing;
        _completedSteps.clear();
        _rollbackActions.clear();
        _currentStep = null;
      },
      errorMessage: 'Failed to start initialization',
      category: ErrorCategory.internal,
    );
  }

  /// Mark a step as started
  CFResult<void> startStep(String stepName) {
    if (_state != InitializationState.initializing) {
      return CFResult.error(
        'Cannot start step when not initializing (current state: $_state)',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidFormat,
      );
    }

    return CFResultExtensions.catching(
      () {
        _currentStep = stepName;
      },
      errorMessage: 'Failed to start step: $stepName',
      category: ErrorCategory.internal,
    );
  }

  /// Mark a step as completed and register rollback action
  CFResult<void> completeStep(String stepName, [Function()? rollbackAction]) {
    if (_state != InitializationState.initializing) {
      return CFResult.error(
        'Cannot complete step when not initializing (current state: $_state)',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidFormat,
      );
    }

    return CFResultExtensions.catching(
      () {
        _completedSteps.add(stepName);
        if (rollbackAction != null) {
          _rollbackActions.add(rollbackAction);
        }
        _currentStep = null;
      },
      errorMessage: 'Failed to complete step: $stepName',
      category: ErrorCategory.internal,
    );
  }

  /// Mark initialization as complete
  CFResult<void> completeInitialization() {
    if (_state != InitializationState.initializing) {
      return CFResult.error(
        'Cannot complete initialization from state: $_state',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidFormat,
      );
    }

    return CFResultExtensions.catching(
      () {
        _state = InitializationState.initialized;
        _currentStep = null;
      },
      errorMessage: 'Failed to complete initialization',
      category: ErrorCategory.internal,
    );
  }

  /// Mark initialization as failed and perform rollback
  Future<void> failInitialization(String reason, dynamic error) async {
    if (_state != InitializationState.initializing) {
      return; // Already failed or in another state
    }

    _state = InitializationState.failed;

    // Perform rollback in reverse order
    for (var i = _rollbackActions.length - 1; i >= 0; i--) {
      try {
        _rollbackActions[i]();
      } catch (e) {
        // Log but continue rollback
        // ignore: avoid_print
        print('Error during rollback of step ${_completedSteps[i]}: $e');
      }
    }

    _rollbackActions.clear();
  }

  /// Reset to not initialized state
  void reset() {
    _state = InitializationState.notInitialized;
    _completedSteps.clear();
    _rollbackActions.clear();
    _currentStep = null;
  }

  /// Mark as shutting down
  void startShutdown() {
    _state = InitializationState.shuttingDown;
  }

  /// Mark as shut down
  void completeShutdown() {
    _state = InitializationState.shutdown;
  }
}
