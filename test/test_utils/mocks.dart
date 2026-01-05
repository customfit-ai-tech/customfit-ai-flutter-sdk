import 'package:mockito/annotations.dart';
import 'package:customfit_ai_flutter_sdk/src/client/cf_client.dart';
import 'package:customfit_ai_flutter_sdk/src/client/cf_client_feature_flags.dart';
import 'package:customfit_ai_flutter_sdk/src/client/cf_client_events.dart';
import 'package:customfit_ai_flutter_sdk/src/client/cf_client_listeners.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/listener_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_tracker.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/config_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/summary/summary_manager.dart';
// Generate mocks for testing
@GenerateMocks([
  CFClient,
  CFClientFeatureFlags,
  CFClientEvents,
  CFClientListeners,
  ListenerManager,
  EventTracker,
  ConfigManager,
  SummaryManager,
])
void main() {}