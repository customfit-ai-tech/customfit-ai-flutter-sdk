// lib/src/client/cf_client_user_management.dart
//
// User management facade for CFClient
// Handles all user-related operations including properties, contexts, and authentication

import 'dart:async';
import '../core/error/cf_result.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../core/error/error_category.dart';
import '../core/model/cf_user.dart';
import '../core/model/evaluation_context.dart';
import '../core/model/context_type.dart';
import '../client/managers/user_manager.dart';
import '../logging/logger.dart';

/// Facade component for user management operations
///
/// This component encapsulates all user-related functionality including:
/// - User properties management
/// - Private properties management
/// - Context management
/// - User authentication handling
class CFClientUserManagement {
  static const _source = 'CFClientUserManagement';

  final UserManager _userManager;

  CFClientUserManagement({
    required UserManager userManager,
  }) : _userManager = userManager;

  // MARK: - User Management

  /// Set the current user
  Future<CFResult<void>> setUser(CFUser user) async {
    final result = _userManager.updateUser(user);
    return result.isSuccess
        ? CFResult.success(null)
        : CFResult.error('Failed to set user: ${result.getErrorMessage()}',
            category: ErrorCategory.configuration);
  }

  /// Get the current user
  CFUser getUser() => _userManager.getUser();

  /// Clear the current user by setting an anonymous user
  Future<CFResult<void>> clearUser() async {
    final result = _userManager.clearUser();
    return result.isSuccess
        ? CFResult.success(null)
        : CFResult.error('Failed to clear user: ${result.getErrorMessage()}',
            category: ErrorCategory.configuration);
  }

  // MARK: - User Properties

  /// Add a property to the user
  CFResult<void> addUserProperty(String key, dynamic value) =>
      _userManager.addUserProperty(key, value);

  /// Add a string property to the user
  CFResult<void> addStringProperty(String key, String value) =>
      _userManager.addStringProperty(key, value);

  /// Add a number property to the user
  CFResult<void> addNumberProperty(String key, num value) =>
      _userManager.addNumberProperty(key, value);

  /// Add a boolean property to the user
  CFResult<void> addBooleanProperty(String key, bool value) =>
      _userManager.addBooleanProperty(key, value);

  /// Add a JSON property to the user
  CFResult<void> addJsonProperty(String key, Map<String, dynamic> value) =>
      _userManager.addJsonProperty(key, value);

  /// Add a map property to the user
  CFResult<void> addMapProperty(String key, Map<String, dynamic> value) =>
      _userManager.addUserProperty(key, value);

  /// Add multiple properties to the user
  CFResult<void> addUserProperties(Map<String, dynamic> properties) =>
      _userManager.addUserProperties(properties);

  /// Get all user properties
  Map<String, dynamic> getUserProperties() => _userManager.getUserProperties();

  /// Remove a property from the user
  CFResult<void> removeProperty(String key) => _userManager.removeProperty(key);

  /// Remove multiple properties from the user
  CFResult<void> removeProperties(List<String> keys) =>
      _userManager.removeProperties(keys);

  // MARK: - Private Property Methods

  /// Add a private string property to the user
  CFResult<void> addPrivateStringProperty(String key, String value) =>
      _userManager.addPrivateStringProperty(key, value);

  /// Add a private number property to the user
  CFResult<void> addPrivateNumberProperty(String key, num value) =>
      _userManager.addPrivateNumberProperty(key, value);

  /// Add a private boolean property to the user
  CFResult<void> addPrivateBooleanProperty(String key, bool value) =>
      _userManager.addPrivateBooleanProperty(key, value);

  /// Add a private map property to the user
  CFResult<void> addPrivateMapProperty(
          String key, Map<String, dynamic> value) =>
      _userManager.addPrivateMapProperty(key, value);

  /// Add a private JSON property to the user
  CFResult<void> addPrivateJsonProperty(
          String key, Map<String, dynamic> value) =>
      _userManager.addPrivateJsonProperty(key, value);

  /// Mark an existing property as private
  CFResult<void> markPropertyAsPrivate(String key) =>
      _userManager.markPropertyAsPrivate(key);

  /// Mark multiple existing properties as private
  CFResult<void> markPropertiesAsPrivate(List<String> keys) =>
      _userManager.markPropertiesAsPrivate(keys);

  // MARK: - Context Management

  /// Add an evaluation context to the user
  CFResult<void> addContext(EvaluationContext context) {
    final result = _userManager.addContext(context);
    if (result.isSuccess) {
      Logger.d('Added evaluation context: ${context.type}:${context.key}');
    } else {
      Logger.e('Failed to add context: ${result.getErrorMessage()}');
      ErrorHandler.handleException(
        Exception(result.getErrorMessage()),
        'Failed to add evaluation context',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
    return result;
  }

  /// Remove an evaluation context from the user
  CFResult<void> removeContext(ContextType type, String key) {
    final result = _userManager.removeContext(type, key);
    if (result.isSuccess) {
      Logger.d('Removed evaluation context: $type:$key');
    } else {
      Logger.e('Failed to remove context: ${result.getErrorMessage()}');
      ErrorHandler.handleException(
        Exception(result.getErrorMessage()),
        'Failed to remove evaluation context',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
    return result;
  }

  /// Get all evaluation contexts for the user
  List<EvaluationContext> getContexts() {
    try {
      final user = _userManager.getUser();
      return user.contexts;
    } catch (e) {
      Logger.e('Failed to get contexts: $e');
      ErrorHandler.handleException(
        e,
        'Failed to get evaluation contexts',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return [];
    }
  }
}
