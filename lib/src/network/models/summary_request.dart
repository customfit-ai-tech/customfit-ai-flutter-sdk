import 'dart:convert';
import '../../core/model/cf_user.dart';
import '../../analytics/summary/cf_config_request_summary.dart';

/// Strongly typed request model for summary flush operations
class SummaryRequest {
  /// User information
  final CFUser user;

  /// List of configuration request summaries
  final List<CFConfigRequestSummary> summaries;

  /// SDK version
  final String cfClientSdkVersion;

  const SummaryRequest({
    required this.user,
    required this.summaries,
    required this.cfClientSdkVersion,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'user': user.toMap(),
      'summaries': summaries.map((s) => s.toMap()).toList(),
      'cf_client_sdk_version': cfClientSdkVersion,
    };
  }

  /// Create from JSON
  factory SummaryRequest.fromJson(Map<String, dynamic> json) {
    return SummaryRequest(
      user: CFUser.fromMap(json['user'] as Map<String, dynamic>),
      summaries: (json['summaries'] as List<dynamic>)
          .map((s) => CFConfigRequestSummary.fromMap(s as Map<String, dynamic>))
          .toList(),
      cfClientSdkVersion: json['cf_client_sdk_version'] as String,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Get number of summaries
  int get summaryCount => summaries.length;

  /// Check if request is empty
  bool get isEmpty => summaries.isEmpty;

  /// Get estimated payload size in bytes
  int get estimatedSizeBytes => toJsonString().length;

  @override
  String toString() =>
      'SummaryRequest(user: ${user.userCustomerId}, summaryCount: $summaryCount)';
}
