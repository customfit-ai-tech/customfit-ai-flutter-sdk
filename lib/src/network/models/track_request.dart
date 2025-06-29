import 'dart:convert';
import '../../core/model/cf_user.dart';
import '../../analytics/event/event_data.dart';

/// Strongly typed request model for event tracking operations
class TrackRequest {
  /// User information
  final CFUser user;

  /// List of events to track
  final List<EventData> events;

  /// SDK version
  final String cfClientSdkVersion;

  const TrackRequest({
    required this.user,
    required this.events,
    required this.cfClientSdkVersion,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'user': user.toMap(),
      'events': events.map((e) => e.serializeForAPI()).toList(),
      'cf_client_sdk_version': cfClientSdkVersion,
    };
  }

  /// Create from JSON
  factory TrackRequest.fromJson(Map<String, dynamic> json) {
    return TrackRequest(
      user: CFUser.fromMap(json['user'] as Map<String, dynamic>),
      events: (json['events'] as List<dynamic>)
          .map((e) => EventData.fromJson(e as Map<String, dynamic>))
          .toList(),
      cfClientSdkVersion: json['cf_client_sdk_version'] as String,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Get number of events
  int get eventCount => events.length;

  /// Check if request is empty
  bool get isEmpty => events.isEmpty;

  /// Get estimated payload size in bytes
  int get estimatedSizeBytes => toJsonString().length;

  /// Get events by type
  List<EventData> getEventsByType(String eventType) {
    return events.where((e) => e.eventType.name == eventType).toList();
  }

  /// Get unique session IDs
  Set<String> get sessionIds => events.map((e) => e.sessionId).toSet();

  /// Get unique customer IDs
  Set<String> get customerIds => events.map((e) => e.eventCustomerId).toSet();

  @override
  String toString() =>
      'TrackRequest(user: ${user.userCustomerId}, eventCount: $eventCount)';
}
