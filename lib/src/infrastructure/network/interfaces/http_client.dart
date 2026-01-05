// infrastructure/network/interfaces/http_client.dart
//
// Abstract interface for HTTP client operations.
// Defines the contract for all HTTP communication in the CustomFit SDK.

import 'dart:async';
import 'package:dio/dio.dart';
import '../../../core/error/cf_result.dart';

/// Abstract interface for HTTP client operations
abstract class IHttpClient {
  /// Perform GET request
  Future<CFResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  /// Perform POST request
  Future<CFResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  /// Perform HEAD request to get response headers
  Future<CFResult<Response>> headResponse(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  /// Fetch metadata headers for conditional requests
  Future<CFResult<Map<String, String>>> fetchMetadata(
    String url, {
    Map<String, String>? headers,
  });

  /// Close the HTTP client and clean up resources
  void close();
}
