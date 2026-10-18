import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/features/setup/pin_gate_screen.dart';
import 'package:nightjar/services/secure_store.dart';
import 'package:nightjar/theme/theme.dart';

import '../support/fakes.dart';

Future<SetupStore> emptyStore() async => SetupStore(MemorySecretStore());

/// A fake record: fast, and any FakePinService instance can verify it.
Future<SetupStore> storeWithPin(String pin) async {
  final store = SetupStore(MemorySecretStore());
  await store.writePin(await FakePinService().create(pin));
  return store;
}

Future<void> pumpGate(
  WidgetTester tester,
  SetupStore store, {
  PinGatePurpose purpose = PinGatePurpose.unlockOrCreate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildNightjarTheme(),
      home: PinGateScreen(
        store: store,
        purpose: purpose,
        pinService: FakePinService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> enterPin(WidgetTester tester, String pin, {int field = 0}) async {
  await tester.enterText(find.byType(TextField).at(field), pin);
  await tester.pump();
}

Future<void> press(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  // Not pumpAndSettle: a focused text field keeps an animation running.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('a short PIN is rejected with the deck copy', (tester) async {
    final store = await emptyStore();
    await pumpGate(tester, store);
    expect(find.text('Create a PIN'), findsOneWidget);
    expect(
      find.text('Use 4 to 8 digits. Avoid repeated or sequential numbers.'),
      findsOneWidget,
    );
    await enterPin(tester, '12');
    await press(tester, 'Continue');
    expect(find.text('Use 4 to 8 digits.'), findsOneWidget);
    expect(await store.readPin(), isNull);
  });

  testWidgets('a sequential PIN is rejected', (tester) async {
    final store = await emptyStore();
    await pumpGate(tester, store);
    await enterPin(tester, '1234');
    await enterPin(tester, '1234', field: 1);
    await press(tester, 'Continue');
    expect(
      find.text('Avoid repeated or sequential numbers.'),
      findsOneWidget,
    );
    expect(await store.readPin(), isNull);
  });

  testWidgets('a mismatched confirmation is rejected', (tester) async {
    final store = await emptyStore();
    await pumpGate(tester, store);
    await enterPin(tester, '4826');
    await enterPin(tester, '4827', field: 1);
    await press(tester, 'Continue');
    expect(find.text('PINs do not match.'), findsOneWidget);
    expect(await store.readPin(), isNull);
  });

  testWidgets('a valid PIN is stored and setup opens', (tester) async {
    final store = await emptyStore();
    await pumpGate(tester, store);
    await enterPin(tester, '4826');
    await enterPin(tester, '4826', field: 1);
    await press(tester, 'Continue');
    expect(await store.readPin(), isNotNull);
    expect(find.text('Safety settings'), findsOneWidget);
  });

  testWidgets('the show toggle reveals the digits', (tester) async {
    final store = await emptyStore();
    await pumpGate(tester, store);
    await enterPin(tester, '4826');
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText,
        isTrue);
    await tester.tap(find.byTooltip('Show PIN').first);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText,
        isFalse);
  });

  testWidgets('a wrong PIN shows the deck copy and does not open setup',
      (tester) async {
    final store = await storeWithPin('4826');
    await pumpGate(tester, store);
    expect(find.text('Enter PIN'), findsOneWidget);
    await enterPin(tester, '9999');
    await press(tester, 'Unlock');
    expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
    expect(find.text('Safety settings'), findsNothing);
  });

  testWidgets('a correct PIN opens setup', (tester) async {
    final store = await storeWithPin('4826');
    await pumpGate(tester, store);
    await enterPin(tester, '4826');
    await press(tester, 'Unlock');
    expect(find.text('Safety settings'), findsOneWidget);
  });

  testWidgets('five wrong attempts lock the gate for 30 seconds',
      (tester) async {
    final store = await storeWithPin('4826');
    await pumpGate(tester, store);
    for (var attempt = 0; attempt < 5; attempt++) {
      await enterPin(tester, '9999');
      await press(tester, 'Unlock');
    }
    expect(
      find.text('Too many attempts. Try again in 30 seconds.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Unlock'),
    );
    expect(button.onPressed, isNull);
    final lockout = await store.readLockout();
    expect(lockout.isLocked(DateTime.now()), isTrue);
  });

  testWidgets('the lockout survives a new gate instance', (tester) async {
    final store = await storeWithPin('4826');
    await pumpGate(tester, store);
    for (var attempt = 0; attempt < 5; attempt++) {
      await enterPin(tester, '9999');
      await press(tester, 'Unlock');
    }
    await pumpGate(tester, store);
    expect(find.textContaining('Too many attempts'), findsOneWidget);
  });

  testWidgets('back returns to the calculator', (tester) async {
    final store = await storeWithPin('4826');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildNightjarTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PinGateScreen(
                      store: store,
                      pinService: FakePinService(),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsOneWidget);
    await tester.tap(find.text('Back to calculator'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('changing the PIN needs the current PIN first', (tester) async {
    final store = await storeWithPin('4826');
    await pumpGate(tester, store, purpose: PinGatePurpose.changePin);
    await enterPin(tester, '4826');
    await press(tester, 'Unlock');
    expect(find.text('Create a PIN'), findsOneWidget);
    await enterPin(tester, '4826');
    await enterPin(tester, '4826', field: 1);
    await press(tester, 'Continue');
    expect(find.text('Choose a PIN you have not used before.'), findsOneWidget);
    await enterPin(tester, '9182');
    await enterPin(tester, '9182', field: 1);
    await press(tester, 'Continue');
    final record = await store.readPin();
    expect(record, isNotNull);
    expect(await FakePinService().verify('9182', record!), isTrue);
  });
}
