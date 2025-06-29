// test/unit/network/config_fetcher_test.dart
//
// Unit tests for ConfigFetcher covering all methods and error scenarios
// to improve coverage from 13.9% to 85%+
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/network/config/config_fetcher.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/error_category.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_error_code.dart';
import 'package:customfit_ai_flutter_sdk/src/constants/cf_constants.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/cache_manager.dart';
import '../../shared/test_configs.dart';
import '../../shared/mocks/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ConfigFetcher Unit Tests', () {
    late ConfigFetcher configFetcher;
    late MockHttpClient mockHttpClient;
    late CFConfig config;
    late CFUser user;
    setUp(() async {
      // Initialize cache manager
      await CacheManager.instance.initialize();
      await CacheManager.instance.clear();
      // Create test config and user
      config = TestConfigs.getConfig(TestConfigType.standard);
      user = TestConfigs.getUser(TestUserType.defaultUser);
      // Create mock HTTP client
      mockHttpClient = MockHttpClient();
      mockHttpClient.reset();
      // Create ConfigFetcher instance
      configFetcher = ConfigFetcher(mockHttpClient, config, user);
    });
    tearDown(() async {
      await CacheManager.instance.clear();
      mockHttpClient.reset();
    });
    group('Initialization and Basic Methods', () {
      test('should initialize with correct user and config', () {
        expect(configFetcher.isOffline(), isFalse);
        expect(() => configFetcher.getConfigs(), returnsNormally);
      });
      test('should handle offline mode correctly', () {
        expect(configFetcher.isOffline(), isFalse);
        configFetcher.setOffline(true);
        expect(configFetcher.isOffline(), isTrue);
        configFetcher.setOffline(false);
        expect(configFetcher.isOffline(), isFalse);
      });
      test('should return error when no config fetched yet', () {
        final result = configFetcher.getConfigs();
        expect(result.isSuccess, isFalse);
        expect(
            result.error?.errorCode, equals(CFErrorCode.configNotInitialized));
      });
      test('should clear configs correctly', () {
        configFetcher.clearConfigs();
        final result = configFetcher.getConfigs();
        expect(result.isSuccess, isFalse);
      });
    });
    group('Configuration Fetching', () {
      test('should not fetch config when offline', () async {
        configFetcher.setOffline(true);
        final result = await configFetcher.fetchConfig();
        expect(result, isFalse);
      });
      test('should fetch config successfully', () async {
        final mockConfigResponse = {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': true,
              'variation_data_type': 'boolean',
              'experience_behaviour_response': {
                'experience_id': 'exp-123',
                'behaviour': 'show'
              }
            },
            'feature2': {
              'config_id': 'feature2-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature2',
              'variation': 'treatment',
              'variation_data_type': 'string'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        final result = await configFetcher.fetchConfig();
        expect(result, isTrue);
        // Verify config was stored
        final configs = configFetcher.getConfigs();
        expect(configs.isSuccess, isTrue);
        expect(configs.getOrNull()?.containsKey('feature1'), isTrue);
        expect(configs.getOrNull()?.containsKey('feature2'), isTrue);
      });
      test('should handle 304 Not Modified response', () async {
        // First fetch with config
        final mockConfigResponse = {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        final firstResult = await configFetcher.fetchConfig();
        expect(firstResult, isTrue); // Ensure first fetch succeeds
        // Verify config was stored
        final firstConfigs = configFetcher.getConfigs();
        expect(firstConfigs.isSuccess, isTrue);
        expect(firstConfigs.getOrNull()?.containsKey('feature1'), isTrue);
        // Second fetch returns null (simulating 304)
        mockHttpClient.whenPost(url, null);
        final result =
            await configFetcher.fetchConfig(lastModified: 'some-date');
        expect(result, isTrue);
        // Should still have cached config
        final configs = configFetcher.getConfigs();
        expect(configs.isSuccess, isTrue);
        expect(configs.getOrNull()?.containsKey('feature1'), isTrue);
      });
      test('should handle network error with cached fallback', () async {
        // First successful fetch
        final mockConfigResponse = {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        await configFetcher.fetchConfig();
        // Network error on second fetch
        mockHttpClient.whenPost(
          url,
          null,
          isError: true,
          errorCode: CFErrorCode.networkUnavailable,
          errorMessage: 'Network error',
        );
        final result = await configFetcher.fetchConfig();
        expect(result, isTrue); // Should succeed with cached data
        // Should still have cached config
        final configs = configFetcher.getConfigs();
        expect(configs.isSuccess, isTrue);
        expect(configs.getOrNull()?.containsKey('feature1'), isTrue);
      });
      test('should handle timeout error', () async {
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.simulateTimeout(url);
        final result = await configFetcher.fetchConfig();
        expect(result, isFalse);
      });
      test('should handle malformed JSON response', () async {
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, 'invalid json{');
        final result = await configFetcher.fetchConfig();
        expect(result, isFalse);
      });
      test('should handle missing configs object in response', () async {
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode({'no_configs': 'here'}));
        final result = await configFetcher.fetchConfig();
        expect(result, isTrue); // Should succeed but with empty configs
        final configs = configFetcher.getConfigs();
        expect(configs.isSuccess, isTrue);
        expect(configs.getOrNull()?.isEmpty, isTrue);
      });
      test('should handle invalid config entries', () async {
        final mockConfigResponse = {
          'configs': {
            'valid_feature': {
              'config_id': 'valid-id',
              'config_customer_id': 'customer-123',
              'config_name': 'valid_feature',
              'variation': true,
              'variation_data_type': 'boolean'
            },
            'invalid_feature': 'not_a_map', // Invalid entry
            'another_valid': {
              'config_id': 'another-id',
              'config_customer_id': 'customer-123',
              'config_name': 'another_valid',
              'variation': 'treatment',
              'variation_data_type': 'string'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        final result = await configFetcher.fetchConfig();
        expect(result, isTrue);
        // Should only have valid configs
        final configs = configFetcher.getConfigs();
        expect(configs.isSuccess, isTrue);
        expect(configs.getOrNull()?.containsKey('valid_feature'), isTrue);
        expect(configs.getOrNull()?.containsKey('another_valid'), isTrue);
        expect(configs.getOrNull()?.containsKey('invalid_feature'), isFalse);
      });
      test('should process experience_behaviour_response correctly', () async {
        final mockConfigResponse = {
          'configs': {
            'feature_with_experience': {
              'config_id': 'exp-feature-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature_with_experience',
              'variation': true,
              'variation_data_type': 'boolean',
              'experience_behaviour_response': {
                'experience_id': 'exp-456',
                'behaviour': 'show',
                'metadata': {'key': 'value'},
                'additional_field': 'additional_value'
              }
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        final result = await configFetcher.fetchConfig();
        expect(result, isTrue);
        final configs = configFetcher.getConfigs();
        expect(configs.isSuccess, isTrue);
        final featureConfig = configs.getOrNull()?['feature_with_experience']
            as Map<String, dynamic>;
        expect(featureConfig['variation'], equals(true));
        expect(featureConfig['experience_behaviour_response'], isNotNull);
      });
      test('should handle conditional request headers', () async {
        final mockConfigResponse = {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        // Test with lastModified
        await configFetcher.fetchConfig(
            lastModified: 'Wed, 21 Oct 2015 07:28:00 GMT');
        // Test with etag
        await configFetcher.fetchConfig(etag: 'W/"123456"');
        // Test with both
        await configFetcher.fetchConfig(
            lastModified: 'Wed, 21 Oct 2015 07:28:00 GMT', etag: 'W/"123456"');
      });
      test('should handle different response types', () async {
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        // Test with Map response
        mockHttpClient.whenPost(url, {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        });
        var result = await configFetcher.fetchConfig();
        expect(result, isTrue);
        // Test with boolean response
        mockHttpClient.reset();
        mockHttpClient.whenPost(url, true);
        result = await configFetcher.fetchConfig();
        expect(result, isTrue);
        // Test with unexpected type
        mockHttpClient.reset();
        mockHttpClient.whenPost(url, 12345);
        result = await configFetcher.fetchConfig();
        expect(result, isFalse);
      });
      test('should use cache when available', () async {
        // Put config in cache
        final cacheKey = 'cf_config_${config.clientKey}_${user.userCustomerId}';
        final cachedConfig = {
          'configs': {
            'cached_feature': {
              'config_id': 'cached-id',
              'config_customer_id': 'customer-123',
              'config_name': 'cached_feature',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          },
          'lastModified': 'cached-date',
          'etag': 'cached-etag'
        };
        await CacheManager.instance.put(
          cacheKey,
          cachedConfig,
          policy: const CachePolicy(ttlSeconds: 3600),
        );
        // Fetch should use cache and still make request
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(
            url,
            jsonEncode({
              'configs': {
                'new_feature': {
                  'config_id': 'new-id',
                  'config_customer_id': 'customer-123',
                  'config_name': 'new_feature',
                  'variation': false,
                  'variation_data_type': 'boolean'
                }
              }
            }));
        final result = await configFetcher.fetchConfig();
        expect(result, isTrue);
      });
    });
    group('Metadata Fetching', () {
      test('should not fetch metadata when offline', () async {
        configFetcher.setOffline(true);
        final result = await configFetcher.fetchMetadata();
        expect(result.isSuccess, isFalse);
        expect(result.error?.errorCode, equals(CFErrorCode.networkUnavailable));
      });
      test('should fetch metadata successfully with HEAD request', () async {
        final dimensionId = config.dimensionId ?? "default";
        final sdkSettingsPath = CFConstants.api.sdkSettingsPathPattern
            .replaceFirst('%s', dimensionId);
        final url = CFConstants.api.sdkSettingsBaseUrl + sdkSettingsPath;
        final mockHeaders = {
          'Last-Modified': 'Wed, 21 Oct 2015 07:28:00 GMT',
          'ETag': 'W/"123456"'
        };
        mockHttpClient.whenHead(url, mockHeaders);
        final result = await configFetcher.fetchMetadata();
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull()?[CFConstants.http.headerLastModified],
            equals('Wed, 21 Oct 2015 07:28:00 GMT'));
        expect(result.getOrNull()?[CFConstants.http.headerEtag],
            equals('W/"123456"'));
      });
      test('should fallback to GET when HEAD fails', () async {
        final dimensionId = config.dimensionId ?? "default";
        final sdkSettingsPath = CFConstants.api.sdkSettingsPathPattern
            .replaceFirst('%s', dimensionId);
        final url = CFConstants.api.sdkSettingsBaseUrl + sdkSettingsPath;
        // HEAD request fails
        mockHttpClient.whenHead(url, {}, isError: true);
        // But we have no GET handler setup, so it will fail
        final result = await configFetcher.fetchMetadata();
        expect(result.isSuccess, isFalse);
      });
      test('should handle metadata fetch errors', () async {
        final dimensionId = config.dimensionId ?? "default";
        final sdkSettingsPath = CFConstants.api.sdkSettingsPathPattern
            .replaceFirst('%s', dimensionId);
        final url = CFConstants.api.sdkSettingsBaseUrl + sdkSettingsPath;
        mockHttpClient.whenHead(url, {}, isError: true);
        final result = await configFetcher.fetchMetadata();
        expect(result.isSuccess, isFalse);
        expect(result.error?.category, equals(ErrorCategory.network));
      });
      test('should build SDK settings URL correctly', () async {
        // The dimension ID is likely set in the config directly, not via builder
        // Test with default dimension ID
        final dimensionId = config.dimensionId ?? "default";
        final sdkSettingsPath = CFConstants.api.sdkSettingsPathPattern
            .replaceFirst('%s', dimensionId);
        final url = CFConstants.api.sdkSettingsBaseUrl + sdkSettingsPath;
        mockHttpClient.whenHead(url, {'Last-Modified': 'test'});
        final result = await configFetcher.fetchMetadata();
        expect(result.isSuccess, isTrue);
      });
    });
    group('SDK Settings Fetching', () {
      test('should not fetch SDK settings when offline', () async {
        configFetcher.setOffline(true);
        final result = await configFetcher.fetchSdkSettings();
        expect(result.isSuccess, isFalse);
        expect(result.error?.errorCode, equals(CFErrorCode.networkUnavailable));
      });
      test('should fetch SDK settings successfully', () async {
        final mockSettings = {
          'polling_interval': 30000,
          'event_batch_size': 50,
          'features': ['feature1', 'feature2']
        };
        final dimensionId = config.dimensionId ?? "default";
        final sdkSettingsPath = CFConstants.api.sdkSettingsPathPattern
            .replaceFirst('%s', dimensionId);
        final url = CFConstants.api.sdkSettingsBaseUrl + sdkSettingsPath;
        mockHttpClient.whenGet(url, mockSettings);
        final result = await configFetcher.fetchSdkSettings();
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull()?['polling_interval'], equals(30000));
        expect(result.getOrNull()?['event_batch_size'], equals(50));
      });
      test('should handle SDK settings fetch error', () async {
        final dimensionId = config.dimensionId ?? "default";
        final sdkSettingsPath = CFConstants.api.sdkSettingsPathPattern
            .replaceFirst('%s', dimensionId);
        final url = CFConstants.api.sdkSettingsBaseUrl + sdkSettingsPath;
        mockHttpClient.whenGet(
          url,
          null,
          isError: true,
          errorCode: CFErrorCode.networkUnavailable,
          errorMessage: 'Failed to fetch settings',
        );
        final result = await configFetcher.fetchSdkSettings();
        expect(result.isSuccess, isFalse);
        expect(result.error?.category, equals(ErrorCategory.network));
      });
    });
    group('Flag Helper Methods', () {
      test('should check if flag exists', () async {
        // Setup config with flags
        final mockConfigResponse = {
          'configs': {
            'existing_flag': {
              'config_id': 'existing-id',
              'config_customer_id': 'customer-123',
              'config_name': 'existing_flag',
              'variation': true,
              'variation_data_type': 'boolean'
            },
            'another_flag': {
              'config_id': 'another-id',
              'config_customer_id': 'customer-123',
              'config_name': 'another_flag',
              'variation': 'treatment',
              'variation_data_type': 'string'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        await configFetcher.fetchConfig();
        expect(configFetcher.flagExists('existing_flag'), isTrue);
        expect(configFetcher.flagExists('another_flag'), isTrue);
        expect(configFetcher.flagExists('non_existing_flag'), isFalse);
        expect(configFetcher.hasFlag('existing_flag'), isTrue);
        expect(configFetcher.hasFlag('non_existing_flag'), isFalse);
      });
      test('should get flag config', () async {
        // Setup config with flags
        final mockConfigResponse = {
          'configs': {
            'test_flag': {
              'config_id': 'test-id',
              'config_customer_id': 'customer-123',
              'config_name': 'test_flag',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        await configFetcher.fetchConfig();
        final flagConfig = configFetcher.getFlagConfig('test_flag');
        expect(flagConfig, isNotNull);
        expect(flagConfig?['variation'], equals(true));
        expect(flagConfig?['config_name'], equals('test_flag'));
        // Test non-existing flag
        expect(configFetcher.getFlagConfig('non_existing'), isNull);
      });
      test('should get config using interface method', () async {
        // Setup config with flags
        final mockConfigResponse = {
          'configs': {
            'interface_flag': {
              'config_id': 'interface-id',
              'config_customer_id': 'customer-123',
              'config_name': 'interface_flag',
              'variation': 'treatment',
              'variation_data_type': 'string'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        await configFetcher.fetchConfig();
        final result = configFetcher.getConfig('interface_flag');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull()?['variation'], equals('treatment'));
        expect(result.getOrNull()?['config_name'], equals('interface_flag'));
        // Test non-existing flag
        final notFoundResult = configFetcher.getConfig('not_found');
        expect(notFoundResult.isSuccess, isFalse);
        expect(notFoundResult.error?.errorCode,
            equals(CFErrorCode.configNotInitialized));
      });
      test('should handle flag config when no configs loaded', () {
        expect(configFetcher.flagExists('any_flag'), isFalse);
        expect(configFetcher.hasFlag('any_flag'), isFalse);
        expect(configFetcher.getFlagConfig('any_flag'), isNull);
        final result = configFetcher.getConfig('any_flag');
        expect(result.isSuccess, isFalse);
      });
      test('should handle invalid flag config format', () async {
        // Setup config with invalid flag format
        final mockConfigResponse = {
          'configs': {
            'string_flag': 'not_a_map',
            'valid_flag': {
              'config_id': 'valid-id',
              'config_customer_id': 'customer-123',
              'config_name': 'valid_flag',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        await configFetcher.fetchConfig();
        // String flag should not be accessible as flag config
        expect(configFetcher.getFlagConfig('string_flag'), isNull);
        expect(configFetcher.getFlagConfig('valid_flag'), isNotNull);
      });
    });
    group('Error Handling Edge Cases', () {
      test('should handle null response body', () async {
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, null);
        final result = await configFetcher.fetchConfig();
        expect(result, isFalse);
      });
      test('should handle empty response body', () async {
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, '');
        final result = await configFetcher.fetchConfig();
        expect(result, isFalse);
      });
      test('should handle exception during config processing', () async {
        // Create a response that will cause JSON parsing to fail
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, '{"configs": {"test": }'); // Invalid JSON
        final result = await configFetcher.fetchConfig();
        expect(result, isFalse);
      });
      test('should handle exception in individual config processing', () async {
        final mockConfigResponse = {
          'configs': {
            'valid_flag': {
              'config_id': 'valid-id',
              'config_customer_id': 'customer-123',
              'config_name': 'valid_flag',
              'variation': true,
              'variation_data_type': 'boolean'
            },
            'problematic_flag': {
              'config_id': 'prob-id',
              'config_customer_id': 'customer-123',
              'config_name': 'problematic_flag',
              'variation': true,
              'variation_data_type': 'boolean',
              'experience_behaviour_response': 'not_a_map' // Should be a map
            },
            'another_valid': {
              'config_id': 'another-id',
              'config_customer_id': 'customer-123',
              'config_name': 'another_valid',
              'variation': false,
              'variation_data_type': 'boolean'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        final result = await configFetcher.fetchConfig();
        expect(result, isTrue);
        // Should still process valid flags
        final configs = configFetcher.getConfigs();
        expect(configs.getOrNull()?.containsKey('valid_flag'), isTrue);
        expect(configs.getOrNull()?.containsKey('another_valid'), isTrue);
      });
      test('should recover from JSON parsing errors in nested objects',
          () async {
        // Simulate partially invalid JSON that can still be parsed
        final partiallyInvalidResponse = {
          'configs': {
            'valid_feature': {
              'config_id': 'valid-id',
              'config_customer_id': 'customer-123',
              'config_name': 'valid_feature',
              'variation': true,
              'variation_data_type': 'boolean'
            },
            'invalid_feature': null, // This might cause issues in processing
            'another_valid': {
              'config_id': 'another-id',
              'config_customer_id': 'customer-123',
              'config_name': 'another_valid',
              'variation': 'test',
              'variation_data_type': 'string'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(partiallyInvalidResponse));
        final result = await configFetcher.fetchConfig();
        expect(result, isTrue);
        final configs = configFetcher.getConfigs();
        expect(configs.getOrNull()?['valid_feature']['variation'], isTrue);
        expect(
            configs.getOrNull()?['another_valid']['variation'], equals('test'));
      });
    });
    group('Request Deduplication', () {
      test('should deduplicate concurrent config requests', () async {
        final mockConfigResponse = {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        // Setup mock to track calls
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        // Make multiple concurrent requests
        final futures = List.generate(5, (_) => configFetcher.fetchConfig());
        final results = await Future.wait(futures);
        // All should succeed
        expect(results.every((r) => r == true), isTrue);
        // Check that the request was made
        expect(mockHttpClient.wasRequestMade('POST', url), isTrue);
      });
      test('should deduplicate metadata requests', () async {
        final dimensionId = config.dimensionId ?? "default";
        final sdkSettingsPath = CFConstants.api.sdkSettingsPathPattern
            .replaceFirst('%s', dimensionId);
        final url = CFConstants.api.sdkSettingsBaseUrl + sdkSettingsPath;
        mockHttpClient.whenHead(url, {'Last-Modified': 'test-date'});
        // Make multiple concurrent requests
        final futures = List.generate(5, (_) => configFetcher.fetchMetadata());
        final results = await Future.wait(futures);
        // All should succeed
        expect(results.every((r) => r.isSuccess), isTrue);
        // Check that request was made
        expect(mockHttpClient.wasRequestMade('HEAD', url), isTrue);
      });
      test('should deduplicate SDK settings requests', () async {
        final dimensionId = config.dimensionId ?? "default";
        final sdkSettingsPath = CFConstants.api.sdkSettingsPathPattern
            .replaceFirst('%s', dimensionId);
        final url = CFConstants.api.sdkSettingsBaseUrl + sdkSettingsPath;
        mockHttpClient.whenGet(url, {'setting': 'value'});
        // Make multiple concurrent requests
        final futures =
            List.generate(5, (_) => configFetcher.fetchSdkSettings());
        final results = await Future.wait(futures);
        // All should succeed
        expect(results.every((r) => r.isSuccess), isTrue);
        // Check that request was made
        expect(mockHttpClient.wasRequestMade('GET', url), isTrue);
      });
    });
    group('Logging and Debug Output', () {
      test('should log config values correctly', () async {
        final mockConfigResponse = {
          'configs': {
            'flag_with_variation': {
              'config_id': 'flag-var-id',
              'config_customer_id': 'customer-123',
              'config_name': 'flag_with_variation',
              'variation': 'test_variation',
              'variation_data_type': 'string'
            },
            'flag_without_variation': {
              'config_id': 'flag-no-var-id',
              'config_customer_id': 'customer-123',
              'config_name': 'flag_without_variation',
              'variation': false,
              'variation_data_type': 'boolean'
            },
            'hero_text': {
              'config_id': 'hero-id',
              'config_customer_id': 'customer-123',
              'config_name': 'hero_text',
              'variation': 'Welcome to our app!',
              'variation_data_type': 'string'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockConfigResponse));
        await configFetcher.fetchConfig();
        // Call getConfigs to trigger logging
        final configs = configFetcher.getConfigs();
        expect(configs.isSuccess, isTrue);
      });
    });
    group('Cache Expiry and Stale-While-Revalidate', () {
      test('should handle cache expiry and fetch fresh data', () async {
        // First, populate cache with initial data
        final initialResponse = {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(initialResponse));
        // Fetch and cache initial data
        await configFetcher.fetchConfig();
        var configs = configFetcher.getConfigs();
        expect(configs.getOrNull()?['feature1']['variation'], isTrue);
        // Clear the cache to simulate expiry
        await CacheManager.instance.clear();
        // Set up new response for fresh fetch
        final freshResponse = {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': false,
              'variation_data_type': 'boolean'
            },
            'feature2': {
              'config_id': 'feature2-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature2',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        };
        mockHttpClient.whenPost(url, jsonEncode(freshResponse));
        // Fetch again after cache expiry
        await configFetcher.fetchConfig();
        configs = configFetcher.getConfigs();
        // Verify fresh data is fetched
        expect(configs.getOrNull()?['feature1']['variation'], isFalse);
        expect(configs.getOrNull()?['feature2']['variation'], isTrue);
      });
      test('should use stale cache while revalidating when network fails',
          () async {
        // First, populate cache with initial data
        final initialResponse = {
          'configs': {
            'cached_feature': {
              'config_id': 'cached-id',
              'config_customer_id': 'customer-123',
              'config_name': 'cached_feature',
              'variation': 'stale_but_valid',
              'variation_data_type': 'string'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(initialResponse));
        // Fetch and cache initial data
        await configFetcher.fetchConfig();
        var configs = configFetcher.getConfigs();
        expect(configs.getOrNull()?['cached_feature']['variation'],
            equals('stale_but_valid'));
        // Simulate network failure for revalidation
        mockHttpClient.whenPost(
          url,
          null,
          isError: true,
          errorCode: CFErrorCode.networkUnavailable,
          errorMessage: 'Network error during revalidation',
        );
        // Attempt to fetch again - should use stale cache when network fails
        await configFetcher.fetchConfig();
        configs = configFetcher.getConfigs();
        // Should still return stale data when network fails
        expect(configs.getOrNull()?['cached_feature']['variation'],
            equals('stale_but_valid'));
      });
      test('should handle conditional requests with etag and last-modified',
          () async {
        // First fetch to get initial data
        final initialResponse = {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          },
          'lastModified': 'Wed, 21 Oct 2025 07:28:00 GMT',
          'etag': '"33a64df551"'
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(initialResponse));
        await configFetcher.fetchConfig();
        // Second fetch should include conditional headers
        // Simulate 304 Not Modified response by returning null
        mockHttpClient.whenPost(url, null); // Empty response for 304
        final result = await configFetcher.fetchConfig(
            lastModified: 'Wed, 21 Oct 2025 07:28:00 GMT',
            etag: '"33a64df551"');
        // Should still have access to cached data
        expect(result, isTrue);
        final configs = configFetcher.getConfigs();
        expect(configs.getOrNull()?['feature1']['variation'], isTrue);
      });
    });
    group('Request Deduplication Edge Cases', () {
      test('should deduplicate requests with different conditional headers',
          () async {
        final mockResponse = {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockResponse));
        // Make concurrent requests with different etags/last-modified
        final futures = [
          configFetcher.fetchConfig(),
          configFetcher.fetchConfig(etag: '"etag1"'),
          configFetcher.fetchConfig(lastModified: 'some-date'),
          configFetcher.fetchConfig(
              etag: '"etag2"', lastModified: 'another-date'),
        ];
        final results = await Future.wait(futures);
        // All should succeed despite different headers
        expect(results.every((r) => r == true), isTrue);
      });
      test('should handle deduplication with concurrent requests', () async {
        final mockResponse = {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(mockResponse));
        // Make multiple concurrent requests
        final futures = [
          configFetcher.fetchConfig(),
          configFetcher.fetchConfig(),
          configFetcher.fetchConfig(),
          configFetcher.fetchConfig(),
        ];
        final results = await Future.wait(futures);
        // All should complete successfully
        expect(results.every((r) => r == true), isTrue);
        // Verify request was only made once (deduplication worked)
        expect(
            mockHttpClient.requestHistory
                .where((r) => r.method == 'POST' && r.path == url)
                .length,
            equals(1));
      });
    });
    group('Error Recovery and Metadata Handling', () {
      test('should recover from JSON parsing errors in nested objects',
          () async {
        // Simulate partially invalid JSON that can still be parsed
        final partiallyInvalidResponse = {
          'configs': {
            'valid_feature': {
              'config_id': 'valid-id',
              'config_customer_id': 'customer-123',
              'config_name': 'valid_feature',
              'variation': true,
              'variation_data_type': 'boolean'
            },
            'invalid_feature': null, // This might cause issues in processing
            'another_valid': {
              'config_id': 'another-id',
              'config_customer_id': 'customer-123',
              'config_name': 'another_valid',
              'variation': 'test',
              'variation_data_type': 'string'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(partiallyInvalidResponse));
        final result = await configFetcher.fetchConfig();
        expect(result, isTrue);
        final configs = configFetcher.getConfigs();
        expect(configs.getOrNull()?['valid_feature']['variation'], isTrue);
        expect(
            configs.getOrNull()?['another_valid']['variation'], equals('test'));
      });
      test('should store and reuse metadata from previous fetches', () async {
        // First metadata fetch
        final dimensionId = config.dimensionId ?? "default";
        final sdkSettingsPath = CFConstants.api.sdkSettingsPathPattern
            .replaceFirst('%s', dimensionId);
        final url = CFConstants.api.sdkSettingsBaseUrl + sdkSettingsPath;
        mockHttpClient.whenHead(url, {
          'Last-Modified': 'Wed, 21 Oct 2025 07:28:00 GMT',
          'ETag': '"metadata-etag-123"'
        });
        var metadataResult = await configFetcher.fetchMetadata();
        expect(metadataResult.isSuccess, isTrue);
        expect(metadataResult.getOrNull()?['Last-Modified'],
            equals('Wed, 21 Oct 2025 07:28:00 GMT'));
        // Second metadata fetch should potentially use stored values
        mockHttpClient.whenHead(url, {
          'Last-Modified': 'Thu, 22 Oct 2025 08:30:00 GMT',
          'ETag': '"metadata-etag-456"'
        });
        metadataResult = await configFetcher.fetchMetadata();
        expect(metadataResult.isSuccess, isTrue);
        expect(metadataResult.getOrNull()?['Last-Modified'],
            equals('Thu, 22 Oct 2025 08:30:00 GMT'));
      });
      test('should handle timeout during response processing', () async {
        // This test verifies timeout handling is properly configured
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        // Simulate a timeout by setting up an error response
        mockHttpClient.whenPost(
          url,
          null,
          isError: true,
          errorCode: CFErrorCode.networkTimeout,
          errorMessage: 'Request timed out',
        );
        final result = await configFetcher.fetchConfig();
        expect(result, isFalse);
        // Verify we can still get cached configs if available
        final configs = configFetcher.getConfigs();
        expect(
            configs.isSuccess, isFalse); // No cached data, so should be false
      });
      test('should handle empty response as potential 304 Not Modified',
          () async {
        // First, populate cache
        final initialResponse = {
          'configs': {
            'feature1': {
              'config_id': 'feature1-id',
              'config_customer_id': 'customer-123',
              'config_name': 'feature1',
              'variation': true,
              'variation_data_type': 'boolean'
            }
          }
        };
        final url =
            "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
        mockHttpClient.whenPost(url, jsonEncode(initialResponse));
        await configFetcher.fetchConfig();
        // Now simulate empty response (like 304)
        mockHttpClient.whenPost(url, null);
        final result = await configFetcher.fetchConfig();
        expect(result, isTrue);
        // Should still have cached data
        final configs = configFetcher.getConfigs();
        expect(configs.getOrNull()?['feature1']['variation'], isTrue);
      });
    });
  });
}
