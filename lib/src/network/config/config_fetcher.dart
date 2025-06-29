// lib/src/network/config/config_fetcher.dart
//
// Handles fetching configuration and feature flags from the CustomFit API.
// Implements caching, offline support, conditional requests, and request
// deduplication to efficiently manage feature flag data retrieval.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:convert';
import '../../core/error/cf_result.dart';

import '../../core/model/cf_user.dart';
import '../../core/error/error_category.dart';
import '../../core/error/error_severity.dart';
import '../../core/error/error_handler.dart';
import '../../core/error/cf_error_code.dart';
import '../../constants/cf_constants.dart';
import '../../logging/logger.dart';
import '../../config/core/cf_config.dart';
import '../request_deduplicator.dart';
import '../../core/util/cache_manager.dart';
import '../http_client.dart';
import '../models/config_request.dart';
import '../models/config_response.dart';

/// Handles fetching configuration from the CustomFit API with support for offline mode
class ConfigFetcher {
  static const String _source = "ConfigFetcher";

  final HttpClient _httpClient;
  final CFConfig _config;
  final CFUser _user;

  bool _offlineMode = false;
  final Completer<void> _fetchMutex = Completer<void>();
  ConfigResponse? _lastConfigResponse;
  final _mutex = Completer<void>();
  int _lastFetchTime = 0;

  // Store metadata headers for conditional requests
  String? _lastModified;
  String? _lastEtag;

  // Request deduplicator to prevent duplicate concurrent requests
  final RequestDeduplicator _requestDeduplicator = RequestDeduplicator();

  ConfigFetcher(this._httpClient, this._config, this._user) {
    _fetchMutex.complete();
    _mutex.complete();
    Logger.d('ConfigFetcher initialized with user: ${_user.userCustomerId}');
  }

  /// Returns whether the client is in offline mode
  bool isOffline() => _offlineMode;

  /// Sets the offline mode status
  void setOffline(bool offline) {
    _offlineMode = offline;
    Logger.i("ConfigFetcher offline mode set to: $offline");
  }

  /// Fetches configuration from the API with improved error handling
  Future<bool> fetchConfig({String? lastModified, String? etag}) async {
    // Don't fetch if in offline mode
    if (isOffline()) {
      Logger.d("Not fetching config because client is in offline mode");
      return false;
    }

    // Try to get from cache first
    final cacheKey = 'cf_config_${_config.clientKey}_${_user.userCustomerId}';
    final cachePolicy = CachePolicy(
      ttlSeconds: _config.sdkSettingsCheckIntervalMs ~/ 1000,
      useStaleWhileRevalidate: true,
      persist: true,
    );

    // Check cache first
    final cachedConfig =
        await CacheManager.instance.get<Map<String, dynamic>>(cacheKey);
    if (cachedConfig != null) {
      Logger.i('ConfigFetcher: Using cached configuration');
      // Parse cached config as strongly typed response
      if (cachedConfig['configs'] != null) {
        final configResponse = _parseConfigResponse(cachedConfig);
        if (configResponse != null) {
          _lastConfigResponse = configResponse;
        }
      }
      // Still make the request with If-Modified-Since to check for updates
      if (cachedConfig['lastModified'] != null) {
        lastModified = cachedConfig['lastModified'] as String;
      }
      if (cachedConfig['etag'] != null) {
        _lastEtag = cachedConfig['etag'] as String;
      }
    }

    // Create a unique key for this request
    final requestKey =
        'config:${_config.clientKey}:${lastModified ?? "none"}:${etag ?? _lastEtag ?? "none"}';

    // Use request deduplicator to prevent duplicate concurrent requests
    final result = await _requestDeduplicator.execute<bool>(
      requestKey,
      () => _fetchConfigInternal(
          lastModified: lastModified,
          etag: etag,
          cacheKey: cacheKey,
          cachePolicy: cachePolicy),
    );

    return result.getOrElse(() => false);
  }

  Future<CFResult<bool>> _fetchConfigInternal(
      {String? lastModified,
      String? etag,
      required String cacheKey,
      required CachePolicy cachePolicy}) async {
    try {
      // SECURITY FIX: Move API key to headers instead of URL parameter
      final url =
          "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";

      Logger.i(
          "API POLL: Fetching config from URL: $url${lastModified != null ? " (If-Modified-Since: $lastModified)" : ""}");

      // Create strongly typed request
      final request = ConfigRequest(
        user: _user,
        includeOnlyFeaturesFlags: true,
      );

      final payload = request.toJsonString();

      Logger.d("CONFIG FETCH: Payload size: ${payload.length} bytes");

      // SECURITY FIX: Add API key to headers with proper authentication
      final headers = <String, String>{
        CFConstants.http.headerContentType: CFConstants.http.contentTypeJson,
        'Authorization': 'Bearer ${_config.clientKey}',
        'X-CF-SDK-Version': CFConstants.general.sdkVersion,
        'Cache-Control': 'no-cache', // Always fetch fresh user configs
      };

      // Add If-Modified-Since header if available (match Kotlin)
      if (lastModified != null &&
          lastModified.isNotEmpty &&
          lastModified != 'unchanged') {
        headers[CFConstants.http.headerIfModifiedSince] = lastModified;
      }

      // Add If-None-Match header for ETag support (consistent with Kotlin SDK)
      if (etag != null && etag.isNotEmpty && etag != 'unchanged') {
        headers[CFConstants.http.headerIfNoneMatch] = etag;
      }

      // Log headers concisely (without exposing sensitive auth header)
      final safeHeaders =
          headers.keys.where((key) => key != 'Authorization').join(', ');
      Logger.d(
          "CONFIG FETCH: Headers: $safeHeaders, Authorization: [REDACTED]");

      // Add timeout to the HTTP request
      final result = await _httpClient
          .post(
        url,
        data: payload,
        headers: headers,
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Logger.w("API POLL: Request timed out after 10 seconds");
          return CFResult.error("Request timed out",
              category: ErrorCategory.network,
              errorCode: CFErrorCode.networkTimeout);
        },
      );

      // The HttpClient now handles 304 as a success, so we need to check the response
      // 304 responses typically have null or empty body
      final responseData = result.getOrNull();
      if (result.isSuccess && responseData == null) {
        // This might be a 304 response
        Logger.i(
            "API POLL: Received empty response (possible 304), using cached configs");
        if (_lastConfigResponse != null) {
          return CFResult.success(true);
        }
      }

      if (!result.isSuccess) {
        Logger.w("API POLL: Failed to fetch: ${result.getErrorMessage()}");

        // Try to use cached config as fallback
        if (_lastConfigResponse != null) {
          Logger.i("API POLL: Using cached configuration as fallback");
          return CFResult.success(true); // Indicate we have config available
        }

        // Propagate the error with proper error code
        final error = result.error;
        ErrorHandler.handleError(
          "Failed to fetch configuration: ${result.getErrorMessage()}",
          source: _source,
          category: error?.category ?? ErrorCategory.network,
          severity: error?.severity ?? ErrorSeverity.high,
        );
        return CFResult.error(
          "Failed to fetch configuration",
          errorCode: error?.errorCode ?? CFErrorCode.networkUnavailable,
          category: error?.category ?? ErrorCategory.network,
          exception: error?.exception,
        );
      }

      final responseBody = result.getOrNull();
      if (responseBody == null || responseBody == '') {
        // This is likely a 304 response or empty body
        Logger.i(
            "API POLL: Empty/null response received (likely 304), using cached configuration");
        if (_lastConfigResponse != null) {
          return CFResult.success(true);
        }

        // No cache available, this is an error
        Logger.w(
            "API POLL: Empty response with no cached configuration available");
        return CFResult.error(
          "Empty configuration response",
          errorCode: CFErrorCode.configInitializationFailed,
          category: ErrorCategory.configuration,
        );
      }

      Logger.i(
          "API POLL: Successfully fetched config, response size: ${responseBody.toString().length} bytes");

      // Cache the new configuration with metadata
      final configWithMetadata = <String, dynamic>{
        'configs': responseBody,
        'lastModified': lastModified,
        'etag': _lastEtag, // Use the stored etag from metadata fetch
        '_cachedAt': DateTime.now().toIso8601String(),
      };

      await CacheManager.instance.put(
        cacheKey,
        configWithMetadata,
        policy: cachePolicy,
        metadata: {
          'clientKey': _config.clientKey,
          'userId': _user.userCustomerId ?? '',
        },
      );

      Logger.d(
          'ConfigFetcher: Cached configuration with TTL ${cachePolicy.ttlSeconds}s');

      // Parse with strongly typed response
      final configResponse = _parseConfigResponse(responseBody);
      if (configResponse == null) {
        return CFResult.error("Failed to parse configuration response",
            errorCode: CFErrorCode.configInitializationFailed,
            category: ErrorCategory.serialization);
      }

      // Update internal state with strongly typed response
      _lastConfigResponse = configResponse;
      _lastFetchTime = DateTime.now().millisecondsSinceEpoch;

      Logger.i(
          "API POLL: Successfully processed ${configResponse.configCount} config entries");
      return CFResult.success(true);
    } catch (e) {
      Logger.e("API POLL: Error fetching configuration: ${e.toString()}");
      ErrorHandler.handleException(
        e,
        "Error fetching configuration",
        source: _source,
        severity: ErrorSeverity.high,
      );
      // Try cached config as fallback
      if (_lastConfigResponse != null) {
        Logger.i(
            "API POLL: Exception occurred, using cached configuration as fallback");
        return CFResult.success(true);
      }

      return CFResult.error(
        "Error fetching configuration: ${e.toString()}",
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalUnknownError,
      );
    }
  }

  /// Parse the configuration response using strongly typed models
  ConfigResponse? _parseConfigResponse(dynamic responseBody) {
    try {
      Map<String, dynamic> responseMap;

      if (responseBody is String) {
        responseMap = jsonDecode(responseBody) as Map<String, dynamic>;
      } else if (responseBody is Map<String, dynamic>) {
        responseMap = responseBody;
      } else if (responseBody is bool && responseBody == true) {
        // Handle boolean true response as empty config (common for 304 responses)
        responseMap = <String, dynamic>{'configs': <String, dynamic>{}};
      } else {
        Logger.w("Unexpected response type: ${responseBody.runtimeType}");
        return null;
      }

      return ConfigResponse.fromJson(responseMap);
    } catch (e) {
      Logger.e("Error parsing configuration response: ${e.toString()}");
      ErrorHandler.handleException(e, "Error parsing configuration response",
          source: _source, severity: ErrorSeverity.high);
      return null;
    }
  }

  /// Convert strongly typed response to raw configs
  Map<String, dynamic> _convertToRawConfigs(ConfigResponse configResponse) {
    final rawConfigs = <String, dynamic>{};

    for (final entry in configResponse.configs.entries) {
      rawConfigs[entry.key] = _convertFlagToRawConfig(entry.value);
    }

    return rawConfigs;
  }

  /// Fetches metadata from a URL with improved error handling
  Future<CFResult<Map<String, String>>> fetchMetadata([String? url]) async {
    // If no URL is provided, construct the SDK settings URL (not user configs)
    final targetUrl = url ?? _buildSdkSettingsUrl();

    if (isOffline()) {
      Logger.d("Not fetching metadata because client is in offline mode");
      return CFResult.error("Client is in offline mode",
          category: ErrorCategory.network,
          errorCode: CFErrorCode.networkUnavailable);
    }

    // Create a unique key for this metadata request
    final requestKey = 'metadata:$targetUrl';

    // Use request deduplicator
    return _requestDeduplicator.execute<Map<String, String>>(
      requestKey,
      () => _fetchMetadataInternal(targetUrl),
    );
  }

  Future<CFResult<Map<String, String>>> _fetchMetadataInternal(
      String targetUrl) async {
    try {
      // First try a lightweight HEAD request (match Kotlin)
      final headResult = await _httpClient.headResponse(targetUrl);

      if (headResult.isSuccess) {
        final headers = headResult.getOrNull()?.headers.map ?? {};
        final metadata = {
          CFConstants.http.headerLastModified:
              headers['last-modified']?.first ?? '',
          CFConstants.http.headerEtag: headers['etag']?.first ?? '',
        };
        return CFResult.success(metadata);
      }

      // If HEAD fails, fall back to the original GET method
      Logger.d("API POLL: Falling back to GET for metadata");
      final getResult = await _httpClient.fetchMetadata(targetUrl,
          lastModified: _lastModified, etag: _lastEtag);

      if (!getResult.isSuccess) {
        Logger.w("API POLL: Metadata fetch failed");
      }

      if (getResult.isSuccess) {
        // Store the headers for next request
        final headers = getResult.getOrNull() ?? {};
        _lastModified = headers[CFConstants.http.headerLastModified];
        _lastEtag = headers[CFConstants.http.headerEtag];
      }

      return getResult;
    } catch (e) {
      Logger.e(
          "API POLL: Exception during metadata fetch attempts: ${e.toString()}");
      ErrorHandler.handleException(
        e,
        "Error fetching metadata from $targetUrl",
        source: _source,
        severity: ErrorSeverity.high,
      );

      return CFResult.error(
        "Error fetching metadata: ${e.toString()}",
        exception: e,
        category: ErrorCategory.network,
        errorCode: CFErrorCode.networkUnavailable,
      );
    }
  }

  /// Build SDK settings URL with dimension ID
  String _buildSdkSettingsUrl() {
    final String dimensionId = _config.dimensionId ?? "default";
    final sdkSettingsPath =
        CFConstants.api.sdkSettingsPathPattern.replaceFirst('%s', dimensionId);
    return CFConstants.api.sdkSettingsBaseUrl + sdkSettingsPath;
  }

  /// Returns the last successfully fetched configuration map
  CFResult<Map<String, dynamic>> getConfigs() {
    if (_lastConfigResponse != null) {
      // Convert strongly typed response to raw map
      final rawConfigs = _convertToRawConfigs(_lastConfigResponse!);
      Logger.d('CONFIG FETCHER: Returning ${rawConfigs.length} config entries');

      return CFResult.success(rawConfigs);
    } else {
      return CFResult.error("No configuration has been fetched yet",
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.configNotInitialized);
    }
  }

  Future<CFResult<Map<String, dynamic>>> fetchSdkSettings() async {
    // Respect offline mode
    if (_offlineMode) {
      Logger.d('Not fetching SDK settings because client is in offline mode');
      return CFResult.error("Cannot fetch SDK settings in offline mode",
          category: ErrorCategory.network,
          errorCode: CFErrorCode.networkUnavailable);
    }

    // Use the same URL building helper method for consistency
    final url = _buildSdkSettingsUrl();

    // Create a unique key for this SDK settings request
    final requestKey = 'sdk-settings:$url';

    // Use request deduplicator
    return _requestDeduplicator.execute<Map<String, dynamic>>(
      requestKey,
      () => _fetchSdkSettingsInternal(url),
    );
  }

  Future<CFResult<Map<String, dynamic>>> _fetchSdkSettingsInternal(
      String url) async {
    try {
      Logger.i("API POLL: Fetching full SDK settings with GET: $url");

      // Use custom request with Cache-Control headers for consistency
      final result = await _httpClient.get<Map<String, dynamic>>(url, headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache', // Always fetch fresh SDK settings
      });

      if (result.isSuccess) {
        Logger.i("API POLL: SDK settings parsed successfully");
      } else {
        Logger.w("API POLL: Failed to parse SDK settings response");
      }

      return result;
    } catch (e) {
      Logger.e(
          "API POLL: Exception during SDK settings fetch: ${e.toString()}");
      ErrorHandler.handleException(e, "Unexpected error fetching SDK settings",
          source: _source, severity: ErrorSeverity.high);

      return CFResult.error("Failed to fetch SDK settings",
          exception: e,
          category: ErrorCategory.internal,
          errorCode: CFErrorCode.internalUnknownError);
    }
  }

  /// Check if a flag exists in the configuration
  bool flagExists(String flagKey) {
    return _lastConfigResponse?.hasFlag(flagKey) ?? false;
  }

  /// Get flag configuration for a specific flag
  Map<String, dynamic>? getFlagConfig(String flagKey) {
    if (_lastConfigResponse == null) return null;

    final flag = _lastConfigResponse!.getFlag(flagKey);
    if (flag == null) return null;

    // Convert the strongly typed flag to raw map
    return _convertFlagToRawConfig(flag);
  }

  /// Convert a single flag to raw config format
  Map<String, dynamic> _convertFlagToRawConfig(FeatureFlagConfig flag) {
    final rawConfig = <String, dynamic>{
      'config_id': flag.configId,
      'config_customer_id': flag.configCustomerId,
      'config_name': flag.configName,
      'variation': flag.variation,
      'version': flag.version,
    };

    // Add optional fields
    if (flag.variationName != null) {
      rawConfig['variation_name'] = flag.variationName;
    }
    if (flag.variationId != null) {
      rawConfig['variation_id'] = flag.variationId;
    }
    if (flag.variationDataType != null) {
      rawConfig['variation_data_type'] = flag.variationDataType;
    }
    if (flag.configCreatedAt != null) {
      rawConfig['config_created_at'] = flag.configCreatedAt;
    }

    // Keep experience_behaviour_response as nested object
    if (flag.experienceBehaviourResponse != null) {
      rawConfig['experience_behaviour_response'] =
          flag.experienceBehaviourResponse!.toJson();
    }

    // Add properties if present
    if (flag.properties != null) {
      rawConfig['properties'] = flag.properties!.toJson();
    }

    return rawConfig;
  }

  /// Get config for a specific flag (interface method)
  CFResult<Map<String, dynamic>> getConfig(String flagKey) {
    final config = getFlagConfig(flagKey);
    if (config != null) {
      return CFResult.success(config);
    }
    return CFResult.error(
      'Flag $flagKey not found',
      category: ErrorCategory.validation,
      errorCode: CFErrorCode.configNotInitialized,
    );
  }

  /// Check if a flag exists (interface method)
  bool hasFlag(String flagKey) {
    return flagExists(flagKey);
  }

  /// Clear all configurations
  void clearConfigs() {
    _lastConfigResponse = null;
    _lastFetchTime = 0;
    Logger.d('ConfigFetcher: All configurations cleared');
  }
}
