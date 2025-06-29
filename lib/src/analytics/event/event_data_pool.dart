// lib/src/analytics/event/event_data_pool.dart
//
// Object pool for EventData instances to reduce GC pressure.
// This pool reuses EventData objects to minimize allocation overhead
// during high-frequency event tracking scenarios.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:collection';
import 'package:uuid/uuid.dart';
import '../../logging/logger.dart';
import 'event_data.dart';
import 'event_type.dart';

/// Object pool for reusing EventData instances
class EventDataPool {
  static const _source = 'EventDataPool';

  /// Maximum pool size to prevent excessive memory usage
  static const int _maxPoolSize = 100; // CFConstants.objectPool.maxEventDataPoolSize

  /// Minimum pool size to maintain ready instances
  static const int _minPoolSize = 10; // CFConstants.objectPool.minEventDataPoolSize

  /// Pool of available EventData instances
  final Queue<_PooledEventData> _pool = Queue<_PooledEventData>();

  /// UUID generator (reused to avoid creating new instances)
  final Uuid _uuid = const Uuid();

  /// String interning cache for common values to reduce memory usage
  final Map<String, String> _stringCache = <String, String>{};
  static const int _maxStringCacheSize = 1000; // CFConstants.objectPool.maxStringCacheSize

  /// Statistics for monitoring pool effectiveness
  int _totalAllocations = 0;
  int _poolHits = 0;
  int _poolMisses = 0;
  int _stringCacheHits = 0;
  int _stringCacheMisses = 0;

  /// Singleton instance
  static EventDataPool? _instance;
  static EventDataPool get instance => _instance ??= EventDataPool._();

  EventDataPool._() {
    // Pre-populate pool with minimum instances
    _prewarmPool();
  }

  /// Pre-populate the pool with minimum instances
  void _prewarmPool() {
    for (int i = 0; i < _minPoolSize; i++) {
      _pool.add(_PooledEventData());
    }
    Logger.d('$_source: Pre-warmed pool with $_minPoolSize instances');
  }

  /// Intern string to reduce memory usage for common values
  String _internString(String value) {
    if (value.isEmpty) return value;

    final cached = _stringCache[value];
    if (cached != null) {
      _stringCacheHits++;
      return cached;
    }

    // Prevent cache from growing too large
    if (_stringCache.length >= _maxStringCacheSize) {
      // Remove oldest entries (simple LRU approximation)
      final keysToRemove = _stringCache.keys.take(_maxStringCacheSize ~/ 4);
      for (final key in keysToRemove) {
        _stringCache.remove(key);
      }
    }

    _stringCache[value] = value;
    _stringCacheMisses++;
    return value;
  }

  /// Acquire an EventData instance from the pool
  EventData acquire({
    required String eventCustomerId,
    required EventType eventType,
    Map<String, dynamic> properties = const {},
    required String sessionId,
    int? eventTimestamp,
  }) {
    _totalAllocations++;

    _PooledEventData pooledData;

    // Try to get from pool
    if (_pool.isNotEmpty) {
      pooledData = _pool.removeFirst();
      _poolHits++;
    } else {
      // Pool is empty, create new instance
      pooledData = _PooledEventData();
      _poolMisses++;
    }

    // Configure the instance with new data
    final eventId = _uuid.v4();
    final timestamp = eventTimestamp ?? DateTime.now().millisecondsSinceEpoch;

    // Intern common strings to reduce memory usage
    final internedCustomerId = _internString(eventCustomerId);
    final internedSessionId = _internString(sessionId);

    pooledData._configure(
      eventId: eventId,
      eventCustomerId: internedCustomerId,
      eventType: eventType,
      properties: properties,
      sessionId: internedSessionId,
      eventTimestamp: timestamp,
    );

    // Log pool statistics periodically
    if (_totalAllocations % 1000 == 0) {
      _logStatistics();
    }

    return pooledData;
  }

  /// Acquire multiple EventData instances efficiently (batch operation)
  List<EventData> acquireBatch({
    required List<String> eventCustomerIds,
    required List<EventType> eventTypes,
    required List<Map<String, dynamic>> propertiesList,
    required String sessionId,
    int? baseTimestamp,
  }) {
    if (eventCustomerIds.length != eventTypes.length ||
        eventCustomerIds.length != propertiesList.length) {
      throw ArgumentError('All lists must have the same length');
    }

    final result = <EventData>[];
    final internedSessionId = _internString(sessionId);
    final timestamp = baseTimestamp ?? DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < eventCustomerIds.length; i++) {
      _totalAllocations++;

      _PooledEventData pooledData;

      // Try to get from pool
      if (_pool.isNotEmpty) {
        pooledData = _pool.removeFirst();
        _poolHits++;
      } else {
        // Pool is empty, create new instance
        pooledData = _PooledEventData();
        _poolMisses++;
      }

      // Configure the instance with new data
      final eventId = _uuid.v4();
      final internedCustomerId = _internString(eventCustomerIds[i]);

      pooledData._configure(
        eventId: eventId,
        eventCustomerId: internedCustomerId,
        eventType: eventTypes[i],
        properties: propertiesList[i],
        sessionId: internedSessionId,
        eventTimestamp: timestamp + i, // Slight offset to ensure uniqueness
      );

      result.add(pooledData);
    }

    // Log pool statistics periodically
    if (_totalAllocations % 1000 == 0) {
      _logStatistics();
    }

    return result;
  }

  /// Release an EventData instance back to the pool
  void release(EventData eventData) {
    // Only accept instances created by this pool
    if (eventData is! _PooledEventData) {
      return;
    }

    // Don't exceed maximum pool size
    if (_pool.length >= _maxPoolSize) {
      return;
    }

    // Reset the instance
    eventData._reset();

    // Return to pool
    _pool.add(eventData);
  }

  /// Release multiple EventData instances efficiently (batch operation)
  void releaseBatch(List<EventData> events) {
    for (final event in events) {
      // Only accept instances created by this pool
      if (event is! _PooledEventData) {
        continue;
      }

      // Don't exceed maximum pool size
      if (_pool.length >= _maxPoolSize) {
        break;
      }

      // Reset the instance
      event._reset();

      // Return to pool
      _pool.add(event);
    }
  }

  /// Clear the pool and release all instances
  void clear() {
    _pool.clear();
    _stringCache.clear();
    Logger.d('$_source: Pool and string cache cleared');
  }

  /// Get pool statistics
  Map<String, dynamic> getStatistics() {
    final hitRate = _totalAllocations > 0
        ? (_poolHits / _totalAllocations * 100).toStringAsFixed(1)
        : '0.0';

    final stringCacheHitRate = (_stringCacheHits + _stringCacheMisses) > 0
        ? (_stringCacheHits / (_stringCacheHits + _stringCacheMisses) * 100)
            .toStringAsFixed(1)
        : '0.0';

    return {
      'poolSize': _pool.length,
      'totalAllocations': _totalAllocations,
      'poolHits': _poolHits,
      'poolMisses': _poolMisses,
      'hitRate': '$hitRate%',
      'stringCacheSize': _stringCache.length,
      'stringCacheHits': _stringCacheHits,
      'stringCacheMisses': _stringCacheMisses,
      'stringCacheHitRate': '$stringCacheHitRate%',
    };
  }

  /// Log pool statistics
  void _logStatistics() {
    final stats = getStatistics();
    Logger.d('$_source: Pool stats - '
        'Size: ${stats['poolSize']}, '
        'Hit rate: ${stats['hitRate']}, '
        'Total: ${stats['totalAllocations']}, '
        'String cache: ${stats['stringCacheSize']} entries, '
        'String hit rate: ${stats['stringCacheHitRate']}');
  }

  /// Reset the singleton instance (for testing)
  static void reset() {
    _instance?.clear();
    _instance = null;
  }
}

/// Pooled EventData implementation that can be reconfigured
class _PooledEventData extends EventData {
  // Mutable fields that can be reconfigured
  late String _eventId;
  late String _eventCustomerId;
  late EventType _eventType;
  late Map<String, dynamic> _properties;
  late String _sessionId;
  late int _eventTimestamp;

  _PooledEventData()
      : super(
          eventId: '',
          eventCustomerId: '',
          eventType: EventType.track,
          properties: const {},
          sessionId: '',
          eventTimestamp: 0,
        );

  // Override getters to return mutable fields
  @override
  String get eventId => _eventId;

  @override
  String get eventCustomerId => _eventCustomerId;

  @override
  EventType get eventType => _eventType;

  @override
  Map<String, dynamic> get properties => _properties;

  @override
  String get sessionId => _sessionId;

  @override
  int get eventTimestamp => _eventTimestamp;

  /// Configure this instance with new data
  void _configure({
    required String eventId,
    required String eventCustomerId,
    required EventType eventType,
    required Map<String, dynamic> properties,
    required String sessionId,
    required int eventTimestamp,
  }) {
    _eventId = eventId;
    _eventCustomerId = eventCustomerId;
    _eventType = eventType;
    // Create a copy of properties to avoid external modifications
    _properties = Map<String, dynamic>.from(properties);
    _sessionId = sessionId;
    _eventTimestamp = eventTimestamp;
  }

  /// Reset this instance for reuse
  void _reset() {
    _eventId = '';
    _eventCustomerId = '';
    _eventType = EventType.track;
    _properties = const {};
    _sessionId = '';
    _eventTimestamp = 0;
  }
}

/// Extension on EventData for pool integration
extension EventDataPoolExtension on EventData {
  /// Create an EventData using the object pool
  static EventData createPooled({
    required String eventCustomerId,
    required EventType eventType,
    Map<String, dynamic> properties = const {},
    required String sessionId,
    int? eventTimestamp,
  }) {
    return EventDataPool.instance.acquire(
      eventCustomerId: eventCustomerId,
      eventType: eventType,
      properties: properties,
      sessionId: sessionId,
      eventTimestamp: eventTimestamp,
    );
  }

  /// Create multiple EventData instances using the object pool (batch operation)
  static List<EventData> createBatchPooled({
    required List<String> eventCustomerIds,
    required List<EventType> eventTypes,
    required List<Map<String, dynamic>> propertiesList,
    required String sessionId,
    int? baseTimestamp,
  }) {
    return EventDataPool.instance.acquireBatch(
      eventCustomerIds: eventCustomerIds,
      eventTypes: eventTypes,
      propertiesList: propertiesList,
      sessionId: sessionId,
      baseTimestamp: baseTimestamp,
    );
  }

  /// Release this EventData back to the pool
  void release() {
    EventDataPool.instance.release(this);
  }

  /// Release multiple EventData instances back to the pool (batch operation)
  static void releaseBatch(List<EventData> events) {
    EventDataPool.instance.releaseBatch(events);
  }
}
