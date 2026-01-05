import 'dart:convert';

/// Properties associated with a feature flag configuration
class ConfigProperties {
  final bool systemCreated;
  final bool isFeatureFlag;
  final String? createdByName;
  final String? createdByEmail;
  final String? featureFlagType;

  const ConfigProperties({
    required this.systemCreated,
    required this.isFeatureFlag,
    this.createdByName,
    this.createdByEmail,
    this.featureFlagType,
  });

  factory ConfigProperties.fromJson(Map<String, dynamic> json) {
    return ConfigProperties(
      systemCreated: json['system_created'] as bool? ?? false,
      isFeatureFlag: json['is_feature_flag'] as bool? ?? false,
      createdByName: json['created_by_name'] as String?,
      createdByEmail: json['created_by_email'] as String?,
      featureFlagType: json['feature_flag_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'system_created': systemCreated,
      'is_feature_flag': isFeatureFlag,
      if (createdByName != null) 'created_by_name': createdByName,
      if (createdByEmail != null) 'created_by_email': createdByEmail,
      if (featureFlagType != null) 'feature_flag_type': featureFlagType,
    };
  }
}

/// Experience behavior response containing targeting and experience information
class ExperienceBehaviourResponse {
  final String? experienceId;
  final String? behaviour;
  final String? behaviourId;
  final String? variationId;
  final int? priority;
  final int? experienceCreatedTime;
  final String? ruleId;
  final String? experience;
  final String? audienceName;
  final String? gaMeasurementId;
  final String? type;
  final Map<String, dynamic>? configModifications;

  const ExperienceBehaviourResponse({
    this.experienceId,
    this.behaviour,
    this.behaviourId,
    this.variationId,
    this.priority,
    this.experienceCreatedTime,
    this.ruleId,
    this.experience,
    this.audienceName,
    this.gaMeasurementId,
    this.type,
    this.configModifications,
  });

  factory ExperienceBehaviourResponse.fromJson(Map<String, dynamic> json) {
    return ExperienceBehaviourResponse(
      experienceId: json['experience_id'] as String?,
      behaviour: json['behaviour'] as String?,
      behaviourId: json['behaviour_id'] as String?,
      variationId: json['variation_id'] as String?,
      priority: json['priority'] as int?,
      experienceCreatedTime: json['experience_created_time'] as int?,
      ruleId: json['rule_id'] as String?,
      experience: json['experience'] as String?,
      audienceName: json['audience_name'] as String?,
      gaMeasurementId: json['ga_measurement_id'] as String?,
      type: json['type'] as String?,
      configModifications:
          json['config_modifications'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (experienceId != null) 'experience_id': experienceId,
      if (behaviour != null) 'behaviour': behaviour,
      if (behaviourId != null) 'behaviour_id': behaviourId,
      if (variationId != null) 'variation_id': variationId,
      if (priority != null) 'priority': priority,
      if (experienceCreatedTime != null)
        'experience_created_time': experienceCreatedTime,
      if (ruleId != null) 'rule_id': ruleId,
      if (experience != null) 'experience': experience,
      if (audienceName != null) 'audience_name': audienceName,
      if (gaMeasurementId != null) 'ga_measurement_id': gaMeasurementId,
      if (type != null) 'type': type,
      if (configModifications != null)
        'config_modifications': configModifications,
    };
  }
}

/// Individual feature flag configuration from the API response
class FeatureFlagConfig {
  final String configId;
  final String configCustomerId;
  final String configName;
  final dynamic variation; // Can be bool, String, num, or Map<String, dynamic>
  final String? variationName;
  final String? variationId;
  final String? variationDataType;
  final ExperienceBehaviourResponse? experienceBehaviourResponse;
  final int? version;
  final ConfigProperties? properties;
  final String? configCreatedAt;

  const FeatureFlagConfig({
    required this.configId,
    required this.configCustomerId,
    required this.configName,
    required this.variation,
    this.variationName,
    this.variationId,
    this.variationDataType,
    this.experienceBehaviourResponse,
    this.version,
    this.properties,
    this.configCreatedAt,
  });

  /// Create from API response data
  factory FeatureFlagConfig.fromJson(Map<String, dynamic> json) {
    return FeatureFlagConfig(
      configId: json['config_id'] as String? ?? '',
      configCustomerId: json['config_customer_id'] as String? ?? '',
      configName: json['config_name'] as String? ?? '',
      variation:
          json['variation'], // Keep as dynamic since it can be various types
      variationName: json['variation_name'] as String?,
      variationId: json['variation_id'] as String?,
      variationDataType: json['variation_data_type'] as String?,
      experienceBehaviourResponse:
          json['experience_behaviour_response'] != null &&
                  json['experience_behaviour_response'] is Map<String, dynamic>
              ? ExperienceBehaviourResponse.fromJson(
                  json['experience_behaviour_response'] as Map<String, dynamic>)
              : null,
      version: json['version'] as int?,
      properties: json['properties'] != null &&
              json['properties'] is Map<String, dynamic>
          ? ConfigProperties.fromJson(
              json['properties'] as Map<String, dynamic>)
          : null,
      configCreatedAt: json['config_created_at'] as String?,
    );
  }

  /// Get the variation value as a specific type with type safety
  T? getVariationAs<T>() {
    if (variation is T) {
      return variation as T;
    }
    return null;
  }

  /// Check if this is a boolean flag
  bool get isBooleanFlag => variationDataType?.toLowerCase() == 'boolean';

  /// Check if this is a string flag
  bool get isStringFlag => variationDataType?.toLowerCase() == 'string';

  /// Check if this is a number flag
  bool get isNumberFlag => variationDataType?.toLowerCase() == 'number';

  /// Check if this is a JSON flag
  bool get isJsonFlag => variationDataType?.toLowerCase() == 'json';

  Map<String, dynamic> toJson() {
    return {
      'config_id': configId,
      'config_customer_id': configCustomerId,
      'config_name': configName,
      'variation': variation,
      if (variationName != null) 'variation_name': variationName,
      if (variationId != null) 'variation_id': variationId,
      if (variationDataType != null) 'variation_data_type': variationDataType,
      if (experienceBehaviourResponse != null)
        'experience_behaviour_response': experienceBehaviourResponse!.toJson(),
      if (version != null) 'version': version,
      if (properties != null) 'properties': properties!.toJson(),
      if (configCreatedAt != null) 'config_created_at': configCreatedAt,
    };
  }

  @override
  String toString() =>
      'FeatureFlagConfig(configId: $configId, variation: $variation, type: $variationDataType)';
}

/// Page paths configuration for targeting
class PagePaths {
  final List<String> pagePathsContainsList;
  final List<String> pagePathsRegexList;
  final List<String> pagePathsExactMatchList;

  const PagePaths({
    this.pagePathsContainsList = const [],
    this.pagePathsRegexList = const [],
    this.pagePathsExactMatchList = const [],
  });

  factory PagePaths.fromJson(Map<String, dynamic> json) {
    return PagePaths(
      pagePathsContainsList:
          (json['page_paths_contains_list'] as List<dynamic>?)
                  ?.cast<String>() ??
              [],
      pagePathsRegexList:
          (json['page_paths_regex_list'] as List<dynamic>?)?.cast<String>() ??
              [],
      pagePathsExactMatchList:
          (json['page_paths_exact_match_list'] as List<dynamic>?)
                  ?.cast<String>() ??
              [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page_paths_contains_list': pagePathsContainsList,
      'page_paths_regex_list': pagePathsRegexList,
      'page_paths_exact_match_list': pagePathsExactMatchList,
    };
  }
}

/// Complete strongly typed response model for config fetch operations
class ConfigResponse {
  final String? userId;
  final String? userCustomerId;
  final Map<String, FeatureFlagConfig> configs;
  final PagePaths pagePaths;
  final String? longUrl;
  final String? cfLatestSdkVersion;

  const ConfigResponse({
    this.userId,
    this.userCustomerId,
    required this.configs,
    required this.pagePaths,
    this.longUrl,
    this.cfLatestSdkVersion,
  });

  /// Create from API response JSON
  factory ConfigResponse.fromJson(Map<String, dynamic> json) {
    final configsJson = json['configs'] as Map<String, dynamic>? ?? {};

    final configs = <String, FeatureFlagConfig>{};
    for (final entry in configsJson.entries) {
      if (entry.value is Map<String, dynamic>) {
        configs[entry.key] =
            FeatureFlagConfig.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    return ConfigResponse(
      userId: json['user_id'] as String?,
      userCustomerId: json['user_customer_id'] as String?,
      configs: configs,
      pagePaths: json['page_paths'] != null
          ? PagePaths.fromJson(json['page_paths'] as Map<String, dynamic>)
          : const PagePaths(),
      longUrl: json['long_url'] as String?,
      cfLatestSdkVersion: json['cf_latest_sdk_version'] as String?,
    );
  }

  /// Create from JSON string
  factory ConfigResponse.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return ConfigResponse.fromJson(json);
  }

  /// Get a specific flag configuration
  FeatureFlagConfig? getFlag(String flagKey) => configs[flagKey];

  /// Check if a flag exists
  bool hasFlag(String flagKey) => configs.containsKey(flagKey);

  /// Get all flag keys
  List<String> get flagKeys => configs.keys.toList();

  /// Get number of configs
  int get configCount => configs.length;

  /// Get boolean flag value with default
  bool getBooleanFlag(String flagKey, {bool defaultValue = false}) {
    final flag = getFlag(flagKey);
    return flag?.getVariationAs<bool>() ?? defaultValue;
  }

  /// Get string flag value with default
  String getStringFlag(String flagKey, {String defaultValue = ''}) {
    final flag = getFlag(flagKey);
    return flag?.getVariationAs<String>() ?? defaultValue;
  }

  /// Get number flag value with default
  num getNumberFlag(String flagKey, {num defaultValue = 0}) {
    final flag = getFlag(flagKey);
    return flag?.getVariationAs<num>() ?? defaultValue;
  }

  /// Get JSON flag value with default
  Map<String, dynamic> getJsonFlag(String flagKey,
      {Map<String, dynamic> defaultValue = const {}}) {
    final flag = getFlag(flagKey);
    final variation = flag?.variation;
    if (variation is Map<String, dynamic>) {
      return variation;
    }
    return defaultValue;
  }

  Map<String, dynamic> toJson() {
    return {
      if (userId != null) 'user_id': userId,
      if (userCustomerId != null) 'user_customer_id': userCustomerId,
      'configs': configs.map((key, value) => MapEntry(key, value.toJson())),
      'page_paths': pagePaths.toJson(),
      if (longUrl != null) 'long_url': longUrl,
      if (cfLatestSdkVersion != null)
        'cf_latest_sdk_version': cfLatestSdkVersion,
    };
  }

  @override
  String toString() =>
      'ConfigResponse(configCount: $configCount, userCustomerId: $userCustomerId, sdkVersion: $cfLatestSdkVersion)';
}
