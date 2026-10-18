# Setup

This file ships with the APK. Read it before you rely on the app.

## Before you install

- The app is Android only, and it is not on the Play Store. You install the APK
  yourself.
- Android will warn about installing from an unknown source. That warning is
  normal for a sideloaded app.
- Your contacts receive a normal text message. Their carrier and their phone
  can see it, and it stays on their phone.
- Recording ambient audio may need consent where you live. You are responsible
  for that. This document is not legal advice.

## First run

1. Open the app. It is a working calculator. Nothing on the screen mentions
   safety.
2. Long press the AC key for 2 seconds. A medium vibration means the PIN screen
   opened. If nothing happens, the calculator simply cleared.
3. Create a PIN of 4 to 8 digits. Repeated digits (0000) and runs (1234, 4321)
   are rejected. There is no PIN recovery: if you forget it, reinstall the app
   and set everything up again.
4. Add all three contacts. Use the full number with country code, for example
   +6591234567. If one number is wrong, that person will not get your alert.
5. Work through the permission rows. The Microphone, Location, and SMS rows are
   needed for a full alert. Background location and the battery exemption make
   an alert survive the screen locking and your phone's battery manager.
6. Set the name that appears in the alert text. It shows as "a contact" if you
   leave it empty.
7. Press Send a test alert. This sends a real text to all three contacts and
   records 5 seconds of audio. The test link works for one hour. Tell your
   contacts it is a test.

## Triggering an alert

- Type your PIN on the calculator and press equals. The display clears and the
  phone gives one short vibration. There is no confirmation screen, by design.
- Or triple-tap the display quickly. This works without a PIN and can be turned
  off in setup.

Your contacts receive: Alert from {name}. Live location: {link} Details: {link}

## Stopping an alert

Type your PIN and press equals again while the alert is running. The display
clears. The page shows "This alert ended" with the last known location, because
a contact may already be on the way.

If the alert was a mistake and no text has been sent yet, no contact is
notified. If the text has already gone out, your contacts keep the link.

## What your phone will show

- A low importance notification named Calculator while an alert is running. It
  has no sound and no vibration, but it appears in the shade and in
  notification history.
- A microphone privacy indicator while the 30 seconds of audio is recorded.
- The app in Android Settings, including its permissions and battery use.

## Limits to plan around

- Data is removed automatically after 24 hours. Removal can take a little
  longer, because it runs asynchronously.
- Setup lives on the phone only. Uninstalling removes the PIN, the contacts,
  and any pending upload. There is no cloud backup.
- The SMS stays on your contact's phone. Nightjar keeps no message history and
  cannot delete a message it did not store.
- Some phones stop background work even with the battery exemption. Test a real
  alert on your own phone before you depend on it.
- If the phone has no signal, the alert page is created when the network comes
  back, and contacts may get a link that does not work yet.

## If you change your phone

Set the app up again from scratch: new PIN, same contacts, permissions, and a
new test alert. Alerts from the old phone expire on their own.
