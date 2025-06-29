import 'dart:async';

import '../client/cf_client_mediator.dart';
import '../client/cf_client.dart';
import '../config/core/cf_config.dart';
import '../core/model/cf_user.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../logging/logger.dart';
import '../core/util/synchronization.dart';

/// Manages the lifecycle of the CFClient instance using mediator pattern.
/// Handles initialization, pause/resume, and shutdown without direct CFClient dependency.
class CFLifecycleManager {
  static const String _source = "CFLifecycleManager";

  /// Whether the lifecycle manager has been initialized
  bool _isInitialized = false;

  /// Lock for initialization and shutdown
  final Object _initLock = Object();

  /// Singleton instance
  static CFLifecycleManager? _instance;

  /// Mediator for decoupled communication
  final CFClientMediator _mediator;

  /// Create a new lifecycle manager (private constructor)
  CFLifecycleManager._() : _mediator = CFClientMediator.instance;

  /// Initialize the lifecycle manager with configuration and user.
  /// This should be called when your application starts.
  /// Note: This method now actually initializes CFClient instead of just publishing events
  Future<void> initialize(CFConfig config, CFUser user) async {
    return synchronizedAsync(_initLock, () async {
      try {
        if (!_isInitialized) {
          Logger.i('Initializing SDK through lifecycle manager');

          // Actually initialize the CFClient instead of just publishing events
          await CFClient.initialize(config, user);

          // Publish initialization event via mediator for other components
          _mediator.publishEvent(
            MediatorEventType.clientStateChanged,
            {
              'action': 'initialize',
              'config': config,
              'user': user,
            },
            source: _source,
          );

          _isInitialized = true;
          Logger.i('SDK initialized successfully through lifecycle manager');
        }
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Failed to initialize SDK",
          source: _source,
          severity: ErrorSeverity.high,
        );
        rethrow;
      }
    });
  }

  /// Puts the client in offline mode when the app is in the background.
  /// This should be called when your application moves to the background.
  void pause() {
    if (_isInitialized) {
      // Publish pause event via mediator
      _mediator.publishEvent(
        MediatorEventType.clientStateChanged,
        {
          'action': 'pause',
          'offline': true,
        },
        source: _source,
      );
      Logger.d('SDK pause requested through lifecycle manager');
    }
  }

  /// Restores the client to online mode and increments app launch count.
  /// This should be called when your application comes to the foreground.
  void resume() {
    if (_isInitialized) {
      // Publish resume event via mediator
      _mediator.publishEvent(
        MediatorEventType.clientStateChanged,
        {
          'action': 'resume',
          'offline': false,
          'incrementLaunchCount': true,
        },
        source: _source,
      );
      Logger.d('SDK resume requested through lifecycle manager');
    }
  }

  /// Clean up resources and shut down the client.
  /// This is automatically called when the app is terminating.
  Future<void> cleanup() async {
    return synchronizedAsync(_initLock, () async {
      if (_isInitialized) {
        Logger.i('Cleaning up SDK through lifecycle manager');
        try {
          // Actually shutdown the CFClient
          await CFClient.shutdownSingleton();

          // Publish shutdown event via mediator
          _mediator.publishEvent(
            MediatorEventType.clientStateChanged,
            {
              'action': 'shutdown',
            },
            source: _source,
          );

          _isInitialized = false;
          Logger.i('SDK cleaned up successfully through lifecycle manager');
        } catch (e) {
          ErrorHandler.handleException(
            e,
            "Error during SDK cleanup",
            source: _source,
            severity: ErrorSeverity.medium,
          );
        }
      }
    });
  }

  /// Returns whether the lifecycle manager has been initialized
  bool isInitialized() => _isInitialized;

  /// Initialize the SDK with lifecycle management using singleton pattern.
  /// This should be called when your application starts.
  static Future<void> initializeInstance(CFConfig config, CFUser user) async {
    _instance ??= CFLifecycleManager._();
    await _instance!.initialize(config, user);
    Logger.i('CFLifecycleManager initialized with singleton pattern');
  }

  /// Puts the client in offline mode.
  /// This should be called when your application moves to the background.
  static void pauseInstance() {
    _instance?.pause();
  }

  /// Restores the client to online mode.
  /// This should be called when your application comes to the foreground.
  static void resumeInstance() {
    _instance?.resume();
  }

  /// Clean up resources and shut down the client.
  /// This should be called when your application is terminating.
  static Future<void> cleanupInstance() async {
    final instance = _instance;
    if (instance != null) {
      await instance.cleanup();
      _instance = null;
    }
  }

  /// Get the current CFClient instance.
  /// Returns null if the client hasn't been initialized.
  static CFClient? getInstanceClient() {
    if (_instance?._isInitialized == true) {
      return CFClient.getInstance();
    }
    return null;
  }

  /// Check if the lifecycle manager is initialized.
  static bool isClientInitialized() => _instance?.isInitialized() ?? false;
}
