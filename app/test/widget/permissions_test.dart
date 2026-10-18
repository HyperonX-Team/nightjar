import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/features/setup/permissions_screen.dart';
import 'package:nightjar/theme/theme.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> pumpPermissions(
  WidgetTester tester,
  List<PermissionRowState> rows,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildNightjarTheme(),
      home: PermissionsScreen(rowsLoader: () async => rows),
    ),
  );
  await tester.pumpAndSettle();
}

PermissionRowState row({
  required String title,
  required String explanation,
  required Permission permission,
  required PermissionStatus status,
  bool fullAlert = false,
  bool recommended = false,
}) =>
    PermissionRowState(
      title: title,
      explanation: explanation,
      permission: permission,
      status: status,
      fullAlert: fullAlert,
      recommended: recommended,
    );

void main() {
  testWidgets('renders granted, denied, and not requested rows',
      (tester) async {
    await pumpPermissions(tester, [
      row(
        title: 'Microphone',
        explanation: 'Records 30 seconds when you trigger an alert.',
        permission: Permission.microphone,
        status: PermissionStatus.granted,
        fullAlert: true,
      ),
      row(
        title: 'SMS',
        explanation: 'Sends the alert text to your contacts.',
        permission: Permission.sms,
        status: PermissionStatus.permanentlyDenied,
        fullAlert: true,
      ),
      row(
        title: 'Location',
        explanation: 'Shares your position for 15 minutes.',
        permission: Permission.location,
        status: PermissionStatus.denied,
        fullAlert: true,
      ),
    ]);

    expect(find.text('Microphone'), findsOneWidget);
    expect(find.text('Granted'), findsOneWidget);
    expect(find.text('Denied'), findsOneWidget);
    expect(find.text('Not requested'), findsOneWidget);
    expect(find.text('Needed for a full alert'), findsNWidgets(3));
    expect(find.text('Allow'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('shows the recommended badge and the closing note',
      (tester) async {
    await pumpPermissions(tester, [
      row(
        title: 'Background location',
        explanation: 'Keeps sharing when the app is not on screen.',
        permission: Permission.locationAlways,
        status: PermissionStatus.denied,
        recommended: true,
      ),
      row(
        title: 'Notifications',
        explanation:
            'Android shows a small notification while an alert is active. '
            'It cannot be hidden.',
        permission: Permission.notification,
        status: PermissionStatus.denied,
      ),
    ]);

    expect(find.text('Recommended'), findsOneWidget);
    expect(
      find.text(
        'You can finish setup without these. The test alert will show '
        'what is missing.',
      ),
      findsOneWidget,
    );
    expect(find.text('Allow'), findsNWidgets(2));
  });

  testWidgets('the notification row explains the Android limit',
      (tester) async {
    await pumpPermissions(tester, [
      row(
        title: 'Notifications',
        explanation:
            'Android shows a small notification while an alert is active. '
            'It cannot be hidden.',
        permission: Permission.notification,
        status: PermissionStatus.granted,
      ),
    ]);
    expect(
      find.text(
        'Android shows a small notification while an alert is active. '
        'It cannot be hidden.',
      ),
      findsOneWidget,
    );
    expect(find.text('Allow'), findsNothing);
  });
}
