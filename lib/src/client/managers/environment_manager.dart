import 'dart:async';

import '../../platform/default_background_state_monitor.dart';
import '../../platform/device_info_detector.dart';
import '../../logging/logger.dart';
import '../../core/error/error_handler.dart';
import '../../core/error/error_severity.dart';
import 'user_manager.dart';

/// Interface for EnvironmentManager
abstract class EnvironmentManager {
  /// Detect environment information
  Future<void> detectEnvironmentInfo(bool force);

  /// Shutdown the environment manager
  void shutdown();
}

/// Implementation of EnvironmentManager
class EnvironmentManagerImpl implements EnvironmentManager {
  final BackgroundStateMonitor _backgroundStateMonitor;
  final UserManager _userManager;

  bool _isDetecting = false;
  DateTime? _lastDetectionTime;

  EnvironmentManagerImpl({
    required BackgroundStateMonitor backgroundStateMonitor,
    required UserManager userManager,
  })  : _backgroundStateMonitor = backgroundStateMonitor,
        _userManager = userManager;

  @override
  Future<void> detectEnvironmentInfo(bool force) async {
    // Skip if already detecting or if not forced and detected recently
    if (_isDetecting ||
        (!force &&
            _lastDetectionTime != null &&
            DateTime.now().difference(_lastDetectionTime!).inMinutes < 60)) {
      return;
    }

    _isDetecting = true;

    try {
      // Detect device info
      final deviceContext = await DeviceInfoDetector.detectDeviceInfo();
      final deviceResult = _userManager.updateDeviceContext(deviceContext);
      if (!deviceResult.isSuccess) {
        Logger.w(
            'Failed to update device context: ${deviceResult.getErrorMessage()}');
      }

      // Detect application info
      final applicationInfo =
          await ApplicationInfoDetector.detectApplicationInfo();
      if (applicationInfo != null) {
        final appResult = _userManager.updateApplicationInfo(applicationInfo);
        if (!appResult.isSuccess) {
          Logger.w(
              'Failed to update application info: ${appResult.getErrorMessage()}');
        }
      }

      _lastDetectionTime = DateTime.now();
    } catch (e) {
      Logger.e('Error detecting environment info: $e');
      ErrorHandler.handleException(
        e,
        'Failed to detect environment information',
        source: 'EnvironmentManager',
        severity: ErrorSeverity.low, // Low severity as this is non-critical
      );
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void shutdown() {
    // Clean up resources
    _backgroundStateMonitor.shutdown();
  }
}
