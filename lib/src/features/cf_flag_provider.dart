import 'dart:async';
import '../client/managers/config_manager.dart';
import '../client/cf_client_mediator.dart';
import '../core/resource_registry.dart';
import '../di/dependency_container.dart';
import '../logging/logger.dart';
import 'flag_provider.dart';

/// Mock config manager for testing when DependencyContainer is not available
class _MockConfigManager implements ConfigManager {
  @override
  Map<String, dynamic> getAllFlags() => {};

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Flag provider that uses the mediator pattern to avoid circular dependencies
/// This eliminates the direct dependency on CFClient, solving the circular dependency issue
class CFFlagProvider implements FlagProvider {
  final ConfigManager _configManager;
  final CFClientMediator _mediator;
  final Map<String, ManagedStreamController<dynamic>> _controllers = {};
  StreamSubscription<MediatorEvent>? _configSubscription;
  bool _isDisposed = false;

  CFFlagProvider({
    required ConfigManager configManager,
    CFClientMediator? mediator,
  })  : _configManager = configManager,
        _mediator = mediator ?? CFClientMediator.instance {
    _setupConfigChangeListener();
  }

  /// Factory constructor that uses DependencyContainer to get the config manager
  /// This breaks the circular dependency by not requiring CFClient directly
  factory CFFlagProvider.fromDependencyContainer() {
    try {
      final configManager = DependencyContainer.instance.get<ConfigManager>();
      return CFFlagProvider(configManager: configManager);
    } catch (e) {
      Logger.w(
          'CFFlagProvider: Failed to get ConfigManager from DependencyContainer: $e');
      // Create a mock config manager for testing purposes
      final mockConfigManager = _MockConfigManager();
      return CFFlagProvider(configManager: mockConfigManager);
    }
  }

  /// Setup listener for configuration changes via mediator
  void _setupConfigChangeListener() {
    _configSubscription =
        _mediator.subscribeToEvents(MediatorEventType.configChanged)?.listen(
      (event) {
        _handleConfigChange(event);
      },
      onError: (error) {
        // Handle subscription errors gracefully
        Logger.w('CFFlagProvider: Error in config change subscription: $error');
      },
    );
  }

  /// Handle configuration changes from the mediator
  void _handleConfigChange(MediatorEvent event) {
    if (_isDisposed) return;

    try {
      // Notify all flag controllers about potential changes
      for (final entry in _controllers.entries) {
        final key = entry.key;
        final controller = entry.value;

        if (!controller.isClosed) {
          final newValue = getFlag(key);
          controller.add(newValue);
        }
      }
    } catch (e) {
      Logger.e('CFFlagProvider: Error handling config change: $e');
    }
  }

  @override
  dynamic getFlag(String key) {
    if (_isDisposed) return null;

    final allFlags = _configManager.getAllFlags();
    final flagConfig = allFlags[key] as Map<String, dynamic>?;

    if (flagConfig == null) {
      return null;
    }

    // Check if flag is enabled
    final enabled = flagConfig['enabled'] as bool? ?? false;
    if (!enabled) {
      return null;
    }

    // Return the value
    return flagConfig['value'];
  }

  @override
  Map<String, dynamic> getAllFlags() {
    if (_isDisposed) return {};

    final allFlags = _configManager.getAllFlags();
    final result = <String, dynamic>{};

    allFlags.forEach((key, config) {
      if (config is Map<String, dynamic>) {
        final enabled = config['enabled'] as bool? ?? false;
        if (enabled) {
          result[key] = config['value'];
        }
      }
    });

    return result;
  }

  @override
  bool flagExists(String key) {
    if (_isDisposed) return false;

    final allFlags = _configManager.getAllFlags();
    return allFlags.containsKey(key);
  }

  @override
  Stream<dynamic> flagChanges(String key) {
    if (_isDisposed) {
      return const Stream.empty();
    }

    // For now, return a stream that just emits the current value
    // In a full implementation, this would listen to config changes
    _controllers[key] ??= ManagedStreamController<dynamic>(
      owner: 'CFFlagProvider',
      broadcast: true,
    );

    // Emit current value immediately
    Future.microtask(() {
      final value = getFlag(key);
      _controllers[key]?.add(value);
    });

    return _controllers[key]!.stream;
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    // Cancel config change subscription
    await _configSubscription?.cancel();
    _configSubscription = null;

    // Dispose all managed controllers
    final futures =
        _controllers.values.map((controller) => controller.dispose());
    await Future.wait(futures);
    _controllers.clear();
  }
}
