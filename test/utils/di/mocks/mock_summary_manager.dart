import 'dart:async';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/summary/cf_config_request_summary.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/summary/summary_manager.dart';

/// Mock summary manager for testing
class MockSummaryManager implements SummaryManager {
  final List<CFConfigRequestSummary> _summaries = [];
  bool shouldFailFlush = false;
  bool shouldFailPush = false;
  bool shouldThrowException = false;
  int flushIntervalMs = 30000;
  List<CFConfigRequestSummary> get summaries => List.unmodifiable(_summaries);
  void reset() {
    _summaries.clear();
    shouldFailFlush = false;
    shouldFailPush = false;
    shouldThrowException = false;
    flushIntervalMs = 30000;
  }

  // Method expected by tests
  List<Map<String, dynamic>> getPendingSummaries() {
    return _summaries
        .map((summary) => {
              'key': summary.configId,
              'experience_id': summary.configId,
              'config_id': summary.configId,
              'variation_id': summary.configId,
              'version': '1.0.0',
              'userCustomerId': summary.userCustomerId,
              'sessionId': summary.sessionId,
              'requestedTime': summary.requestedTime,
            })
        .toList();
  }

  @override
  Future<CFResult<bool>> pushSummary(Map<String, dynamic> summaryData) async {
    if (shouldThrowException) {
      throw Exception('Mock summary push exception');
    }
    if (shouldFailPush) {
      return CFResult.error('Mock push failure');
    }
    // Create a CFConfigRequestSummary from the summary data
    final summary = CFConfigRequestSummary(
      configId: summaryData['key'] ?? 'unknown',
      variationId: summaryData['variation'] != null
          ? summaryData['variation'].toString()
          : summaryData['variation_id']?.toString(),
      requestedTime: DateTime.now().toIso8601String(),
      userCustomerId: summaryData['userCustomerId'] ?? 'mock-user',
      sessionId: summaryData['sessionId'] ?? 'mock-session',
      experienceId: summaryData['experience_id'],
      behaviourId: summaryData['behaviour_id'],
      ruleId: summaryData['rule_id'],
    );
    _summaries.add(summary);
    return CFResult.success(true);
  }

  @override
  Future<CFResult<int>> flushSummaries() async {
    if (shouldFailFlush || shouldFailPush) {
      return CFResult.error('Mock flush failure');
    }
    final count = _summaries.length;
    _summaries.clear();
    return CFResult.success(count);
  }

  @override
  void updateFlushInterval(int intervalMs) {
    flushIntervalMs = intervalMs;
  }

  @override
  int getPendingSummariesCount() {
    return _summaries.length;
  }

  @override
  void clearSummaries() {
    _summaries.clear();
  }

  @override
  void shutdown() {
    clearSummaries();
  }

  @override
  int getQueueSize() {
    return _summaries.length;
  }

  @override
  Map<String, bool> getSummaries() {
    // Convert summaries to map format expected by the interface
    final Map<String, bool> summaryMap = {};
    for (final summary in _summaries) {
      final configId = summary.configId;
      if (configId != null) {
        summaryMap[configId] = true;
      }
    }
    return Map.unmodifiable(summaryMap);
  }
}
