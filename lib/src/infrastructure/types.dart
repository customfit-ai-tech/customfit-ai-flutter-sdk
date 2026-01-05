// lib/src/infrastructure/types.dart
//
// Centralized type aliases for infrastructure module.
// Prevents conflicts and provides clean interface definitions.
//
// This file is part of the CustomFit SDK for Flutter.

// Import interfaces for type aliases
import 'network/interfaces/http_client.dart';
import 'network/interfaces/connection_manager.dart';
import 'network/interfaces/config_fetcher.dart';
import 'storage/interfaces/cache_manager.dart';
import 'storage/interfaces/preferences_service.dart';
import 'storage/interfaces/secure_storage_service.dart';
import 'platform/interfaces/device_info_detector.dart';
import 'platform/interfaces/background_state_monitor.dart';

// Re-export all interfaces
export 'network/interfaces/http_client.dart';
export 'network/interfaces/connection_manager.dart';
export 'network/interfaces/config_fetcher.dart';
export 'storage/interfaces/cache_manager.dart';
export 'storage/interfaces/preferences_service.dart';
export 'storage/interfaces/secure_storage_service.dart';
export 'platform/interfaces/device_info_detector.dart';
export 'platform/interfaces/background_state_monitor.dart';

/// Type aliases for clean interface definitions across the SDK
typedef HttpClient = IHttpClient;
typedef ConfigFetcher = IConfigFetcher;
typedef ConnectionManager = IConnectionManager;
typedef ConnectionStatusListener = IConnectionStatusListener;
typedef CacheManager = ICacheManager;
typedef PreferencesService = IPreferencesService;
typedef SecureStorageService = ISecureStorageService;
typedef DeviceInfoDetector = IDeviceInfoDetector;
typedef BackgroundStateMonitor = IBackgroundStateMonitor;
