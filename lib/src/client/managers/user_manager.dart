import 'package:flutter/foundation.dart';

import '../../core/model/cf_user.dart';
import '../../core/model/evaluation_context.dart';
import '../../core/model/context_type.dart';
import '../../core/model/device_context.dart';
import '../../core/model/application_info.dart';
import '../../logging/logger.dart';

import '../../core/error/cf_result.dart';
import '../../core/error/cf_result_extensions.dart';

/// Interface for UserManager
abstract class UserManager {
  /// Get the current user
  CFUser getUser();

  /// Update the current user
  CFResult<void> updateUser(CFUser user);

  /// Clear the current user by setting an anonymous user
  CFResult<void> clearUser();

  /// Add a property to the user
  CFResult<void> addUserProperty(String key, dynamic value);

  /// Add a string property to the user
  CFResult<void> addStringProperty(String key, String value);

  /// Add a number property to the user
  CFResult<void> addNumberProperty(String key, num value);

  /// Add a boolean property to the user
  CFResult<void> addBooleanProperty(String key, bool value);

  /// Add a JSON property to the user
  CFResult<void> addJsonProperty(String key, Map<String, dynamic> value);

  /// Add multiple properties to the user
  CFResult<void> addUserProperties(Map<String, dynamic> properties);

  /// Get all user properties
  Map<String, dynamic> getUserProperties();

  /// Add a context to the user
  CFResult<void> addContext(EvaluationContext context);

  /// Remove a context from the user
  CFResult<void> removeContext(ContextType type, String key);

  /// Update the device context
  CFResult<void> updateDeviceContext(DeviceContext deviceContext);

  /// Update the application info
  CFResult<void> updateApplicationInfo(ApplicationInfo applicationInfo);

  // Private property methods

  /// Add a private string property to the user
  CFResult<void> addPrivateStringProperty(String key, String value);

  /// Add a private number property to the user
  CFResult<void> addPrivateNumberProperty(String key, num value);

  /// Add a private boolean property to the user
  CFResult<void> addPrivateBooleanProperty(String key, bool value);

  /// Add a private map property to the user
  CFResult<void> addPrivateMapProperty(String key, Map<String, dynamic> value);

  /// Add a private JSON property to the user
  CFResult<void> addPrivateJsonProperty(String key, Map<String, dynamic> value);

  /// Remove a property from the user
  CFResult<void> removeProperty(String key);

  /// Remove multiple properties from the user
  CFResult<void> removeProperties(List<String> keys);

  /// Mark an existing property as private
  CFResult<void> markPropertyAsPrivate(String key);

  /// Mark multiple existing properties as private
  CFResult<void> markPropertiesAsPrivate(List<String> keys);

  /// Add a listener for user changes
  void addUserChangeListener(void Function(CFUser) listener);

  /// Remove a listener for user changes
  void removeUserChangeListener(void Function(CFUser) listener);

  /// Setup user change listeners
  /// This method centralizes the user change listener setup that was previously in CFClient
  void setupListeners({
    required void Function(CFUser) onUserChange,
  });
}

/// Implementation of UserManager
class UserManagerImpl implements UserManager {
  // Current user
  CFUser _user;

  // Listeners for user changes
  final List<void Function(CFUser)> _userChangeListeners = [];

  /// Create a new UserManagerImpl
  UserManagerImpl(CFUser initialUser) : _user = initialUser;

  @override
  CFUser getUser() {
    return _user;
  }

  @override
  CFResult<void> updateUser(CFUser user) {
    return CFResultExtensions.catching(
      () {
        _user = user;
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to update user',
    );
  }

  @override
  CFResult<void> clearUser() {
    return CFResultExtensions.catching(
      () {
        // Create anonymous user
        _user = CFUser.anonymousBuilder().build();
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to clear user',
    );
  }

  @override
  CFResult<void> addUserProperty(String key, dynamic value) {
    // SECURITY FIX: Validate property key and value using CFResult pattern
    final keyValidation = CFResultValidation.validatePropertyKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'UserManager: Property key validation failed: ${keyValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property key: ${keyValidation.getErrorMessage()}');
    }

    final valueValidation = CFResultValidation.validatePropertyValue(value);
    if (!valueValidation.isSuccess) {
      Logger.w(
          'UserManager: Property value validation failed: ${valueValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property value: ${valueValidation.getErrorMessage()}');
    }

    // Use validated inputs
    return CFResultExtensions.catching(
      () {
        final validatedKey = keyValidation.getOrThrow();
        final validatedValue = valueValidation.getOrThrow();
        _user = _user.addProperty(validatedKey, validatedValue);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to add user property',
    );
  }

  @override
  CFResult<void> addStringProperty(String key, String value) {
    return addUserProperty(key, value);
  }

  @override
  CFResult<void> addNumberProperty(String key, num value) {
    return addUserProperty(key, value);
  }

  @override
  CFResult<void> addBooleanProperty(String key, bool value) {
    return addUserProperty(key, value);
  }

  @override
  CFResult<void> addJsonProperty(String key, Map<String, dynamic> value) {
    return addUserProperty(key, value);
  }

  @override
  CFResult<void> addUserProperties(Map<String, dynamic> properties) {
    // SECURITY FIX: Validate all properties before processing using CFResult pattern
    final propertiesValidation =
        CFResultValidation.validateProperties(properties);
    if (!propertiesValidation.isSuccess) {
      Logger.w(
          'UserManager: User properties validation failed: ${propertiesValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid user properties: ${propertiesValidation.getErrorMessage()}');
    }

    return CFResultExtensions.catching(
      () {
        final validatedProperties = propertiesValidation.getOrThrow();
        for (final entry in validatedProperties.entries) {
          final result = addUserProperty(entry.key, entry.value);
          if (!result.isSuccess) {
            throw Exception(
                'Failed to add property ${entry.key}: ${result.getErrorMessage()}');
          }
        }
      },
      errorMessage: 'Failed to add user properties',
    );
  }

  @override
  Map<String, dynamic> getUserProperties() {
    return Map<String, dynamic>.from(_user.properties);
  }

  @override
  CFResult<void> addContext(EvaluationContext context) {
    return CFResultExtensions.catching(
      () {
        _user = _user.addContext(context);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to add context',
    );
  }

  @override
  CFResult<void> removeContext(ContextType type, String key) {
    return CFResultExtensions.catching(
      () {
        _user = _user.removeContext(type, key);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to remove context',
    );
  }

  @override
  CFResult<void> updateDeviceContext(DeviceContext deviceContext) {
    return CFResultExtensions.catching(
      () {
        _user = _user.withDeviceContext(deviceContext);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to update device context',
    );
  }

  @override
  CFResult<void> updateApplicationInfo(ApplicationInfo applicationInfo) {
    return CFResultExtensions.catching(
      () {
        _user = _user.withApplicationInfo(applicationInfo);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to update application info',
    );
  }

  /// Add a listener for user changes
  @override
  void addUserChangeListener(void Function(CFUser) listener) {
    _userChangeListeners.add(listener);
  }

  /// Remove a listener for user changes
  @override
  void removeUserChangeListener(void Function(CFUser) listener) {
    _userChangeListeners.remove(listener);
  }

  /// Notify listeners of user changes
  void _notifyUserChangeListeners() {
    for (final listener
        in List<void Function(CFUser)>.from(_userChangeListeners)) {
      try {
        listener(_user);
      } catch (e) {
        debugPrint('Error notifying user change listener: $e');
      }
    }
  }

  // Private property method implementations

  @override
  CFResult<void> addPrivateStringProperty(String key, String value) {
    // SECURITY FIX: Validate inputs before processing using CFResult pattern
    final keyValidation = CFResultValidation.validatePropertyKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'UserManager: Private string property key validation failed: ${keyValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property key: ${keyValidation.getErrorMessage()}');
    }

    final valueValidation = CFResultValidation.validatePropertyValue(value);
    if (!valueValidation.isSuccess) {
      Logger.w(
          'UserManager: Private string property value validation failed: ${valueValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property value: ${valueValidation.getErrorMessage()}');
    }

    return CFResultExtensions.catching(
      () {
        _user = _user.addStringProperty(
            keyValidation.getOrThrow(), valueValidation.getOrThrow() as String,
            isPrivate: true);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to add private string property',
    );
  }

  @override
  CFResult<void> addPrivateNumberProperty(String key, num value) {
    // SECURITY FIX: Validate inputs before processing using CFResult pattern
    final keyValidation = CFResultValidation.validatePropertyKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'UserManager: Private number property key validation failed: ${keyValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property key: ${keyValidation.getErrorMessage()}');
    }

    final valueValidation = CFResultValidation.validatePropertyValue(value);
    if (!valueValidation.isSuccess) {
      Logger.w(
          'UserManager: Private number property value validation failed: ${valueValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property value: ${valueValidation.getErrorMessage()}');
    }

    return CFResultExtensions.catching(
      () {
        _user = _user.addNumberProperty(
            keyValidation.getOrThrow(), valueValidation.getOrThrow() as num,
            isPrivate: true);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to add private number property',
    );
  }

  @override
  CFResult<void> addPrivateBooleanProperty(String key, bool value) {
    // SECURITY FIX: Validate inputs before processing using CFResult pattern
    final keyValidation = CFResultValidation.validatePropertyKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'UserManager: Private boolean property key validation failed: ${keyValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property key: ${keyValidation.getErrorMessage()}');
    }

    final valueValidation = CFResultValidation.validatePropertyValue(value);
    if (!valueValidation.isSuccess) {
      Logger.w(
          'UserManager: Private boolean property value validation failed: ${valueValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property value: ${valueValidation.getErrorMessage()}');
    }

    return CFResultExtensions.catching(
      () {
        _user = _user.addBooleanProperty(
            keyValidation.getOrThrow(), valueValidation.getOrThrow() as bool,
            isPrivate: true);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to add private boolean property',
    );
  }

  @override
  CFResult<void> addPrivateMapProperty(String key, Map<String, dynamic> value) {
    // SECURITY FIX: Validate inputs before processing using CFResult pattern
    final keyValidation = CFResultValidation.validatePropertyKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'UserManager: Private map property key validation failed: ${keyValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property key: ${keyValidation.getErrorMessage()}');
    }

    final valueValidation = CFResultValidation.validatePropertyValue(value);
    if (!valueValidation.isSuccess) {
      Logger.w(
          'UserManager: Private map property value validation failed: ${valueValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property value: ${valueValidation.getErrorMessage()}');
    }

    return CFResultExtensions.catching(
      () {
        _user = _user.addMapProperty(keyValidation.getOrThrow(),
            valueValidation.getOrThrow() as Map<String, dynamic>,
            isPrivate: true);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to add private map property',
    );
  }

  @override
  CFResult<void> addPrivateJsonProperty(
      String key, Map<String, dynamic> value) {
    // SECURITY FIX: Validate inputs before processing using CFResult pattern
    final keyValidation = CFResultValidation.validatePropertyKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'UserManager: Private JSON property key validation failed: ${keyValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property key: ${keyValidation.getErrorMessage()}');
    }

    final valueValidation = CFResultValidation.validatePropertyValue(value);
    if (!valueValidation.isSuccess) {
      Logger.w(
          'UserManager: Private JSON property value validation failed: ${valueValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property value: ${valueValidation.getErrorMessage()}');
    }

    return CFResultExtensions.catching(
      () {
        _user = _user.addJsonProperty(keyValidation.getOrThrow(),
            valueValidation.getOrThrow() as Map<String, dynamic>,
            isPrivate: true);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to add private JSON property',
    );
  }

  @override
  CFResult<void> removeProperty(String key) {
    // SECURITY FIX: Validate property key before processing using CFResult pattern
    final keyValidation = CFResultValidation.validatePropertyKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'UserManager: Remove property key validation failed: ${keyValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property key: ${keyValidation.getErrorMessage()}');
    }

    return CFResultExtensions.catching(
      () {
        _user = _user.removeProperty(keyValidation.getOrThrow());
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to remove property',
    );
  }

  @override
  CFResult<void> removeProperties(List<String> keys) {
    // SECURITY FIX: Validate all property keys before processing using CFResult pattern
    final validatedKeys = <String>[];
    for (final key in keys) {
      final keyValidation = CFResultValidation.validatePropertyKey(key);
      if (!keyValidation.isSuccess) {
        Logger.w(
            'UserManager: Remove properties key validation failed for "$key": ${keyValidation.getErrorMessage()}');
        return CFResult.error(
            'Invalid property key "$key": ${keyValidation.getErrorMessage()}');
      }
      validatedKeys.add(keyValidation.getOrThrow());
    }

    return CFResultExtensions.catching(
      () {
        _user = _user.removeProperties(validatedKeys);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to remove properties',
    );
  }

  @override
  CFResult<void> markPropertyAsPrivate(String key) {
    // SECURITY FIX: Validate property key before processing using CFResult pattern
    final keyValidation = CFResultValidation.validatePropertyKey(key);
    if (!keyValidation.isSuccess) {
      Logger.w(
          'UserManager: Mark property as private key validation failed: ${keyValidation.getErrorMessage()}');
      return CFResult.error(
          'Invalid property key: ${keyValidation.getErrorMessage()}');
    }

    return CFResultExtensions.catching(
      () {
        _user = _user.markPropertyAsPrivate(keyValidation.getOrThrow());
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to mark property as private',
    );
  }

  @override
  CFResult<void> markPropertiesAsPrivate(List<String> keys) {
    // SECURITY FIX: Validate all property keys before processing using CFResult pattern
    final validatedKeys = <String>[];
    for (final key in keys) {
      final keyValidation = CFResultValidation.validatePropertyKey(key);
      if (!keyValidation.isSuccess) {
        Logger.w(
            'UserManager: Mark properties as private key validation failed for "$key": ${keyValidation.getErrorMessage()}');
        return CFResult.error(
            'Invalid property key "$key": ${keyValidation.getErrorMessage()}');
      }
      validatedKeys.add(keyValidation.getOrThrow());
    }

    return CFResultExtensions.catching(
      () {
        _user = _user.markPropertiesAsPrivate(validatedKeys);
        _notifyUserChangeListeners();
      },
      errorMessage: 'Failed to mark properties as private',
    );
  }

  /// Setup user change listeners
  /// This method centralizes the user change listener setup that was previously in CFClient
  @override
  void setupListeners({
    required void Function(CFUser) onUserChange,
  }) {
    addUserChangeListener(onUserChange);
  }
}
