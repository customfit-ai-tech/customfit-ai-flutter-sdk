import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'memory_platform_interface.dart';

/// Android-specific memory detection implementation
class AndroidMemoryDetector implements MemoryPlatformInterface {
  static const _channel = MethodChannel('com.customfit.sdk/memory');
  
  Timer? _monitoringTimer;
  StreamController<MemoryInfo>? _memoryStreamController;
  
  @override
  String get platformName => 'Android';
  
  @override
  bool get isSupported => Platform.isAndroid;
  
  @override
  Future<MemoryInfo> getMemoryInfo() async {
    try {
      // First try platform channel for accurate info
      final result = await _getMemoryViaChannel();
      if (result != null) return result;
    } catch (e) {
      // Fallback to file-based approach
    }
    
    // Fallback: Read from /proc/meminfo
    return _getMemoryFromProc();
  }
  
  Future<MemoryInfo?> _getMemoryViaChannel() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('getMemoryInfo');
      
      return MemoryInfo.fromAvailableAndTotal(
        availableMemory: result['availableMemory'] as int,
        totalMemory: result['totalMemory'] as int,
        appMemoryUsage: result['appMemoryUsage'] as int,
      );
    } on PlatformException {
      return null;
    }
  }
  
  Future<MemoryInfo> _getMemoryFromProc() async {
    try {
      final meminfoFile = File('/proc/meminfo');
      if (!meminfoFile.existsSync()) {
        return _getFallbackMemoryInfo();
      }
      
      final lines = await meminfoFile.readAsLines();
      int? totalMemory;
      int? availableMemory;
      
      for (final line in lines) {
        if (line.startsWith('MemTotal:')) {
          totalMemory = _parseMemoryLine(line);
        } else if (line.startsWith('MemAvailable:')) {
          availableMemory = _parseMemoryLine(line);
        }
        
        if (totalMemory != null && availableMemory != null) break;
      }
      
      if (totalMemory == null || availableMemory == null) {
        return _getFallbackMemoryInfo();
      }
      
      // Get app memory usage from runtime
      final appMemoryUsage = _getAppMemoryUsage();
      
      return MemoryInfo.fromAvailableAndTotal(
        availableMemory: availableMemory,
        totalMemory: totalMemory,
        appMemoryUsage: appMemoryUsage,
      );
    } catch (e) {
      return _getFallbackMemoryInfo();
    }
  }
  
  int _parseMemoryLine(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final value = int.tryParse(parts[1]) ?? 0;
      // Convert from KB to bytes
      return value * 1024;
    }
    return 0;
  }
  
  /// Get current RSS (Resident Set Size) memory usage - stub implementation
  int? _getCurrentRss() {
    try {
      // Placeholder implementation - in a real app this would use platform channels
      // to get actual RSS memory usage from native Android code
      return 100 * 1024 * 1024; // Return 100MB as default
    } catch (e) {
      return null;
    }
  }
  
  int _getAppMemoryUsage() {
    try {
      // Use developer.getCurrentRss() for actual RSS memory
      final runtime = _getCurrentRss() ?? 0;
      return runtime;
    } catch (e) {
      return 0;
    }
  }
  
  MemoryInfo _getFallbackMemoryInfo() {
    // Fallback values when we can't get real data
    const totalMemory = 2 * 1024 * 1024 * 1024; // 2GB
    const availableMemory = 512 * 1024 * 1024; // 512MB
    
    return MemoryInfo.fromAvailableAndTotal(
      availableMemory: availableMemory,
      totalMemory: totalMemory,
      appMemoryUsage: _getAppMemoryUsage(),
    );
  }
  
  @override
  Stream<MemoryInfo> startMonitoring({Duration interval = const Duration(seconds: 10)}) {
    stopMonitoring();
    
    _memoryStreamController = StreamController<MemoryInfo>.broadcast();
    
    // Emit initial value
    getMemoryInfo().then((info) {
      _memoryStreamController?.add(info);
    });
    
    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(interval, (_) async {
      final info = await getMemoryInfo();
      _memoryStreamController?.add(info);
    });
    
    return _memoryStreamController!.stream;
  }
  
  @override
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _memoryStreamController?.close();
    _memoryStreamController = null;
  }
}