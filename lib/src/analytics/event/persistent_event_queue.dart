import 'dart:async';
import 'dart:convert';
import '../../logging/logger.dart';
import '../../core/util/storage_abstraction.dart';
import 'event_data.dart';
import 'event_queue.dart';

/// A persistent event queue that saves events to disk and restores them on app restart
class PersistentEventQueue extends EventQueue {
  static const String _storageKey = 'cf_event_queue';
  static const String _source = 'PersistentEventQueue';
  static const int _maxStoredEvents =
      1000; // CFConstants.eventDefaults.maxStoredEvents
  static const Duration _persistenceTimeout = Duration(
      seconds: 5); // CFConstants.eventDefaults.persistenceTimeoutSeconds

  /// Timer for debouncing persistence operations
  Timer? _persistenceTimer;

  /// Flag to track if we need to persist
  bool _needsPersistence = false;

  /// Track if we're currently persisting
  bool _isPersisting = false;

  /// Track last persisted event count for optimization
  int _lastPersistedCount = 0;

  /// Storage configuration for secure storage support
  StorageConfig? _storageConfig;

  /// Create a new persistent event queue
  PersistentEventQueue({
    super.maxQueueSize,
    super.onEventsDropped,
  }) {
    // Initialize storage config and load persisted events on initialization
    _initializeStorage();
  }

  /// Initialize storage configuration
  Future<void> _initializeStorage() async {
    try {
      // Check if we're in a test environment and use test config
      try {
        _storageConfig = StorageManager.config;
      } catch (e) {
        // StorageManager not configured, create default
        _storageConfig = await StorageManager.createDefaultConfig();
      }
    } catch (e) {
      Logger.w(
          '$_source: Failed to initialize storage config, using fallback: $e');
      // Create a minimal fallback config for testing
      _storageConfig = StorageConfig(
        keyValueStorage: InMemoryKeyValueStorage(),
        fileStorage: InMemoryFileStorage(),
      );
    }
    // Load persisted events regardless of storage config availability
    _loadPersistedEvents();
  }

  @override
  void addEvent(EventData event) {
    super.addEvent(event);
    // For critical events, persist immediately
    if (_shouldPersistImmediately(event)) {
      _persistEventsImmediately();
    } else {
      _schedulePersistence();
    }
  }

  @override
  void addEvents(List<EventData> events) {
    super.addEvents(events);
    // Check if any critical events
    if (events.any((e) => _shouldPersistImmediately(e))) {
      _persistEventsImmediately();
    } else {
      _schedulePersistence();
    }
  }

  @override
  List<EventData> popAllEvents() {
    final events = super.popAllEvents();
    if (events.isNotEmpty) {
      _schedulePersistence();
    }
    return events;
  }

  @override
  List<EventData> popEventBatch(int batchSize) {
    final events = super.popEventBatch(batchSize);
    if (events.isNotEmpty) {
      _schedulePersistence();
    }
    return events;
  }

  @override
  void clear() {
    super.clear();
    _clearPersistedEvents();
  }

  /// Check if event should be persisted immediately
  bool _shouldPersistImmediately(EventData event) {
    // Persist immediately for critical events like purchases, errors, or session events
    final criticalTypes = [
      'purchase',
      'error',
      'crash',
      'session_end',
      'app_terminate'
    ];
    // Check both event type name and customer ID for critical patterns
    final eventTypeName = event.eventType.name.toLowerCase();
    final customerIdLower = event.eventCustomerId.toLowerCase();
    final shouldPersist = criticalTypes.any((type) =>
        eventTypeName.contains(type) || customerIdLower.contains(type));

    return shouldPersist;
  }

  /// Schedule persistence operation with debouncing
  void _schedulePersistence() {
    _needsPersistence = true;

    // Cancel existing timer
    _persistenceTimer?.cancel();

    // Use shorter delay for better reliability
    _persistenceTimer = Timer(
        const Duration(
            milliseconds: 100), () { // persistenceDebounceMs
      if (_needsPersistence) {
        _persistEvents();
      }
    });
  }

  /// Persist events immediately without debouncing
  Future<void> _persistEventsImmediately() async {
    _persistenceTimer?.cancel();
    await _persistEvents();
  }

  /// Load persisted events from storage with validation
  Future<void> _loadPersistedEvents() async {
    try {
      String? jsonString;

      if (_storageConfig == null) {
        Logger.w(
            '$_source: Storage not initialized, cannot load persisted events');
        return;
      }

      // Try secure storage first, fall back to regular storage
      try {
        if (_storageConfig!.hasSecureStorage) {
          jsonString = await _storageConfig!.getSecureString(_storageKey);
        } else {
          jsonString =
              await _storageConfig!.keyValueStorage.getString(_storageKey);
        }
      } catch (e) {
        Logger.w(
            '$_source: Secure storage not available, falling back to regular storage: $e');
        jsonString =
            await _storageConfig!.keyValueStorage.getString(_storageKey);
      }

      if (jsonString != null && jsonString.isNotEmpty) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        final now = DateTime.now();
        final validEvents = <EventData>[];
        int corruptedEventCount = 0;
        int expiredEventCount = 0;

        // Validate and filter events
        for (final json in jsonList) {
          try {
            if (json is! Map<String, dynamic>) {
              corruptedEventCount++;
              Logger.w(
                  '$_source: Skipping non-map event data: ${json.runtimeType}');
              continue;
            }

            // Validate required fields before creating EventData
            if (!_validateEventJson(json)) {
              corruptedEventCount++;
              Logger.w(
                  '$_source: Skipping invalid event structure: missing required fields');
              continue;
            }

            final event = EventData.fromJson(json);

            // Skip events older than 7 days
            final eventDateTime =
                DateTime.fromMillisecondsSinceEpoch(event.eventTimestamp);
            final eventAge = now.difference(eventDateTime);
            if (eventAge.inDays <
                7) { // eventExpirationDays
              validEvents.add(event);
            } else {
              expiredEventCount++;
              Logger.d('$_source: Skipping expired event from $eventDateTime');
            }
          } catch (e) {
            corruptedEventCount++;
            Logger.w('$_source: Skipping corrupted event: $e');
          }
        }

        if (validEvents.isNotEmpty) {
          Logger.i(
              '$_source: Loaded ${validEvents.length} valid persisted events');
          if (corruptedEventCount > 0) {
            Logger.w('$_source: Skipped $corruptedEventCount corrupted events');
          }
          if (expiredEventCount > 0) {
            Logger.i('$_source: Skipped $expiredEventCount expired events');
          }
          super.addEvents(validEvents);
          _lastPersistedCount = validEvents.length;
        }

        // Clear storage after loading to prevent duplicates
        try {
          if (_storageConfig!.hasSecureStorage) {
            await _storageConfig!.removeSecure(_storageKey);
          } else {
            await _storageConfig!.keyValueStorage.remove(_storageKey);
          }
        } catch (e) {
          Logger.w(
              '$_source: Could not clear storage after loading, falling back to regular storage: $e');
          await _storageConfig!.keyValueStorage.remove(_storageKey);
        }
      }
    } on TimeoutException {
      Logger.e('$_source: Loading persisted events timed out');
    } on FormatException catch (e) {
      Logger.e('$_source: JSON parsing error in persisted events: $e');
      await _clearPersistedEvents(); // Clear corrupt data
    } catch (e) {
      Logger.e('$_source: Error loading persisted events: $e');
      // Clear corrupted data
      await _clearPersistedEvents();
    }
  }

  /// Validate event JSON structure
  bool _validateEventJson(Map<String, dynamic> json) {
    // Check for required fields
    final requiredFields = [
      'eventId',
      'eventCustomerId',
      'eventType',
      'sessionId',
      'eventTimestamp'
    ];
    for (final field in requiredFields) {
      if (!json.containsKey(field) || json[field] == null) {
        return false;
      }
    }

    // Validate data types
    if (json['eventId'] is! String ||
        json['eventCustomerId'] is! String ||
        json['eventType'] is! String ||
        json['sessionId'] is! String ||
        json['eventTimestamp'] is! int) {
      return false;
    }

    // Validate timestamp is reasonable (not too old, not in future)
    final timestamp = json['eventTimestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAge = const Duration(days: 30).inMilliseconds;
    final maxFuture = const Duration(hours: 1).inMilliseconds;

    if (timestamp < (now - maxAge) || timestamp > (now + maxFuture)) {
      return false;
    }

    return true;
  }

  /// Persist current events to storage with thread safety
  Future<void> _persistEvents() async {
    // Prevent concurrent persistence operations
    if (_isPersisting) {
      Logger.d('$_source: Persistence already in progress, skipping');
      return;
    }

    _isPersisting = true;
    _needsPersistence = false;

    try {
      // Get all events without removing them (thread-safe copy)
      final events = List<EventData>.from(super.toList());

      if (events.isEmpty) {
        if (_lastPersistedCount > 0) {
          await _clearPersistedEvents();
          _lastPersistedCount = 0;
        }
        return;
      }

      // Skip if nothing changed
      if (events.length == _lastPersistedCount) {
        Logger.d('$_source: No new events to persist');
        return;
      }

      // Limit stored events to prevent unbounded growth
      final eventsToStore = events.length > _maxStoredEvents
          ? events.sublist(events.length - _maxStoredEvents)
          : events;

      // Convert to JSON with proper serialization
      final jsonList = eventsToStore.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      // Save to storage with timeout
      if (_storageConfig == null) {
        Logger.e('$_source: Storage not initialized, cannot persist events');
        return;
      }

      bool success = false;
      try {
        if (_storageConfig!.hasSecureStorage) {
          success =
              await _storageConfig!.setSecureString(_storageKey, jsonString);
        } else {
          success = await _storageConfig!.keyValueStorage
              .setString(_storageKey, jsonString);
        }
      } catch (e) {
        Logger.w(
            '$_source: Secure storage not available, falling back to regular storage: $e');
        success = await _storageConfig!.keyValueStorage
            .setString(_storageKey, jsonString);
      }

      if (success) {
        _lastPersistedCount = eventsToStore.length;
        Logger.d(
            '$_source: Persisted ${eventsToStore.length} events successfully');
      } else {
        Logger.e('$_source: Failed to persist events to storage');
      }
    } on TimeoutException {
      Logger.e('$_source: Persistence operation timed out');
    } catch (e) {
      Logger.e('$_source: Error persisting events: $e');
    } finally {
      _isPersisting = false;
    }
  }

  /// Clear persisted events from storage
  Future<void> _clearPersistedEvents() async {
    try {
      if (_storageConfig == null) {
        Logger.w('$_source: Storage not initialized, cannot clear events');
        return;
      }

      try {
        if (_storageConfig!.hasSecureStorage) {
          await _storageConfig!.removeSecure(_storageKey);
        } else {
          await _storageConfig!.keyValueStorage.remove(_storageKey);
        }
      } catch (e) {
        Logger.w(
            '$_source: Secure storage not available, falling back to regular storage: $e');
        await _storageConfig!.keyValueStorage.remove(_storageKey);
      }
      Logger.d('$_source: Cleared persisted events');
    } on TimeoutException {
      Logger.e('$_source: Clearing persisted events timed out');
    } catch (e) {
      // In test environments, storage might not be available
      Logger.e('$_source: Error clearing persisted events: $e');
    }
  }

  /// Force immediate persistence (used on app termination)
  Future<void> forcePersist() async {
    _persistenceTimer?.cancel();
    if (size > 0) {
      await _persistEvents();
    }
  }

  /// Shutdown and cleanup
  Future<void> shutdown() async {
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    await forcePersist();
  }
}
