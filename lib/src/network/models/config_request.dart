import 'dart:convert';
import '../../core/model/cf_user.dart';

/// Strongly typed request model for config fetch operations
class ConfigRequest {
  /// User information for targeting
  final CFUser user;

  /// Whether to include only feature flags in the response
  final bool includeOnlyFeaturesFlags;

  const ConfigRequest({
    required this.user,
    this.includeOnlyFeaturesFlags = true,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user': user.toMap(),
      'include_only_features_flags': includeOnlyFeaturesFlags,
    };
  }

  /// Create from JSON
  factory ConfigRequest.fromJson(Map<String, dynamic> json) {
    return ConfigRequest(
      user: CFUser.fromMap(json['user'] as Map<String, dynamic>),
      includeOnlyFeaturesFlags:
          json['include_only_features_flags'] as bool? ?? true,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() =>
      'ConfigRequest(user: ${user.userCustomerId}, includeOnlyFeaturesFlags: $includeOnlyFeaturesFlags)';
}
