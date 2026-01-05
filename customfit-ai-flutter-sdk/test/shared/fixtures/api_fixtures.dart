// test/shared/fixtures/api_fixtures.dart
//
// Common API response fixtures for testing.
// Provides realistic API responses for different scenarios including
// success, error, timeout, and edge cases.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'dart:convert';
/// API response fixtures for testing
class ApiFixtures {
  // Prevent instantiation
  ApiFixtures._();
  /// Standard successful configuration response
  static Map<String, dynamic> successfulConfigResponse({
    String? version,
    Map<String, dynamic>? customFlags,
  }) {
    return {
      'status': 'success',
      'data': {
        'feature_flags': customFlags ?? {
          'new_dashboard': {
            'enabled': true,
            'value': true,
            'metadata': {
              'rollout_percentage': 100,
              'created_at': '2023-01-01T00:00:00Z',
            }
          },
          'payment_method': {
            'enabled': true,
            'value': 'stripe',
            'metadata': {
              'variants': ['stripe', 'paypal', 'crypto'],
            }
          },
          'dark_mode': {
            'enabled': true,
            'value': false,
          },
          'api_rate_limit': {
            'enabled': true,
            'value': 1000,
            'metadata': {
              'unit': 'requests_per_hour',
            }
          },
          'complex_config': {
            'enabled': true,
            'value': {
              'nested': {
                'settings': {
                  'theme': 'blue',
                  'layout': 'grid',
                  'items_per_page': 20,
                }
              },
              'features': ['search', 'filter', 'sort'],
            }
          }
        },
        'sdk_settings': {
          'events_flush_interval_ms': 30000,
          'config_refresh_interval_ms': 60000,
          'max_event_batch_size': 100,
          'enable_debug_logging': false,
          'cache_ttl_seconds': 3600,
        },
        'user_context': {
          'user_id': 'test_user_123',
          'segment': 'beta_testers',
          'attributes': {
            'plan': 'premium',
            'region': 'us-west-2',
          }
        },
        'metadata': {
          'environment': 'production',
          'server_time': DateTime.now().toUtc().toIso8601String(),
          'config_version': version ?? '1.0.0',
          'etag': 'W/"686897696a7c876b7e"',
        }
      }
    };
  }
  /// Empty configuration response (no flags)
  static Map<String, dynamic> emptyConfigResponse() {
    return {
      'status': 'success',
      'data': {
        'feature_flags': {},
        'sdk_settings': {
          'events_flush_interval_ms': 30000,
          'config_refresh_interval_ms': 60000,
        },
        'metadata': {
          'environment': 'production',
          'server_time': DateTime.now().toUtc().toIso8601String(),
          'config_version': '1.0.0',
        }
      }
    };
  }
  /// Large configuration response for performance testing
  static Map<String, dynamic> largeConfigResponse({int flagCount = 1000}) {
    final flags = <String, dynamic>{};
    for (int i = 0; i < flagCount; i++) {
      flags['feature_$i'] = {
        'enabled': i % 2 == 0,
        'value': ApiFixtureHelpers.generateRandomValue(i),
        'metadata': {
          'created_at': DateTime.now().subtract(Duration(days: i)).toIso8601String(),
          'rollout_percentage': (i % 100),
          'tags': ['tag_${i % 10}', 'category_${i % 5}'],
        }
      };
    }
    return {
      'status': 'success',
      'data': {
        'feature_flags': flags,
        'sdk_settings': {
          'events_flush_interval_ms': 30000,
          'config_refresh_interval_ms': 60000,
        },
        'metadata': {
          'environment': 'production',
          'server_time': DateTime.now().toUtc().toIso8601String(),
          'config_version': '1.0.0',
          'flag_count': flagCount,
        }
      }
    };
  }
  /// Convert response to JSON string
  static String toJsonString(Map<String, dynamic> response) {
    return jsonEncode(response);
  }
  /// Create a delayed response for timeout testing
  static Future<Map<String, dynamic>> delayedResponse(
    Map<String, dynamic> response,
    Duration delay,
  ) async {
    await Future.delayed(delay);
    return response;
  }
}
/// Error response fixtures
class ApiErrorResponses {
  /// 400 Bad Request
  static Map<String, dynamic> badRequest({String? message}) {
    return {
      'status': 'error',
      'error': {
        'code': 'BAD_REQUEST',
        'message': message ?? 'Invalid request parameters',
        'details': {
          'missing_fields': ['api_key'],
          'invalid_fields': ['user_id'],
        }
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
  /// 401 Unauthorized
  static Map<String, dynamic> unauthorized() {
    return {
      'status': 'error',
      'error': {
        'code': 'UNAUTHORIZED',
        'message': 'Invalid or expired API key',
        'details': {
          'realm': 'CustomFit API',
          'auth_url': 'https://auth.customfit.com/token',
        }
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
  /// 403 Forbidden
  static Map<String, dynamic> forbidden() {
    return {
      'status': 'error',
      'error': {
        'code': 'FORBIDDEN',
        'message': 'Access denied to this resource',
        'details': {
          'required_permission': 'feature_flags:read',
          'user_permissions': ['analytics:read'],
        }
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
  /// 404 Not Found
  static Map<String, dynamic> notFound({String? resource}) {
    return {
      'status': 'error',
      'error': {
        'code': 'NOT_FOUND',
        'message': 'Resource not found: ${resource ?? "unknown"}',
        'details': {
          'resource_type': 'configuration',
          'resource_id': resource,
        }
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
  /// 429 Too Many Requests
  static Map<String, dynamic> rateLimited({int? retryAfter}) {
    return {
      'status': 'error',
      'error': {
        'code': 'RATE_LIMITED',
        'message': 'Too many requests',
        'details': {
          'limit': 100,
          'window': '1 hour',
          'retry_after_seconds': retryAfter ?? 3600,
        }
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
  /// 500 Internal Server Error
  static Map<String, dynamic> internalError() {
    return {
      'status': 'error',
      'error': {
        'code': 'INTERNAL_ERROR',
        'message': 'An unexpected error occurred',
        'details': {
          'request_id': 'req_${DateTime.now().millisecondsSinceEpoch}',
          'support_url': 'https://support.customfit.com',
        }
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
  /// 503 Service Unavailable
  static Map<String, dynamic> serviceUnavailable() {
    return {
      'status': 'error',
      'error': {
        'code': 'SERVICE_UNAVAILABLE',
        'message': 'Service temporarily unavailable',
        'details': {
          'maintenance': true,
          'expected_uptime': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
/// Event response fixtures
class ApiEventResponses {
  /// Successful event batch response
  static Map<String, dynamic> successfulBatch({int? accepted, int? rejected}) {
    return {
      'status': 'success',
      'data': {
        'accepted': accepted ?? 10,
        'rejected': rejected ?? 0,
        'errors': rejected != null && rejected > 0 ? [
          {
            'index': 5,
            'reason': 'Invalid event type',
          }
        ] : [],
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
  /// Partial success response
  static Map<String, dynamic> partialSuccess() {
    return {
      'status': 'partial_success',
      'data': {
        'accepted': 8,
        'rejected': 2,
        'errors': [
          {
            'index': 3,
            'reason': 'Missing required field: user_id',
          },
          {
            'index': 7,
            'reason': 'Event timestamp too old',
          }
        ],
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
/// Summary response fixtures  
class ApiSummaryResponses {
  /// Successful summary submission
  static Map<String, dynamic> successful() {
    return {
      'status': 'success',
      'data': {
        'summary_id': 'sum_${DateTime.now().millisecondsSinceEpoch}',
        'processed': true,
        'metrics': {
          'events_processed': 150,
          'unique_users': 45,
          'session_duration_avg': 320,
        }
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
/// HTTP headers fixtures
class ApiHeaders {
  /// Standard successful response headers
  static Map<String, String> success() {
    return {
      'Content-Type': 'application/json',
      'X-RateLimit-Limit': '100',
      'X-RateLimit-Remaining': '99',
      'X-RateLimit-Reset': '${DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000}',
      'X-Request-ID': 'req_${DateTime.now().millisecondsSinceEpoch}',
      'Cache-Control': 'private, max-age=0',
    };
  }
  /// Headers with caching information
  static Map<String, String> withCaching({
    String? etag,
    String? lastModified,
  }) {
    return {
      ...success(),
      'ETag': etag ?? 'W/"${DateTime.now().millisecondsSinceEpoch}"',
      'Last-Modified': lastModified ?? ApiFixtureHelpers.httpDate(DateTime.now()),
      'Cache-Control': 'private, max-age=3600',
    };
  }
  /// Rate limited response headers
  static Map<String, String> rateLimited({int retryAfter = 3600}) {
    return {
      'Content-Type': 'application/json',
      'X-RateLimit-Limit': '100',
      'X-RateLimit-Remaining': '0',
      'X-RateLimit-Reset': '${DateTime.now().add(Duration(seconds: retryAfter)).millisecondsSinceEpoch ~/ 1000}',
      'Retry-After': '$retryAfter',
    };
  }
}
/// Helper class with static methods for fixture utilities
class ApiFixtureHelpers {
  /// Generate a random value based on index for variety
  static dynamic generateRandomValue(int index) {
    switch (index % 5) {
      case 0:
        return true;
      case 1:
        return false;
      case 2:
        return 'variant_${index % 3}';
      case 3:
        return index * 10;
      case 4:
        return {
          'config_id': index,
          'settings': {
            'enabled': index % 2 == 0,
            'threshold': index * 5,
          }
        };
      default:
        return null;
    }
  }
  /// Format DateTime as HTTP date
  static String httpDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final utc = date.toUtc();
    final weekday = weekdays[utc.weekday - 1];
    final month = months[utc.month - 1];
    return '$weekday, ${utc.day.toString().padLeft(2, '0')} $month ${utc.year} '
           '${utc.hour.toString().padLeft(2, '0')}:'
           '${utc.minute.toString().padLeft(2, '0')}:'
           '${utc.second.toString().padLeft(2, '0')} GMT';
  }
}