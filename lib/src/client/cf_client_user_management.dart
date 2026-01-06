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
import '../infrastructure/logging/logger.dart';

/// Callback for scheduling config refresh after user property changes
typedef RefreshCallback = void Function();

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
  final RefreshCallback? _onPropertyChange;

  CFClientUserManagement({
    required UserManager userManager,
    RefreshCallback? onPropertyChange,
  })  : _userManager = userManager,
        _onPropertyChange = onPropertyChange;

  /// Internal helper to notify property changes
  void _notifyPropertyChange() {
    _onPropertyChange?.call();
  }

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

  // MARK: - Simplified Property API (Recommended)

  /// Add a property to the user (unified method)
  ///
  /// This is the **recommended** method for adding user properties.
  /// Supports all types: String, num, bool, `Map<String, dynamic>`.
  ///
  /// Example:
  /// ```dart
  /// client.user.addProperty('name', 'John');
  /// client.user.addProperty('age', 25);
  /// client.user.addProperty('premium', true, isPrivate: true);
  /// ```
  CFResult<void> addProperty(String key, dynamic value, {bool isPrivate = false}) {
    final result = _userManager.addProperty(key, value, isPrivate: isPrivate);
    if (result.isSuccess) _notifyPropertyChange();
    return result;
  }

  /// Add multiple properties to the user (unified method)
  ///
  /// Example:
  /// ```dart
  /// client.user.addProperties({'name': 'John', 'age': 25});
  /// client.user.addProperties({'ssn': '123'}, isPrivate: true);
  /// ```
  CFResult<void> addProperties(Map<String, dynamic> properties, {bool isPrivate = false}) {
    final result = _userManager.addProperties(properties, isPrivate: isPrivate);
    if (result.isSuccess) _notifyPropertyChange();
    return result;
  }

  /// Get all user properties
  Map<String, dynamic> getUserProperties() => _userManager.getUserProperties();

  /// Remove a property from the user
  CFResult<void> removeProperty(String key) => _userManager.removeProperty(key);

  /// Remove multiple properties from the user
  CFResult<void> removeProperties(List<String> keys) =>
      _userManager.removeProperties(keys);

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
