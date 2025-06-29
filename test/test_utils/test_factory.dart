import 'dart:async';
class TestFactory {
  /// Creates a broadcast stream controller for testing
  static StreamController<T> createStreamController<T>() {
    return StreamController<T>.broadcast();
  }
  /// Creates a stream with initial values for testing
  static Stream<T> createStream<T>(List<T> values) {
    final controller = StreamController<T>.broadcast();
    // Emit values asynchronously
    Future.microtask(() async {
      for (final value in values) {
        controller.add(value);
        await Future.delayed(const Duration(milliseconds: 10));
      }
      await controller.close();
    });
    return controller.stream;
  }
  /// Creates a future that completes after a delay
  static Future<T> delayedFuture<T>(T value, {Duration? delay}) {
    return Future.delayed(
      delay ?? const Duration(milliseconds: 100),
      () => value,
    );
  }
  /// Creates a future that fails after a delay
  static Future<T> failedFuture<T>(Object error, {Duration? delay}) {
    return Future.delayed(
      delay ?? const Duration(milliseconds: 100),
      () => throw error,
    );
  }
}