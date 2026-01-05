import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
/// Helper class to manage TestWidgetsFlutterBinding lifecycle
/// Prevents resource exhaustion from multiple binding initializations
class TestBindingHelper {
  static bool _isInitialized = false;
  /// Ensures the test binding is initialized only once
  /// Safe to call multiple times - subsequent calls are no-ops
  static void ensureInitialized() {
    if (!_isInitialized) {
      TestWidgetsFlutterBinding.ensureInitialized();
      _isInitialized = true;
    }
  }
  /// Reset the initialization state (useful for test cleanup)
  /// Note: This doesn't actually reset the binding, just our tracking
  static void reset() {
    _isInitialized = false;
  }
}
/// Extension on WidgetTester for common test patterns
extension TestHelperExtensions on WidgetTester {
  /// Pump and settle with a timeout to prevent infinite loops
  Future<void> pumpAndSettleWithTimeout({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);
    await pump();
    while (DateTime.now().isBefore(end)) {
      if (binding.hasScheduledFrame) {
        await pump(const Duration(milliseconds: 100));
      } else {
        return;
      }
    }
    throw TimeoutException('pumpAndSettle timed out', timeout);
  }
}
/// Mixin for tests that need TestWidgetsFlutterBinding
/// Automatically handles initialization
mixin TestBindingMixin {
  void setUpTestBinding() {
    TestBindingHelper.ensureInitialized();
  }
}