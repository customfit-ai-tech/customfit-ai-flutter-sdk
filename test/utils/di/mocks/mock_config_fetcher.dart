import 'dart:async';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/network/config/config_fetcher.dart';
/// Mock config fetcher for testing
class MockConfigFetcher implements ConfigFetcher {
  final Map<String, dynamic> _configs = {};
  final Map<String, String> _metadata = {};
  final Map<String, dynamic> _sdkSettings = {};
  bool _isOffline = false;
  bool shouldFailFetch = false;
  bool _shouldFetchConfigSucceed = true;
  Duration? _fetchConfigDelay;
  String? lastFetchedModified;
  // Call counters for test verification
  int _fetchMetadataCallCount = 0;
  int _fetchSdkSettingsCallCount = 0;
  int _fetchConfigCallCount = 0;
  // Getters for call counts
  int get fetchMetadataCallCount => _fetchMetadataCallCount;
  int get fetchSdkSettingsCallCount => _fetchSdkSettingsCallCount;
  int get fetchConfigCallCount => _fetchConfigCallCount;
  void setConfig(String key, dynamic value) {
    _configs[key] = {
      'variation': value,
      'version': 1,
      'flag': key,
    };
  }
  void setConfigs(Map<String, dynamic> configs) {
    _configs.clear();
    configs.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        _configs[key] = value;
      } else {
        _configs[key] = {
          'variation': value,
          'version': 1,
          'flag': key,
        };
      }
    });
  }
  void setMetadata(Map<String, String> metadata) {
    _metadata.clear();
    _metadata.addAll(metadata);
  }
  void setSdkSettings(Map<String, dynamic> settings) {
    _sdkSettings.clear();
    _sdkSettings.addAll(settings);
  }
  void setShouldFetchConfigSucceed(bool succeed) {
    _shouldFetchConfigSucceed = succeed;
  }
  void setShouldFetchConfigDelay(Duration delay) {
    _fetchConfigDelay = delay;
  }
  void reset() {
    _configs.clear();
    _metadata.clear();
    _sdkSettings.clear();
    _isOffline = false;
    shouldFailFetch = false;
    _shouldFetchConfigSucceed = true;
    _fetchConfigDelay = null;
    lastFetchedModified = null;
    _fetchMetadataCallCount = 0;
    _fetchSdkSettingsCallCount = 0;
    _fetchConfigCallCount = 0;
  }
  @override
  bool isOffline() {
    return _isOffline;
  }
  @override
  void setOffline(bool offline) {
    _isOffline = offline;
  }
  @override
  Future<bool> fetchConfig({String? lastModified, String? etag}) async {
    _fetchConfigCallCount++;
    if (_isOffline) {
      return false;
    }
    if (!_shouldFetchConfigSucceed || shouldFailFetch) {
      return false;
    }
    if (_fetchConfigDelay != null) {
      await Future.delayed(_fetchConfigDelay!);
    }
    lastFetchedModified = lastModified;
    return true;
  }
  @override
  Future<CFResult<Map<String, String>>> fetchMetadata([String? url]) async {
    _fetchMetadataCallCount++;
    if (_isOffline) {
      return CFResult.error('Client is in offline mode');
    }
    if (_metadata.isNotEmpty) {
      return CFResult.success(Map.from(_metadata));
    }
    return CFResult.success({
      'Last-Modified': 'mock-last-modified',
      'ETag': 'mock-etag',
    });
  }
  // Additional method expected by tests
  @override
  Future<CFResult<Map<String, dynamic>>> fetchSdkSettings() async {
    _fetchSdkSettingsCallCount++;
    if (_isOffline) {
      return CFResult.error('Client is in offline mode');
    }
    return CFResult.success(Map.from(_sdkSettings));
  }
  @override
  CFResult<Map<String, dynamic>> getConfigs() {
    return CFResult.success(Map.from(_configs));
  }
  @override
  CFResult<Map<String, dynamic>> getConfig(String flagKey) {
    if (_configs.containsKey(flagKey)) {
      return CFResult.success(_configs[flagKey]!);
    }
    return CFResult.error('Flag not found: $flagKey');
  }
  // Implement the interface method
  @override
  Map<String, dynamic>? getFlagConfig(String flagKey) {
    final result = getConfig(flagKey);
    return result.isSuccess ? result.getOrNull() : null;
  }
  @override
  bool hasFlag(String flagKey) {
    return _configs.containsKey(flagKey);
  }
  // Legacy method name expected by tests
  @override
  bool flagExists(String flagKey) {
    return hasFlag(flagKey);
  }
  @override
  void clearConfigs() {
    _configs.clear();
  }
}