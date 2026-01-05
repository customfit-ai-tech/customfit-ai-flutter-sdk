/// Test HTTP mocks for CustomFit SDK
///
/// Provides pre-configured mocks for common API endpoints including
/// SDK settings, configuration, and metadata endpoints.
library;
import '../shared/mocks/mock_http_client.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
/// Comprehensive HTTP mock setup for tests
class TestHttpMocks {
  /// SDK settings response from the actual endpoint
  static const Map<String, dynamic> sdkSettingsResponse = {
    "cf_intelligent_code_enabled": false,
    "cf_account_enabled": true,
    "cf_personalize_post_sdk_timeout": false,
    "cfspa": false,
    "cfspa_auto_detect_page_url_change": false,
    "cf_is_page_update_enabled": false,
    "cf_retain_text_value": false,
    "cf_is_whitelabel_account": false,
    "cf_skip_sdk": false,
    "enable_event_analyzer": false,
    "cf_skip_dfs": false,
    "cf_is_ms_clarity_enabled": false,
    "cf_is_hotjar_enabled": false,
    "cf_is_shopify_integrated": false,
    "cf_is_ga_enabled": false,
    "cf_is_segment_enabled": false,
    "cf_is_mixpanel_enabled": false,
    "cf_is_moengage_enabled": false,
    "cf_is_clevertap_enabled": false,
    "cf_is_webengage_enabled": false,
    "cf_is_netcore_enabled": false,
    "cf_is_amplitude_enabled": false,
    "cf_is_heap_enabled": false,
    "cf_is_gokwik_enabled": false,
    "cf_is_shopflo_enabled": false,
    "cf_is_bigcommerce_enabled": false,
    "cf_is_shiprocket_enabled": false,
    "cf_send_error_report": false,
    "personalized_users_limit_exceeded": false,
    "cf_sdk_timeout_in_seconds": 0,
    "cf_initial_delay_in_ms": 0,
    "cf_last_visited_product_url": 0,
    "rule_events": [],
    "_inbound": false,
    "_outbound": false,
    "_auto_form_capture": false,
    "_auto_email_capture": false
  };
  /// Default HEAD API response headers
  static const Map<String, String> defaultHeadResponse = {
    'Last-Modified': 'Wed, 21 Oct 2015 07:28:00 GMT',
    'ETag': '"test-etag-123"',
    'Content-Type': 'application/json',
    'Cache-Control': 'max-age=3600',
    'X-Custom-Header': 'test-value'
  };
  /// Feature flags configuration response
  static const Map<String, dynamic> featureFlagsResponse = {
    "flags": {
      "test_feature": {
        "enabled": true,
        "value": "test_value",
        "type": "string"
      },
      "premium_feature": {"enabled": false, "value": false, "type": "boolean"},
      "numeric_feature": {"enabled": true, "value": 42, "type": "number"}
    },
    "user_segments": ["test_segment"],
    "timestamp": "2024-01-01T00:00:00Z"
  };
  /// Analytics/events submission response
  static const Map<String, dynamic> analyticsResponse = {
    "success": true,
    "events_processed": 1,
    "batch_id": "test-batch-123",
    "timestamp": "2024-01-01T00:00:00Z"
  };
  /// Creates a fully configured MockHttpClient with all common endpoints
  static MockHttpClient createConfiguredMock(CFConfig config) {
    final mockClient = MockHttpClient();
    // Configure SDK settings endpoint
    mockClient.whenGet(
      'https://sdk.customfit.ai/af76f680-057f-11f0-b76e-57ad8cff4a15/cf-sdk-settings.json',
      sdkSettingsResponse,
    );
    // Configure HEAD responses for various endpoints
    _configureHeadResponses(mockClient);
    // Configure common API endpoints
    _configureApiEndpoints(mockClient);
    return mockClient;
  }
  /// Configure HEAD API responses for metadata checking
  static void _configureHeadResponses(MockHttpClient client) {
    // SDK settings HEAD response
    client.whenHead(
      'https://sdk.customfit.ai/af76f680-057f-11f0-b76e-57ad8cff4a15/cf-sdk-settings.json',
      defaultHeadResponse,
    );
    // Config endpoint HEAD response
    client.whenHead(
      '/api/config',
      defaultHeadResponse,
    );
    // Events endpoint HEAD response
    client.whenHead(
      '/api/events',
      defaultHeadResponse,
    );
    // Feature flags HEAD response
    client.whenHead(
      '/api/flags',
      {
        ...defaultHeadResponse,
        'X-Flags-Version': '1.2.3',
        'X-User-Segments': 'test_segment'
      },
    );
  }
  /// Configure common API endpoints with realistic responses
  static void _configureApiEndpoints(MockHttpClient client) {
    // Feature flags configuration
    client.whenGet('/api/config', featureFlagsResponse);
    client.whenGet('/api/flags', featureFlagsResponse);
    // Analytics/events endpoints
    client.whenPost('/api/events', analyticsResponse);
    client.whenPost('/api/track', analyticsResponse);
    client.whenPost('/api/analytics', analyticsResponse);
    // User/session endpoints
    client.whenGet('/api/user', {
      "user_id": "test_user_123",
      "segments": ["test_segment"],
      "properties": {"plan": "test", "environment": "test"}
    });
    client.whenGet('/api/session', {
      "session_id": "test_session_456",
      "started_at": "2024-01-01T00:00:00Z",
      "expires_at": "2024-01-01T01:00:00Z"
    });
  }
  /// Creates a mock client that simulates network errors
  static MockHttpClient createErrorMock(CFConfig config) {
    final mockClient = MockHttpClient();
    // Configure errors for testing error handling
    mockClient.whenGet('/api/config', null, isError: true, errorMessage: 'Network timeout');
    mockClient.whenPost('/api/events', null, isError: true, errorMessage: 'Server error');
    mockClient.whenGet('/api/flags', null, isError: true, errorMessage: 'Authentication failed');
    return mockClient;
  }
  /// Creates a mock client for offline mode testing
  static MockHttpClient createOfflineMock(CFConfig config) {
    final mockClient = MockHttpClient();
    // All endpoints return network unavailable errors
    mockClient.whenGet('/api/config', null, isError: true, errorMessage: 'Network unavailable');
    mockClient.whenPost('/api/events', null, isError: true, errorMessage: 'Network unavailable');
    mockClient.whenGet('/api/flags', null, isError: true, errorMessage: 'Network unavailable');
    mockClient.whenPost('/api/track', null, isError: true, errorMessage: 'Network unavailable');
    return mockClient;
  }
  /// Creates a mock client with slow responses for performance testing
  static MockHttpClient createSlowMock(CFConfig config) {
    final mockClient = MockHttpClient();
    // Configure normal responses - the slow behavior would be handled
    // by the mock implementation's internal delays if needed
    mockClient.whenGet('/api/config', featureFlagsResponse);
    mockClient.whenPost('/api/events', analyticsResponse);
    mockClient.whenGet('/api/flags', featureFlagsResponse);
    return mockClient;
  }
  /// Helper to create a mock with custom responses
  static MockHttpClient createCustomMock(
    CFConfig config,
    Map<String, dynamic> customResponses,
  ) {
    final mockClient = MockHttpClient();
    // Configure SDK settings first
    mockClient.whenGet(
      'https://sdk.customfit.ai/af76f680-057f-11f0-b76e-57ad8cff4a15/cf-sdk-settings.json',
      sdkSettingsResponse,
    );
    // Configure custom responses
    customResponses.forEach((endpoint, response) {
      // Assume GET for simplicity, tests can use specific mock methods if needed
      mockClient.whenGet(endpoint, response);
    });
    return mockClient;
  }
  /// Set up mock config response with initial flags for testing
  /// This is a simplified approach for TestClientBuilder integration
  static void setupMockConfigResponse(Map<String, dynamic> initialFlags) {
    // Note: This is a placeholder implementation
    // In a real scenario, we would need to configure the HTTP client
    // that will be used by the CFClient instance
    // For now, this just stores the flags for potential use
    _storedInitialFlags = initialFlags;
  }
  // Store initial flags for potential use by mock setup
  static Map<String, dynamic>? _storedInitialFlags;
  /// Get stored initial flags (for internal use)
  static Map<String, dynamic>? getStoredInitialFlags() {
    return _storedInitialFlags;
  }
  /// Clear stored initial flags
  static void clearStoredInitialFlags() {
    _storedInitialFlags = null;
  }
}
/// Test data for various scenarios
class TestScenarios {
  static const Map<String, dynamic> userWithPremiumFeatures = {
    "user_id": "premium_user_123",
    "segments": ["premium", "beta"],
    "properties": {
      "plan": "premium",
      "tier": "gold",
      "features": ["all_features"]
    }
  };
  static const Map<String, dynamic> anonymousUser = {
    "user_id": "anonymous",
    "segments": ["public"],
    "properties": {"environment": "test"}
  };
  static const Map<String, dynamic> organizationUser = {
    "user_id": "org_user_456",
    "organization_id": "test_org_123",
    "segments": ["organization", "admin"],
    "properties": {"role": "admin", "department": "engineering"}
  };
  static const Map<String, dynamic> largeEventBatch = {
    "success": true,
    "events_processed": 100,
    "batch_id": "large-batch-789",
    "processing_time_ms": 250
  };
  static const Map<String, dynamic> featureFlagsWithOverrides = {
    "flags": {
      "test_feature": {"enabled": true, "value": "override_value"},
      "premium_feature": {"enabled": true, "value": true},
      "beta_feature": {"enabled": true, "value": "beta_only"}
    },
    "overrides": {
      "user_segments": ["premium", "beta"],
      "expires_at": "2024-12-31T23:59:59Z"
    }
  };
}
