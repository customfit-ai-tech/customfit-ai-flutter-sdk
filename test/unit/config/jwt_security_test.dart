// test/unit/config/jwt_security_test.dart
//
// Test suite for JWT security validation improvements.
// Validates that JWT tokens are properly verified for security.
//
// This file is part of the CustomFit SDK for Flutter.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/jwt_security_exception.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
void main() {
  group('JWT Security Validation Tests', () {
    // Valid JWT token for testing (from existing tests)
    const validJWT = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.'
        'eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiaXNzIjoickhISDZHSUFoQ0xsbUNhRWdKUG5YNjB1QlpaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.'
        'Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek';
    group('JWT Format Validation', () {
      test('should reject JWT with wrong number of parts', () {
        expect(() => CFConfig.builder('invalid.jwt').build().getOrThrow(),
            throwsA(isA<CFException>()));
        expect(() => CFConfig.builder('part1.part2.part3.part4').build().getOrThrow(),
            throwsA(isA<CFException>()));
      });
      test('should reject empty JWT', () {
        expect(
            () => CFConfig.builder('').build().getOrThrow(), throwsA(isA<CFException>()));
      });
      test('should reject JWT with invalid base64 encoding', () {
        // JWT with invalid base64 in payload
        const invalidBase64JWT = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'invalid-base64-payload!_with_extra_characters_to_make_it_longer_than_100_chars'
            '.signature_with_proper_length_for_testing_purposes_1234567890';
        final config = CFConfig.builder(invalidBase64JWT).build().getOrThrow();
        // Should handle gracefully and return null dimension ID
        expect(config.dimensionId, isNull);
      });
      test('should accept valid JWT format', () {
        final config = CFConfig.builder(validJWT).build().getOrThrow();
        expect(config.clientKey, equals(validJWT));
        expect(config.dimensionId, isNotNull);
      });
    });
    group('JWT Algorithm Security', () {
      test('should reject JWT with "none" algorithm', () {
        // Create JWT with "none" algorithm
        const noneAlgJWT = 'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.'
            'eyJkaW1lbnNpb25faWQiOiJ0ZXN0LWRpbWVuc2lvbiIsImV4dHJhIjoicGFkZGluZyB0byBtYWtlIGl0IGxvbmdlciJ9.'
            'empty_signature_padded_to_make_token_long_enough_for_validation'; // Empty signature for "none" algorithm
        final config = CFConfig.builder(noneAlgJWT).build().getOrThrow();
        // Should reject and return null dimension ID
        expect(config.dimensionId, isNull);
      });
      test('should reject JWT with missing algorithm', () {
        // JWT header without "alg" field
        const noAlgJWT = 'eyJ0eXAiOiJKV1QifQ.' // No "alg" field
            'eyJkaW1lbnNpb25faWQiOiJ0ZXN0LWRpbWVuc2lvbiIsImV4dHJhX2ZpZWxkIjoidG8gbWFrZSBpdCBsb25nZXIifQ.'
            'signature_with_proper_length_for_testing_validation_1234567890';
        final config = CFConfig.builder(noAlgJWT).build().getOrThrow();
        expect(config.dimensionId, isNull);
      });
      test('should accept JWT with valid algorithms', () {
        final config = CFConfig.builder(validJWT).build().getOrThrow();
        expect(config.dimensionId, isNotNull);
      });
    });
    group('JWT Expiry Validation', () {
      test('should reject expired JWT token', () {
        // Create JWT with past expiry time
        final expiredPayload = {
          'dimension_id': 'test-dimension',
          'exp': 1000000000, // Year 2001 - clearly expired
          'iat': 999999999,
        };
        final expiredJWT = _createTestJWT(expiredPayload);
        final config = CFConfig.builder(expiredJWT).build().getOrThrow();
        // Should reject expired token
        expect(config.dimensionId, isNull);
      });
      test('should accept JWT token with future expiry', () {
        // Create JWT with future expiry time
        final futureExpiry = DateTime.now().add(const Duration(hours: 1));
        final validPayload = {
          'dimension_id': 'test-dimension',
          'exp': (futureExpiry.millisecondsSinceEpoch / 1000).floor(),
          'iat': (DateTime.now().millisecondsSinceEpoch / 1000).floor(),
        };
        final validJWT = _createTestJWT(validPayload);
        final config = CFConfig.builder(validJWT).build().getOrThrow();
        expect(config.dimensionId, equals('test-dimension'));
      });
      test('should handle JWT without expiry time', () {
        // JWT without exp claim should be accepted with warning
        final noExpiryPayload = {
          'dimension_id': 'test-dimension',
          'iat': (DateTime.now().millisecondsSinceEpoch / 1000).floor(),
        };
        final noExpiryJWT = _createTestJWT(noExpiryPayload);
        final config = CFConfig.builder(noExpiryJWT).build().getOrThrow();
        expect(config.dimensionId, equals('test-dimension'));
      });
    });
    group('JWT Time Validation', () {
      test('should reject JWT issued in the future', () {
        final futureTime = DateTime.now().add(const Duration(hours: 1));
        final futureIssuedPayload = {
          'dimension_id': 'test-dimension',
          'iat': (futureTime.millisecondsSinceEpoch / 1000).floor(),
        };
        final futureJWT = _createTestJWT(futureIssuedPayload);
        final config = CFConfig.builder(futureJWT).build().getOrThrow();
        // Should reject token issued in future
        expect(config.dimensionId, isNull);
      });
      test('should reject JWT not yet valid (nbf)', () {
        final futureTime = DateTime.now().add(const Duration(hours: 1));
        final notYetValidPayload = {
          'dimension_id': 'test-dimension',
          'nbf': (futureTime.millisecondsSinceEpoch / 1000).floor(),
          'iat': (DateTime.now().millisecondsSinceEpoch / 1000).floor(),
        };
        final notYetValidJWT = _createTestJWT(notYetValidPayload);
        final config = CFConfig.builder(notYetValidJWT).build().getOrThrow();
        // Should reject token not yet valid
        expect(config.dimensionId, isNull);
      });
      test('should accept JWT within clock skew tolerance', () {
        // JWT issued 2 minutes in the future (within 5-minute tolerance)
        final slightlyFutureTime =
            DateTime.now().add(const Duration(minutes: 2));
        final skewPayload = {
          'dimension_id': 'test-dimension',
          'iat': (slightlyFutureTime.millisecondsSinceEpoch / 1000).floor(),
        };
        final skewJWT = _createTestJWT(skewPayload);
        final config = CFConfig.builder(skewJWT).build().getOrThrow();
        expect(config.dimensionId, equals('test-dimension'));
      });
    });
    group('JWT Signature Validation', () {
      test('should reject JWT with empty signature', () {
        const emptySignatureJWT = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJkaW1lbnNpb25faWQiOiJ0ZXN0LWRpbWVuc2lvbiIsInBhZGRpbmciOiJleHRyYV9maWVsZF90b19tYWtlX2l0X2xvbmdlciJ9.'
            ''; // Empty signature
        final config = CFConfig.builder(emptySignatureJWT).build().getOrThrow();
        expect(config.dimensionId, isNull);
      });
      test('should reject JWT with suspicious signature patterns', () {
        // JWT with obviously fake signature
        const fakeSignatureJWT = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJkaW1lbnNpb25faWQiOiJ0ZXN0LWRpbWVuc2lvbiJ9.'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; // All 'a' characters
        final config = CFConfig.builder(fakeSignatureJWT).build().getOrThrow();
        expect(config.dimensionId, isNull);
      });
      test('should reject JWT with signature too short for algorithm', () {
        // JWT with signature too short for HS256
        const shortSignatureJWT = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJkaW1lbnNpb25faWQiOiJ0ZXN0LWRpbWVuc2lvbiIsImV4dHJhX2ZpZWxkIjoidG9fbWFrZV9pdF9sb25nZXIifQ.'
            'short'; // Too short for HS256
        final config = CFConfig.builder(shortSignatureJWT).build().getOrThrow();
        expect(config.dimensionId, isNull);
      });
      test('should accept JWT with properly formatted signature', () {
        final config = CFConfig.builder(validJWT).build().getOrThrow();
        expect(config.dimensionId, isNotNull);
      });
    });
    group('JWT Security Exception Tests', () {
      test('should create security exceptions with proper context', () {
        final exception = JWTSecurityException.invalidFormat('test details');
        expect(exception.code, equals('JWT_INVALID_FORMAT'));
        expect(exception.message, contains('test details'));
        expect(exception.context, isNotNull);
        expect(exception.timestamp, isNotNull);
      });
      test('should create expired token exception', () {
        final expiryTime = DateTime.now().subtract(const Duration(hours: 1));
        final exception = JWTSecurityException.expired(expiryTime);
        expect(exception.code, equals('JWT_EXPIRED'));
        expect(exception.message, contains('expired'));
        expect(exception.context!['expiryTime'], isNotNull);
      });
      test('should create invalid signature exception', () {
        final exception = JWTSecurityException.invalidSignature('HS256');
        expect(exception.code, equals('JWT_INVALID_SIGNATURE'));
        expect(exception.context!['algorithm'], equals('HS256'));
      });
      test('should convert exception to map', () {
        final exception = JWTSecurityException.invalidFormat('test');
        final map = exception.toMap();
        expect(map['type'], equals('JWTSecurityException'));
        expect(map['code'], equals('JWT_INVALID_FORMAT'));
        expect(map['message'], isNotNull);
        expect(map['timestamp'], isNotNull);
      });
    });
    group('JWT Caching Security', () {
      test('should cache valid JWT parsing results', () {
        final config1 = CFConfig.builder(validJWT).build().getOrThrow();
        final config2 = CFConfig.builder(validJWT).build().getOrThrow();
        // Both should return the same dimension ID (cached)
        expect(config1.dimensionId, equals(config2.dimensionId));
        expect(config1.dimensionId, isNotNull);
      });
      test('should not cache invalid JWT results', () {
        const invalidJWT = 'invalid.jwt.token';
        // Multiple attempts should consistently fail
        expect(() => CFConfig.builder(invalidJWT).build().getOrThrow(),
            throwsA(isA<CFException>()));
        expect(() => CFConfig.builder(invalidJWT).build().getOrThrow(),
            throwsA(isA<CFException>()));
      });
    });
    group('JWT Security Regression Tests', () {
      test('should prevent JWT injection attacks', () {
        // Common JWT injection payloads
        final injectionPayloads = [
          'eyJhbGciOiJub25lIn0.eyJzdWIiOiJhZG1pbiJ9.',
          '{"alg":"none"}.{"sub":"admin"}.',
          'null.null.null',
        ];
        for (final payload in injectionPayloads) {
          try {
            final config = CFConfig.builder(payload).build().getOrThrow();
            // If it doesn't throw, dimension ID should be null (rejected)
            expect(config.dimensionId, isNull);
          } catch (e) {
            // Throwing an error is also acceptable for invalid format
            expect(e, isA<CFException>());
          }
        }
      });
      test('should prevent algorithm confusion attacks', () {
        // Try to use public key as HMAC secret (common attack)
        const algConfusionJWT = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJkaW1lbnNpb25faWQiOiJhdHRhY2tlciJ9.'
            'fake_signature_using_public_key_as_hmac';
        final config = CFConfig.builder(algConfusionJWT).build().getOrThrow();
        // Should be rejected due to suspicious signature pattern
        expect(config.dimensionId, isNull);
      });
      test('should handle malformed JSON in JWT parts', () {
        // JWT with malformed JSON in payload
        const malformedJWT = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'bWFsZm9ybWVkX2pzb25fd2l0aF9leHRyYV9wYWRkaW5nX3RvX21ha2VfaXRfbG9uZ2VyX3RoYW5fMTAwX2NoYXJhY3RlcnM=' // malformed json in base64
            '.signature_with_proper_length_for_testing_validation';
        final config = CFConfig.builder(malformedJWT).build().getOrThrow();
        expect(config.dimensionId, isNull);
      });
    });
  });
}
/// Helper function to create test JWT tokens
String _createTestJWT(Map<String, dynamic> payload) {
  const header =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'; // {"alg":"HS256","typ":"JWT"}
  final payloadJson = jsonEncode(payload);
  final payloadBase64 = base64Url.encode(utf8.encode(payloadJson)).replaceAll('=', '');
  // Use a properly formatted base64url signature for testing (no padding, URL-safe chars)
  const signature = 'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
  return '$header.$payloadBase64.$signature';
}
// Removed unused _base64UrlEncode function
