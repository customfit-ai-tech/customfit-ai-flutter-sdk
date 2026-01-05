// infrastructure/platform/interfaces/device_info_detector.dart
//
// Abstract interface for device information detection.
// Defines the contract for accessing device and platform information.

/// Abstract interface for device information detection
abstract class IDeviceInfoDetector {
  /// Get device platform (Android, iOS, etc.)
  String getPlatform();

  /// Get device model
  String getDeviceModel();

  /// Get operating system version
  String getOSVersion();

  /// Get app version
  String getAppVersion();

  /// Get app build number
  String getBuildNumber();

  /// Get device identifier (if available)
  String? getDeviceIdentifier();

  /// Check if device is tablet
  bool isTablet();

  /// Get screen resolution
  Map<String, dynamic> getScreenInfo();
}
