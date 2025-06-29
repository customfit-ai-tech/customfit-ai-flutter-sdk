import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/app_state.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AppState Tests', () {
    group('Enum Values', () {
      test('should have all expected app states', () {
        expect(AppState.values, hasLength(4));
        expect(AppState.values, contains(AppState.active));
        expect(AppState.values, contains(AppState.background));
        expect(AppState.values, contains(AppState.inactive));
        expect(AppState.values, contains(AppState.unknown));
      });
    });
    group('stringValue Extension Method', () {
      test('should convert active state to string', () {
        expect(AppState.active.stringValue, equals('active'));
      });
      test('should convert background state to string', () {
        expect(AppState.background.stringValue, equals('background'));
      });
      test('should convert inactive state to string', () {
        expect(AppState.inactive.stringValue, equals('inactive'));
      });
      test('should convert unknown state to string', () {
        expect(AppState.unknown.stringValue, equals('unknown'));
      });
      test('should handle all enum values in stringValue', () {
        for (final state in AppState.values) {
          final stringValue = state.stringValue;
          expect(stringValue, isNotEmpty);
          expect(stringValue, isA<String>());
        }
      });
    });
    group('fromString Extension Method', () {
      test('should create active state from string', () {
        expect(AppStateExtension.fromString('active'), equals(AppState.active));
      });
      test('should create background state from string', () {
        expect(AppStateExtension.fromString('background'),
            equals(AppState.background));
      });
      test('should create inactive state from string', () {
        expect(AppStateExtension.fromString('inactive'),
            equals(AppState.inactive));
      });
      test('should create unknown state from string', () {
        expect(
            AppStateExtension.fromString('unknown'), equals(AppState.unknown));
      });
      test('should handle uppercase strings', () {
        expect(AppStateExtension.fromString('ACTIVE'), equals(AppState.active));
        expect(AppStateExtension.fromString('BACKGROUND'),
            equals(AppState.background));
        expect(AppStateExtension.fromString('INACTIVE'),
            equals(AppState.inactive));
        expect(
            AppStateExtension.fromString('UNKNOWN'), equals(AppState.unknown));
      });
      test('should handle mixed case strings', () {
        expect(AppStateExtension.fromString('AcTiVe'), equals(AppState.active));
        expect(AppStateExtension.fromString('BaCkGrOuNd'),
            equals(AppState.background));
        expect(AppStateExtension.fromString('InAcTiVe'),
            equals(AppState.inactive));
        expect(
            AppStateExtension.fromString('UnKnOwN'), equals(AppState.unknown));
      });
      test('should return unknown as default for invalid strings', () {
        expect(
            AppStateExtension.fromString('invalid'), equals(AppState.unknown));
        expect(AppStateExtension.fromString(''), equals(AppState.unknown));
        expect(
            AppStateExtension.fromString('running'), equals(AppState.unknown));
        expect(AppStateExtension.fromString('123'), equals(AppState.unknown));
      });
      test('should handle whitespace strings', () {
        // The implementation doesn't trim whitespace, so these return unknown (default)
        expect(AppStateExtension.fromString('  active  '),
            equals(AppState.unknown));
        expect(AppStateExtension.fromString(' background '),
            equals(AppState.unknown));
        expect(AppStateExtension.fromString('\tinactive\t'),
            equals(AppState.unknown));
        expect(AppStateExtension.fromString('\nunknown\n'),
            equals(AppState.unknown));
      });
      test('should handle special characters', () {
        expect(
            AppStateExtension.fromString('active!'), equals(AppState.unknown));
        expect(AppStateExtension.fromString('background@'),
            equals(AppState.unknown));
        expect(AppStateExtension.fromString('inactive#'),
            equals(AppState.unknown));
        expect(AppStateExtension.fromString('unknown\$'),
            equals(AppState.unknown));
      });
    });
    group('fromAppLifecycleState Extension Method', () {
      test('should convert resumed to active state', () {
        expect(
          AppStateExtension.fromAppLifecycleState(AppLifecycleState.resumed),
          equals(AppState.active),
        );
      });
      test('should convert inactive to inactive state', () {
        expect(
          AppStateExtension.fromAppLifecycleState(AppLifecycleState.inactive),
          equals(AppState.inactive),
        );
      });
      test('should convert paused to background state', () {
        expect(
          AppStateExtension.fromAppLifecycleState(AppLifecycleState.paused),
          equals(AppState.background),
        );
      });
      test('should convert detached to background state', () {
        expect(
          AppStateExtension.fromAppLifecycleState(AppLifecycleState.detached),
          equals(AppState.background),
        );
      });
      test('should handle all AppLifecycleState values', () {
        for (final lifecycleState in AppLifecycleState.values) {
          final appState =
              AppStateExtension.fromAppLifecycleState(lifecycleState);
          expect(appState, isA<AppState>());
          expect(AppState.values.contains(appState), isTrue);
        }
      });
    });
    group('Round-trip Conversion', () {
      test('should maintain consistency between stringValue and fromString',
          () {
        for (final state in AppState.values) {
          final stringValue = state.stringValue;
          final reconstructed = AppStateExtension.fromString(stringValue);
          expect(reconstructed, equals(state));
        }
      });
    });
    group('Use Cases', () {
      test('should be usable in switch statements', () {
        String getStateMessage(AppState state) {
          switch (state) {
            case AppState.active:
              return 'App is active and in foreground';
            case AppState.background:
              return 'App is in background';
            case AppState.inactive:
              return 'App is transitioning';
            case AppState.unknown:
              return 'App state is unknown';
          }
        }
        expect(getStateMessage(AppState.active), contains('foreground'));
        expect(getStateMessage(AppState.background), contains('background'));
        expect(getStateMessage(AppState.inactive), contains('transitioning'));
        expect(getStateMessage(AppState.unknown), contains('unknown'));
      });
      test('should be comparable', () {
        const state1 = AppState.active;
        const state2 = AppState.active;
        const state3 = AppState.background;
        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
      test('should work in collections', () {
        final states = <AppState>{
          AppState.active,
          AppState.background,
          AppState.inactive,
          AppState.unknown,
        };
        expect(states.length, equals(4));
        expect(states.contains(AppState.active), isTrue);
        expect(states.contains(AppState.background), isTrue);
      });
      test('should handle state transitions', () {
        // Simulate app lifecycle transitions
        final transitions = [
          AppLifecycleState.resumed,
          AppLifecycleState.inactive,
          AppLifecycleState.paused,
          AppLifecycleState.detached,
          AppLifecycleState.resumed,
        ];
        final appStates = transitions
            .map((state) => AppStateExtension.fromAppLifecycleState(state))
            .toList();
        expect(appStates[0], equals(AppState.active));
        expect(appStates[1], equals(AppState.inactive));
        expect(appStates[2], equals(AppState.background));
        expect(appStates[3], equals(AppState.background));
        expect(appStates[4], equals(AppState.active));
      });
    });
    group('Edge Cases', () {
      test('should handle rapid state changes', () {
        final rapidStates = List.generate(100, (index) {
          const lifecycleStates = AppLifecycleState.values;
          return lifecycleStates[index % lifecycleStates.length];
        });
        for (final lifecycleState in rapidStates) {
          final appState =
              AppStateExtension.fromAppLifecycleState(lifecycleState);
          expect(appState, isA<AppState>());
        }
      });
      test('should handle concurrent conversions', () {
        final futures = <Future<AppState>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(Future(() => AppStateExtension.fromString('active')));
          futures.add(Future(() => AppStateExtension.fromString('background')));
          futures.add(Future(() => AppStateExtension.fromAppLifecycleState(
              AppLifecycleState.resumed)));
        }
        expectLater(Future.wait(futures), completes);
      });
    });
    group('Platform Consistency', () {
      test('should provide consistent state names across platforms', () {
        // These state names should be consistent with iOS/Android conventions
        expect(AppState.active.stringValue, equals('active'));
        expect(AppState.background.stringValue, equals('background'));
        expect(AppState.inactive.stringValue, equals('inactive'));
        expect(AppState.unknown.stringValue, equals('unknown'));
      });
      test('should map Flutter lifecycle states correctly', () {
        // Verify the mapping follows Flutter's lifecycle documentation
        expect(
          AppStateExtension.fromAppLifecycleState(AppLifecycleState.resumed),
          equals(AppState.active),
          reason: 'resumed should map to active state',
        );
        expect(
          AppStateExtension.fromAppLifecycleState(AppLifecycleState.paused),
          equals(AppState.background),
          reason: 'paused should map to background state',
        );
      });
    });
  });
}
