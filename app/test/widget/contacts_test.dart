import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/features/setup/contacts_screen.dart';
import 'package:nightjar/services/secure_store.dart';
import 'package:nightjar/theme/theme.dart';

Future<SetupStore> storeWith(List<Contact> contacts) async {
  final store = SetupStore(MemorySecretStore());
  await store.writeContacts(contacts);
  return store;
}

Future<void> pumpContacts(WidgetTester tester, SetupStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildNightjarTheme(),
      home: ContactsScreen(store: store),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('three empty slots are offered with the deck warnings',
      (tester) async {
    await pumpContacts(tester, await storeWith(const []));
    expect(find.text('Add contact'), findsNWidgets(3));
    expect(
      find.text(
        'Your contacts receive a normal text message. Their carrier and '
        'their phone can see it.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Add all three. If one number is wrong, that person will not get '
        'your alert.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('adding a contact stores E.164 and masks the number',
      (tester) async {
    final store = await storeWith(const []);
    await pumpContacts(tester, store);
    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Amal');
    await tester.enterText(find.byType(TextField).last, '+65 9123 4567');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = await store.readContacts();
    expect(saved, hasLength(1));
    expect(saved.single.name, 'Amal');
    expect(saved.single.phone, '+6591234567');
    expect(find.text('Amal'), findsOneWidget);
    expect(find.text(maskPhone('+6591234567')), findsOneWidget);
    expect(find.text('Add contact'), findsNWidgets(2));
  });

  testWidgets('an invalid number blocks save with the deck copy',
      (tester) async {
    final store = await storeWith(const []);
    await pumpContacts(tester, store);
    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Amal');
    await tester.enterText(find.byType(TextField).last, '12345');
    await tester.pump();
    final phoneField = tester.widget<TextField>(find.byType(TextField).last);
    expect(
      phoneField.decoration?.errorText,
      'Use the full number with country code.',
    );
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('save stays disabled until a name is present', (tester) async {
    await pumpContacts(tester, await storeWith(const []));
    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '+6591234567');
    await tester.pump();
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('a duplicate number is rejected', (tester) async {
    final store = await storeWith(
      const [Contact(name: 'Amal', phone: '+6591234567')],
    );
    await pumpContacts(tester, store);
    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Second');
    await tester.enterText(find.byType(TextField).last, '+6591234567');
    await tester.pump();
    expect(find.text('That number is already added.'), findsOneWidget);
  });

  testWidgets('editing a contact keeps its slot and updates the number',
      (tester) async {
    final store = await storeWith(
      const [Contact(name: 'Amal', phone: '+6591234567')],
    );
    await pumpContacts(tester, store);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '+6598765432');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    final saved = await store.readContacts();
    expect(saved.single.phone, '+6598765432');
  });

  testWidgets('removing a contact asks first', (tester) async {
    final store = await storeWith(const [
      Contact(name: 'Amal', phone: '+6591234567'),
      Contact(name: 'Bo', phone: '+6591234568'),
    ]);
    await pumpContacts(tester, store);
    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('Remove contact?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await store.readContacts(), hasLength(2));

    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    final remaining = await store.readContacts();
    expect(remaining, hasLength(1));
    expect(remaining.single.name, 'Bo');
  });
}
