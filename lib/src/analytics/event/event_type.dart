/// Represents the type of events that can be tracked
enum EventType {
  /// Track custom event
  track;

  /// Gets the string name of the event type
  String get name {
    switch (this) {
      case EventType.track:
        return 'track';
    }
  }
}

/// Extension methods for EventType
extension EventTypeExtension on EventType {
  /// Convert an event type string to EventType enum
  static EventType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'track':
        return EventType.track;
      default:
        return EventType.track; // Default to track for any unrecognized value
    }
  }
}
