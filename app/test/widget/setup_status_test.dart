import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/features/setup/permissions_screen.dart';
import 'package:nightjar/features/setup/setup_status_screen.dart';
import 'package:nightjar/services/secure_store.dart';
import 'package:nightjar/theme/theme.dart';
import 'package:permission_handler/permission_handler.dart';

import '../support/fakes.dart';

PermissionRowState okRow(String title, Permission permission) =>
    PermissionRowState(
      title: title,
      explanation: 'explanation',
      permission: permission,
      status: PermissionStatus.granted,
      fullAlert: true,
    );

Future<void> pumpStatus(
  WidgetTester tester, {
  required SetupStore store,
  required List<PermissionRowState> rows,
  required bool battery,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildNightjarTheme(),
      home: SetupStatusScreen(
        store: store,
        pinService: FakePinService(),
        rowsLoader: () async => rows,
        batteryGranted: () async => battery,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a complete setup shows no amber line', (tester) async {
    final harness = await buildHarness(pinService: FakePinService());
    await pumpStatus(
      tester,
      store: harness.store,
      rows: [
        okRow('Microphone', Permission.microphone),
        okRow('Location', Permission.location),
        okRow('SMS', Permission.sms),
      ],
      battery: true,
    );

    expect(find.text('Safety settings'), findsOneWidget);
    expect(find.text('Set'), findsOneWidget);
    expect(find.text('3 of 3'), findsOneWidget);
    expect(find.text('All set'), findsOneWidget);
    expect(find.text('Allowed'), findsOneWidget);
    expect(find.text('No test yet'), findsOneWidget);
    expect(
      find.text('Finish the amber items before you rely on Nightjar.'),
      findsNothing,
    );
    expect(find.text('Send a test alert'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('missing pieces show counts and the amber line', (tester) async {
    final store = SetupStore(MemorySecretStore());
    await pumpStatus(
      tester,
      store: store,
      rows: [
        okRow('Microphone', Permission.microphone),
        PermissionRowState(
          title: 'SMS',
          explanation: 'explanation',
          permission: Permission.sms,
          status: PermissionStatus.denied,
          fullAlert: true,
        ),
      ],
      battery: false,
    );

    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('0 of 3'), findsOneWidget);
    expect(find.text('1 need attention'), findsOneWidget);
    expect(find.text('Restricted'), findsOneWidget);
    expect(
      find.text('Finish the amber items before you rely on Nightjar.'),
      findsOneWidget,
    );
  });

  testWidgets('the triple tap switch writes its state', (tester) async {
    final harness = await buildHarness(pinService: FakePinService());
    await pumpStatus(
      tester,
      store: harness.store,
      rows: [okRow('Microphone', Permission.microphone)],
      battery: true,
    );
    expect(find.text('Triple-tap trigger'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    await tester.ensureVisible(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(await harness.store.readTripleTapEnabled(), isFalse);
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('the name row falls back to the default label',
      (tester) async {
    final store = SetupStore(MemorySecretStore());
    await pumpStatus(
      tester,
      store: store,
      rows: [okRow('Microphone', Permission.microphone)],
      battery: true,
    );
    expect(find.text('Name in the alert'), findsOneWidget);
    expect(find.text('Shows as a contact'), findsOneWidget);

    await tester.ensureVisible(find.text('Name in the alert'));
    await tester.pump();
    await tester.tap(find.text('Name in the alert'));
    // Not pumpAndSettle: the focused field in the dialog keeps animating.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Amal');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await store.readOwnerName(), 'Amal');
    expect(find.text('Amal'), findsOneWidget);
  });
}
