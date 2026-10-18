import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/features/calculator/calculator_screen.dart';
import 'package:nightjar/features/calculator/keypad.dart';
import 'package:nightjar/features/incident/incident.dart';
import 'package:nightjar/theme/palette.dart';
import 'package:nightjar/theme/theme.dart';

import '../support/fakes.dart';

const displayKey = ValueKey('calculator-display');

Future<Harness> pumpCalculator(
  WidgetTester tester, {
  Size size = const Size(360, 640),
  double textScale = 1.0,
  Harness? existing,
}) async {
  // No audio file path: the widget tests stay clear of real file IO, which
  // fake async cannot drive. The upload path is covered by the controller
  // tests, which run on the real event loop.
  final harness = existing ??
      await buildHarness(
        pinService: FakePinService(),
        audio: FakeAudio(status: AudioStatus.failed, path: null),
      );
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildNightjarTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: CalculatorScreen(
          store: harness.store,
          factory: harness.factory,
          pinService: FakePinService(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> tapKey(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

Finder displayText(String value) =>
    find.descendant(of: find.byKey(displayKey), matching: find.text(value));

/// Runs the fake clock past the recording and location windows so the pipeline
/// finishes and its hard cap timer is cleared before the test ends.
Future<void> finishAlert(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('holds up at 320, 360, and 420 dp without overflow',
      (tester) async {
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(420, 800),
    ]) {
      await pumpCalculator(tester, size: size);
      expect(tester.takeException(), isNull, reason: 'at $size');
      expect(find.byKey(displayKey), findsOneWidget);
      expect(find.text('='), findsOneWidget);
      expect(find.text('AC'), findsOneWidget);
    }
  });

  testWidgets('holds up at 200 percent text scale', (tester) async {
    await pumpCalculator(
      tester,
      size: const Size(320, 640),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
    expect(displayText('0'), findsOneWidget);
  });

  testWidgets('keys stay at least 56 dp at 320 dp wide', (tester) async {
    await pumpCalculator(tester, size: const Size(320, 568));
    final size = tester.getSize(find.byType(KeyButton).first);
    expect(size.width, greaterThanOrEqualTo(56));
    expect(size.height, greaterThanOrEqualTo(56));
  });

  testWidgets('keys are flat rectangles with the spec radius',
      (tester) async {
    await pumpCalculator(tester);
    final equals = tester.widget<AnimatedContainer>(
      find
          .ancestor(of: find.text('='), matching: find.byType(AnimatedContainer))
          .first,
    );
    final decoration = equals.decoration! as BoxDecoration;
    expect(decoration.color, Palette.oxide);
    expect(
      (decoration.borderRadius! as BorderRadius).topLeft.x,
      6,
    );
    expect(decoration.boxShadow, isNull);

    final digit = tester.widget<AnimatedContainer>(
      find
          .ancestor(of: find.text('7'), matching: find.byType(AnimatedContainer))
          .first,
    );
    final digitDecoration = digit.decoration! as BoxDecoration;
    expect(digitDecoration.color, Palette.keySurface);
  });

  testWidgets('taps compute with immediate execution', (tester) async {
    await pumpCalculator(tester);
    await tapKey(tester, '7');
    await tapKey(tester, '+');
    await tapKey(tester, '3');
    await tapKey(tester, '=');
    await tester.pumpAndSettle();
    expect(displayText('10'), findsOneWidget);
  });

  testWidgets('AC clears the display', (tester) async {
    await pumpCalculator(tester);
    await tapKey(tester, '9');
    await tapKey(tester, 'AC');
    await tester.pumpAndSettle();
    expect(displayText('0'), findsOneWidget);
  });

  testWidgets('a long press under two seconds does not open the gate',
      (tester) async {
    await pumpCalculator(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('AC')));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Enter PIN'), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsNothing);
  });

  testWidgets('a two second long press opens the PIN gate', (tester) async {
    await pumpCalculator(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('AC')));
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a long press does not clear the display on release',
      (tester) async {
    await pumpCalculator(tester);
    await tapKey(tester, '8');
    await tapKey(tester, '5');
    final gesture = await tester.startGesture(tester.getCenter(find.text('AC')));
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(displayText('85'), findsOneWidget);
  });

  testWidgets('a triple tap starts an alert and shows no setup',
      (tester) async {
    final harness = await pumpCalculator(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(displayKey));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Enter PIN'), findsNothing);
    expect(find.text('Create a PIN'), findsNothing);
    expect(harness.writer.created, isNotEmpty);
    expect(harness.writer.created.single.trigger, TriggerKind.tripleTap);
    expect(displayText('0'), findsOneWidget);
    await finishAlert(tester);
  });

  testWidgets('a fourth tap during an active alert starts nothing new',
      (tester) async {
    final harness = await pumpCalculator(tester);
    for (var round = 0; round < 2; round++) {
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(displayKey));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(harness.writer.created, hasLength(1));
    await finishAlert(tester);
  });

  testWidgets('PIN then equals starts an alert and offers no confirmation',
      (tester) async {
    final harness = await pumpCalculator(tester);
    for (final digit in ['4', '8', '2', '6']) {
      await tapKey(tester, digit);
    }
    await tester.tap(find.text('='));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(displayText('0'), findsOneWidget);
    expect(harness.writer.created, hasLength(1));
    expect(harness.writer.created.single.trigger, TriggerKind.pin);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await finishAlert(tester);
  });

  testWidgets('the trigger pulses haptics and never plays a sound',
      (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpCalculator(tester);
    for (final digit in ['4', '8', '2', '6']) {
      await tapKey(tester, digit);
    }
    await tester.tap(find.text('='));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      calls.any((call) => call.method == 'HapticFeedback.vibrate'),
      isTrue,
    );
    expect(
      calls.any((call) => call.method == 'SystemSound.play'),
      isFalse,
    );
    await finishAlert(tester);
  });

  testWidgets('a wrong PIN falls through to a normal calculation',
      (tester) async {
    await pumpCalculator(tester);
    for (final digit in ['1', '3', '5', '7']) {
      await tapKey(tester, digit);
    }
    await tester.tap(find.text('='));
    await tester.pumpAndSettle();
    expect(displayText('1,357'), findsOneWidget);
  });
}
