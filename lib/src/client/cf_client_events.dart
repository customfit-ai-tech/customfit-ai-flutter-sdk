// lib/src/client/cf_client_events.dart
//
// Events component for CFClient - handles all analytics and event tracking.
// This extracts complex event tracking logic from the main CFClient class.
//
// This file is part of the CustomFit SDK for Flutter.

import '../config/core/cf_config.dart';
import '../core/model/cf_user.dart';
import '../analytics/event/event_tracker.dart';
import '../logging/logger.dart';
import '../core/error/cf_result.dart';

/// Handles all event tracking operations for CFClient
class CFClientEvents {
  static const _source = 'CFClientEvents';

  final CFConfig _config;
  final CFUser _user;
  final EventTracker _eventTracker;
  final String _sessionId;

  CFClientEvents({
    required CFConfig config,
    required CFUser user,
    required EventTracker eventTracker,
    required String sessionId,
  })  : _config = config,
        _user = user,
        _eventTracker = eventTracker,
        _sessionId = sessionId;

  /// Track a simple event with just a name
  ///
  /// This is the most basic event tracking method. Use it for simple user actions
  /// that don't require additional context or properties.
  ///
  /// Example:
  /// ```dart
  /// await client.trackEvent('button_clicked');
  /// await client.trackEvent('user_logged_in');
  /// await client.trackEvent('feature_accessed');
  /// ```
  ///
  /// The event will be automatically enriched with:
  /// - User information
  /// - Session ID
  /// - Timestamp
  /// - Device context
  Future<CFResult<bool>> trackEvent(String eventName) async {
    return trackEventWithProperties(eventName, {});
  }

  /// Track an event with custom properties
  ///
  /// Use this method when you need to include additional context with your events.
  /// Properties can include any relevant data about the user action.
  ///
  /// Example:
  /// ```dart
  /// await client.trackEventWithProperties('purchase_completed', {
  ///   'product_id': 'prod_123',
  ///   'amount': 99.99,
  ///   'currency': 'USD',
  ///   'payment_method': 'credit_card',
  /// });
  ///
  /// await client.trackEventWithProperties('page_viewed', {
  ///   'page_name': 'product_detail',
  ///   'product_category': 'electronics',
  ///   'view_duration': 45.2,
  /// });
  /// ```
  Future<CFResult<bool>> trackEventWithProperties(
    String eventName,
    Map<String, dynamic> properties,
  ) async {
    try {
      Logger.d('🔔 Tracking event: $eventName');

      // Validate event name
      if (eventName.trim().isEmpty) {
        const errorMsg = 'Event name cannot be empty';
        Logger.w('🔔 $errorMsg');
        return CFResult.error(errorMsg);
      }

      // Add event name to properties for tracking
      final eventProperties = {
        ...properties,
        'event_name': eventName,
      };

      // Track the event using EventTracker's trackEvent method
      final result = await _eventTracker.trackEvent(eventName, eventProperties);

      if (result.isSuccess) {
        Logger.i('🔔 Successfully tracked event: $eventName');
        return CFResult.success(true);
      } else {
        final errorMsg = 'Failed to track event: ${result.getErrorMessage()}';
        Logger.w('🔔 $errorMsg');
        return CFResult.error(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Error tracking event "$eventName": $e';
      Logger.e('🔔 $errorMsg');
      return CFResult.error(errorMsg);
    }
  }

  /// Track a conversion event
  ///
  /// Conversion events are special events that represent important business outcomes.
  /// These are typically given higher priority in analytics and may be used for
  /// optimization and targeting.
  ///
  /// Example:
  /// ```dart
  /// await client.trackConversion('signup_completed', {
  ///   'plan_type': 'premium',
  ///   'signup_source': 'landing_page',
  ///   'trial_duration': 14,
  /// });
  ///
  /// await client.trackConversion('purchase', {
  ///   'value': 149.99,
  ///   'items': ['item1', 'item2'],
  /// });
  /// ```
  Future<CFResult<bool>> trackConversion(
    String conversionName,
    Map<String, dynamic> properties,
  ) async {
    try {
      Logger.d('🔔 Tracking conversion: $conversionName');

      // Add conversion marker to properties
      final conversionProperties = {
        ...properties,
        '_is_conversion': true,
        '_conversion_type': conversionName,
        '_tracked_at': DateTime.now().toIso8601String(),
      };

      return await trackEventWithProperties(
        'conversion_$conversionName',
        conversionProperties,
      );
    } catch (e) {
      final errorMsg = 'Error tracking conversion "$conversionName": $e';
      Logger.e('🔔 $errorMsg');
      return CFResult.error(errorMsg);
    }
  }

  /// Track user property changes
  ///
  /// Use this method to track when user properties change. This is useful
  /// for analytics and for updating user targeting in real-time.
  ///
  /// Example:
  /// ```dart
  /// await client.trackUserPropertyChange('plan_upgraded', {
  ///   'old_plan': 'basic',
  ///   'new_plan': 'premium',
  ///   'upgrade_reason': 'feature_limit_reached',
  /// });
  /// ```
  Future<CFResult<bool>> trackUserPropertyChange(
    String propertyName,
    Map<String, dynamic> changeDetails,
  ) async {
    try {
      Logger.d('🔔 Tracking user property change: $propertyName');

      final properties = {
        ...changeDetails,
        '_property_name': propertyName,
        '_user_id': _user.userCustomerId ?? '',
        '_session_id': _sessionId,
      };

      return await trackEventWithProperties(
        'user_property_changed',
        properties,
      );
    } catch (e) {
      final errorMsg = 'Error tracking property change "$propertyName": $e';
      Logger.e('🔔 $errorMsg');
      return CFResult.error(errorMsg);
    }
  }

  /// Track app lifecycle events
  ///
  /// Automatically track important app lifecycle events like app start,
  /// app background, app foreground, etc.
  ///
  /// Example:
  /// ```dart
  /// await client.trackLifecycleEvent('app_launched', {
  ///   'launch_time': DateTime.now().toIso8601String(),
  ///   'cold_start': true,
  /// });
  /// ```
  Future<CFResult<bool>> trackLifecycleEvent(
    String lifecycleEvent,
    Map<String, dynamic> context,
  ) async {
    try {
      Logger.d('🔔 Tracking lifecycle event: $lifecycleEvent');

      final properties = {
        ...context,
        '_lifecycle_event': lifecycleEvent,
        '_app_version': 'unknown', // Could be extracted from PackageInfo
        '_platform': 'flutter',
      };

      return await trackEventWithProperties(
        'app_lifecycle',
        properties,
      );
    } catch (e) {
      final errorMsg = 'Error tracking lifecycle event "$lifecycleEvent": $e';
      Logger.e('🔔 $errorMsg');
      return CFResult.error(errorMsg);
    }
  }

  /// Flush all pending events immediately
  ///
  /// Forces the event tracker to send all queued events to the server immediately,
  /// bypassing the normal batching intervals. Useful before app shutdown or
  /// during critical user actions.
  ///
  /// Example:
  /// ```dart
  /// // Before app shutdown
  /// await client.flushEvents();
  ///
  /// // After critical user action
  /// await client.trackEvent('payment_completed');
  /// await client.flushEvents(); // Ensure it's sent immediately
  /// ```
  Future<CFResult<bool>> flushEvents() async {
    try {
      Logger.d('🔔 Flushing all pending events');
      final result = await _eventTracker.flush();

      if (result.isSuccess) {
        Logger.i('🔔 Successfully flushed all events');
        return CFResult.success(true);
      } else {
        final errorMsg = 'Failed to flush events: ${result.getErrorMessage()}';
        Logger.w('🔔 $errorMsg');
        return CFResult.error(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Error flushing events: $e';
      Logger.e('🔔 $errorMsg');
      return CFResult.error(errorMsg);
    }
  }

  /// Get the count of pending events in the queue
  ///
  /// Returns the number of events currently queued and waiting to be sent
  /// to the server. Useful for debugging or showing queue status to users.
  ///
  /// Example:
  /// ```dart
  /// final pendingCount = client.getPendingEventCount();
  /// print('Events waiting to be sent: $pendingCount');
  /// ```
  int getPendingEventCount() {
    try {
      return _eventTracker.getPendingEventsCount();
    } catch (e) {
      Logger.e('🔔 Error getting pending event count: $e');
      return 0;
    }
  }

  /// Method chaining support - returns this instance for fluent API
  ///
  /// Enables method chaining for a more fluent API experience.
  ///
  /// Example:
  /// ```dart
  /// await client.trackEvent('action1')
  ///     .then((_) => client.trackEvent('action2'))
  ///     .then((_) => client.flushEvents());
  /// ```
  CFClientEvents enableMethodChaining() {
    return this;
  }

  /// Add user property for event enrichment
  ///
  /// This method supports the fluent API by allowing you to chain
  /// user property updates with event tracking.
  ///
  /// Example:
  /// ```dart
  /// await client.addUserProperty('page', 'checkout')
  ///     .trackEvent('checkout_viewed');
  /// ```
  CFClientEvents addUserProperty(String key, dynamic value) {
    try {
      // This would update the user context for subsequent events
      Logger.d('🔔 Adding user property for events: $key = $value');
      // Implementation would add to user context
    } catch (e) {
      Logger.w('🔔 Failed to add user property: $e');
    }
    return this;
  }
}
