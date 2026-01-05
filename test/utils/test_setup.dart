import 'package:flutter_test/flutter_test.dart';
import 'test_plugin_mocks.dart';
/// Common test setup that all tests should use
class TestSetup {
  static bool _isSetup = false;
  /// Initialize the test environment with all necessary mocks and bindings
  static void initialize() {
    if (_isSetup) return;
    // Ensure Flutter test bindings are initialized
    TestWidgetsFlutterBinding.ensureInitialized();
    // Initialize all plugin mocks
    TestPluginMocks.initializePluginMocks();
    _isSetup = true;
  }
  /// Reset test environment (call this in tearDown)
  static void reset() {
    TestPluginMocks.resetMocks();
    _isSetup = false;
  }
  /// Setup method for each test group
  static void setupGroup() {
    setUpAll(() {
      initialize();
    });
    tearDownAll(() {
      reset();
    });
  }
  /// Setup method for each individual test
  static void setupTest() {
    setUp(() {
      initialize();
    });
    tearDown(() {
      // Reset mocks after each test to ensure clean state
      TestPluginMocks.resetMocks();
      TestPluginMocks.initializePluginMocks();
    });
  }
}