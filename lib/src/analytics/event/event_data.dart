import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'event_type.dart';
import 'event_data_pool.dart';
import '../../core/util/type_conversion_strategy.dart';
import '../../utils/timestamp_util.dart';

/// Represents event data to be sent to the backend
class EventData {
  /// Unique identifier for the event
  final String eventId;

  /// Customer ID associated with the event
  final String eventCustomerId;

  /// Type of the event
  final EventType eventType;

  /// Properties/attributes associated with the event
  final Map<String, dynamic> properties;

  /// Session ID for the event
  final String sessionId;

  /// Timestamp when the event occurred
  final int eventTimestamp;

  /// Creates a new event data instance
  EventData({
    required this.eventId,
    required this.eventCustomerId,
    required this.eventType,
    this.properties = const {},
    required this.sessionId,
    required this.eventTimestamp,
  });

  /// Factory method to create an event with automatically generated values where needed
  /// Uses object pooling to reduce GC pressure
  static EventData create({
    required String eventCustomerId,
    required EventType eventType,
    Map<String, dynamic> properties = const {},
    required String sessionId,
    int? eventTimestamp,
    bool usePool = true,
  }) {
    // Use object pool by default to reduce allocations
    if (usePool) {
      return EventDataPoolExtension.createPooled(
        eventCustomerId: eventCustomerId,
        eventType: eventType,
        properties: properties,
        sessionId: sessionId,
        eventTimestamp: eventTimestamp,
      );
    }

    // Fallback to direct allocation if pool is disabled
    const uuid = Uuid();
    return EventData(
      eventId: uuid.v4(),
      eventCustomerId: eventCustomerId,
      eventType: eventType,
      properties: properties,
      sessionId: sessionId,
      eventTimestamp: eventTimestamp ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Convert this event to a JSON map
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventCustomerId': eventCustomerId,
      'eventType': eventType.name,
      'properties': properties,
      'sessionId': sessionId,
      'eventTimestamp': eventTimestamp,
    };
  }

  /// Create an EventData instance from a JSON map
  factory EventData.fromMap(Map<String, dynamic> map) {
    return EventData(
      eventId:
          SafeTypeConverter.convertWithFallback<String>(map['eventId'], ''),
      eventCustomerId: SafeTypeConverter.convertWithFallback<String>(
          map['eventCustomerId'], ''),
      eventType: EventTypeExtension.fromString(
          SafeTypeConverter.convertWithFallback<String>(
              map['eventType'], 'UNKNOWN')),
      properties: SafeTypeConverter.convertWithFallback<Map<String, dynamic>>(
          map['properties'], <String, dynamic>{}),
      sessionId:
          SafeTypeConverter.convertWithFallback<String>(map['sessionId'], ''),
      eventTimestamp:
          SafeTypeConverter.convertWithFallback<int>(map['eventTimestamp'], 0),
    );
  }

  /// Convert to JSON-compatible map (alias for toMap)
  Map<String, dynamic> toJson() => toMap();

  /// Create from JSON map
  factory EventData.fromJson(Map<String, dynamic> json) =>
      EventData.fromMap(json);

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toMap());

  /// Create from JSON string
  factory EventData.fromJsonString(String source) =>
      EventData.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// Serialize for API with proper field names and formatting
  /// This ensures compatibility with backend expectations
  Map<String, dynamic> serializeForAPI() {
    // Format timestamp to match expected format: "yyyy-MM-dd HH:mm:ss.SSSX"
    final dateTime =
        DateTime.fromMillisecondsSinceEpoch(eventTimestamp, isUtc: true);
    final formattedTimestamp = TimestampUtil.formatForAPI(dateTime);

    // Debug logging removed for production

    return {
      'insert_id': eventId, // eventId -> insert_id
      'event_customer_id':
          eventCustomerId, // eventCustomerId -> event_customer_id
      'event_type': eventType.name.toUpperCase(), // Ensure uppercase
      'properties': properties,
      'session_id': sessionId, // sessionId -> session_id
      'event_timestamp': formattedTimestamp, // Format timestamp properly
    };
  }
}
