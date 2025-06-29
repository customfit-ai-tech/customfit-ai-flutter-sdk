// test/shared/fixtures/network_responses.dart
//
// Network response fixtures for testing various API scenarios
// including success cases, error conditions, and edge cases.
//
// This file is part of the CustomFit SDK test infrastructure.
import 'dart:convert';
/// Provides pre-defined network response fixtures for testing
class NetworkResponses {
  // ====== Success Responses ======
  /// Standard successful configuration response
  static const String successConfig = '''
{
  "configs": {
    "hero_text": {
      "variation": "Welcome to CustomFit!",
      "type": "string",
      "enabled": true,
      "experience_behaviour_response": {
        "display_mode": "banner",
        "priority": 1
      }
    },
    "show_discount": {
      "variation": true,
      "type": "boolean",
      "enabled": true
    },
    "discount_percentage": {
      "variation": 15,
      "type": "number",
      "enabled": true
    },
    "feature_flags": {
      "variation": ["new_ui", "analytics_v2"],
      "type": "array",
      "enabled": true
    }
  }
}
''';
  /// Empty configuration response
  static const String emptyConfig = '''
{
  "configs": {}
}
''';
  /// Large configuration response for performance testing
  static String get largeConfig {
    final configs = <String, dynamic>{};
    for (int i = 0; i < 1000; i++) {
      configs['flag_$i'] = {
        'variation': 'value_$i',
        'type': 'string',
        'enabled': i % 2 == 0,
      };
    }
    return jsonEncode({'configs': configs});
  }
  /// Successful event batch response
  static const String successEventBatch = '''
{
  "success": true,
  "processed": 100,
  "failed": 0,
  "message": "Events processed successfully"
}
''';
  /// Partial event batch success
  static const String partialEventBatch = '''
{
  "success": true,
  "processed": 75,
  "failed": 25,
  "failed_events": [
    {"id": "evt_101", "reason": "Invalid timestamp"},
    {"id": "evt_102", "reason": "Missing required field"}
  ],
  "message": "Partial batch processed"
}
''';
  // ====== Error Responses ======
  /// Rate limit error response
  static const String rateLimitError = '''
{
  "error": "Rate limit exceeded",
  "error_code": "RATE_LIMIT_EXCEEDED",
  "retry_after": 60,
  "message": "Too many requests. Please retry after 60 seconds."
}
''';
  /// Authentication error response
  static const String authError = '''
{
  "error": "Authentication failed",
  "error_code": "AUTH_FAILED",
  "message": "Invalid API key or client credentials"
}
''';
  /// Validation error response
  static const String validationError = '''
{
  "error": "Validation failed",
  "error_code": "VALIDATION_ERROR",
  "details": {
    "user_id": "User ID is required",
    "timestamp": "Invalid timestamp format"
  }
}
''';
  /// Server error response
  static const String serverError = '''
{
  "error": "Internal server error",
  "error_code": "INTERNAL_ERROR",
  "message": "An unexpected error occurred. Please try again later.",
  "request_id": "req_123456789"
}
''';
  /// Service unavailable response
  static const String serviceUnavailable = '''
{
  "error": "Service temporarily unavailable",
  "error_code": "SERVICE_UNAVAILABLE",
  "message": "The service is currently undergoing maintenance",
  "retry_after": 300
}
''';
  // ====== Edge Case Responses ======
  /// Malformed JSON response
  static const String malformedJson = '''
{
  "configs": {
    "test_flag": {
      "variation": "test"
      // Missing closing braces
''';
  /// Invalid data types in response
  static const String invalidDataTypes = '''
{
  "configs": {
    "string_as_number": {
      "variation": "not_a_number",
      "type": "number",
      "enabled": true
    },
    "null_variation": {
      "variation": null,
      "type": "string",
      "enabled": true
    }
  }
}
''';
  /// Response with unexpected fields
  static const String unexpectedFields = '''
{
  "configs": {
    "test_flag": {
      "variation": "test",
      "type": "string",
      "enabled": true,
      "unexpected_field": "should_be_ignored",
      "another_unexpected": 123
    }
  },
  "metadata": {
    "version": "2.0",
    "timestamp": "2024-01-01T00:00:00Z"
  }
}
''';
  /// Very large single value response
  static String get largeValueResponse {
    final largeString = 'x' * 1000000; // 1MB string
    return jsonEncode({
      'configs': {
        'large_flag': {
          'variation': largeString,
          'type': 'string',
          'enabled': true,
        }
      }
    });
  }
  // ====== Special Cases ======
  /// 304 Not Modified (empty body)
  static const String notModified = '';
  /// HTML error page (non-JSON)
  static const String htmlErrorPage = '''
<!DOCTYPE html>
<html>
<head><title>502 Bad Gateway</title></head>
<body>
<h1>502 Bad Gateway</h1>
<p>The server returned an invalid response.</p>
</body>
</html>
''';
  /// Timeout simulation helper
  static Future<String> delayedResponse(String response, int delayMs) async {
    await Future.delayed(Duration(milliseconds: delayMs));
    return response;
  }
  /// SDK settings response
  static const String sdkSettings = '''
{
  "polling_interval_ms": 30000,
  "event_flush_interval_ms": 10000,
  "max_event_queue_size": 10000,
  "features": {
    "analytics_enabled": true,
    "offline_mode_enabled": true,
    "compression_enabled": false
  },
  "endpoints": {
    "config": "https://api.customfit.com/v1/config",
    "events": "https://api.customfit.com/v1/events"
  }
}
''';
  /// Metadata headers for conditional requests
  static Map<String, String> metadataHeaders({
    String? lastModified,
    String? etag,
  }) {
    final headers = <String, String>{
      'content-type': 'application/json',
    };
    if (lastModified != null) {
      headers['last-modified'] = lastModified;
    }
    if (etag != null) {
      headers['etag'] = etag;
    }
    return headers;
  }
  /// Create custom error response
  static String customError({
    required String error,
    required String errorCode,
    String? message,
    Map<String, dynamic>? details,
  }) {
    return jsonEncode({
      'error': error,
      'error_code': errorCode,
      if (message != null) 'message': message,
      if (details != null) 'details': details,
    });
  }
  /// Create custom config response
  static String customConfig(Map<String, dynamic> flags) {
    final configs = <String, dynamic>{};
    flags.forEach((key, value) {
      configs[key] = {
        'variation': value,
        'type': _getTypeForValue(value),
        'enabled': true,
      };
    });
    return jsonEncode({'configs': configs});
  }
  static String _getTypeForValue(dynamic value) {
    if (value is String) return 'string';
    if (value is bool) return 'boolean';
    if (value is num) return 'number';
    if (value is List) return 'array';
    if (value is Map) return 'object';
    return 'unknown';
  }
}