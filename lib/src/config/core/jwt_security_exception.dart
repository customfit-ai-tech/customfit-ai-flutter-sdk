// lib/src/config/core/jwt_security_exception.dart
//
// Security exception class for JWT validation errors.
// Provides structured error handling for JWT-related security issues.
//
// This file is part of the CustomFit SDK for Flutter.

import '../../logging/logger.dart';

/// Exception thrown when JWT validation fails for security reasons
class JWTSecurityException implements Exception {
  /// The error message describing what went wrong
  final String message;

  /// The error code for categorizing the type of failure
  final String code;

  /// Additional context about the error
  final Map<String, dynamic>? context;

  /// Timestamp when the error occurred
  final DateTime? timestamp;

  const JWTSecurityException(
    this.message, {
    required this.code,
    this.context,
  }) : timestamp = null;

  JWTSecurityException._(
    this.message, {
    required this.code,
    this.context,
    required this.timestamp,
  });

  /// Create a new JWT security exception with current timestamp
  factory JWTSecurityException.create(
    String message, {
    required String code,
    Map<String, dynamic>? context,
  }) {
    final exception = JWTSecurityException._(
      message,
      code: code,
      context: context,
      timestamp: DateTime.now(),
    );

    // Log the security exception
    Logger.e('JWT Security Exception [$code]: $message');

    return exception;
  }

  /// JWT format is invalid (wrong number of parts, encoding issues)
  factory JWTSecurityException.invalidFormat(String details) {
    return JWTSecurityException.create(
      'JWT format is invalid: $details',
      code: 'JWT_INVALID_FORMAT',
      context: {'details': details},
    );
  }

  /// JWT signature verification failed
  factory JWTSecurityException.invalidSignature(String algorithm) {
    return JWTSecurityException.create(
      'JWT signature verification failed for algorithm: $algorithm',
      code: 'JWT_INVALID_SIGNATURE',
      context: {'algorithm': algorithm},
    );
  }

  /// JWT token has expired
  factory JWTSecurityException.expired(DateTime expiryTime) {
    return JWTSecurityException.create(
      'JWT token expired at $expiryTime',
      code: 'JWT_EXPIRED',
      context: {
        'expiryTime': expiryTime.toIso8601String(),
        'currentTime': DateTime.now().toIso8601String(),
      },
    );
  }

  /// JWT token is not yet valid (nbf claim)
  factory JWTSecurityException.notYetValid(DateTime notBeforeTime) {
    return JWTSecurityException.create(
      'JWT token not valid before $notBeforeTime',
      code: 'JWT_NOT_YET_VALID',
      context: {
        'notBeforeTime': notBeforeTime.toIso8601String(),
        'currentTime': DateTime.now().toIso8601String(),
      },
    );
  }

  /// JWT token issued in the future (iat claim)
  factory JWTSecurityException.issuedInFuture(DateTime issuedTime) {
    return JWTSecurityException.create(
      'JWT token issued in future at $issuedTime',
      code: 'JWT_ISSUED_IN_FUTURE',
      context: {
        'issuedTime': issuedTime.toIso8601String(),
        'currentTime': DateTime.now().toIso8601String(),
      },
    );
  }

  /// JWT uses insecure algorithm
  factory JWTSecurityException.insecureAlgorithm(String algorithm) {
    return JWTSecurityException.create(
      'JWT uses insecure algorithm: $algorithm',
      code: 'JWT_INSECURE_ALGORITHM',
      context: {'algorithm': algorithm},
    );
  }

  /// JWT contains suspicious patterns indicating tampering
  factory JWTSecurityException.suspiciousPattern(String pattern) {
    return JWTSecurityException.create(
      'JWT contains suspicious patterns: $pattern',
      code: 'JWT_SUSPICIOUS_PATTERN',
      context: {'pattern': pattern},
    );
  }

  /// JWT header or payload cannot be decoded
  factory JWTSecurityException.decodingError(String part, String error) {
    return JWTSecurityException.create(
      'Failed to decode JWT $part: $error',
      code: 'JWT_DECODING_ERROR',
      context: {'part': part, 'error': error},
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('JWTSecurityException: $message');
    if (context != null && context!.isNotEmpty) {
      buffer.write(' (${context.toString()})');
    }
    return buffer.toString();
  }

  /// Convert to a map for logging or serialization
  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'code': code,
      'context': context,
      'timestamp': timestamp?.toIso8601String(),
      'type': 'JWTSecurityException',
    };
  }
}
