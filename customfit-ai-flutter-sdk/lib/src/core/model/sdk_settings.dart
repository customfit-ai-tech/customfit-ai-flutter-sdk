import 'package:flutter/foundation.dart';
import '../error/cf_result.dart';

/// Simplified SDK settings model with only essential fields
@immutable
class SdkSettings {
  final bool cfAccountEnabled;
  final bool cfSkipSdk;
  final List<String> ruleEvents;

  const SdkSettings({
    required this.cfAccountEnabled,
    required this.cfSkipSdk,
    required this.ruleEvents,
  });

  factory SdkSettings.fromJson(Map<String, dynamic> json) {
    return SdkSettings(
      cfAccountEnabled: json['cf_account_enabled'] as bool? ?? true,
      cfSkipSdk: json['cf_skip_sdk'] as bool? ?? false,
      ruleEvents: List<String>.from(json['rule_events'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cf_account_enabled': cfAccountEnabled,
      'cf_skip_sdk': cfSkipSdk,
      'rule_events': ruleEvents,
    };
  }

  SdkSettings copyWith({
    bool? cfAccountEnabled,
    bool? cfSkipSdk,
    List<String>? ruleEvents,
  }) {
    return SdkSettings(
      cfAccountEnabled: cfAccountEnabled ?? this.cfAccountEnabled,
      cfSkipSdk: cfSkipSdk ?? this.cfSkipSdk,
      ruleEvents: ruleEvents ?? this.ruleEvents,
    );
  }

  static SdkSettingsBuilder builder() => SdkSettingsBuilder();
}

class SdkSettingsBuilder {
  bool _cfAccountEnabled = true;
  bool _cfSkipSdk = false;
  List<String> _ruleEvents = [];

  SdkSettingsBuilder cfAccountEnabled(bool enabled) {
    _cfAccountEnabled = enabled;
    return this;
  }

  SdkSettingsBuilder cfSkipSdk(bool skip) {
    _cfSkipSdk = skip;
    return this;
  }

  SdkSettingsBuilder ruleEvents(List<String> events) {
    _ruleEvents = events;
    return this;
  }

  CFResult<SdkSettings> build() {
    try {
      return CFResult.success(SdkSettings(
        cfAccountEnabled: _cfAccountEnabled,
        cfSkipSdk: _cfSkipSdk,
        ruleEvents: _ruleEvents,
      ));
    } catch (e) {
      return CFResult.error(
        'Failed to build SdkSettings: $e',
        exception: e,
      );
    }
  }
}
