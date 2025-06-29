// lib/src/analytics/summary/cf_config_request_summary.dart

import 'dart:convert';
import '../../../src/core/util/type_conversion_strategy.dart';
import '../../utils/timestamp_util.dart';

/// Mirrors Kotlin's CFConfigRequestSummary data class
class CFConfigRequestSummary {
  final String? configId;
  final String? version;
  final String requestedTime;
  final String? variationId;
  final String userCustomerId;
  final String sessionId;
  final String? behaviourId;
  final String? experienceId;
  final String? ruleId;

  /// Timestamp for when this summary was created
  String get timestamp => requestedTime;

  // Note: Using manual formatting instead of DateFormat due to 'X' pattern issues
  // static final _formatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSSX');

  CFConfigRequestSummary({
    this.configId,
    this.version,
    required this.requestedTime,
    this.variationId,
    required this.userCustomerId,
    required this.sessionId,
    this.behaviourId,
    this.experienceId,
    this.ruleId,
  });

  /// Factory to construct from a config map, customer ID, and session ID
  factory CFConfigRequestSummary.fromConfig(
    Map<String, dynamic> config,
    String customerUserId,
    String sessionId,
  ) {
    return CFConfigRequestSummary(
      configId: SafeTypeConverter.convertWithFallback<String?>(
          config['config_id'], null),
      version: SafeTypeConverter.convertWithFallback<String?>(
          config['version'], null),
      requestedTime: TimestampUtil.formatForAPI(DateTime.now().toUtc()),
      variationId: SafeTypeConverter.convertWithFallback<String?>(
          config['variation_id'], null),
      userCustomerId: customerUserId,
      sessionId: sessionId,
      behaviourId: SafeTypeConverter.convertWithFallback<String?>(
          config['behaviour_id'], null),
      experienceId: SafeTypeConverter.convertWithFallback<String?>(
          config['experience_id'], null),
      ruleId: SafeTypeConverter.convertWithFallback<String?>(
          config['rule_id'], null),
    );
  }

  /// Convert to Map for JSON serialization
  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'config_id': configId,
      'version': version,
      'requested_time': requestedTime,
      'timestamp': requestedTime, // Add alias for test compatibility
      'variation_id': variationId,
      'user_customer_id': userCustomerId,
      'session_id': sessionId,
      'behaviour_id': behaviourId,
      'experience_id': experienceId,
      'rule_id': ruleId,
    };
    m.removeWhere((k, v) => v == null);
    return m;
  }

  /// Convert to JSON string
  String toJson() => jsonEncode(toMap());

  /// Factory to create from a Map
  factory CFConfigRequestSummary.fromMap(Map<String, dynamic> m) {
    return CFConfigRequestSummary(
      configId:
          SafeTypeConverter.convertWithFallback<String?>(m['config_id'], null),
      version:
          SafeTypeConverter.convertWithFallback<String?>(m['version'], null),
      requestedTime: SafeTypeConverter.convertWithFallback<String>(
          m['requested_time'], ''),
      variationId: SafeTypeConverter.convertWithFallback<String?>(
          m['variation_id'], null),
      userCustomerId: SafeTypeConverter.convertWithFallback<String>(
          m['user_customer_id'], ''),
      sessionId:
          SafeTypeConverter.convertWithFallback<String>(m['session_id'], ''),
      behaviourId: SafeTypeConverter.convertWithFallback<String?>(
          m['behaviour_id'], null),
      experienceId: SafeTypeConverter.convertWithFallback<String?>(
          m['experience_id'], null),
      ruleId:
          SafeTypeConverter.convertWithFallback<String?>(m['rule_id'], null),
    );
  }

  /// Generate a unique key for this summary
  String uniqueKey() {
    return '${configId ?? 'unknown'}_${experienceId ?? 'unknown'}_${variationId ?? 'unknown'}';
  }

  @override
  String toString() =>
      'CFConfigRequestSummary(configId: $configId, experienceId: $experienceId, variationId: $variationId)';
}
