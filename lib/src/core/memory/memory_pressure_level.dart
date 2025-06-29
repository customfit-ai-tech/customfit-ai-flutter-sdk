/// Memory pressure levels indicating system memory availability
enum MemoryPressureLevel {
  /// System has plenty of available memory (>30%)
  low,
  
  /// Memory usage is moderate (70-85%)
  /// Some cleanup may be beneficial
  medium,
  
  /// Memory usage is high (85-95%)
  /// Active cleanup should be performed
  high,
  
  /// Memory usage is critical (>95%)
  /// Emergency cleanup required to prevent OOM
  critical,
}

/// Extension methods for memory pressure levels
extension MemoryPressureLevelExtension on MemoryPressureLevel {
  /// Returns true if this pressure level requires immediate action
  bool get requiresAction => this == MemoryPressureLevel.high || this == MemoryPressureLevel.critical;
  
  /// Returns true if this is a critical state
  bool get isCritical => this == MemoryPressureLevel.critical;
  
  /// Returns a human-readable description
  String get description {
    switch (this) {
      case MemoryPressureLevel.low:
        return 'Low memory pressure - normal operation';
      case MemoryPressureLevel.medium:
        return 'Medium memory pressure - consider cleanup';
      case MemoryPressureLevel.high:
        return 'High memory pressure - active cleanup needed';
      case MemoryPressureLevel.critical:
        return 'Critical memory pressure - emergency cleanup required';
    }
  }
  
  /// Returns the threshold percentage for this level
  double get threshold {
    switch (this) {
      case MemoryPressureLevel.low:
        return 0.70; // <70% usage
      case MemoryPressureLevel.medium:
        return 0.85; // 70-85% usage
      case MemoryPressureLevel.high:
        return 0.95; // 85-95% usage
      case MemoryPressureLevel.critical:
        return 1.0; // >95% usage
    }
  }
}