import 'dart:async';
import 'dart:io';
import '../../logging/logger.dart';
import '../weak_listener_manager.dart';
import '../resource_registry.dart';
import 'memory_pressure_level.dart';
import 'platform/memory_platform_interface.dart';
import 'platform/android_memory_detector.dart';
import 'platform/ios_memory_detector.dart';

/// Monitors system memory pressure and notifies listeners
class MemoryPressureMonitor {
  static MemoryPressureMonitor? _instance;
  static MemoryPressureMonitor get instance => _instance ??= MemoryPressureMonitor._();
  
  late final WeakListenerManager<MemoryPressureListener> _listenerManager;
  late final ManagedStreamController<MemoryPressureLevel> _pressureController;
  
  MemoryPlatformInterface? _platformDetector;
  StreamSubscription<MemoryInfo>? _monitoringSubscription;
  MemoryPressureLevel _currentLevel = MemoryPressureLevel.low;
  MemoryInfo? _lastMemoryInfo;
  ManagedTimer? _fallbackTimer;
  bool _isDisposed = false;
  
  // Configurable thresholds
  double _lowThreshold = 0.70;      // <70% usage
  double _mediumThreshold = 0.85;   // 70-85% usage
  double _highThreshold = 0.95;     // 85-95% usage
  
  Duration _monitoringInterval = const Duration(seconds: 10);
  bool _isMonitoring = false;
  
  MemoryPressureMonitor._() {
    _listenerManager = WeakListenerManager<MemoryPressureListener>(
      name: 'MemoryPressureMonitor',
      cleanupInterval: const Duration(minutes: 2),
    );
    _pressureController = ManagedStreamController<MemoryPressureLevel>(
      owner: 'MemoryPressureMonitor',
      broadcast: true,
    );
    _initializePlatformDetector();
  }
  
  void _initializePlatformDetector() {
    if (Platform.isAndroid) {
      _platformDetector = AndroidMemoryDetector();
    } else if (Platform.isIOS) {
      _platformDetector = IOSMemoryDetector();
    } else {
      Logger.w('Memory pressure monitoring not supported on ${Platform.operatingSystem}');
    }
  }
  
  /// Current memory pressure level
  MemoryPressureLevel get currentPressure => _currentLevel;
  
  /// Stream of pressure level changes
  Stream<MemoryPressureLevel> get pressureChanges => _pressureController.stream;
  
  /// Last recorded memory information
  MemoryInfo? get lastMemoryInfo => _lastMemoryInfo;
  
  /// Whether monitoring is currently active
  bool get isMonitoring => _isMonitoring;
  
  /// Configure monitoring thresholds
  void configureThresholds({
    double? lowThreshold,
    double? mediumThreshold,
    double? highThreshold,
  }) {
    if (lowThreshold != null) _lowThreshold = lowThreshold;
    if (mediumThreshold != null) _mediumThreshold = mediumThreshold;
    if (highThreshold != null) _highThreshold = highThreshold;
    
    // Validate thresholds
    assert(_lowThreshold < _mediumThreshold, 'Low threshold must be less than medium');
    assert(_mediumThreshold < _highThreshold, 'Medium threshold must be less than high');
    assert(_highThreshold <= 1.0, 'High threshold must be <= 1.0');
  }
  
  /// Configure monitoring interval
  void configureInterval(Duration interval) {
    _monitoringInterval = interval;
    
    // Restart monitoring if active
    if (_isMonitoring) {
      stopMonitoring();
      startMonitoring();
    }
  }
  
  /// Start monitoring memory pressure
  void startMonitoring() {
    if (_isMonitoring) {
      Logger.d('Memory pressure monitoring already active');
      return;
    }
    
    if (_platformDetector == null || !_platformDetector!.isSupported) {
      Logger.w('Memory pressure monitoring not supported on this platform');
      _startFallbackMonitoring();
      return;
    }
    
    _isMonitoring = true;
    Logger.i('Starting memory pressure monitoring with interval: $_monitoringInterval');
    
    // Start platform-specific monitoring
    final memoryStream = _platformDetector!.startMonitoring(interval: _monitoringInterval);
    
    _monitoringSubscription = memoryStream.listen(
      _handleMemoryInfo,
      onError: (error) {
        Logger.e('Memory monitoring error: $error');
        _startFallbackMonitoring();
      },
    );
    
    // Get initial reading
    _checkMemoryPressure();
  }
  
  /// Stop monitoring memory pressure
  void stopMonitoring() {
    if (!_isMonitoring || _isDisposed) return;
    
    _isMonitoring = false;
    _monitoringSubscription?.cancel();
    _monitoringSubscription = null;
    _fallbackTimer?.dispose();
    _fallbackTimer = null;
    _platformDetector?.stopMonitoring();
    
    Logger.i('Stopped memory pressure monitoring');
  }
  
  /// Add a listener for pressure changes
  void addListener(MemoryPressureListener listener) {
    if (_isDisposed) return;
    _listenerManager.addListener(listener);
  }
  
  /// Remove a listener
  void removeListener(MemoryPressureListener listener) {
    if (_isDisposed) return;
    _listenerManager.removeListener(listener);
  }
  
  /// Force an immediate memory check
  Future<void> checkMemoryPressure() async {
    await _checkMemoryPressure();
  }
  
  Future<void> _checkMemoryPressure() async {
    if (_platformDetector == null) return;
    
    try {
      final memoryInfo = await _platformDetector!.getMemoryInfo();
      _handleMemoryInfo(memoryInfo);
    } catch (e) {
      Logger.e('Failed to check memory pressure: $e');
    }
  }
  
  void _handleMemoryInfo(MemoryInfo memoryInfo) {
    _lastMemoryInfo = memoryInfo;
    
    final newLevel = _calculatePressureLevel(memoryInfo.usageRatio);
    
    if (newLevel != _currentLevel) {
      final oldLevel = _currentLevel;
      _currentLevel = newLevel;
      
      Logger.i('Memory pressure changed: $oldLevel → $newLevel (${(memoryInfo.usageRatio * 100).toStringAsFixed(1)}% usage)');
      
      // Notify via stream
      _pressureController.add(newLevel);
      
      // Notify listeners
      _listenerManager.notifyListeners((listener) {
        listener.onMemoryPressureChanged(newLevel, memoryInfo);
      });
    }
  }
  
  MemoryPressureLevel _calculatePressureLevel(double usageRatio) {
    if (usageRatio >= _highThreshold) {
      return MemoryPressureLevel.critical;
    } else if (usageRatio >= _mediumThreshold) {
      return MemoryPressureLevel.high;
    } else if (usageRatio >= _lowThreshold) {
      return MemoryPressureLevel.medium;
    } else {
      return MemoryPressureLevel.low;
    }
  }
  
  void _startFallbackMonitoring() {
    if (_isDisposed) return;
    
    // Simple fallback that estimates based on app memory growth
    _fallbackTimer = ManagedTimer.periodic(
      owner: 'MemoryPressureMonitor_fallback',
      duration: _monitoringInterval,
      callback: (_) {
        if (_isDisposed) return;
        
        try {
          final currentRss = _getCurrentRss() ?? 100 * 1024 * 1024;
        
        // Estimate pressure based on app memory usage
        // This is very approximate but better than nothing
        final estimatedPressure = _estimatePressureFromAppMemory(currentRss);
        
        final memoryInfo = MemoryInfo(
          totalMemory: 2 * 1024 * 1024 * 1024, // 2GB estimate
          availableMemory: 512 * 1024 * 1024, // 512MB estimate
          usedMemory: 1536 * 1024 * 1024, // 1.5GB estimate
          usageRatio: estimatedPressure,
          appMemoryUsage: currentRss,
          timestamp: DateTime.now(),
        );
        
        _handleMemoryInfo(memoryInfo);
      } catch (e) {
        Logger.e('Fallback memory monitoring failed: $e');
      }
    });
  }
  
  /// Get current RSS (Resident Set Size) memory usage
  /// This is a stub implementation as getCurrentRss() doesn't exist in dart:developer
  int? _getCurrentRss() {
    try {
      // Placeholder implementation - in a real app this would use platform channels
      // to get actual RSS memory usage from native code
      return 100 * 1024 * 1024; // Return 100MB as default
    } catch (e) {
      Logger.w('Failed to get RSS memory: $e');
      return null;
    }
  }
  
  double _estimatePressureFromAppMemory(int appMemoryBytes) {
    // Simple heuristic: if app uses >200MB, assume medium pressure
    // >400MB high, >600MB critical
    final appMemoryMB = appMemoryBytes / 1024 / 1024;
    
    if (appMemoryMB > 600) return 0.96; // Critical
    if (appMemoryMB > 400) return 0.86; // High
    if (appMemoryMB > 200) return 0.71; // Medium
    return 0.50; // Low
  }
  
  /// Clean up resources
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    stopMonitoring();
    _pressureController.dispose();
    _listenerManager.dispose();
  }
}

/// Listener interface for memory pressure changes
abstract class MemoryPressureListener {
  /// Called when memory pressure level changes
  void onMemoryPressureChanged(MemoryPressureLevel level, MemoryInfo memoryInfo);
}

