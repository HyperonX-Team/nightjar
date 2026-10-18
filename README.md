# Nightjar

Android only. A covert safety utility that looks and works like a calculator.
A person in an unsafe situation types a secret PIN and presses equals, or
triple-taps the display. The app records 30 seconds of audio, shares location
for 15 minutes, and texts three trusted contacts a coordinate link and a
private page. No in-app history. Server data expires after 24 hours.

The source of truth for behavior is `SPEC.md`. Visual direction is `DESIGN.md`.
The goal and non-goals are in `GOAL.md`. Agent routing rules are in `AGENTS.md`.

## What is in the repository

```
app/            Flutter app (the calculator cover, hidden setup, alert pipeline)
web/contact/    Static contact page served at /i/<token>
rules-tests/    Firestore and Storage rules tests
docs/           SETUP.md (ships with the APK), THREAT-MODEL.md, VERIFICATION.md
anti-slop/      Design audit reports
firebase.json   Hosting rewrites, rules, emulator ports
firestore.rules, storage.rules, storage.lifecycle.json, firestore.indexes.json
```

## Build and test

```
cd app
flutter analyze
flutter test
flutter build apk --release --flavor prod
```

The release build fails when `android/key.properties` is missing, so an
unsigned or debug signed APK cannot be produced by accident. The keystore and
`key.properties` stay outside version control.

Local backends:

```
firebase emulators:start --only firestore,storage
cd app && flutter run --dart-define=USE_EMULATOR=true
```

Emulator ports are 8180 (Firestore), 9299 (Storage), 9298 (Auth), set in
`firebase.json` because the defaults were taken on the build machine.

Rules tests:

```
npx firebase-tools emulators:exec --only firestore,storage --project quiet-tally "npm --prefix rules-tests test"
```

## Firebase

Project `nightjar-8d561`. The values in `google-services.json` are wired into
`app/lib/firebase_options.dart`, the page config, and the SMS page domain.
`google-services.json` registers the Android package `com.hyperonx.nightjar`,
while the app ships as `com.tally.calculator` (SPEC 22.1). Register
`com.tally.calculator` and `com.tally.calculator.dev` in the Firebase console,
or use a `google-services.json` for the spec package, so API key restrictions
and console data stay consistent. The contact page needs its own Web app
registration for a web API key; see `web/contact/config.js`.

## Every known platform limit, stated plainly

- Android shows a foreground service notification while an alert runs. The
  channel is named Calculator and the text is neutral, but it cannot be hidden.
- Android 12 and later show a microphone privacy indicator. It cannot be
  suppressed.
- An app cannot delete a sent SMS unless it is the default SMS app. Nightjar
  does not request that role. The message stays on the recipient phone.
- If background location is denied, updates may stop when the app leaves the
  screen. The page shows the last fix and its age.
- Some manufacturer battery managers stop foreground services. Setup includes a
  battery step, and the app still cannot guarantee survival on every device.
- The contact page is readable by anyone who has the link. The link is a
  192 bit capability.
- Data is removed automatically after 24 hours by Firestore TTL and a Storage
  lifecycle rule. TTL removal is asynchronous and can take longer.

The app does not claim to be undetectable. It is built for a brief, discreet
action, not against a forensic adversary.

## Distribution

The MVP is a sideloaded APK. Google Play restricts covert surveillance and
background SMS, so Play distribution is out of scope. Distribution requires a
legal review for recording consent in the target jurisdiction, plus Terms and
Privacy pages. See `docs/SETUP.md` for the owner-facing setup steps and
`docs/VERIFICATION.md` for what has been verified and what has not.
